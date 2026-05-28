#!/usr/bin/env python3
"""Pink test browser — python3 test/testbrowser.py → http://127.0.0.1:8765"""

import difflib
import http.server
import json
import pathlib
import subprocess

ROOT = pathlib.Path(__file__).parent.parent
RUNTIME = ROOT / "test" / "runtime"
RESULTS = ROOT / "test" / "results"
INKLECATE = pathlib.Path.home() / "app" / "inklecate" / "inklecate"
PORT = 8765

HTML = r"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Pink Tests</title>
<style>
* { box-sizing: border-box; margin: 0; padding: 0; }
body { font-family: monospace; font-size: 13px; display: flex; height: 100vh; overflow: hidden; background: #f5f5f5; color: #1a1a1a; }
#left { width: 260px; min-width: 240px; display: flex; flex-direction: column; border-right: 1px solid #ccc; background: #fafafa; }
#left-toolbar { padding: 8px; display: flex; flex-direction: column; gap: 6px; border-bottom: 1px solid #ccc; }
#search { background: #fff; color: #1a1a1a; border: 1px solid #ccc; padding: 4px 6px; width: 100%; }
#filters { display: flex; gap: 4px; flex-wrap: wrap; }
.filter-btn { background: #fff; color: #666; border: 1px solid #ccc; padding: 2px 6px; cursor: pointer; }
.filter-btn.active { background: #0078d4; color: #fff; border-color: #0078d4; }
#left-actions { display: flex; gap: 4px; }
#test-list { overflow-y: auto; flex: 1; }
.test-item { padding: 4px 8px; cursor: pointer; display: flex; align-items: center; gap: 6px; border-bottom: 1px solid #eee; }
.test-item:hover { background: #e8f0fe; }
.test-item.selected { background: #0078d4; color: #fff; }
.git-m { margin-left: auto; font-size: 10px; font-weight: bold; color: #e65100; }
.test-item.selected .git-m { color: #ffcc80; }
.dot { width: 8px; height: 8px; border-radius: 50%; flex-shrink: 0; }
.dot.pass { background: #2e7d32; }
.dot.fail { background: #c62828; }
.dot.unknown { background: #bbb; }
#right { flex: 1; overflow-y: auto; padding: 12px; display: flex; flex-direction: column; gap: 8px; background: #fff; }
#right-header { display: flex; align-items: center; gap: 8px; flex-wrap: wrap; }
#test-title { font-size: 16px; font-weight: bold; }
.badge { padding: 2px 8px; border-radius: 3px; font-size: 11px; }
.badge.pass { background: #e8f5e9; color: #2e7d32; border: 1px solid #a5d6a7; }
.badge.fail { background: #ffebee; color: #c62828; border: 1px solid #ef9a9a; }
.badge.unknown { background: #f5f5f5; color: #888; border: 1px solid #ddd; }
button { background: #f0f0f0; color: #1a1a1a; border: 1px solid #ccc; padding: 4px 10px; cursor: pointer; font-family: monospace; font-size: 12px; }
button:hover { background: #e0e0e0; }
button:disabled { opacity: 0.4; cursor: default; }
button.primary { background: #0078d4; color: #fff; border-color: #0078d4; }
button.primary:hover { background: #006bbf; }
#run-result { background: #fafafa; border: 1px solid #ddd; padding: 8px; }
#run-result h3 { margin-bottom: 6px; }
.diff-line { white-space: pre-wrap; word-break: break-all; font-family: monospace; line-height: 1.4; }
.diff-add { background: #e8f5e9; color: #1b5e20; }
.diff-del { background: #ffebee; color: #b71c1c; }
.diff-info { color: #888; }
.git-badge { display: inline-block; margin-left: 6px; padding: 1px 5px; border-radius: 3px; font-size: 10px; font-weight: bold; vertical-align: middle; }
.git-badge.modified { background: #fff3e0; color: #e65100; border: 1px solid #ffcc80; }
.git-badge.untracked { background: #e8f5e9; color: #2e7d32; border: 1px solid #a5d6a7; }
details { border: 1px solid #ddd; margin: 10px 0; background: #f5f5f5; }
summary { padding: 6px 8px; cursor: pointer; user-select: none; display: flex; align-items: center; }
summary:hover { background: #ebebeb; }
.file-body { padding: 8px; display: flex; flex-direction: column; gap: 6px; background: #fff; }
textarea { background: #fff; color: #1a1a1a; border: 1px solid #ccc; padding: 6px; width: 100%; font-family: monospace; font-size: 12px; resize: vertical; min-height: 80px; }
#run-all-output { background: #fafafa; border: 1px solid #ddd; padding: 8px; white-space: pre-wrap; font-size: 12px; max-height: 300px; overflow-y: auto; display: none; }
#add-file-row { display: flex; gap: 6px; align-items: center; padding: 4px 0; }
#add-file-row input { background: #fff; color: #1a1a1a; border: 1px solid #ccc; padding: 4px 6px; font-family: monospace; font-size: 12px; width: 180px; }
#modal-overlay { display: none; position: fixed; inset: 0; background: rgba(0,0,0,0.3); align-items: center; justify-content: center; }
#modal-overlay.show { display: flex; }
#modal { background: #fff; border: 1px solid #ccc; box-shadow: 0 4px 16px rgba(0,0,0,0.15); padding: 16px; width: 320px; display: flex; flex-direction: column; gap: 10px; }
#modal h2 { font-size: 14px; }
#modal label { display: flex; flex-direction: column; gap: 4px; font-size: 12px; color: #666; }
#modal input { background: #fff; color: #1a1a1a; border: 1px solid #ccc; padding: 6px; font-family: monospace; font-size: 12px; }
#modal-actions { display: flex; gap: 6px; justify-content: flex-end; }
</style>
</head>
<body>
<div id="left">
  <div id="left-toolbar">
    <input id="search" placeholder="filter tests..." oninput="applyFilters()">
    <div id="filters">
      <button class="filter-btn active" data-status="all" onclick="setStatusFilter('all')">All</button>
      <button class="filter-btn" data-status="pass" onclick="setStatusFilter('pass')">Pass</button>
      <button class="filter-btn" data-status="fail" onclick="setStatusFilter('fail')">Fail</button>
      <button class="filter-btn" data-status="unknown" onclick="setStatusFilter('unknown')">?</button>
      <button class="filter-btn" id="git-filter-btn" onclick="toggleGitFilter()">M</button>
    </div>
    <div id="left-actions">
      <button onclick="showNewTest()">New</button>
      <button onclick="runAll()">Run All</button>
      <div id="pass-count" style="font-size:11px;color:#555;margin-left:auto;align-self:center;"></div>
    </div>
  </div>
  <div id="test-list"></div>
</div>

<div id="right">
  <div id="placeholder" style="color:#aaa;padding:40px;text-align:center">Select a test</div>
  <div id="right-content" style="display:none">
    <div id="right-header">
      <span id="test-title"></span>
      <span id="status-badge" class="badge"></span>
      <button class="primary" onclick="runTest()">Run</button>
    </div>
    <div id="run-all-output">
      <div style="position:sticky;top:0;display:flex;justify-content:flex-end;background:#fafafa;padding-bottom:4px"><button onclick="document.getElementById('run-all-output').style.display='none'">✕</button></div>
      <div id="run-all-output-text"></div>
    </div>
    <div id="run-result" style="display:none">
      <h3 id="run-result-title"></h3>
      <div id="run-result-body"></div>
    </div>
    <div id="file-sections"></div>
    <div id="add-file-row" style="display:none">
      <input id="new-file-name" placeholder="filename">
      <button onclick="addFile()">Add File</button>
    </div>
  </div>
</div>

<div id="modal-overlay">
  <div id="modal">
    <h2>New Test</h2>
    <label>Name (e.g. I136, W2.4.001, P055)<input id="new-name" placeholder="I136"></label>
    <div id="modal-actions">
      <button onclick="hideNewTest()">Cancel</button>
      <button class="primary" onclick="createTest()">Create</button>
    </div>
  </div>
</div>

<script>
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
  const q = document.getElementById('search').value.toLowerCase();
  const list = document.getElementById('test-list');
  list.innerHTML = '';
  for (const t of tests) {
    if (statusFilter !== 'all' && t.status !== statusFilter) continue;
    if (gitFilter && !t.gitModified) continue;
    if (q && !t.name.toLowerCase().includes(q)) continue;
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
    appendFileSection(container, name, f, gitFiles[f] || null);
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
      <textarea data-file="${escHtml(f)}" rows="${Math.min(Math.max(content.split('\n').length + 1, 3), 30)}">${escHtml(content)}</textarea>
      <div style="display:flex;gap:6px;align-items:center">
        <button onclick="saveFile('${escHtml(name)}','${escHtml(f)}',this)">Save</button>
        ${restoreBtn}
        ${f === 'transcript.txt' ? `<button id="regen-btn" onclick="regenTranscript()">Regenerate</button>` : ''}
        <span class="save-status" style="color:#888;font-size:11px"></span>
      </div>
    </div>`;
  container.appendChild(det);
}

async function restoreFile(name, file, btn) {
  const det = btn.closest('details');
  const ta = det.querySelector('textarea');
  const statusEl = det.querySelector('.save-status');
  const resp = await fetch(`/api/tests/${name}/files/${encodeURIComponent(file)}/restore`, {method: 'POST'});
  const data = await resp.json();
  if (data.ok) {
    ta.value = data.content;
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
  const statusEl = btn.nextElementSibling;
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

async function runTest() {
  if (!selected) return;
  const resultDiv = document.getElementById('run-result');
  const titleEl = document.getElementById('run-result-title');
  const bodyEl = document.getElementById('run-result-body');
  resultDiv.style.display = 'block';
  titleEl.textContent = 'Running…';
  titleEl.style.color = '';
  bodyEl.innerHTML = '';
  const resp = await fetch(`/api/tests/${selected}/run`, {method: 'POST'});
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
      if (l.startsWith('+')) cls = 'diff-add';
      else if (l.startsWith('-')) cls = 'diff-del';
      else if (l.startsWith('@@') || l.startsWith('---') || l.startsWith('+++')) cls = 'diff-info';
      return `<div class="diff-line ${cls}">${escHtml(l)}</div>`;
    }).join('');
  } else if (data.pass) {
    bodyEl.innerHTML = '<div style="color:#888;padding:4px">Output matches transcript.</div>';
  }
}

async function regenTranscript() {
  if (!selected) return;
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

document.getElementById('modal-overlay').addEventListener('click', e => {
  if (e.target === document.getElementById('modal-overlay')) hideNewTest();
});
document.getElementById('new-file-name').addEventListener('keydown', e => {
  if (e.key === 'Enter') addFile();
});
document.getElementById('new-name').addEventListener('keydown', e => {
  if (e.key === 'Enter') createTest();
});

init();
</script>
</body>
</html>
"""


def load_statuses():
    """Return set of passed test names from the most recent results file."""
    if not RESULTS.exists():
        return set()
    files = sorted(RESULTS.glob("*-passed-*"), key=lambda p: p.stat().st_mtime)
    if not files:
        return set()
    passed = set()
    with open(files[-1], encoding="utf-8") as f:
        for line in f:
            name = line.strip()
            if name:
                passed.add(name)
    return passed


def git_modified_dirs():
    """Return set of test dir names that have any modified/untracked files."""
    result = subprocess.run(
        ["git", "status", "--porcelain", str(RUNTIME)],
        capture_output=True,
        text=True,
        cwd=ROOT,
    )
    modified = set()
    for line in result.stdout.splitlines():
        if len(line) < 4:
            continue
        path = pathlib.Path(line[3:].strip())
        parts = path.parts
        try:
            idx = list(parts).index("runtime")
            if idx + 1 < len(parts):
                modified.add(parts[idx + 1])
        except ValueError:
            pass
    return modified


def list_tests(passed_set):
    git_modified = git_modified_dirs()
    has_results = bool(passed_set)
    tests = []
    for d in sorted(RUNTIME.iterdir()):
        if not d.is_dir():
            continue
        name = d.name
        if not name[0].upper() in "IWPX":
            continue
        files = sorted(p.name for p in d.iterdir() if p.is_file())
        if name in passed_set:
            status = "pass"
        elif has_results:
            status = "fail"
        else:
            status = "unknown"
        tests.append({"name": name, "files": files, "status": status, "gitModified": name in git_modified})
    return tests


def run_test(name):
    d = RUNTIME / name
    story = d / "setup.ink" if (d / "setup.ink").exists() else d / "story.ink"
    inp = d / "input.txt"
    transcript = d / "transcript.txt"

    is_x = name.startswith("X")
    compat = [] if is_x else ["--compat"]

    with open(inp, encoding="utf-8") as f:
        stdin_data = f.read()

    result = subprocess.run(
        ["lua", str(ROOT / "pink-cli")] + compat + [str(story)],
        input=stdin_data,
        capture_output=True,
        text=True,
        cwd=ROOT,
    )
    actual = result.stdout + result.stderr

    expected = ""
    if transcript.exists():
        with open(transcript, encoding="utf-8") as f:
            expected = f.read()

    passed = actual == expected
    diff = ""
    if not passed:
        diff = "".join(
            difflib.unified_diff(
                expected.splitlines(keepends=True),
                actual.splitlines(keepends=True),
                fromfile="expected (transcript.txt)",
                tofile="actual",
            )
        )
    return {"pass": passed, "output": actual, "diff": diff}


def git_file_status(name):
    d = RUNTIME / name
    result = subprocess.run(
        ["git", "status", "--porcelain", str(d)],
        capture_output=True,
        text=True,
        cwd=ROOT,
    )
    files = {}
    for line in result.stdout.splitlines():
        if len(line) < 4:
            continue
        xy = line[:2]
        path = line[3:].strip()
        fname = pathlib.Path(path).name
        files[fname] = xy
    return {"files": files}


def git_restore_file(name, fname):
    fpath = RUNTIME / name / fname
    result = subprocess.run(
        ["git", "checkout", "--", str(fpath)],
        capture_output=True,
        text=True,
        cwd=ROOT,
    )
    if result.returncode != 0:
        return {"ok": False, "error": result.stderr.strip()}
    with open(fpath, encoding="utf-8") as f:
        return {"ok": True, "content": f.read()}


def regen_transcript(name):
    if not INKLECATE.exists():
        return {"ok": False, "error": "inklecate not found at " + str(INKLECATE)}
    d = RUNTIME / name
    story = d / "setup.ink" if (d / "setup.ink").exists() else d / "story.ink"
    inp = d / "input.txt"
    transcript = d / "transcript.txt"
    with open(inp, encoding="utf-8") as f:
        stdin_data = f.read()
    result = subprocess.run(
        [str(INKLECATE), "-p", str(story)],
        input=stdin_data,
        capture_output=True,
        text=True,
        cwd=ROOT,
    )
    if result.returncode != 0 and not result.stdout:
        return {"ok": False, "error": result.stderr}
    with open(transcript, "w", encoding="utf-8") as f:
        f.write(result.stdout)
    return {"ok": True}


class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        pass  # suppress default logging

    def send_json(self, code, data):
        body = json.dumps(data).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", len(body))
        self.end_headers()
        self.wfile.write(body)

    def send_text(self, code, text):
        body = text.encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", len(body))
        self.end_headers()
        self.wfile.write(body)

    def send_html(self, html):
        body = html.encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", len(body))
        self.end_headers()
        self.wfile.write(body)

    def safe_name(self, name):
        return name.replace("/", "").replace("..", "")

    def do_GET(self):
        if self.path == "/":
            self.send_html(HTML)
        elif self.path == "/api/tests":
            self.send_json(200, list_tests(load_statuses()))
        elif self.path.startswith("/api/tests/") and self.path.endswith("/gitstatus"):
            name = self.safe_name(self.path[len("/api/tests/") : -len("/gitstatus")])
            self.send_json(200, git_file_status(name))
        elif self.path.startswith("/api/tests/") and "/files/" in self.path:
            parts = self.path[len("/api/tests/"):].split("/files/", 1)
            name = self.safe_name(parts[0])
            fname = parts[1] if len(parts) > 1 else ""
            fname = fname.replace("/", "").replace("..", "")
            fpath = RUNTIME / name / fname
            if not fpath.exists():
                self.send_text(404, "not found")
                return
            with open(fpath, encoding="utf-8") as f:
                self.send_text(200, f.read())
        else:
            self.send_text(404, "not found")

    def do_PUT(self):
        if self.path.startswith("/api/tests/") and "/files/" in self.path:
            parts = self.path[len("/api/tests/"):].split("/files/", 1)
            name = self.safe_name(parts[0])
            fname = parts[1] if len(parts) > 1 else ""
            fname = fname.replace("/", "").replace("..", "")
            length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(length).decode("utf-8")
            fpath = RUNTIME / name / fname
            if not fpath.parent.exists():
                self.send_json(404, {"error": "test not found"})
                return
            with open(fpath, "w", encoding="utf-8") as f:
                f.write(body)
            self.send_json(200, {"ok": True})
        else:
            self.send_text(404, "not found")

    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(length)

        if self.path == "/api/tests":
            data = json.loads(body)
            name = self.safe_name(data.get("name", ""))
            if not name:
                self.send_json(400, {"error": "name required"})
                return
            d = RUNTIME / name
            if d.exists():
                self.send_json(409, {"error": "test already exists"})
                return
            d.mkdir()
            (d / "story.ink").write_text("", encoding="utf-8")
            (d / "input.txt").write_text("", encoding="utf-8")
            (d / "transcript.txt").write_text("", encoding="utf-8")
            self.send_json(201, {"ok": True})

        elif self.path.startswith("/api/tests/") and "/files/" in self.path and self.path.endswith("/restore"):
            inner = self.path[len("/api/tests/") : -len("/restore")]
            parts = inner.split("/files/", 1)
            name = self.safe_name(parts[0])
            fname = parts[1].replace("/", "").replace("..", "") if len(parts) > 1 else ""
            self.send_json(200, git_restore_file(name, fname))
        elif self.path.startswith("/api/tests/") and self.path.endswith("/run"):
            name = self.safe_name(self.path[len("/api/tests/"):-len("/run")])
            self.send_json(200, run_test(name))

        elif self.path.startswith("/api/tests/") and self.path.endswith("/regenerate"):
            name = self.safe_name(self.path[len("/api/tests/"):-len("/regenerate")])
            self.send_json(200, regen_transcript(name))

        elif self.path == "/api/run-all":
            result = subprocess.run(
                ["./test/test.sh"],
                capture_output=True,
                text=True,
                cwd=ROOT,
            )
            self.send_json(200, {"output": result.stdout + result.stderr})

        else:
            self.send_text(404, "not found")


if __name__ == "__main__":
    server = http.server.HTTPServer(("127.0.0.1", PORT), Handler)
    print(f"Pink test browser running at http://127.0.0.1:{PORT}")
    server.serve_forever()
