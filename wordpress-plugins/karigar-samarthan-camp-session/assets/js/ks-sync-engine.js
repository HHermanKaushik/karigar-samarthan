/**
 * Walks the local product queue and pushes each pending/failed item to
 * product-sync.php's AJAX endpoints. Each product syncs independently.
 * Requires ks-offline-db.js loaded first and the global `ksCampSession`
 * object from wp_localize_script.
 */
(function (global) {
  'use strict';

  const db = global.KsCampOfflineDB;
  let syncing = false;
  const listeners = [];

  function onSyncEvent(fn) {
    listeners.push(fn);
  }

  function emit(event) {
    for (const fn of listeners) {
      try { fn(event); } catch (_) { /* a listener error shouldn't break the sync loop */ }
    }
  }

  async function fetchFreshNonces() {
    const res = await fetch(global.ksCampSession.ajaxUrl, {
      method: 'POST',
      credentials: 'same-origin',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: 'action=kscamp_refresh_nonce',
    });
    const json = await res.json();
    if (!json || !json.success) {
      throw new Error('could_not_refresh_nonce');
    }
    return json.data;
  }

  async function createProductRemote(product, karigar, session, nonce) {
    const body = new URLSearchParams({
      action: 'kscamp_sync_product',
      _wpnonce: nonce,
      local_uuid: product.localId,
      product_name: product.productName,
      price: String(product.price),
      karigar_name: karigar.name,
      village: karigar.village || '',
      craft: karigar.craft,
      location: session.location || '',
      camp_id: session.campId || '',
      drive_name: session.driveName || '',
    });

    const res = await fetch(global.ksCampSession.ajaxUrl, {
      method: 'POST',
      credentials: 'same-origin',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: body.toString(),
    });
    const json = await res.json();
    if (!json || !json.success) {
      const message = (json && json.data && json.data.message) || 'sync_failed';
      throw new Error(message);
    }
    return json.data.product_id;
  }

  async function uploadPhotosRemote(productId, photos, nonce) {
    if (!photos || !photos.length) return [];

    const form = new FormData();
    form.append('action', 'kscamp_sync_photos');
    form.append('_wpnonce', nonce);
    form.append('product_id', String(productId));
    photos.forEach((blob, i) => {
      form.append('kscamp_photos[]', blob, `photo-${i}.jpg`);
    });

    const res = await fetch(global.ksCampSession.ajaxUrl, {
      method: 'POST',
      credentials: 'same-origin',
      body: form,
    });
    const json = await res.json();
    if (!json || !json.success) {
      const message = (json && json.data && json.data.message) || 'photo_sync_failed';
      throw new Error(message);
    }
    return json.data.attachment_ids;
  }

  async function syncOne(product, session) {
    const karigar = await db.getKarigar(product.karigarLocalId);
    if (!karigar) {
      await db.updateProduct(product.localId, { status: 'failed', error: 'karigar_record_missing' });
      return;
    }

    await db.updateProduct(product.localId, { status: 'syncing', error: null });
    emit({ type: 'product-syncing', product });

    try {
      const nonces = await fetchFreshNonces();

      const productId = await createProductRemote(
        product,
        karigar,
        session,
        nonces.kscamp_submit_nonce
      );

      if (product.photos && product.photos.length) {
        await uploadPhotosRemote(productId, product.photos, nonces.kscamp_photo_nonce);
      }

      await db.updateProduct(product.localId, {
        status: 'synced',
        wooProductId: productId,
        syncedAt: Date.now(),
        error: null,
      });
      emit({ type: 'product-synced', product });
    } catch (err) {
      await db.updateProduct(product.localId, { status: 'failed', error: String(err.message || err) });
      emit({ type: 'product-failed', product, error: err });
    }
  }

  /**
   * navigator.onLine doesn't guarantee the site is reachable - a cheap
   * probe first avoids marking a whole batch "failed" from one doomed
   * attempt.
   */
  async function isReachable() {
    if (!navigator.onLine) return false;
    try {
      const res = await fetch(global.ksCampSession.ajaxUrl + '?action=kscamp_refresh_nonce', {
        method: 'HEAD',
        credentials: 'same-origin',
        cache: 'no-store',
      });
      return res.ok || res.status === 400 || res.status === 405;
    } catch (_) {
      return false;
    }
  }

  async function syncAll() {
    if (syncing) return;
    if (!(await isReachable())) return;

    syncing = true;
    emit({ type: 'sync-start' });
    try {
      const session = await db.getSession();
      const queue = await db.getSyncableProducts();
      for (const product of queue) {
        await syncOne(product, session);
      }
    } finally {
      syncing = false;
      emit({ type: 'sync-end' });
    }
  }

  global.addEventListener('online', () => { syncAll(); });

  // Periodic fallback - the 'online' event isn't always reliable on mobile.
  setInterval(() => { syncAll(); }, 30000);

  global.KsCampSyncEngine = { syncAll, onSyncEvent, isReachable };
})(window);
