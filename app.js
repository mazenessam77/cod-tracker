const API_BASE = '/api/achievements';

const achievementForm = document.getElementById('achievement-form');
const titleInput      = document.getElementById('input-title');
const mapInput        = document.getElementById('input-map');
const killsInput      = document.getElementById('input-kills');
const notesInput      = document.getElementById('input-notes');
const tableBody       = document.getElementById('achievements-body');
const toastContainer  = document.getElementById('toast-container');
const statTotal       = document.getElementById('stat-total');
const statKills       = document.getElementById('stat-kills');
const statMaps        = document.getElementById('stat-maps');

let achievements = [];

// ── API Calls ──────────────────────────────────────────

async function fetchAchievements() {
  showLoading();
  try {
    const res = await fetch(API_BASE);
    if (!res.ok) throw new Error(res.status);
    achievements = await res.json();
    renderTable();
    updateStats();
  } catch (err) {
    console.error('Fetch error:', err);
    showToast('Could not load achievements. Is the server running?', 'error');
    renderEmpty('Unable to connect to server');
  }
}

async function createAchievement(data) {
  try {
    const res = await fetch(API_BASE, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data),
    });
    if (!res.ok) throw new Error(res.status);
    const created = await res.json();
    achievements.unshift(created);
    renderTable();
    updateStats();
    showToast('Achievement logged!');
    return created;
  } catch (err) {
    console.error('Create error:', err);
    showToast('Failed to save achievement.', 'error');
    return null;
  }
}

async function deleteAchievement(id) {
  try {
    const res = await fetch(`${API_BASE}/${id}`, { method: 'DELETE' });
    if (!res.ok) throw new Error(res.status);
    achievements = achievements.filter(a => (a.id ?? a._id) !== id);
    renderTable();
    updateStats();
    showToast('Achievement removed.');
  } catch (err) {
    console.error('Delete error:', err);
    showToast('Failed to delete.', 'error');
  }
}

// ── Rendering ──────────────────────────────────────────

function escapeHTML(str) {
  const d = document.createElement('div');
  d.textContent = str;
  return d.innerHTML;
}

function formatDate(ds) {
  return new Date(ds).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
}

function renderTable() {
  if (!achievements.length) { renderEmpty(); return; }

  tableBody.innerHTML = achievements.map((a, i) => {
    const id = a.id ?? a._id ?? i;
    const title = escapeHTML(a.title || '—');
    const map = escapeHTML(a.map || a.mapMode || '—');
    const kills = a.kills ?? 0;
    const notes = escapeHTML(a.notes || '');
    const date = a.createdAt ? formatDate(a.createdAt) : '—';
    return `<tr class="row-enter" style="animation-delay:${i * 50}ms">
      <td class="cell-title">${title}</td>
      <td><span class="map-tag">${map}</span></td>
      <td><span class="kills-badge">💀 ${kills}</span></td>
      <td class="cell-notes" title="${notes}">${notes || '—'}</td>
      <td class="cell-date">${date}</td>
      <td><button class="btn-delete" data-id="${id}">✕</button></td>
    </tr>`;
  }).join('');

  tableBody.querySelectorAll('.btn-delete').forEach(btn => {
    btn.addEventListener('click', () => deleteAchievement(btn.dataset.id));
  });
}

function renderEmpty(msg) {
  tableBody.innerHTML = `<tr><td colspan="6"><div class="empty-state">
    <div class="empty-icon">🎯</div>
    <p>${msg || 'No achievements logged yet.<br>Drop your first entry above!'}</p>
  </div></td></tr>`;
}

function showLoading() {
  tableBody.innerHTML = `<tr><td colspan="6"><div class="spinner"></div></td></tr>`;
}

// ── Stats ──────────────────────────────────────────────

function updateStats() {
  const total = achievements.length;
  const totalKills = achievements.reduce((s, a) => s + (Number(a.kills) || 0), 0);
  const maps = new Set(achievements.map(a => (a.map || a.mapMode || '').toLowerCase()).filter(Boolean));
  animateCounter(statTotal, total);
  animateCounter(statKills, totalKills);
  animateCounter(statMaps, maps.size);
}

function animateCounter(el, target) {
  const current = parseInt(el.textContent) || 0;
  if (current === target) return;
  const duration = 500, start = performance.now();
  function tick(now) {
    const p = Math.min((now - start) / duration, 1);
    el.textContent = Math.round(current + (target - current) * (1 - Math.pow(1 - p, 3)));
    if (p < 1) requestAnimationFrame(tick);
  }
  requestAnimationFrame(tick);
}

// ── Form ───────────────────────────────────────────────

achievementForm.addEventListener('submit', async (e) => {
  e.preventDefault();
  const title = titleInput.value.trim();
  if (!title) { showToast('Title is required.', 'error'); titleInput.focus(); return; }
  const payload = {
    title,
    map: mapInput.value.trim(),
    kills: parseInt(killsInput.value, 10) || 0,
    notes: notesInput.value.trim(),
  };
  const result = await createAchievement(payload);
  if (result) { achievementForm.reset(); titleInput.focus(); }
});

// ── Toast ──────────────────────────────────────────────

function showToast(message, type = 'success') {
  const t = document.createElement('div');
  t.className = `toast ${type === 'error' ? 'error' : ''}`;
  t.textContent = message;
  toastContainer.appendChild(t);
  setTimeout(() => {
    t.classList.add('toast-exit');
    t.addEventListener('animationend', () => t.remove());
  }, 3500);
}

// ── Init ───────────────────────────────────────────────

document.addEventListener('DOMContentLoaded', fetchAchievements);
