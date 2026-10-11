package uk.tonytong.aios.shell;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.net.ServerSocket;
import java.net.Socket;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.TimeUnit;

/**
 * 远程 shell 通道的并发守护（2026-10-11）：取代 rs.sh 里的 toybox nc -L（串行）。
 * 病根：nc -L 一次只处理一个连接，而桥每 ~30 秒有一次 25 秒长的 /v1/events 轮询占着串行口，
 * 其它调用（装/卸/读屏）排队超时 → 客户端整批 RSH_DOWN。
 * 本守护线程/连接，协议与口令与 rsh.sh 完全一致（首行口令 → 命令行×N → exit），客户端零改动。
 * 输出仍写临时文件再回写：命令的子孙进程继承不到 socket fd，会话必随命令结束而结束。
 * 只听 127.0.0.1:2222（经手机发起的 ssh -R 反向隧道映射到 Mac mini），以 root 跑（rs.sh 拉起）。
 */
public class RshD {
    private static final String TOKEN_FILE = "/data/local/tmp/rt/token";
    private static final File TMP_DIR = new File("/data/local/tmp/rt");
    private static final long CMD_TIMEOUT_S = 290;   // 比客户端最长 nc -w(300+5) 略短

    public static void main(String[] args) throws Exception {
        int port = args.length > 0 ? Integer.parseInt(args[0]) : 2222;
        ServerSocket ss = new ServerSocket();
        ss.setReuseAddress(true);
        ss.bind(new InetSocketAddress("127.0.0.1", port), 16);
        log("rshd 并发监听 127.0.0.1:" + port);
        // 只在前台持锁跑：rs.sh 的 listener() 用 nc -z 探测本端口判活
        while (true) {
            final Socket s = ss.accept();
            Thread t = new Thread(() -> handle(s));
            t.setDaemon(true);
            t.start();
        }
    }

    private static void handle(Socket s) {
        try (Socket sock = s) {
            sock.setSoTimeout(310_000);
            BufferedReader in = new BufferedReader(new InputStreamReader(sock.getInputStream(), StandardCharsets.UTF_8));
            OutputStream out = sock.getOutputStream();
            String tok = in.readLine();
            if (tok == null || !tok.equals(readToken())) {
                out.write("DENIED\n".getBytes(StandardCharsets.US_ASCII));
                out.flush();
                return;
            }
            String line;
            while ((line = in.readLine()) != null) {
                if (line.equals("exit")) break;
                if (line.isEmpty()) continue;
                File o = File.createTempFile("rshd", ".out", TMP_DIR);
                try {
                    Process p = new ProcessBuilder("sh", "-c", line)
                            .redirectInput(new File("/dev/null"))
                            .redirectErrorStream(true)
                            .redirectOutput(o)
                            .start();
                    if (!p.waitFor(CMD_TIMEOUT_S, TimeUnit.SECONDS)) {
                        p.destroyForcibly();
                        append(o, "\nRSHD_TIMEOUT " + line.substring(0, Math.min(60, line.length())) + "\n");
                    }
                } catch (Exception e) {
                    append(o, "\nRSHD_EXEC_ERR " + e + "\n");
                }
                try (FileInputStream fi = new FileInputStream(o)) {
                    byte[] b = new byte[16384];
                    int n;
                    while ((n = fi.read(b)) > 0) out.write(b, 0, n);
                    out.flush();
                }
                o.delete();
            }
        } catch (Exception ignored) {
        }
    }

    private static void append(File f, String s) {
        try (FileOutputStream2 fo = new FileOutputStream2(f, true)) {
            fo.write(s.getBytes(StandardCharsets.UTF_8));
        } catch (IOException ignored) {
        }
    }

    /** 小 wrapper 只为追加写（避免 java.io.FileWriter 的平台差异）。 */
    static class FileOutputStream2 extends java.io.FileOutputStream {
        FileOutputStream2(File f, boolean append) throws IOException {
            super(f, append);
        }
    }

    private static String readToken() {
        try (BufferedReader r = new BufferedReader(new FileReader(TOKEN_FILE))) {
            String l = r.readLine();
            return l == null ? "" : l.trim();
        } catch (IOException e) {
            return "";
        }
    }

    private static void log(String s) {
        System.out.println(s);
    }
}
