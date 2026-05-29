#!/usr/bin/env python3
"""Pink test browser — python3 test/ui/ui.py → http://127.0.0.1:8765"""

import difflib
import http.server
import json
import pathlib
import subprocess

UI_DIR = pathlib.Path(__file__).parent
ROOT = UI_DIR.parent.parent
RUNTIME = ROOT / "test" / "runtime"
RESULTS = ROOT / "test" / "results"
INKLECATE = pathlib.Path.home() / "app" / "inklecate" / "inklecate"
PORT = 8765

CONTENT_TYPES = {
    ".html": "text/html; charset=utf-8",
    ".css": "text/css; charset=utf-8",
    ".js": "application/javascript; charset=utf-8",
}


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


def run_test(name, compat=True):
    d = RUNTIME / name
    story = d / "setup.ink" if (d / "setup.ink").exists() else d / "story.ink"
    inp = d / "input.txt"
    transcript = d / "transcript.txt"

    is_x = name.startswith("X")
    compat_flag = [] if is_x or not compat else ["--compat"]

    with open(inp, encoding="utf-8") as f:
        stdin_data = f.read()

    result = subprocess.run(
        ["lua", str(ROOT / "pink-cli")] + compat_flag + [str(story)],
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
            difflib.ndiff(
                expected.splitlines(keepends=True),
                actual.splitlines(keepends=True),
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

    def send_file(self, path):
        suffix = path.suffix
        content_type = CONTENT_TYPES.get(suffix, "application/octet-stream")
        body = path.read_bytes()
        self.send_response(200)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", len(body))
        self.end_headers()
        self.wfile.write(body)

    def safe_name(self, name):
        return name.replace("/", "").replace("..", "")

    def do_GET(self):
        if self.path == "/":
            self.send_file(UI_DIR / "index.html")
        elif self.path == "/style.css":
            self.send_file(UI_DIR / "style.css")
        elif self.path == "/app.js":
            self.send_file(UI_DIR / "app.js")
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
            req = json.loads(body) if body else {}
            self.send_json(200, run_test(name, compat=req.get("compat", True)))

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
