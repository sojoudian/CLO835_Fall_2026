// CLO835 Assignment 2 — Node.js starter (built-in http module, no dependencies)
// This is VERSION 0.2. To release VERSION 0.3, change MESSAGE below to:
//   "Hello world from the CLO835 class and <YOUR_STUDENT_ID>!"
// (replace <YOUR_STUDENT_ID> with your own Seneca student ID, e.g. 10112233)
const http = require("http");

const VERSION = "0.2";
const MESSAGE = "Hello world from the CLO835 class!";
const PORT = 8080;

http
  .createServer((req, res) => {
    if (req.url === "/healthz" || req.url === "/readyz") {
      res.writeHead(200);
      return res.end("ok");
    }
    res.writeHead(200, { "Content-Type": "text/plain" });
    res.end(MESSAGE + "\n");
  })
  .listen(PORT, "0.0.0.0", () => console.log(`CLO835 app v${VERSION} listening on :${PORT}`));
