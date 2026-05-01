// ── API HELPER ──────────────────────────────────────────────────────────────
const BASE = '';  // same origin

async function api(url, method='GET', body=null) {
  const opts = { method, headers: {'Content-Type':'application/json'} };
  if (body) opts.body = JSON.stringify(body);
  const res = await fetch(BASE + url, opts);
  return res.json();
}

// ── TOAST ────────────────────────────────────────────────────────────────────
function toast(msg, type='success') {
  let c = document.getElementById('toast-container');
  if (!c) { c = document.createElement('div'); c.id='toast-container'; document.body.appendChild(c); }
  const t = document.createElement('div');
  t.className = `toast ${type==='error'?'error':type==='warn'?'warn':''}`;
  t.textContent = msg;
  c.appendChild(t);
  setTimeout(()=>t.remove(), 3500);
}

// ── MODAL HELPERS ────────────────────────────────────────────────────────────
function openModal(id) {
  document.getElementById(id).classList.add('open');
}
function closeModal(id) {
  document.getElementById(id).classList.remove('open');
}
function closeOnOverlay(e) {
  if (e.target.classList.contains('modal-overlay')) closeModal(e.target.id);
}

// ── TABLE RENDER ─────────────────────────────────────────────────────────────
function renderTable(containerId, rows, columns, actions=[]) {
  const container = document.getElementById(containerId);
  if (!rows || rows.length === 0) {
    container.innerHTML = '<div class="empty" style="padding:20px;text-align:center;color:var(--muted)">No records found</div>';
    return;
  }
  let html = '<div class="table-wrap"><table><thead><tr>';
  columns.forEach(c => { html += `<th>${c.label}</th>`; });
  if (actions.length) html += '<th>Actions</th>';
  html += '</tr></thead><tbody>';
  rows.forEach(row => {
    html += '<tr>';
    columns.forEach(c => {
      let val = row[c.key] ?? '—';
      if (c.badge) val = `<span class="badge ${String(val).toLowerCase()}">${val}</span>`;
      if (c.status) val = `<span class="status-tag ${String(val).toLowerCase()}">${val}</span>`;
      if (c.format) val = c.format(row);
      html += `<td>${val}</td>`;
    });
    if (actions.length) {
      html += '<td>';
      actions.forEach(a => {
        html += `<button class="btn btn-sm ${a.cls||'btn-secondary'}" onclick="${a.fn}(${row[a.idKey||'id']})" style="margin-right:4px">${a.label}</button>`;
      });
      html += '</td>';
    }
    html += '</tr>';
  });
  html += '</tbody></table></div>';
  container.innerHTML = html;
}

// ── SEARCH FILTER ────────────────────────────────────────────────────────────
function filterTable(searchVal, rows, keys) {
  const q = searchVal.toLowerCase();
  return rows.filter(r => keys.some(k => String(r[k]||'').toLowerCase().includes(q)));
}

// ── DATE FORMAT ──────────────────────────────────────────────────────────────
function fmtDt(dt) {
  if (!dt) return '—';
  return new Date(dt).toLocaleString('en-IN', {
    dateStyle:'short', timeStyle:'short', timeZone:'Asia/Kolkata'
  });
}

// ── POPULATE SELECT ──────────────────────────────────────────────────────────
function populateSelect(selId, items, valKey, labelKey, placeholder='Select...') {
  const sel = document.getElementById(selId);
  if (!sel) return;
  sel.innerHTML = `<option value="">${placeholder}</option>`;
  items.forEach(i => {
    sel.innerHTML += `<option value="${i[valKey]}">${i[labelKey]}</option>`;
  });
}
