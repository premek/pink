let tests = [];
let statusFilter = 'all';
let gitFilter = false;
let selected = null;

async function init() {
  tests = await fetch('/api/tests').then(r => r.json());
  renderList();
  const fromHash = decodeURIComponent(location.hash.slice(1));
  if (fromHash && tests.find(x => x.name === fromHash)) {
    selectTest(fromHash);
  }
}

function renderList() {
  const pass = tests.filter(t => t.status === 'pass').length;
  document.getElementById('pass-count').textContent = `${pass}/${tests.length} passing`;
  const q = document.getElementById('search').value;
  let searchRe = null;
  if (q) { try { searchRe = new RegExp(q, 'i'); } catch { searchRe = null; } }
  const list = document.getElementById('test-list');
  list.innerHTML = '';
  for (const t of tests) {
    if (statusFilter !== 'all' && t.status !== statusFilter) continue;
    if (gitFilter && !t.gitModified) continue;
    if (q && !(searchRe ? searchRe.test(t.name) : t.name.toLowerCase().includes(q.toLowerCase()))) continue;
    const el = document.createElement('div');
    el.className = 'test-item' + (selected === t.name ? ' selected' : '');
    el.dataset.name = t.name;
    el.innerHTML = `<span class="dot ${t.status}"></span><span>${t.name}</span>${t.gitModified ? '<span class="git-m">M</span>' : ''}`;
    el.onclick = () => selectTest(t.name);
    list.appendChild(el);
  }
}

function setStatusFilter(s) {
  statusFilter = s;
  document.querySelectorAll('.filter-btn').forEach(b => {
    b.classList.toggle('active', b.dataset.status === s);
  });
  renderList();
}

function toggleGitFilter() {
  gitFilter = !gitFilter;
  document.getElementById('git-filter-btn').classList.toggle('active', gitFilter);
  renderList();
}

function applyFilters() { renderList(); }

async function selectTest(name) {
  selected = name;
  location.hash = name;
  renderList();
  document.getElementById('placeholder').style.display = 'none';
  document.getElementById('right-content').style.display = 'flex';
  document.getElementById('right-content').style.flexDirection = 'column';
  document.getElementById('right-content').style.gap = '8px';
  document.getElementById('test-title').textContent = name;
  document.getElementById('run-result').style.display = 'none';
  document.getElementById('add-file-row').style.display = 'flex';
  document.getElementById('new-file-name').value = '';
  const t = tests.find(x => x.name === name);
  updateStatusBadge(t ? t.status : 'unknown');
  await loadFiles(name, t ? t.files : []);
}

function updateStatusBadge(status) {
  const b = document.getElementById('status-badge');
  b.className = 'badge ' + status;
  b.textContent = status;
}

async function loadFiles(name, files) {
  const preferred = ['story.ink', 'input.txt', 'transcript.txt'];
  const ordered = [
    ...preferred.filter(f => files.includes(f)),
    ...files.filter(f => !preferred.includes(f))
  ];
  const container = document.getElementById('file-sections');
  container.innerHTML = '';
  const gsResp = await fetch(`/api/tests/${name}/gitstatus`);
  const gs = await gsResp.json();
  const gitFiles = gs.files || {};
  for (const f of ordered) {
    await appendFileSection(container, name, f, gitFiles[f] || null);
  }
}

async function appendFileSection(container, name, f, gitStatus) {
  const resp = await fetch(`/api/tests/${name}/files/${f}`);
  const content = await resp.text();
  const det = document.createElement('details');
  det.open = true;
  det.dataset.filename = f;
  const isModified = gitStatus && gitStatus !== '??';
  const isUntracked = gitStatus === '??';
  const modBadge = isModified ? `<span class="git-badge modified">M</span>`
                 : isUntracked ? `<span class="git-badge untracked">new</span>` : '';
  const restoreBtn = isModified
    ? `<button data-restore onclick="restoreFile('${escHtml(name)}','${escHtml(f)}',this)">Restore</button>` : '';
  det.innerHTML = `
    <summary>${escHtml(f)}${modBadge}</summary>
    <div class="file-body">
      <div class="file-actions">
        <button onclick="saveFile('${escHtml(name)}','${escHtml(f)}',this)" title="Ctrl-S">Save</button>
        ${restoreBtn}
        ${f === 'transcript.txt' ? `<button id="regen-btn" onclick="regenTranscript()">Regenerate</button>` : ''}
        <span class="save-status"></span>
      </div>
      <div class="editor-wrap">
        <div class="line-nums"></div>
        <textarea data-file="${escHtml(f)}" rows="${Math.min(Math.max(content.split('\n').length + 1, 3), 30)}"></textarea>
      </div>
    </div>`;
  det.querySelector('textarea').value = content;
  container.appendChild(det);
  initEditor(det.querySelector('textarea'));
}

async function restoreFile(name, file, btn) {
  const det = btn.closest('details');
  const ta = det.querySelector('textarea');
  const statusEl = det.querySelector('.save-status');
  const resp = await fetch(`/api/tests/${name}/files/${encodeURIComponent(file)}/restore`, {method: 'POST'});
  const data = await resp.json();
  if (data.ok) {
    ta.value = data.content;
    updateLineNums(ta);
    det.querySelector('.git-badge.modified')?.remove();
    btn.remove();
    if (statusEl) { statusEl.textContent = 'restored'; setTimeout(() => { statusEl.textContent = ''; }, 2000); }
    const gsResp = await fetch(`/api/tests/${name}/gitstatus`);
    const gs = await gsResp.json();
    const t = tests.find(x => x.name === name);
    if (t) { t.gitModified = Object.values(gs.files || {}).some(s => s); renderList(); }
  } else {
    alert('Restore failed: ' + (data.error || 'unknown'));
  }
}

function escHtml(s) {
  return s.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
}

async function saveFile(name, file, btn) {
  const det = btn.closest('.file-body');
  const ta = det.querySelector('textarea');
  const statusEl = det.querySelector('.save-status');
  const resp = await fetch(`/api/tests/${name}/files/${file}`, {
    method: 'PUT',
    headers: {'Content-Type': 'text/plain'},
    body: ta.value
  });
  if (!resp.ok) { statusEl.textContent = 'error'; setTimeout(() => { statusEl.textContent = ''; }, 2000); return; }
  statusEl.textContent = 'saved';
  setTimeout(() => { statusEl.textContent = ''; }, 2000);
  // Refresh git badge for this file
  const gsResp = await fetch(`/api/tests/${name}/gitstatus`);
  const gs = await gsResp.json();
  const gitFiles = gs.files || {};
  const xy = gitFiles[file] || null;
  const details = btn.closest('details');
  const summary = details.querySelector('summary');
  summary.querySelector('.git-badge')?.remove();
  det.querySelector('button[data-restore]')?.remove();
  if (xy && xy !== '??') {
    summary.insertAdjacentHTML('beforeend', `<span class="git-badge modified">M</span>`);
    btn.insertAdjacentHTML('afterend',
      `<button data-restore onclick="restoreFile('${escHtml(name)}','${escHtml(file)}',this)">Restore</button>`);
  } else if (xy === '??') {
    summary.insertAdjacentHTML('beforeend', `<span class="git-badge untracked">new</span>`);
  }
  // Update left panel git indicator
  const t = tests.find(x => x.name === name);
  if (t) {
    t.gitModified = Object.values(gitFiles).some(s => s);
    renderList();
  }
}

async function addFile() {
  if (!selected) return;
  const input = document.getElementById('new-file-name');
  const fname = input.value.trim();
  if (!fname) return;
  const container = document.getElementById('file-sections');
  // Check not already present
  if (container.querySelector(`[data-filename="${CSS.escape(fname)}"]`)) {
    input.value = '';
    return;
  }
  // Create empty file on server
  await fetch(`/api/tests/${selected}/files/${encodeURIComponent(fname)}`, {
    method: 'PUT',
    headers: {'Content-Type': 'text/plain'},
    body: ''
  });
  // Update test's file list in memory
  const t = tests.find(x => x.name === selected);
  if (t && !t.files.includes(fname)) t.files.push(fname);
  appendFileSection(container, selected, fname, true);
  input.value = '';
}

async function saveAllFiles() {
  if (!selected) return;
  const tasks = [];
  document.querySelectorAll('#file-sections textarea').forEach(ta => {
    const btn = ta.closest('.file-body').querySelector('button');
    tasks.push(saveFile(selected, ta.dataset.file, btn));
  });
  await Promise.all(tasks);
}

async function runTest() {
  if (!selected) return;
  await saveAllFiles();
  const resultDiv = document.getElementById('run-result');
  const titleEl = document.getElementById('run-result-title');
  const bodyEl = document.getElementById('run-result-body');
  resultDiv.style.display = 'block';
  titleEl.textContent = 'Running…';
  titleEl.style.color = '';
  bodyEl.innerHTML = '';
  const compat = document.getElementById('compat-check').checked;
  const verbose = document.getElementById('verbose-check').checked;
  const resp = await fetch(`/api/tests/${selected}/run`, {
    method: 'POST',
    headers: {'Content-Type': 'application/json'},
    body: JSON.stringify({compat, verbose})
  });
  const data = await resp.json();
  const t = tests.find(x => x.name === selected);
  const newStatus = data.pass ? 'pass' : 'fail';
  if (t) { t.status = newStatus; renderList(); }
  updateStatusBadge(newStatus);
  titleEl.textContent = data.pass ? '✓ PASS' : '✗ FAIL';
  titleEl.style.color = data.pass ? '#2e7d32' : '#c62828';
  if (data.diff) {
    const lines = data.diff.split('\n');
    bodyEl.innerHTML = lines.map(l => {
      let cls = '';
      if (l.startsWith('+ ')) cls = 'diff-add';
      else if (l.startsWith('- ')) cls = 'diff-del';
      else if (l.startsWith('? ')) cls = 'diff-info';
      return `<div class="diff-line ${cls}">${escHtml(l)}</div>`;
    }).join('');
  } else if (data.pass) {
    bodyEl.innerHTML = '<div class="pass-note">Output matches transcript.</div>';
  }
}

async function regenTranscript() {
  if (!selected) return;
  await saveAllFiles();
  const resp = await fetch(`/api/tests/${selected}/regenerate`, {method: 'POST'});
  const data = await resp.json();
  if (data.ok) {
    await selectTest(selected);
  } else {
    alert('Error: ' + (data.error || 'unknown'));
  }
}

async function runAll() {
  const out = document.getElementById('run-all-output');
  const text = document.getElementById('run-all-output-text');
  out.style.display = 'block';
  text.textContent = 'Running all tests…\n';
  const resp = await fetch('/api/run-all', {method: 'POST'});
  const data = await resp.json();
  text.textContent = data.output;
  const testsResp = await fetch('/api/tests');
  tests = await testsResp.json();
  renderList();
  if (selected) {
    const t = tests.find(x => x.name === selected);
    if (t) updateStatusBadge(t.status);
  }
}

function showNewTest() {
  document.getElementById('modal-overlay').classList.add('show');
  document.getElementById('new-name').focus();
}
function hideNewTest() {
  document.getElementById('modal-overlay').classList.remove('show');
}

async function createTest() {
  const name = document.getElementById('new-name').value.trim();
  if (!name) { alert('Name required'); return; }
  const resp = await fetch('/api/tests', {
    method: 'POST',
    headers: {'Content-Type': 'application/json'},
    body: JSON.stringify({name})
  });
  const data = await resp.json();
  if (!resp.ok) { alert('Error: ' + (data.error || resp.status)); return; }
  hideNewTest();
  document.getElementById('new-name').value = '';
  const testsResp = await fetch('/api/tests');
  tests = await testsResp.json();
  renderList();
  selectTest(name);
}

document.getElementById('file-sections').addEventListener('keydown', e => {
  if ((e.ctrlKey || e.metaKey) && e.key === 's') {
    e.preventDefault();
    const ta = e.target.closest('textarea');
    if (!ta || !selected) return;
    const btn = ta.closest('.file-body').querySelector('button');
    saveFile(selected, ta.dataset.file, btn);
  }
});

document.addEventListener('keydown', e => {
  if ((e.ctrlKey || e.metaKey) && e.key === 'Enter') {
    e.preventDefault();
    runTest();
  }
}, true);

document.getElementById('modal-overlay').addEventListener('click', e => {
  if (e.target === document.getElementById('modal-overlay')) hideNewTest();
});
document.getElementById('new-file-name').addEventListener('keydown', e => {
  if (e.key === 'Enter') addFile();
});
document.getElementById('new-name').addEventListener('keydown', e => {
  if (e.key === 'Enter') createTest();
});

function updateLineNums(ta) {
  const lnDiv = ta.parentElement.querySelector('.line-nums');
  if (!lnDiv) return;
  const count = ta.value.split('\n').length;
  lnDiv.textContent = Array.from({length: count}, (_, i) => i + 1).join('\n');
}

function initEditor(ta) {
  if (!ta) return;
  updateLineNums(ta);
  ta.addEventListener('input', () => updateLineNums(ta));
  ta.addEventListener('scroll', () => {
    const lnDiv = ta.parentElement.querySelector('.line-nums');
    if (lnDiv) lnDiv.scrollTop = ta.scrollTop;
  });
}

init();
