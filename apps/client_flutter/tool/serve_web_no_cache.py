#!/usr/bin/env python3
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import os
from pathlib import Path


class NoCacheHandler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0")
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")
        super().end_headers()


def main() -> None:
    root = Path(__file__).resolve().parents[1] / "build" / "web"
    os.chdir(root)
    server = ThreadingHTTPServer(("0.0.0.0", 18081), NoCacheHandler)
    print(f"Serving {root} on http://0.0.0.0:18081 with no-cache headers")
    server.serve_forever()


if __name__ == "__main__":
    main()
