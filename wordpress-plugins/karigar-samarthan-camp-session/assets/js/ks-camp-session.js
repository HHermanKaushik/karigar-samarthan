/**
 * UI controller for the [ks_camp_entry] shortcode. Talks only to
 * KsCampOfflineDB for storage - never calls fetch() itself.
 *
 *   1. Start camp session - location / camp ID / drive name, once
 *   2. Karigar list        - "start new karigar" + today's list
 *   3. Active karigar       - add products (+ photos)
 *
 * Active karigar ID lives in localStorage (not IndexedDB - it's
 * ephemeral UI state) so reopening the page mid-day resumes where the
 * volunteer left off.
 */
(function () {
  'use strict';

  const db = window.KsCampOfflineDB;
  const sync = window.KsCampSyncEngine;
  const ACTIVE_KARIGAR_KEY = 'kscamp_active_karigar_local_id';

  const root = document.getElementById('kscamp-root');
  if (!root) return;

  function h(html) {
    const t = document.createElement('template');
    t.innerHTML = html.trim();
    return t.content.firstElementChild;
  }

  function esc(str) {
    const d = document.createElement('div');
    d.textContent = str == null ? '' : String(str);
    return d.innerHTML;
  }

  function statusPillClass(status) {
    return {
      pending: 'kscamp-pill-pending',
      syncing: 'kscamp-pill-syncing',
      synced: 'kscamp-pill-synced',
      failed: 'kscamp-pill-failed',
    }[status] || 'kscamp-pill-pending';
  }

  async function render() {
    const session = await db.getSession();

    if (!session.location && !session.campId && !session.driveName) {
      renderSessionForm(session);
      return;
    }

    const activeKarigarId = localStorage.getItem(ACTIVE_KARIGAR_KEY);
    if (activeKarigarId) {
      const karigar = await db.getKarigar(activeKarigarId);
      if (karigar) {
        renderActiveKarigar(session, karigar);
        return;
      }
      localStorage.removeItem(ACTIVE_KARIGAR_KEY);
    }

    renderKarigarList(session);
  }

  // ---------------------------------------------------------------------
  // Screen 1: camp session details (asked once)
  // ---------------------------------------------------------------------

  function renderSessionForm(session) {
    root.innerHTML = '';
    root.appendChild(h(`
      <div class="kscamp-card">
        <h2>Start Camp Session</h2>
        <p class="kscamp-hint">These details apply to every karigar and product you add today.</p>
        <form id="kscamp-session-form">
          <label>Drive / camp name
            <input type="text" name="driveName" value="${esc(session.driveName)}" required>
          </label>
          <label>Camp ID
            <input type="text" name="campId" value="${esc(session.campId)}">
          </label>
          <label>Location
            <input type="text" name="location" value="${esc(session.location)}" required>
          </label>
          <button type="submit" class="kscamp-btn-primary">Start session</button>
        </form>
      </div>
    `));

    document.getElementById('kscamp-session-form').addEventListener('submit', async (e) => {
      e.preventDefault();
      const fd = new FormData(e.target);
      await db.saveSession({
        driveName: fd.get('driveName').trim(),
        campId: fd.get('campId').trim(),
        location: fd.get('location').trim(),
      });
      render();
    });
  }

  // ---------------------------------------------------------------------
  // Screen 2: today's karigars + start a new one
  // ---------------------------------------------------------------------

  async function renderKarigarList(session) {
    root.innerHTML = '';
    const karigars = await db.getAllKarigars();

    const container = h(`
      <div>
        <div class="kscamp-card kscamp-session-banner">
          <strong>${esc(session.driveName)}</strong> — ${esc(session.location)}
          <button type="button" class="kscamp-btn-link" id="kscamp-edit-session">edit</button>
        </div>

        <div class="kscamp-card">
          <h2>Start a new karigar</h2>
          <form id="kscamp-karigar-form">
            <label>Karigar name
              <input type="text" name="name" required>
            </label>
            <label>Village
              <input type="text" name="village">
            </label>
            <label>Craft
              <input type="text" name="craft" required>
            </label>
            <button type="submit" class="kscamp-btn-primary">Start karigar →</button>
          </form>
        </div>

        <div id="kscamp-karigar-list"></div>
        ${queueSummaryMarkup()}
      </div>
    `);
    root.appendChild(container);

    await renderKarigarListItems(karigars);
    await refreshQueueSummary();
    wireQueueSummaryControls();

    document.getElementById('kscamp-edit-session').addEventListener('click', async () => {
      await db.saveSession({ location: '', campId: '', driveName: '' });
      render();
    });

    document.getElementById('kscamp-karigar-form').addEventListener('submit', async (e) => {
      e.preventDefault();
      const fd = new FormData(e.target);
      const karigar = await db.addKarigar({
        name: fd.get('name').trim(),
        village: fd.get('village').trim(),
        craft: fd.get('craft').trim(),
      });
      localStorage.setItem(ACTIVE_KARIGAR_KEY, karigar.localId);
      render();
    });
  }

  async function renderKarigarListItems(karigars) {
    const listEl = document.getElementById('kscamp-karigar-list');
    if (!karigars.length) {
      listEl.innerHTML = '<p class="kscamp-hint">No karigars added yet today.</p>';
      return;
    }

    listEl.innerHTML = '<h3>Today so far</h3>';
    for (const k of karigars) {
      const products = await db.getProductsByKarigar(k.localId);
      const row = h(`
        <button type="button" class="kscamp-karigar-row" data-id="${esc(k.localId)}">
          <span class="kscamp-karigar-row-name">${esc(k.name)}</span>
          <span class="kscamp-karigar-row-meta">${esc(k.craft)} · ${products.length} product${products.length === 1 ? '' : 's'}</span>
        </button>
      `);
      row.addEventListener('click', () => {
        localStorage.setItem(ACTIVE_KARIGAR_KEY, k.localId);
        render();
      });
      listEl.appendChild(row);
    }
  }

  // ---------------------------------------------------------------------
  // Screen 3: active karigar - add products
  // ---------------------------------------------------------------------

  async function renderActiveKarigar(session, karigar) {
    root.innerHTML = '';
    const products = await db.getProductsByKarigar(karigar.localId);

    const container = h(`
      <div>
        <div class="kscamp-card kscamp-session-banner">
          <strong>${esc(karigar.name)}</strong> — ${esc(karigar.craft)}${karigar.village ? ' · ' + esc(karigar.village) : ''}
          <button type="button" class="kscamp-btn-link" id="kscamp-done-karigar">done with this karigar</button>
        </div>

        <div class="kscamp-card">
          <h2>Add a product</h2>
          <form id="kscamp-product-form">
            <label>Product name
              <input type="text" name="productName" required>
            </label>
            <label>Price (₹)
              <input type="number" name="price" min="0" step="1" required>
            </label>
            <label>Photos
              <input type="file" name="photos" accept="image/*" multiple>
            </label>
            <button type="submit" class="kscamp-btn-primary">Add product</button>
          </form>
        </div>

        <div id="kscamp-product-list"></div>
        ${queueSummaryMarkup()}
      </div>
    `);
    root.appendChild(container);

    renderProductListItems(products);
    await refreshQueueSummary();
    wireQueueSummaryControls();

    document.getElementById('kscamp-done-karigar').addEventListener('click', () => {
      localStorage.removeItem(ACTIVE_KARIGAR_KEY);
      render();
    });

    document.getElementById('kscamp-product-form').addEventListener('submit', async (e) => {
      e.preventDefault();
      const form = e.target;
      const fd = new FormData(form);
      const fileInput = form.querySelector('input[name="photos"]');
      const photos = fileInput.files ? Array.from(fileInput.files) : [];

      await db.addProduct({
        karigarLocalId: karigar.localId,
        productName: fd.get('productName').trim(),
        price: parseFloat(fd.get('price')) || 0,
        photos,
      });

      form.reset();
      const products = await db.getProductsByKarigar(karigar.localId);
      renderProductListItems(products);
      await refreshQueueSummary();
      sync.syncAll();
    });
  }

  function renderProductListItems(products) {
    const listEl = document.getElementById('kscamp-product-list');
    if (!products.length) {
      listEl.innerHTML = '<p class="kscamp-hint">No products added for this karigar yet.</p>';
      return;
    }

    listEl.innerHTML = '<h3>Products for this karigar</h3>';
    for (const p of products) {
      listEl.appendChild(h(`
        <div class="kscamp-product-row" data-local-id="${esc(p.localId)}">
          <span class="kscamp-product-row-name">${esc(p.productName)} — ₹${esc(p.price)}</span>
          <span class="kscamp-pill ${statusPillClass(p.status)}">${esc(p.status)}</span>
        </div>
      `));
    }
  }

  // ---------------------------------------------------------------------
  // Shared: queue summary bar + sync controls (present on every screen)
  // ---------------------------------------------------------------------

  function queueSummaryMarkup() {
    return `
      <div class="kscamp-card kscamp-queue-summary" id="kscamp-queue-summary">
        <span id="kscamp-queue-counts">…</span>
        <span id="kscamp-conn-indicator" class="kscamp-conn-indicator">checking…</span>
        <button type="button" class="kscamp-btn-secondary" id="kscamp-sync-now">Sync now</button>
      </div>
    `;
  }

  async function refreshQueueSummary() {
    const el = document.getElementById('kscamp-queue-counts');
    if (!el) return;
    const s = await db.getSummary();
    el.textContent = `${s.total} total · ${s.pending} pending · ${s.syncing} syncing · ${s.synced} synced` +
      (s.failed ? ` · ${s.failed} failed` : '');

    const connEl = document.getElementById('kscamp-conn-indicator');
    if (connEl) {
      const reachable = await sync.isReachable();
      connEl.textContent = reachable ? 'online' : 'offline — saved on device';
      connEl.className = 'kscamp-conn-indicator ' + (reachable ? 'kscamp-conn-online' : 'kscamp-conn-offline');
    }
  }

  function wireQueueSummaryControls() {
    const btn = document.getElementById('kscamp-sync-now');
    if (btn) {
      btn.addEventListener('click', () => sync.syncAll());
    }
  }

  sync.onSyncEvent((event) => {
    refreshQueueSummary();

    // Patch the row in place - a full render() here would blow away
    // whatever the volunteer is mid-typing into the next product form.
    if (event.product) {
      const row = document.querySelector(
        `.kscamp-product-row[data-local-id="${event.product.localId}"] .kscamp-pill`
      );
      if (row) {
        const status = event.type === 'product-syncing' ? 'syncing'
          : event.type === 'product-synced' ? 'synced'
          : event.type === 'product-failed' ? 'failed'
          : row.textContent;
        row.textContent = status;
        row.className = 'kscamp-pill ' + statusPillClass(status);
      }
    }
  });

  render();
})();
