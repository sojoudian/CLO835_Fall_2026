// CLO835 Assignment 2 — Java starter (JDK built-in HTTP server, no dependencies)
// This is VERSION 0.2. To release VERSION 0.3, change MESSAGE below to:
//   "Hello world from the CLO835 class and <YOUR_STUDENT_ID>!"
// (replace <YOUR_STUDENT_ID> with your own Seneca student ID, e.g. 10112233)
import com.sun.net.httpserver.HttpServer;

import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;

public class Main {
    static final String VERSION = "0.2";
    static final String MESSAGE = "Hello world from the CLO835 class!";

    public static void main(String[] args) throws Exception {
        HttpServer server = HttpServer.create(new InetSocketAddress("0.0.0.0", 8080), 0);
        server.createContext("/", exchange -> {
            String path = exchange.getRequestURI().getPath();
            byte[] body = (path.equals("/healthz") || path.equals("/readyz"))
                    ? "ok".getBytes(StandardCharsets.UTF_8)
                    : (MESSAGE + "\n").getBytes(StandardCharsets.UTF_8);
            exchange.sendResponseHeaders(200, body.length);
            try (OutputStream os = exchange.getResponseBody()) {
                os.write(body);
            }
        });
        System.out.println("CLO835 app v" + VERSION + " listening on :8080");
        server.start();
    }
}
