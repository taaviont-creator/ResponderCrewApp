"""Local-only server for the separate, synthetic Flutter center demo."""
import argparse
import json
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('--directory', required=True)
parser.add_argument('--port', type=int, default=8765)
args = parser.parse_args()
root = Path(args.directory).resolve()
if not (root / 'index.html').is_file():
    raise SystemExit('Build the center demo before starting the server.')

class Handler(SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/__respondcrew_preview_health':
            body = json.dumps({'application': 'RespondCrew center demo', 'synthetic': True}).encode()
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        super().do_GET()

    def end_headers(self):
        self.send_header('Referrer-Policy', 'strict-origin-when-cross-origin')
        self.send_header('X-Content-Type-Options', 'nosniff')
        super().end_headers()

ThreadingHTTPServer(('127.0.0.1', args.port), partial(Handler, directory=str(root))).serve_forever()
