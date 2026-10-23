"""Run with python3 test/nginx_author_test.py on a machine with Docker."""
import pathlib
import subprocess
import tempfile
import time
import urllib.error
import urllib.request


def docker(*args):
    return subprocess.check_output(["docker", *args], text=True).strip()


with tempfile.TemporaryDirectory() as temp:
    root = pathlib.Path(temp)
    root.chmod(0o755)
    config = (pathlib.Path(__file__).parents[1] / "script/deploy/nginx.conf").read_text()
    config = config.replace("http://100.64.0.4:3000", "http://127.0.0.1:8081")
    config += '\nserver { listen 8081; add_header Cache-Control public; location / { return 200 "DYNAMIC $request_uri $http_cookie"; } }\n'
    (root / "nginx.conf").write_text(config)
    for path in ("", "thoughts", "thoughts/example", "posts", "posts/feed.rss"):
        page = root / "current/pages" / path / "index.p1.m.d.html"
        page.parent.mkdir(parents=True, exist_ok=True)
        page.write_text("STATIC " + path)
    (root / "current/assets").mkdir()
    (root / "current/assets/app.css").write_text("STATIC CSS")
    container = docker("run", "--rm", "-d", "-p", "127.0.0.1::80",
                       "-v", f"{root}:/site:ro",
                       "-v", f"{root}/nginx.conf:/etc/nginx/conf.d/default.conf:ro",
                       "public.ecr.aws/docker/library/nginx:1.28-alpine")
    try:
        port = docker("port", container, "80/tcp").rsplit(":", 1)[1]

        def request(path, cookie="", method="GET"):
            req = urllib.request.Request(f"http://127.0.0.1:{port}{path}",
                                         headers={"Cookie": cookie}, method=method)
            try:
                response = urllib.request.urlopen(req, timeout=5)
            except urllib.error.HTTPError as error:
                response = error
            with response:
                return response.status, response.headers, response.read().decode()

        for attempt in range(30):
            try:
                request("/up")
                break
            except OSError:
                time.sleep(0.1)
        for path in ("/", "/thoughts", "/thoughts/"):
            for cookie in ("", "other=abc"):
                status, headers, body = request(path, cookie)
                assert status == 200 and body.startswith("STATIC"), (path, status, body)
                assert "cookie" in headers.get("Vary", "").lower(), headers
            status, headers, body = request(path, "session_id=author")
            assert status == 200 and body.startswith("DYNAMIC"), (path, status, body)
            assert "session_id=author" in body, body
            assert headers.get_all("Cache-Control") == ["private, no-store"], headers
            assert "cookie" in headers.get("Vary", "").lower(), headers
        _, _, body = request("/thoughts?month=2026-10&page=2", "session_id=author")
        assert "/thoughts?month=2026-10&page=2" in body, body
        for path in ("/posts", "/thoughts/example", "/assets/app.css", "/posts/feed.rss"):
            status, _, body = request(path, "session_id=author")
            assert status == 200 and body.startswith("STATIC"), (path, status, body)
        for cookie in ("", "session_id=author"):
            assert request("/", cookie, "POST")[0] == 403
        status, headers, _ = request("/thoughts", "session_id=author", "HEAD")
        assert status == 200 and headers.get("Cache-Control") == "private, no-store"
        print("PASS: author routing, guest static pages, cache isolation, query forwarding, and read-only methods")
    finally:
        docker("rm", "-f", container)
