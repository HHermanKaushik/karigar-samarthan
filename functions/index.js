const functions = require("firebase-functions");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, Timestamp } = require("firebase-admin/firestore");
const crypto = require("crypto");

initializeApp();

// ── Shared constants ──────────────────────────────────────────────────────────

const WOO_BASE = "https://jstrust.in/wp-json/wc/v3";
const WOO_KEY  = "ck_e032198dba74f0dcb29465c666f15a39303758e5";
const WOO_SEC  = "cs_86014fba07077c5c60e3248ad5a1dc6bd5393889";

const STATUS_MAP = {
  pending:    "placed",
  "on-hold":  "placed",
  processing: "paid",
  completed:  "delivered",
  cancelled:  "placed",
  refunded:   "placed",
  failed:     "placed",
};

// ── testWoo ───────────────────────────────────────────────────────────────────

exports.testWoo = functions.https.onRequest(async (req, res) => {
  try {
    const wooUrl =
      `${WOO_BASE}/products?consumer_key=${WOO_KEY}&consumer_secret=${WOO_SEC}`;

    const { title, description, price } = req.body;

    const axios = require("axios");
    const response = await axios.post(wooUrl, {
      name: title,
      description: description,
      regular_price: price,
      status: "publish",
    });

    res.status(200).send(response.data);
  } catch (error) {
    console.error(error.response?.data || error.message);
    res.status(500).send(error.response?.data || error.message);
  }
});

// ── wooOrderWebhook ───────────────────────────────────────────────────────────
//
// Receives WooCommerce webhooks for order.created and order.updated.
// Reads _ks_karigar_uid from order meta (written by the WP plugin at checkout)
// and upserts the order into Firestore so the Flutter app sees it in real time.
//
// Setup:
//   1. Deploy: firebase deploy --only functions --project karigar-samarthan
//   2. WooCommerce → Settings → Advanced → Webhooks → Add webhook (x2):
//        Topic: Order created / Order updated
//        Delivery URL: <function URL>/wooOrderWebhook
//        Secret: set WOO_WEBHOOK_SECRET env var (optional but recommended)

exports.wooOrderWebhook = functions.https.onRequest(async (req, res) => {
  if (req.method !== "POST") return res.status(405).send("Method Not Allowed");

  const secret = process.env.WOO_WEBHOOK_SECRET || "";
  if (secret) {
    const sig = req.headers["x-wc-webhook-signature"] || "";
    const expected = crypto
      .createHmac("sha256", secret)
      .update(req.rawBody)
      .digest("base64");
    if (sig !== expected) {
      functions.logger.warn("wooOrderWebhook: invalid signature — rejected");
      return res.status(401).send("Unauthorized");
    }
  }

  const order = req.body;
  if (!order || !order.id) return res.status(400).send("Invalid payload");

  const meta = Array.isArray(order.meta_data) ? order.meta_data : [];
  const karigarUid = meta.find((m) => m.key === "_ks_karigar_uid")?.value || "";

  if (!karigarUid) {
    functions.logger.info(`Order ${order.id}: no _ks_karigar_uid, skipped`);
    return res.status(200).send("OK");
  }

  const firstItem = (order.line_items || [])[0] || {};

  const orderDoc = {
    productTitle: firstItem.name || "Order",
    productImage: firstItem.image?.src || null,
    quantity: firstItem.quantity || 1,
    total: parseFloat(order.total) || 0,
    placedAt: Timestamp.fromDate(new Date(order.date_created || Date.now())),
    status: STATUS_MAP[order.status] || "placed",
    customerName: [order.billing?.first_name, order.billing?.last_name]
      .filter(Boolean).join(" ").trim() || "Customer",
    shippingAddress: [
      order.shipping?.address_1, order.shipping?.address_2,
      order.shipping?.city, order.shipping?.state, order.shipping?.postcode,
    ].filter(Boolean).join(", "),
    customerPhone: order.billing?.phone || "",
    wooOrderId: order.id,
    upiUtr: meta.find((m) => m.key === "_ks_upi_utr")?.value || "",
    wooStatus: order.status,
  };

  try {
    const db = getFirestore("karigar");
    await db
      .collection("users").doc(karigarUid)
      .collection("orders").doc(String(order.id))
      .set(orderDoc, { merge: true });

    functions.logger.info(
      `Order ${order.id} (${order.status}) → users/${karigarUid}/orders`
    );
    return res.status(200).send("OK");
  } catch (err) {
    functions.logger.error("wooOrderWebhook: Firestore write failed", err);
    return res.status(500).send("Internal error");
  }
});

// ── backfillOrders ────────────────────────────────────────────────────────────
//
// Correctly attributes each WooCommerce order to an artisan by:
//   1. Checking _ks_karigar_uid in the WooCommerce order meta (newer orders)
//   2. Cross-referencing the order's line item product IDs against each artisan's
//      Firestore products sub-collection (users/{uid}/products[].wooId)
//
// Also deletes stale Firestore orders that no longer belong to an artisan
// (cleans up any previously incorrect backfill runs).
//
// Usage:
//   curl -X POST <URL>/backfillOrders \
//        -H "x-backfill-token: karigar-backfill" \
//        -H "Content-Type: application/json" \
//        -d '{"karigarUid":"<uid>"}'   ← optional; omit to sync all artisans

exports.backfillOrders = functions.https.onRequest(async (req, res) => {
  if (req.method !== "POST") return res.status(405).send("POST only");

  const token = req.headers["x-backfill-token"] || "";
  if (token !== "karigar-backfill") return res.status(401).send("Unauthorized");

  const axios = require("axios");
  const db = getFirestore("karigar");

  try {
    // ── Step 1: Build wooProductId → karigarUid map from Firestore ────────────

    const targetUid = req.body?.karigarUid || null;
    const wooIdToKarigarUid = {};

    let artisanEntries;
    if (targetUid) {
      const snap = await db.collection("users").doc(targetUid).collection("products").get();
      artisanEntries = [{ uid: targetUid, snap }];
    } else {
      const usersSnap = await db.collection("users").get();
      artisanEntries = await Promise.all(
        usersSnap.docs.map(async (u) => ({
          uid: u.id,
          snap: await db.collection("users").doc(u.id).collection("products").get(),
        }))
      );
    }

    for (const { uid, snap } of artisanEntries) {
      for (const doc of snap.docs) {
        const wooId = doc.data().wooId;
        if (wooId) wooIdToKarigarUid[wooId] = uid;
      }
    }

    functions.logger.info(
      `backfillOrders: tracking ${Object.keys(wooIdToKarigarUid).length} products`
    );

    // ── Step 2: Fetch all WooCommerce orders ──────────────────────────────────

    const allOrders = [];
    let page = 1;
    while (true) {
      const { data: orders } = await axios.get(`${WOO_BASE}/orders`, {
        params: { consumer_key: WOO_KEY, consumer_secret: WOO_SEC, per_page: 100, page },
      });
      if (!orders?.length) break;
      allOrders.push(...orders);
      if (orders.length < 100) break;
      page++;
    }

    // ── Step 3: Attribute each order to a karigar ─────────────────────────────

    const karigarOrderDocs = {}; // { uid: { wooOrderId: docData } }

    for (const order of allOrders) {
      const meta = Array.isArray(order.meta_data) ? order.meta_data : [];

      // Priority 1: _ks_karigar_uid already on the order (set by WP plugin)
      let karigarUid = meta.find((m) => m.key === "_ks_karigar_uid")?.value || null;

      // Priority 2: look up the ordered product's owner in our Firestore map
      if (!karigarUid) {
        for (const item of order.line_items || []) {
          karigarUid = wooIdToKarigarUid[item.product_id] || null;
          if (karigarUid) break;
        }
      }

      if (!karigarUid) continue;
      if (targetUid && karigarUid !== targetUid) continue;

      const firstItem = order.line_items?.[0] || {};

      if (!karigarOrderDocs[karigarUid]) karigarOrderDocs[karigarUid] = {};
      karigarOrderDocs[karigarUid][String(order.id)] = {
        productTitle: firstItem.name || "Order",
        productImage: firstItem.image?.src || null,
        quantity: firstItem.quantity || 1,
        total: parseFloat(order.total) || 0,
        placedAt: Timestamp.fromDate(new Date(order.date_created || Date.now())),
        status: STATUS_MAP[order.status] || "placed",
        customerName: [order.billing?.first_name, order.billing?.last_name]
          .filter(Boolean).join(" ").trim() || "Customer",
        shippingAddress: [
          order.shipping?.address_1, order.shipping?.address_2,
          order.shipping?.city, order.shipping?.state, order.shipping?.postcode,
        ].filter(Boolean).join(", "),
        customerPhone: order.billing?.phone || "",
        wooOrderId: order.id,
        upiUtr: meta.find((m) => m.key === "_ks_upi_utr")?.value || "",
        wooStatus: order.status,
      };
    }

    // ── Step 4: Write correct orders; delete stale ones ───────────────────────

    let synced = 0;
    let deleted = 0;

    // Upsert matching orders and remove any extras for each matched karigar
    for (const [uid, correctOrders] of Object.entries(karigarOrderDocs)) {
      const collRef = db.collection("users").doc(uid).collection("orders");
      const existingSnap = await collRef.get();
      const correctIds = new Set(Object.keys(correctOrders));

      for (const doc of existingSnap.docs) {
        if (!correctIds.has(doc.id)) {
          await doc.ref.delete();
          deleted++;
        }
      }
      for (const [orderId, data] of Object.entries(correctOrders)) {
        await collRef.doc(orderId).set(data, { merge: true });
        synced++;
      }
    }

    // For artisans that had orders before but have NONE now, delete all their orders
    const knownUids = new Set(Object.keys(karigarOrderDocs));
    for (const { uid } of artisanEntries) {
      if (knownUids.has(uid)) continue;
      const ordersSnap = await db.collection("users").doc(uid).collection("orders").get();
      for (const doc of ordersSnap.docs) {
        await doc.ref.delete();
        deleted++;
      }
    }

    functions.logger.info(
      `backfillOrders complete: synced=${synced} deleted=${deleted} wooTotal=${allOrders.length}`
    );
    return res.status(200).json({ synced, deleted, total: allOrders.length });
  } catch (err) {
    functions.logger.error("backfillOrders failed", err.message);
    return res.status(500).send(err.message);
  }
});
