package uk.tonytong.permguard;

import android.content.Context;
import android.net.nsd.NsdManager;
import android.net.nsd.NsdServiceInfo;
import android.os.Build;
import android.util.Base64;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.DataInputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.OutputStream;
import java.math.BigInteger;
import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.net.ServerSocket;
import java.net.Socket;
import java.net.SocketTimeoutException;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.security.KeyFactory;
import java.security.KeyPair;
import java.security.Principal;
import java.security.PrivateKey;
import java.security.Signature;
import java.security.cert.CertificateFactory;
import java.security.cert.X509Certificate;
import java.security.interfaces.RSAPrivateCrtKey;
import java.security.interfaces.RSAPublicKey;
import java.security.spec.PKCS8EncodedKeySpec;
import java.security.spec.RSAPublicKeySpec;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.Executor;
import java.util.concurrent.TimeUnit;
import java.util.function.IntConsumer;

import javax.net.ssl.KeyManager;
import javax.net.ssl.SSLContext;
import javax.net.ssl.SSLEngine;
import javax.net.ssl.SSLSocket;
import javax.net.ssl.TrustManager;
import javax.net.ssl.X509ExtendedKeyManager;
import javax.net.ssl.X509TrustManager;

/**
 * 最小 ADB-over-TLS 客户端（Android 11+ 无线调试）：连本机 adbd 跑一条 shell 命令。守门员用它在 Shizuku 没起来时把它拉起来。
 * 钥匙：Mac 上 permguard/adb/pair_watchdog.sh 生成专用 RSA-2048（permguard@bixi）、配对进 adb_keys，推到
 *   /sdcard/Android/data/uk.tonytong.permguard/files/adbkey.import；守门员收进设备加密（DE）存储（开机未解锁也能用）并删掉那份，
 *   Mac 上的临时副本脚本跑完即删。（不在手机上生成再配对：adb pair 发的公钥由它自己的私钥算出，不读 adbkey.pub。）
 * 端口：App 读不到 /proc/net，用 NSD 找本机的 _adb-tls-connect._tcp；找不到再扫本机监听口（bind 探测）逐个握手。
 * 不校验 adbd 的证书：只连 127.0.0.1，冒充者拿到的只是一条启动命令，拿不到能去连 adbd 的东西（TLS 1.3 客户端签名绑定本次会话）。
 */
final class Adb {
    static final int CNXN = 0x4e584e43, STLS = 0x534c5453, OPEN = 0x4e45504f, OKAY = 0x59414b4f, CLSE = 0x45534c43, WRTE = 0x45545257;
    static final int VERSION = 0x01000001, MAXDATA = 1 << 20, STLS_VERSION = 0x01000000;
    static final String SERVICE = "_adb-tls-connect._tcp";

    /** 不是 adbd 的口（扫口时会遇到）。 */
    static final class NotAdb extends IOException { NotAdb(String m) { super(m); } }
    /** TLS 握手或握手后第一包失败：基本就是本 App 的钥匙不在 adb_keys 里（没配对 / 被「撤销 USB 调试授权」）。 */
    static final class Rejected extends IOException { Rejected(String m) { super(m); } }

    // ---- 钥匙 ----

    static File dir(Context c) {
        File d = new File(c.createDeviceProtectedStorageContext().getFilesDir(), "adb");
        d.mkdirs();
        return d;
    }

    static boolean hasKey(Context c) { return new File(dir(c), "adbkey.pk8").isFile(); }

    static synchronized KeyPair key(Context c) throws Exception {
        File f = new File(dir(c), "adbkey.pk8");
        if (!f.isFile()) throw new Rejected("还没有钥匙（Mac 上跑 permguard/adb/pair_watchdog.sh）");
        KeyFactory kf = KeyFactory.getInstance("RSA");
        RSAPrivateCrtKey k = (RSAPrivateCrtKey) kf.generatePrivate(new PKCS8EncodedKeySpec(Files.readAllBytes(f.toPath())));
        return new KeyPair(kf.generatePublic(new RSAPublicKeySpec(k.getModulus(), k.getPublicExponent())), k);
    }

    /** 收下 pair_watchdog.sh 推来的私钥（PKCS#8 DER），删掉外部那份。 */
    static synchronized void importKey(Context c, File src) throws Exception {
        byte[] b = Files.readAllBytes(src.toPath());
        src.delete();
        RSAPrivateCrtKey k = (RSAPrivateCrtKey) KeyFactory.getInstance("RSA").generatePrivate(new PKCS8EncodedKeySpec(b));
        if (k.getModulus().bitLength() != 2048) throw new IOException("不是 RSA-2048");
        File f = new File(dir(c), "adbkey.pk8"), tmp = new File(f.getPath() + ".tmp");
        try (FileOutputStream o = new FileOutputStream(tmp)) { o.write(b); }
        if (!tmp.renameTo(f)) throw new IOException("写不了 " + f);
    }

    /** adb_keys 的一行：mincrypt RSAPublicKey（len、n0inv、n、rr、e，小端）的 base64 + 名字（设置 → 无线调试 → 已配对设备里显示）。 */
    static String publicKey(Context c) throws Exception {
        RSAPublicKey k = (RSAPublicKey) key(c).getPublic();
        BigInteger n = k.getModulus(), r32 = BigInteger.ONE.shiftLeft(32);
        ByteBuffer b = ByteBuffer.allocate(4 + 4 + 256 + 256 + 4).order(ByteOrder.LITTLE_ENDIAN);
        b.putInt(64);
        b.putInt(r32.subtract(n.mod(r32).modInverse(r32)).intValue());
        b.put(le(n));
        b.put(le(BigInteger.ONE.shiftLeft(4096).mod(n)));
        b.putInt(k.getPublicExponent().intValue());
        return Base64.encodeToString(b.array(), Base64.NO_WRAP) + " permguard@" + Build.DEVICE;
    }

    static byte[] le(BigInteger v) {
        byte[] be = v.toByteArray(), out = new byte[256];
        for (int i = 0; i < 256 && i < be.length; i++) out[i] = be[be.length - 1 - i];
        return out;
    }

    /** 自签证书（v1）。adbd 只比对证书里的公钥，不看名字和有效期。 */
    static X509Certificate cert(KeyPair kp) throws Exception {
        byte[] alg = der(0x30, new byte[]{6, 9, 0x2a, (byte) 0x86, 0x48, (byte) 0x86, (byte) 0xf7, 0x0d, 1, 1, 11}, new byte[]{5, 0});
        byte[] name = der(0x30, der(0x31, der(0x30, new byte[]{6, 3, 0x55, 4, 3}, der(0x0c, "permguard".getBytes(StandardCharsets.UTF_8)))));
        byte[] validity = der(0x30, der(0x17, "200101000000Z".getBytes(StandardCharsets.US_ASCII)),
                der(0x18, "20991231235959Z".getBytes(StandardCharsets.US_ASCII)));
        byte[] tbs = der(0x30, new byte[]{2, 1, 1}, alg, name, validity, name, kp.getPublic().getEncoded());
        Signature s = Signature.getInstance("SHA256withRSA");
        s.initSign(kp.getPrivate());
        s.update(tbs);
        byte[] cert = der(0x30, tbs, alg, der(0x03, new byte[]{0}, s.sign()));
        return (X509Certificate) CertificateFactory.getInstance("X.509").generateCertificate(new ByteArrayInputStream(cert));
    }

    static byte[] der(int tag, byte[]... parts) {
        int n = 0;
        for (byte[] p : parts) n += p.length;
        ByteArrayOutputStream o = new ByteArrayOutputStream();
        o.write(tag);
        if (n < 0x80) o.write(n);
        else if (n < 0x100) { o.write(0x81); o.write(n); }
        else { o.write(0x82); o.write(n >> 8); o.write(n & 0xff); }
        for (byte[] p : parts) o.write(p, 0, p.length);
        return o.toByteArray();
    }

    // ---- 找端口 ----

    static List<Integer> findPorts(Context c) {
        List<Integer> r = nsd(c, 8000);
        return r.isEmpty() ? scan() : r;
    }

    /** 本机在 127.0.0.1 上有人监听这个口？（bind 失败且是 EADDRINUSE） */
    static boolean listening(int port) {
        try (ServerSocket s = new ServerSocket()) {
            s.setReuseAddress(true);
            s.bind(new InetSocketAddress(InetAddress.getByAddress(new byte[]{127, 0, 0, 1}), port), 1);
            return false;
        } catch (IOException e) {
            return String.valueOf(e.getMessage()).contains("EADDRINUSE");
        }
    }

    static List<Integer> nsd(Context c, long waitMs) {
        NsdManager nsd = c.getSystemService(NsdManager.class);
        List<Integer> found = Collections.synchronizedList(new ArrayList<>());
        List<NsdManager.ServiceInfoCallback> cbs = Collections.synchronizedList(new ArrayList<>());
        CountDownLatch done = new CountDownLatch(1);
        Executor direct = Runnable::run;   // 别用自建线程池：注销后 NSD 还会补投回调，池已关就 RejectedExecutionException 崩进程
        IntConsumer hit = port -> {   // 局域网里别的设备也可能广播这个服务：只认本机在监听的口
            if (port > 0 && !found.contains(port) && listening(port)) { found.add(port); done.countDown(); }
        };
        NsdManager.DiscoveryListener dl = new NsdManager.DiscoveryListener() {
            @Override public void onStartDiscoveryFailed(String t, int e) { done.countDown(); }
            @Override public void onStopDiscoveryFailed(String t, int e) { }
            @Override public void onDiscoveryStarted(String t) { }
            @Override public void onDiscoveryStopped(String t) { }
            @Override public void onServiceLost(NsdServiceInfo s) { }
            @Override public void onServiceFound(NsdServiceInfo s) {
                if (Build.VERSION.SDK_INT >= 34) {
                    NsdManager.ServiceInfoCallback cb = new NsdManager.ServiceInfoCallback() {
                        @Override public void onServiceInfoCallbackRegistrationFailed(int e) { }
                        @Override public void onServiceUpdated(NsdServiceInfo i) { hit.accept(i.getPort()); }
                        @Override public void onServiceLost() { }
                        @Override public void onServiceInfoCallbackUnregistered() { }
                    };
                    cbs.add(cb);
                    nsd.registerServiceInfoCallback(s, direct, cb);
                } else {
                    nsd.resolveService(s, new NsdManager.ResolveListener() {
                        @Override public void onResolveFailed(NsdServiceInfo i, int e) { }
                        @Override public void onServiceResolved(NsdServiceInfo i) { hit.accept(i.getPort()); }
                    });
                }
            }
        };
        try {
            nsd.discoverServices(SERVICE, NsdManager.PROTOCOL_DNS_SD, dl);
            done.await(waitMs, TimeUnit.MILLISECONDS);
        } catch (Exception ignored) {
        }
        try { nsd.stopServiceDiscovery(dl); } catch (Exception ignored) { }
        for (NsdManager.ServiceInfoCallback cb : new ArrayList<>(cbs)) try { nsd.unregisterServiceInfoCallback(cb); } catch (Exception ignored) { }
        return new ArrayList<>(found);
    }

    /** NSD 不灵时的兜底：adbd 的无线调试口是临时端口（ip_local_port_range 32768–60999），bind 探测出本机在监听的口。 */
    static List<Integer> scan() {
        List<Integer> r = new ArrayList<>();
        for (int p = 32768; p <= 60999 && r.size() < 40; p++) if (listening(p)) r.add(p);
        return r;
    }

    // ---- 协议 ----

    /** 连 127.0.0.1:port 的 adbd，跑 `shell:cmd`，返回输出。 */
    static String shell(Context c, int port, String cmd) throws Exception { return shell(key(c), port, cmd); }

    static String shell(KeyPair kp, int port, String cmd) throws Exception {
        X509Certificate cert = cert(kp);
        try (Socket s = new Socket()) {
            s.connect(new InetSocketAddress(InetAddress.getByAddress(new byte[]{127, 0, 0, 1}), port), 2000);
            s.setTcpNoDelay(true);
            s.setSoTimeout(1500);
            DataInputStream pin = new DataInputStream(s.getInputStream());
            send(s.getOutputStream(), CNXN, VERSION, MAXDATA, cstr("host::"));
            int[] h;
            try { h = recv(pin, null); } catch (IOException e) { throw new NotAdb(port + ": " + e); }
            if (h[0] != STLS) throw new NotAdb(port + ": 首包 0x" + Integer.toHexString(h[0]));
            send(s.getOutputStream(), STLS, STLS_VERSION, 0, null);

            SSLContext ctx = SSLContext.getInstance("TLSv1.3");
            ctx.init(new KeyManager[]{new Km(kp.getPrivate(), cert)}, new TrustManager[]{new TrustAll()}, null);
            SSLSocket t = (SSLSocket) ctx.getSocketFactory().createSocket(s, "127.0.0.1", port, true);
            t.setSoTimeout(5000);
            DataInputStream in;
            OutputStream out;
            try {
                t.startHandshake();
                in = new DataInputStream(t.getInputStream());
                out = t.getOutputStream();
                h = recv(in, null);   // TLS 1.3 下客户端证书被拒，要读第一包才知道
            } catch (SocketTimeoutException e) {
                throw e;
            } catch (IOException e) {
                throw new Rejected(e.toString());
            }
            if (h[0] != CNXN) throw new IOException("TLS 后首包不是 CNXN：0x" + Integer.toHexString(h[0]));

            t.setSoTimeout(60_000);
            send(out, OPEN, 1, 0, cstr("shell:" + cmd));
            ByteArrayOutputStream res = new ByteArrayOutputStream();
            while (true) {
                h = recv(in, res);
                if (h[0] == WRTE) send(out, OKAY, 1, h[1], null);
                else if (h[0] == CLSE) break;
                else if (h[0] != OKAY) throw new IOException("意外的 adb 消息 0x" + Integer.toHexString(h[0]));
            }
            return res.toString("UTF-8");
        }
    }

    static byte[] cstr(String s) { return (s + "\0").getBytes(StandardCharsets.UTF_8); }

    static void send(OutputStream o, int cmd, int a0, int a1, byte[] data) throws IOException {
        int n = data == null ? 0 : data.length, sum = 0;
        for (int i = 0; i < n; i++) sum += data[i] & 0xff;
        ByteBuffer b = ByteBuffer.allocate(24 + n).order(ByteOrder.LITTLE_ENDIAN);
        b.putInt(cmd).putInt(a0).putInt(a1).putInt(n).putInt(sum).putInt(~cmd);
        if (n > 0) b.put(data);
        o.write(b.array());
        o.flush();
    }

    /** 读一条消息，返回 {cmd, arg0, arg1}；WRTE 的载荷追加到 sink。 */
    static int[] recv(DataInputStream in, ByteArrayOutputStream sink) throws IOException {
        byte[] hb = new byte[24];
        in.readFully(hb);
        ByteBuffer b = ByteBuffer.wrap(hb).order(ByteOrder.LITTLE_ENDIAN);
        int cmd = b.getInt(), a0 = b.getInt(), a1 = b.getInt(), n = b.getInt();
        if (n < 0 || n > MAXDATA) throw new IOException("adb 消息长度不对：" + n);
        byte[] d = new byte[n];
        in.readFully(d);
        if (cmd == WRTE && sink != null) sink.write(d, 0, n);
        return new int[]{cmd, a0, a1};
    }

    /** adbd 发来的 CA 名单是已知公钥的摘要，默认 KeyManager 按它筛会挑不出钥匙：一律交这把。 */
    static final class Km extends X509ExtendedKeyManager {
        final PrivateKey k;
        final X509Certificate[] chain;
        Km(PrivateKey k, X509Certificate c) { this.k = k; chain = new X509Certificate[]{c}; }
        @Override public String chooseClientAlias(String[] t, Principal[] i, Socket s) { return "adb"; }
        @Override public String chooseEngineClientAlias(String[] t, Principal[] i, SSLEngine e) { return "adb"; }
        @Override public String[] getClientAliases(String t, Principal[] i) { return new String[]{"adb"}; }
        @Override public X509Certificate[] getCertificateChain(String a) { return chain; }
        @Override public PrivateKey getPrivateKey(String a) { return k; }
        @Override public String[] getServerAliases(String t, Principal[] i) { return null; }
        @Override public String chooseServerAlias(String t, Principal[] i, Socket s) { return null; }
    }

    static final class TrustAll implements X509TrustManager {
        @Override public void checkClientTrusted(X509Certificate[] c, String a) { }
        @Override public void checkServerTrusted(X509Certificate[] c, String a) { }
        @Override public X509Certificate[] getAcceptedIssuers() { return new X509Certificate[0]; }
    }
}
