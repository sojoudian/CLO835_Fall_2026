// CLO835 Assignment 2 — C# (.NET) starter (BCL HttpListener, no extra packages)
// This is VERSION 0.2. To release VERSION 0.3, change Message below to:
//   "Hello world from the CLO835 class and <YOUR_STUDENT_ID>!"
// (replace <YOUR_STUDENT_ID> with your own Seneca student ID, e.g. 10112233)
using System.Net;
using System.Text;

const string Version = "0.2";
const string Message = "Hello world from the CLO835 class!";

var listener = new HttpListener();
listener.Prefixes.Add("http://*:8080/");
listener.Start();
Console.WriteLine($"CLO835 app v{Version} listening on :8080");

while (true)
{
    var ctx = listener.GetContext();
    var path = ctx.Request.Url?.AbsolutePath ?? "/";
    byte[] body = (path == "/healthz" || path == "/readyz")
        ? Encoding.UTF8.GetBytes("ok")
        : Encoding.UTF8.GetBytes(Message + "\n");
    ctx.Response.ContentType = "text/plain";
    ctx.Response.ContentLength64 = body.Length;
    ctx.Response.OutputStream.Write(body, 0, body.Length);
    ctx.Response.OutputStream.Close();
}
