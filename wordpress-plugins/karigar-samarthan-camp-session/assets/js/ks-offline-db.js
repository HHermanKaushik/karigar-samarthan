/**
 * Local-first storage for the camp-session flow: one IndexedDB database
 * for session info, karigars, and products (photos as Blobs). No network
 * calls here - ks-sync-engine.js handles that. Exposed as
 * `window.KsCampOfflineDB`.
 */
(function (global) {
  'use strict';

  const DB_NAME = 'kscamp_offline';
  const DB_VERSION = 1;

  let dbPromise = null;

  function openDb() {
    if (dbPromise) return dbPromise;

    dbPromise = new Promise((resolve, reject) => {
      const req = indexedDB.open(DB_NAME, DB_VERSION);

      req.onupgradeneeded = (event) => {
        const db = event.target.result;

        if (!db.objectStoreNames.contains('session')) {
          db.createObjectStore('session', { keyPath: 'id' });
        }
        if (!db.objectStoreNames.contains('karigars')) {
          db.createObjectStore('karigars', { keyPath: 'localId' });
        }
        if (!db.objectStoreNames.contains('products')) {
          const store = db.createObjectStore('products', { keyPath: 'localId' });
          store.createIndex('karigarLocalId', 'karigarLocalId', { unique: false });
          store.createIndex('status', 'status', { unique: false });
        }
      };

      req.onsuccess = () => resolve(req.result);
      req.onerror = () => reject(req.error);
    });

    return dbPromise;
  }

  function tx(storeName, mode) {
    return openDb().then((db) => db.transaction(storeName, mode).objectStore(storeName));
  }

  function reqToPromise(req) {
    return new Promise((resolve, reject) => {
      req.onsuccess = () => resolve(req.result);
      req.onerror = () => reject(req.error);
    });
  }

  function newLocalId() {
    if (global.crypto && global.crypto.randomUUID) {
      return global.crypto.randomUUID();
    }
    // Fallback for older WebViews without crypto.randomUUID.
    return 'kscamp-' + Date.now().toString(36) + '-' + Math.random().toString(36).slice(2, 10);
  }

  const KsCampOfflineDB = {
    newLocalId,

    // ---- Session (camp-level fields: location, camp_id, drive_name) ----

    async getSession() {
      const store = await tx('session', 'readonly');
      const result = await reqToPromise(store.get('current'));
      return result || { id: 'current', location: '', campId: '', driveName: '' };
    },

    async saveSession(fields) {
      const store = await tx('session', 'readwrite');
      const record = Object.assign({ id: 'current' }, fields, { updatedAt: Date.now() });
      await reqToPromise(store.put(record));
      return record;
    },

    // ---- Karigars ----

    async addKarigar({ name, village, craft }) {
      const store = await tx('karigars', 'readwrite');
      const record = {
        localId: newLocalId(),
        name,
        village,
        craft,
        createdAt: Date.now(),
      };
      await reqToPromise(store.add(record));
      return record;
    },

    async getKarigar(localId) {
      const store = await tx('karigars', 'readonly');
      return reqToPromise(store.get(localId));
    },

    async getAllKarigars() {
      const store = await tx('karigars', 'readonly');
      const all = await reqToPromise(store.getAll());
      return all.sort((a, b) => b.createdAt - a.createdAt);
    },

    // ---- Products ----

    async addProduct({ karigarLocalId, productName, price, photos }) {
      const store = await tx('products', 'readwrite');
      const record = {
        localId: newLocalId(),
        karigarLocalId,
        productName,
        price,
        photos: photos || [], // array of Blobs
        status: 'pending', // pending | syncing | synced | failed
        wooProductId: null,
        error: null,
        createdAt: Date.now(),
        syncedAt: null,
      };
      await reqToPromise(store.add(record));
      return record;
    },

    async getProductsByKarigar(karigarLocalId) {
      const store = await tx('products', 'readonly');
      const index = store.index('karigarLocalId');
      const all = await reqToPromise(index.getAll(karigarLocalId));
      return all.sort((a, b) => a.createdAt - b.createdAt);
    },

    async getAllProducts() {
      const store = await tx('products', 'readonly');
      const all = await reqToPromise(store.getAll());
      return all.sort((a, b) => a.createdAt - b.createdAt);
    },

    async getSyncableProducts() {
      const all = await this.getAllProducts();
      return all.filter((p) => p.status === 'pending' || p.status === 'failed');
    },

    async updateProduct(localId, changes) {
      const store = await tx('products', 'readwrite');
      const existing = await reqToPromise(store.get(localId));
      if (!existing) return null;
      const updated = Object.assign(existing, changes);
      await reqToPromise(store.put(updated));
      return updated;
    },

    async clearSyncedProducts() {
      const all = await this.getAllProducts();
      const store = await tx('products', 'readwrite');
      const synced = all.filter((p) => p.status === 'synced');
      for (const p of synced) {
        await reqToPromise(store.delete(p.localId));
      }
      return synced.length;
    },

    // ---- Aggregate summary for the queue UI ----

    async getSummary() {
      const products = await this.getAllProducts();
      const summary = { pending: 0, syncing: 0, synced: 0, failed: 0, total: products.length };
      for (const p of products) {
        summary[p.status] = (summary[p.status] || 0) + 1;
      }
      return summary;
    },
  };

  global.KsCampOfflineDB = KsCampOfflineDB;
})(window);
