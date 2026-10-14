# CLO835 Assignment 2 — Python starter
# This is VERSION 0.2. To release VERSION 0.3, change MESSAGE below to:
#   "Hello world from the CLO835 class and <YOUR_STUDENT_ID>!"
# (replace <YOUR_STUDENT_ID> with your own Seneca student ID, e.g. 10112233)
from http.server import BaseHTTPRequestHandler, HTTPServer

VERSION = "0.2"
MESSAGE = "Hello world from the CLO835 class!"
PORT = 8080


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path in ("/healthz", "/readyz"):   # for the bonus probes
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b"ok")
            return
        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.end_headers()
        self.wfile.write((MESSAGE + "\n").encode())

    def log_message(self, format, *args):
        pass


if __name__ == "__main__":
    print(f"CLO835 app v{VERSION} listening on :{PORT}")
    HTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
