package uk.tonytong.permguard;

import java.io.*;
import java.nio.charset.StandardCharsets;
import java.text.SimpleDateFormat;
import java.util.*;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * permguard 规则引擎：「默认拒绝 + 白名单」收回隐私权限。
 *
 * 以 shell 身份运行（adb：CLASSPATH=permguard.dex app_process / uk.tonytong.permguard.Core …；
 * 手机端：Shizuku 起的 shell 进程，classpath = permguard App 的 APK），只调用系统自带命令
 * （dumpsys package / cmd package revoke|grant|set-permission-flags / cmd appops / dumpsys role），不用隐藏 API。
 *
 * 用法: Core plan|apply|verify|restore [--conf 文件|-] [--dir 目录] [--snapshot 文件] [--system]
 *   plan     只算不改（= --dry-run），输出将被收回的清单
 *   apply    先写快照 state/snapshot-*.tsv，再收回，最后回读核对；结果写 journal-*.tsv
 *   verify   每个 App 每项隐私权限的实际状态（dumpsys/appops 原值）+「关不掉」清单；--system 连系统 App 一起查
 *   restore  按 --snapshot 把权限授予状态、可改的权限标志、appop 模式恢复到快照时的值
 * 退出码: 0 正常 / 3 有项目因 App 正在前台或正在用相机麦克风定位而推迟 / 1 出错 / 2 用法错
 */
public final class Core {

    static final String VERSION = "2026.10.03";
    static final int USER = 0;

    // ---------- 权限组 ----------
    static final Map<String, String> PERM_GROUP = new HashMap<>();
    static void g(String group, String... perms) { for (String p : perms) PERM_GROUP.put(p, group); }
    static {
        String a = "android.permission.";
        g("LOCATION", a + "ACCESS_FINE_LOCATION", a + "ACCESS_COARSE_LOCATION");
        g("LOCATION_BG", a + "ACCESS_BACKGROUND_LOCATION");
        g("CONTACTS", a + "READ_CONTACTS", a + "WRITE_CONTACTS", a + "GET_ACCOUNTS");
        g("CALL_LOG", a + "READ_CALL_LOG", a + "WRITE_CALL_LOG", a + "PROCESS_OUTGOING_CALLS");
        g("SMS", a + "READ_SMS", a + "SEND_SMS", a + "RECEIVE_SMS", a + "RECEIVE_MMS", a + "RECEIVE_WAP_PUSH",
                a + "READ_CELL_BROADCASTS");
        g("PHONE", a + "READ_PHONE_STATE", a + "READ_PHONE_NUMBERS", a + "CALL_PHONE", a + "ANSWER_PHONE_CALLS",
                a + "USE_SIP", a + "ACCEPT_HANDOVER", "com.android.voicemail.permission.ADD_VOICEMAIL");
        g("CAMERA", a + "CAMERA");
        g("MICROPHONE", a + "RECORD_AUDIO");
        g("CALENDAR", a + "READ_CALENDAR", a + "WRITE_CALENDAR");
        g("SENSORS", a + "BODY_SENSORS", a + "BODY_SENSORS_BACKGROUND");
        g("ACTIVITY", a + "ACTIVITY_RECOGNITION");
        g("MEDIA", a + "READ_EXTERNAL_STORAGE", a + "WRITE_EXTERNAL_STORAGE", a + "READ_MEDIA_IMAGES",
                a + "READ_MEDIA_VIDEO", a + "READ_MEDIA_AUDIO", a + "READ_MEDIA_VISUAL_USER_SELECTED");
        g("MEDIA_LOCATION", a + "ACCESS_MEDIA_LOCATION");
        g("NEARBY", a + "BLUETOOTH_SCAN", a + "BLUETOOTH_CONNECT", a + "BLUETOOTH_ADVERTISE",
                a + "NEARBY_WIFI_DEVICES", a + "UWB_RANGING", a + "RANGING");
        g("INSTALLED_APPS", "com.android.permission.GET_INSTALLED_APPS");   // 小米自定义 dangerous 权限（lbe 定义）
        g("NOTIFICATIONS", a + "POST_NOTIFICATIONS");                       // 不算隐私，不收
    }
    static String groupOf(String perm) {
        String gr = PERM_GROUP.get(perm);
        if (gr != null) return gr;
        if (perm.startsWith("android.permission.health.")) return "SENSORS";   // Android 16 的心率/血氧等
        return "OTHER";
    }

    /** 受管 appop：名称 → 组。数字 = MIUI 自有 op，常量名由 `Core opnames` 在本机反射 AppOpsManager 实测（README 附表）。 */
    static final LinkedHashMap<String, String> OP_GROUP = new LinkedHashMap<>();
    static final Map<String, String> OP_LABEL = new HashMap<>();
    static void op(String op, String group, String label) { OP_GROUP.put(op, group); OP_LABEL.put(op, label); }
    static {
        op("GET_USAGE_STATS", "USAGE_STATS", "使用情况访问");
        op("MANAGE_EXTERNAL_STORAGE", "ALL_FILES", "所有文件访问");
        op("READ_CLIPBOARD", "CLIPBOARD", "读剪贴板");
        op("10008", "AUTOSTART", "OP_AUTO_START 自启动");
        op("10021", "BG_START", "OP_BACKGROUND_START_ACTIVITY 后台弹出界面");
        op("10022", "INSTALLED_APPS", "OP_GET_INSTALLED_APPS 获取应用列表");
        op("10019", "USAGE_STATS", "OP_GET_TASKS 获取运行中的应用");
        op("10024", "AD_ID", "OP_GET_ANONYMOUS_ID 匿名设备标识");
        op("10025", "AD_ID", "OP_GET_UDEVICE_ID 设备标识");
        op("10037", "AD_ID", "OP_GET_OAID 广告标识符 OAID");
        op("10038", "AD_ID", "OP_GET_OAID_USER");
        op("10050", "AD_ID", "OP_DEVICE_ID 设备 ID");
        op("10027", "LOCATION_BG", "OP_BACKGROUND_LOCATION 后台定位");
        op("10036", "LOCATION", "OP_ACCESS_LOCATION_REAL");
        op("10043", "LOCATION", "OP_ANDROID_LOCATION_REAL");
        op("10004", "SMS", "OP_SEND_MMS 发彩信");
        op("10018", "SMS", "OP_READ_NOTIFICATION_SMS 读通知类短信");
        op("10028", "SMS", "OP_READ_SMS_REAL");
        op("10029", "CONTACTS", "OP_READ_CONTACTS_REAL");
        op("10030", "CALENDAR", "OP_READ_CALENDAR_REAL");
        op("10031", "CALL_LOG", "OP_READ_CALL_LOG_REAL");
        op("10032", "PHONE", "OP_READ_PHONE_STATE_REAL");
        op("10039", "PHONE", "OP_GET_PHONE_NUMBER_OPERATOR 运营商取本机号码");
        op("10046", "MICROPHONE", "OP_RECORD_VOICE_CALL 通话录音");
        op("10054", "SCREEN", "OP_AI_GET_SCREEN_CONTENT AI 读屏幕内容");
        op("10055", "SCREEN", "OP_AI_CTL_SCREEN_APP AI 操控屏幕");
    }

    static final Set<String> ALL_GROUPS = new TreeSet<>(Arrays.asList(
            "LOCATION", "LOCATION_BG", "CONTACTS", "CALL_LOG", "SMS", "PHONE", "CAMERA", "MICROPHONE", "CALENDAR",
            "SENSORS", "ACTIVITY", "MEDIA", "MEDIA_LOCATION", "NEARBY", "INSTALLED_APPS", "USAGE_STATS", "ALL_FILES",
            "CLIPBOARD", "AUTOSTART", "BG_START", "AD_ID", "SCREEN", "OTHER"));

    /** 永不触碰（不依赖配置文件，配置写错也碰不到）：Clash = always-on+锁定 VPN，动它整机断网。 */
    static final Set<String> HARD_EXEMPT = new HashSet<>(Arrays.asList(
            "com.github.metacubex.clash.meta", "moe.shizuku.privileged.api", "uk.tonytong.permguard"));

    /** shell 能改的权限标志（pm set-permission-flags），restore 只管这几个。 */
    static final String[][] FLAG_NAMES = {
            {"USER_SET", "user-set"}, {"USER_FIXED", "user-fixed"}, {"REVOKE_WHEN_REQUESTED", "revoke-when-requested"},
            {"REVOKED_COMPAT", "revoked-compat"}, {"REVIEW_REQUIRED", "review-required"}};

    // ---------- 配置 ----------
    static final class Conf {
        final Map<String, Set<String>> allow = new HashMap<>();
        final Map<String, String> note = new HashMap<>();
        final Set<String> reportOnly = new HashSet<>(Arrays.asList("OTHER", "CLIPBOARD"));
        final Set<String> manageSystem = new HashSet<>();
        final List<String> warnings = new ArrayList<>();

        boolean exempt(String pkg) {
            Set<String> s = allow.get(pkg);
            return HARD_EXEMPT.contains(pkg) || (s != null && s.contains("*"));
        }
        boolean allows(String pkg, String group) {
            Set<String> s = allow.get(pkg);
            if (s == null) return false;
            if (s.contains("*") || s.contains(group)) return true;
            return group.equals("LOCATION") && s.contains("LOCATION_BG");   // 给了后台定位就隐含前台
        }

        static Conf parse(Reader r) throws IOException {
            Conf c = new Conf();
            BufferedReader br = new BufferedReader(r);
            String line;
            int n = 0;
            while ((line = br.readLine()) != null) {
                n++;
                String cm = "";
                int h = line.indexOf('#');
                if (h >= 0) { cm = line.substring(h + 1).trim(); line = line.substring(0, h); }
                String[] t = line.trim().split("\\s+");
                if (t.length == 0 || t[0].isEmpty()) continue;
                if (t[0].startsWith("@")) {
                    for (int i = 1; i < t.length; i++) {
                        switch (t[0]) {
                            case "@report": c.checkGroup(t[i], n); c.reportOnly.add(t[i]); break;
                            case "@enforce": c.checkGroup(t[i], n); c.reportOnly.remove(t[i]); break;
                            case "@manage": c.manageSystem.add(t[i]); break;
                            default: c.warnings.add("第 " + n + " 行: 未知指令 " + t[0]);
                        }
                    }
                    continue;
                }
                Set<String> s = c.allow.computeIfAbsent(t[0], k -> new TreeSet<>());
                if (t.length > 1 && !t[1].equals("-")) {
                    for (String gr : t[1].split(",")) {
                        gr = gr.trim();
                        if (gr.isEmpty()) continue;
                        if (!gr.equals("*")) c.checkGroup(gr, n);
                        s.add(gr);
                    }
                }
                if (!cm.isEmpty()) c.note.put(t[0], cm);
            }
            return c;
        }
        void checkGroup(String gr, int n) {
            if (!ALL_GROUPS.contains(gr)) warnings.add("第 " + n + " 行: 未知权限组 " + gr + "（可用: " + ALL_GROUPS + "）");
        }
    }

    // ---------- 设备状态 ----------
    static final class Perm {
        final String name; boolean granted; String flags;
        Perm(String name, boolean granted, String flags) { this.name = name; this.granted = granted; this.flags = flags; }
        boolean hasFlag(String f) { return (" " + flags.replace('|', ' ') + " ").contains(" " + f + " "); }
    }
    static final class OpState { String uidMode = "none", pkgMode = "none", last = ""; boolean running; }
    static final class Pkg {
        String name, sharedUser = "", codePath = "";
        int targetSdk = -1, appId = -1;
        boolean system, updatedSystem, third, qap, disabled;
        final LinkedHashMap<String, Perm> rt = new LinkedHashMap<>();
        final Map<String, OpState> ops = new LinkedHashMap<>();
    }

    static String sh(String... cmd) {
        try {
            Process p = new ProcessBuilder(cmd).redirectErrorStream(true).start();
            p.getOutputStream().close();
            ByteArrayOutputStream bo = new ByteArrayOutputStream();
            InputStream in = p.getInputStream();
            byte[] b = new byte[65536];
            int k;
            while ((k = in.read(b)) > 0) bo.write(b, 0, k);
            p.waitFor();
            return bo.toString("UTF-8").replace("\r", "");
        } catch (Exception e) {
            return "EXEC-ERROR " + e;
        }
    }
    static List<String> pkgList(String... flags) {
        List<String> cmd = new ArrayList<>(Arrays.asList("cmd", "package", "list", "packages", "--user", String.valueOf(USER)));
        cmd.addAll(Arrays.asList(flags));
        List<String> r = new ArrayList<>();
        for (String l : sh(cmd.toArray(new String[0])).split("\n"))
            if (l.startsWith("package:")) r.add(l.substring(8).trim());
        Collections.sort(r);
        return r;
    }

    static final Pattern RT_LINE = Pattern.compile("^\\s+(\\S+): granted=(true|false)(?:, flags=\\[ ?(.*?)\\])?");

    static Pkg readPkg(String name) {
        Pkg p = new Pkg();
        p.name = name;
        String out = sh("dumpsys", "package", name);
        String[] L = out.split("\n");
        int i = 0;
        while (i < L.length && !L[i].equals("Packages:")) i++;
        while (i < L.length && !L[i].startsWith("  Package [" + name + "]")) i++;
        if (i >= L.length) return null;
        String section = "";
        boolean inUser0 = false;
        for (i = i + 1; i < L.length && L[i].startsWith("    "); i++) {
            String l = L[i];
            Matcher m;
            if (l.startsWith("    ") && !l.startsWith("     ")) {   // 4 格缩进 = 属性行 / 小节头
                section = "";
                inUser0 = false;
                if ((m = Pattern.compile("targetSdk=(\\d+)").matcher(l)).find()) p.targetSdk = Integer.parseInt(m.group(1));
                if ((m = Pattern.compile("^    appId=(\\d+)").matcher(l)).find()) p.appId = Integer.parseInt(m.group(1));
                if ((m = Pattern.compile("sharedUser=SharedUserSetting\\{\\S+ (\\S+)/(\\d+)\\}").matcher(l)).find()) p.sharedUser = m.group(1);
                if (l.startsWith("    codePath=")) p.codePath = l.substring(13).trim();
                if (l.startsWith("    pkgFlags=[")) {
                    p.system = l.contains(" SYSTEM ");
                    p.updatedSystem = l.contains("UPDATED_SYSTEM_APP");
                }
                if (l.equals("    install permissions:")) section = "install";
                if (l.startsWith("    User " + USER + ":")) {
                    inUser0 = true;
                    p.disabled = Pattern.compile("enabled=[23]").matcher(l).find();
                }
                continue;
            }
            if (section.equals("install") && l.trim().startsWith("android.permission.QUERY_ALL_PACKAGES: granted=true")) p.qap = true;
            if (inUser0) {
                if (l.equals("      runtime permissions:")) { section = "rt"; continue; }
                if (l.startsWith("      ") && !l.startsWith("       ")) section = section.equals("rt") ? "" : section;
                if (section.equals("rt") && (m = RT_LINE.matcher(l)).find())
                    p.rt.put(m.group(1), new Perm(m.group(1), m.group(2).equals("true"), m.group(3) == null ? "" : m.group(3)));
            }
        }
        if (!p.sharedUser.isEmpty()) {   // 共享 UID 的运行时权限记在 Shared users 小节
            int j = 0;
            while (j < L.length && !L[j].startsWith("  SharedUser [" + p.sharedUser + "]")) j++;
            boolean u0 = false, rt = false;
            for (j = j + 1; j < L.length && L[j].startsWith("    "); j++) {
                String l = L[j];
                if (l.startsWith("    ") && !l.startsWith("     ")) { u0 = l.startsWith("    User " + USER + ":"); rt = false; continue; }
                if (u0 && l.equals("      runtime permissions:")) { rt = true; continue; }
                Matcher m;
                if (u0 && rt && (m = RT_LINE.matcher(l)).find())
                    p.rt.put(m.group(1), new Perm(m.group(1), m.group(2).equals("true"), m.group(3) == null ? "" : m.group(3)));
            }
        }
        return p;
    }

    static OpState readOp(String pkg, String op) {
        OpState s = new OpState();
        for (String l : sh("cmd", "appops", "get", "--user", String.valueOf(USER), pkg, op).split("\n")) {
            boolean uid = l.startsWith("Uid mode: ");
            String body = uid ? l.substring(10) : l;
            int c = body.indexOf(": ");
            if (c < 0) continue;
            String rest = body.substring(c + 2);
            String mode = rest.split("[;\\s]")[0];
            if (uid) s.uidMode = mode; else s.pkgMode = mode;
            Matcher m = Pattern.compile("time=\\+(\\S+) ago").matcher(rest);
            if (m.find() && !rest.contains("rejectTime=+" + m.group(1))) s.last = m.group(1);
            if (rest.contains("running")) s.running = true;
        }
        return s;
    }
    /** 整包 appops 里出现且为 allow/foreground 的受管 op（整包输出分不清 uid/包模式，所以再逐个精确查）。 */
    static Set<String> candidateOps(String pkg) {
        Set<String> r = new LinkedHashSet<>();
        for (String l : sh("cmd", "appops", "get", "--user", String.valueOf(USER), pkg).split("\n")) {
            if (l.startsWith("Uid mode: ")) l = l.substring(10);
            int c = l.indexOf(": ");
            if (c < 0) continue;
            String name = l.substring(0, c).trim(), mode = l.substring(c + 2).split("[;\\s]")[0];
            if (name.startsWith("MIUIOP(") && name.endsWith(")")) name = name.substring(7, name.length() - 1);
            if (OP_GROUP.containsKey(name) && allowedMode(mode)) r.add(name);
        }
        return r;
    }
    static boolean allowedMode(String m) { return m.equals("allow") || m.equals("foreground"); }

    static final class Device {
        List<String> third, sys;
        final Map<String, Pkg> pkgs = new TreeMap<>();
        final Map<String, Set<String>> roles = new TreeMap<>();     // pkg → 角色
        final Set<String> foreground = new HashSet<>();
        final Map<String, List<String>> special = new TreeMap<>();   // pkg → 特殊权限说明
        String fingerprint = "";

        static Device collect(Conf conf, boolean withSystem) {
            Device d = new Device();
            d.fingerprint = sh("getprop", "ro.build.fingerprint").trim();
            d.third = pkgList("-3");
            d.sys = pkgList("-s");
            String role = null;
            for (String l : sh("dumpsys", "role").split("\n")) {
                String t = l.trim();
                if (t.startsWith("name=")) role = t.substring(5);
                else if (t.startsWith("holders=") && role != null)
                    for (String h : t.substring(8).split(","))
                        if (!h.trim().isEmpty()) d.roles.computeIfAbsent(h.trim(), k -> new TreeSet<>()).add(role.replace("android.app.role.", ""));
            }
            if (sh("dumpsys", "power").contains("mWakefulness=Awake")) {   // 灭屏时不算前台
                Matcher m = Pattern.compile("(?:topResumedActivity|mResumedActivity|ResumedActivity)[:=] ?ActivityRecord\\{\\S+ u\\d+ ([^/ ]+)/")
                        .matcher(sh("dumpsys", "activity", "activities"));
                while (m.find()) d.foreground.add(m.group(1));
            }
            d.specials();
            Set<String> want = new TreeSet<>(d.third);
            want.addAll(conf.manageSystem);
            if (withSystem) want.addAll(d.sys);
            Set<String> thirdSet = new HashSet<>(d.third);
            for (String n : want) {
                Pkg p = readPkg(n);
                if (p == null) continue;
                p.third = thirdSet.contains(n);
                if (p.third || conf.manageSystem.contains(n))
                    for (String op : candidateOps(n)) p.ops.put(op, readOp(n, op));
                d.pkgs.put(n, p);
            }
            return d;
        }

        void specials() {
            String[][] keys = {{"enabled_notification_listeners", "通知使用权"}, {"enabled_accessibility_services", "无障碍服务"},
                    {"default_input_method", "默认输入法（看得到所有键入）"}, {"always_on_vpn_app", "常驻 VPN"}};
            for (String[] k : keys) {
                String v = sh("settings", "get", "secure", k[0]).trim();
                if (v.isEmpty() || v.equals("null")) continue;
                for (String comp : v.split(":")) {
                    String pkg = comp.split("/")[0].trim();
                    if (!pkg.isEmpty()) special.computeIfAbsent(pkg, x -> new ArrayList<>()).add(k[1]);
                }
            }
            Matcher m = Pattern.compile("admin=ComponentInfo\\{([^/}]+)/").matcher(sh("dumpsys", "device_policy"));
            while (m.find()) special.computeIfAbsent(m.group(1), x -> new ArrayList<>()).add("设备管理器");
        }
        boolean managed(Conf c, Pkg p) { return p.third || c.manageSystem.contains(p.name); }
        boolean inUse(Pkg p) {
            if (foreground.contains(p.name)) return true;
            for (String op : new String[]{"CAMERA", "RECORD_AUDIO", "FINE_LOCATION", "COARSE_LOCATION"})
                if (readOp(p.name, op).running) return true;
            return false;
        }
    }

    // ---------- 决策 ----------
    enum Act { REVOKE, KEEP, REPORT, FIXED, DEFER }
    static final class Item {
        String pkg, kind, name, group, cur, target = "", reason;   // kind: perm / op / uidop
        Act act;
        String result = "";
    }

    static List<Item> decide(Device d, Conf c, boolean checkInUse) {
        List<Item> out = new ArrayList<>();
        Map<String, Boolean> inUse = new HashMap<>();
        for (Pkg p : d.pkgs.values()) {
            boolean managed = d.managed(c, p);
            Set<String> roles = d.roles.getOrDefault(p.name, Collections.emptySet());
            for (Perm r : p.rt.values()) {
                String gr = groupOf(r.name);
                if (!r.granted || gr.equals("NOTIFICATIONS")) continue;
                Item it = new Item();
                it.pkg = p.name; it.kind = "perm"; it.name = r.name; it.group = gr;
                it.cur = "granted [" + r.flags + "]";
                if (c.exempt(p.name)) { it.act = Act.KEEP; it.reason = "豁免"; }
                else if (r.hasFlag("SYSTEM_FIXED") || r.hasFlag("POLICY_FIXED")) { it.act = Act.FIXED; it.reason = "SYSTEM_FIXED/POLICY_FIXED，shell 不能收"; }
                else if (r.hasFlag("GRANTED_BY_ROLE") && !roles.isEmpty()) { it.act = Act.KEEP; it.reason = "默认角色 " + roles; }
                else if (c.allows(p.name, gr)) { it.act = Act.KEEP; it.reason = "白名单"; }
                else if (c.reportOnly.contains(gr)) { it.act = Act.REPORT; it.reason = "该组只报告"; }
                else if (!managed) { it.act = Act.REPORT; it.reason = "系统 App，只报告（白名单 @manage 才收）"; }
                else {
                    it.act = Act.REVOKE;
                    it.target = p.targetSdk < 23 ? "revoked-compat+appop ignore" : "revoke";
                    it.reason = p.targetSdk < 23 ? "targetSdk<23 兼容模式" : "默认拒绝";
                    if (checkInUse && inUse.computeIfAbsent(p.name, k -> d.inUse(p))) { it.act = Act.DEFER; it.reason = "正在前台/正在用相机麦克风定位，下轮再收"; }
                }
                out.add(it);
            }
            for (Map.Entry<String, OpState> e : p.ops.entrySet()) {
                String op = e.getKey(), gr = OP_GROUP.get(op);
                OpState s = e.getValue();
                for (String kind : new String[]{"uidop", "op"}) {
                    String mode = kind.equals("uidop") ? s.uidMode : s.pkgMode;
                    if (!allowedMode(mode)) continue;
                    if (op.equals("READ_CLIPBOARD") && kind.equals("uidop") && mode.equals("foreground")) continue;   // MIUI 给所有 App 的默认值
                    Item it = new Item();
                    it.pkg = p.name; it.kind = kind; it.name = op; it.group = gr;
                    it.cur = mode + (s.last.isEmpty() ? "" : " (最近使用 " + s.last + " 前)");
                    if (c.exempt(p.name)) { it.act = Act.KEEP; it.reason = "豁免"; }
                    else if (c.allows(p.name, gr)) { it.act = Act.KEEP; it.reason = "白名单"; }
                    else if (c.reportOnly.contains(gr)) { it.act = Act.REPORT; it.reason = "该组只报告"; }
                    else if (!managed) { it.act = Act.REPORT; it.reason = "系统 App，只报告"; }
                    else { it.act = Act.REVOKE; it.target = "ignore"; it.reason = "默认拒绝"; }
                    out.add(it);
                }
            }
        }
        return out;
    }

    // ---------- 执行 ----------
    static String permToOp(String perm) {
        try {   // app_process 里框架类在 bootclasspath 上
            Object o = Class.forName("android.app.AppOpsManager").getMethod("permissionToOp", String.class).invoke(null, perm);
            return o == null ? null : o.toString();
        } catch (Throwable t) {
            return null;
        }
    }

    static String exec(Item it) {
        String u = String.valueOf(USER);
        String r;
        switch (it.kind) {
            case "perm":
                if (it.target.startsWith("revoked-compat")) {
                    String op = permToOp(it.name);
                    if (op == null) return "FAIL 找不到对应 appop";
                    r = sh("cmd", "package", "set-permission-flags", "--user", u, it.pkg, it.name, "revoked-compat")
                            + sh("cmd", "appops", "set", "--user", u, it.pkg, op, "ignore");
                } else {
                    r = sh("cmd", "package", "revoke", "--user", u, it.pkg, it.name);
                }
                break;
            case "uidop":
                r = sh("cmd", "appops", "set", "--user", u, "--uid", it.pkg, it.name, it.target);
                break;
            default:
                r = sh("cmd", "appops", "set", "--user", u, it.pkg, it.name, it.target);
        }
        r = r.trim();
        return r.isEmpty() ? "OK" : "FAIL " + r.replace('\n', ' ').replace('\t', ' ');
    }

    // ---------- 快照 / 恢复 ----------
    static void writeSnapshot(Device d, File f, String ts) throws IOException {
        try (PrintWriter w = new PrintWriter(new OutputStreamWriter(new FileOutputStream(f), StandardCharsets.UTF_8))) {
            w.println("#permguard-snapshot v1 " + ts + " " + d.fingerprint);
            w.println("#P 包 权限 granted(1/0) flags | O 包 op uid|pkg 模式（none=未设置）");
            for (Pkg p : d.pkgs.values()) {
                for (Perm r : p.rt.values()) w.println("P\t" + p.name + "\t" + r.name + "\t" + (r.granted ? 1 : 0) + "\t" + r.flags);
                for (Map.Entry<String, OpState> e : p.ops.entrySet()) {
                    w.println("O\t" + p.name + "\t" + e.getKey() + "\tuid\t" + e.getValue().uidMode);
                    w.println("O\t" + p.name + "\t" + e.getKey() + "\tpkg\t" + e.getValue().pkgMode);
                }
            }
        }
    }

    static int restore(File snap, PrintStream out) throws IOException {
        List<String[]> rows = new ArrayList<>();
        try (BufferedReader br = new BufferedReader(new InputStreamReader(new FileInputStream(snap), StandardCharsets.UTF_8))) {
            String l;
            while ((l = br.readLine()) != null) if (!l.startsWith("#") && !l.isEmpty()) rows.add(l.split("\t", -1));
        }
        Map<String, Pkg> now = new HashMap<>();
        Set<String> installed = new HashSet<>(pkgList());
        String u = String.valueOf(USER);
        int changed = 0, failed = 0, same = 0;
        for (String[] r : rows) {
            String pkg = r[1];
            if (!installed.contains(pkg)) continue;
            Pkg p = now.computeIfAbsent(pkg, Core::readPkg);
            if (p == null) continue;
            if (r[0].equals("P")) {
                Perm cur = p.rt.get(r[2]);
                if (cur == null) continue;
                boolean want = r[3].equals("1");
                Perm snapPerm = new Perm(r[2], want, r.length > 4 ? r[4] : "");
                List<String> cmds = new ArrayList<>();
                for (String[] fl : FLAG_NAMES) {   // 先改标志（USER_FIXED 等会挡住 grant）
                    boolean a = snapPerm.hasFlag(fl[0]), b = cur.hasFlag(fl[0]);
                    if (a && !b) cmds.add("set-permission-flags " + fl[1]);
                    if (!a && b) cmds.add("clear-permission-flags " + fl[1]);
                }
                if (want != cur.granted) cmds.add(want ? "grant" : "revoke");
                if (cmds.isEmpty()) { same++; continue; }
                StringBuilder res = new StringBuilder();
                for (String c : cmds) {
                    String[] cc = c.split(" ");
                    String o = cc.length == 2
                            ? sh("cmd", "package", cc[0], "--user", u, pkg, r[2], cc[1])
                            : sh("cmd", "package", cc[0], "--user", u, pkg, r[2]);
                    res.append(o.trim());
                }
                boolean ok = res.toString().isEmpty();
                if (ok) changed++; else failed++;
                out.println((ok ? "RESTORED\t" : "FAILED\t") + pkg + "\t" + r[2] + "\t" + String.join(",", cmds) + (ok ? "" : "\t" + res.toString().replace('\n', ' ')));
            } else if (r[0].equals("O")) {
                OpState cur = readOp(pkg, r[2]);
                String want = r[4], have = r[3].equals("uid") ? cur.uidMode : cur.pkgMode;
                if (want.equals(have)) { same++; continue; }
                String mode = want.equals("none") ? "default" : want;
                if (mode.equals("default") && have.equals("default")) { same++; continue; }
                String o = r[3].equals("uid")
                        ? sh("cmd", "appops", "set", "--user", u, "--uid", pkg, r[2], mode)
                        : sh("cmd", "appops", "set", "--user", u, pkg, r[2], mode);
                boolean ok = o.trim().isEmpty();
                if (ok) changed++; else failed++;
                out.println((ok ? "RESTORED\t" : "FAILED\t") + pkg + "\t" + r[2] + "(" + r[3] + ")\t" + have + "→" + mode + (ok ? "" : "\t" + o.trim()));
            }
        }
        out.println("restore: 改回 " + changed + " 项，失败 " + failed + " 项，本来就一致 " + same + " 项（快照 " + snap.getName() + "）");
        return failed == 0 ? 0 : 1;
    }

    // ---------- 报告 ----------
    static String esc(String s) { return s.replace("|", "\\|"); }
    static String shortPerm(String p) { return p.replace("android.permission.", "").replace("com.android.permission.", "").replace("com.android.voicemail.permission.", ""); }
    static String opLabel(String op) { String l = OP_LABEL.get(op); return l == null ? op : op + " " + l; }

    static void writeItemsTsv(List<Item> items, File f) throws IOException {
        try (PrintWriter w = new PrintWriter(new OutputStreamWriter(new FileOutputStream(f), StandardCharsets.UTF_8))) {
            w.println("pkg\tkind\tname\tgroup\tcurrent\taction\ttarget\treason\tresult");
            for (Item it : items)
                w.println(String.join("\t", it.pkg, it.kind, it.name, it.group, it.cur, it.act.name(), it.target, it.reason, it.result));
        }
    }

    static Map<Act, Integer> count(List<Item> items) {
        Map<Act, Integer> m = new EnumMap<>(Act.class);
        for (Act a : Act.values()) m.put(a, 0);
        for (Item it : items) m.merge(it.act, 1, Integer::sum);
        return m;
    }
    static int pkgCount(List<Item> items, Act a) {
        Set<String> s = new HashSet<>();
        for (Item it : items) if (it.act == a) s.add(it.pkg);
        return s.size();
    }

    static void writePlanMd(List<Item> items, Device d, Conf c, File f, String title) throws IOException {
        try (PrintWriter w = new PrintWriter(new OutputStreamWriter(new FileOutputStream(f), StandardCharsets.UTF_8))) {
            Map<Act, Integer> n = count(items);
            w.println("# " + title);
            w.println();
            w.println("- 设备：`" + d.fingerprint + "`；第三方 App " + d.third.size() + " 个；permguard " + VERSION);
            w.println("- 收回 " + n.get(Act.REVOKE) + " 项 / " + pkgCount(items, Act.REVOKE) + " 个 App；推迟 " + n.get(Act.DEFER)
                    + "；保留（白名单/角色/豁免）" + n.get(Act.KEEP) + "；只报告 " + n.get(Act.REPORT) + "；系统固定 " + n.get(Act.FIXED));
            for (String wn : c.warnings) w.println("- ⚠️ 配置: " + wn);
            for (Act a : new Act[]{Act.REVOKE, Act.DEFER, Act.REPORT, Act.FIXED, Act.KEEP}) {
                List<Item> sel = new ArrayList<>();
                for (Item it : items) if (it.act == a) sel.add(it);
                if (sel.isEmpty()) continue;
                w.println();
                w.println("## " + actTitle(a) + "（" + sel.size() + "）");
                w.println();
                w.println("| App | 组 | 权限 / appop | 当前 | 动作 | 理由 |" + (sel.get(0).result.isEmpty() ? "" : " 结果 |"));
                w.println("|---|---|---|---|---|---|" + (sel.get(0).result.isEmpty() ? "" : "---|"));
                for (Item it : sel)
                    w.println("| " + it.pkg + " | " + it.group + " | " + (it.kind.equals("perm") ? shortPerm(it.name) : esc(opLabel(it.name)) + (it.kind.equals("uidop") ? "（uid 模式）" : ""))
                            + " | " + esc(it.cur) + " | " + (it.target.isEmpty() ? "—" : it.target) + " | " + esc(it.reason) + " |"
                            + (it.result.isEmpty() ? "" : " " + esc(it.result) + " |"));
            }
        }
    }
    static String actTitle(Act a) {
        switch (a) {
            case REVOKE: return "收回";
            case DEFER: return "推迟（App 正在用）";
            case REPORT: return "只报告不改";
            case FIXED: return "系统固定（shell 收不了）";
            default: return "保留";
        }
    }

    static final String[] VERIFY_GROUPS = {"LOCATION", "LOCATION_BG", "CONTACTS", "CALL_LOG", "SMS", "PHONE", "CAMERA",
            "MICROPHONE", "CALENDAR", "SENSORS", "ACTIVITY", "MEDIA", "MEDIA_LOCATION", "NEARBY", "INSTALLED_APPS", "OTHER"};

    /** verify：每个第三方 App 每项隐私权限的实际状态（只列 App 申请了的），CSV + Markdown。 */
    static void writeVerify(Device d, Conf c, File csv, File md) throws IOException {
        try (PrintWriter wc = new PrintWriter(new OutputStreamWriter(new FileOutputStream(csv), StandardCharsets.UTF_8));
             PrintWriter wm = new PrintWriter(new OutputStreamWriter(new FileOutputStream(md), StandardCharsets.UTF_8))) {
            wc.println("pkg,third_party,kind,name,group,state,flags_or_last_use,whitelisted");
            wm.println("# permguard verify — 实际状态（dumpsys package / cmd appops 原值）");
            wm.println();
            wm.println("设备 `" + d.fingerprint + "`。每格 = 该组里**已授予**的权限 / 申请了的权限；✔ = 白名单或角色允许持有。appop 列只列 allow/foreground。");
            wm.println();
            wm.println("| App | " + String.join(" | ", VERIFY_GROUPS) + " | appop 放行 |");
            StringBuilder sep = new StringBuilder("|---|");
            for (int i = 0; i <= VERIFY_GROUPS.length; i++) sep.append("---|");
            wm.println(sep);
            int grantedPriv = 0, pk = 0;
            for (Pkg p : d.pkgs.values()) {
                if (!d.managed(c, p)) continue;
                Map<String, int[]> gc = new HashMap<>();
                for (Perm r : p.rt.values()) {
                    String gr = groupOf(r.name);
                    if (gr.equals("NOTIFICATIONS")) continue;
                    int[] v = gc.computeIfAbsent(gr, k -> new int[2]);
                    v[1]++;
                    if (r.granted) v[0]++;
                    boolean wl = c.exempt(p.name) || c.allows(p.name, gr);
                    wc.println(csvRow(p.name, "1", "perm", r.name, gr, r.granted ? "granted" : "denied", r.flags, wl ? "1" : "0"));
                }
                List<String> opAllowed = new ArrayList<>();
                for (Map.Entry<String, OpState> e : p.ops.entrySet()) {
                    OpState s = e.getValue();
                    String gr = OP_GROUP.get(e.getKey());
                    boolean wl = c.exempt(p.name) || c.allows(p.name, gr);
                    wc.println(csvRow(p.name, "1", "op", e.getKey(), gr, "uid=" + s.uidMode + " pkg=" + s.pkgMode, s.last, wl ? "1" : "0"));
                    for (String m : new String[]{s.uidMode, s.pkgMode})
                        if (allowedMode(m) && !(e.getKey().equals("READ_CLIPBOARD") && m.equals("foreground") && s.uidMode.equals(m))) {
                            opAllowed.add(e.getKey() + "=" + m + (wl ? "✔" : ""));
                            break;
                        }
                }
                StringBuilder row = new StringBuilder("| " + p.name + " |");
                boolean any = false;
                for (String gr : VERIFY_GROUPS) {
                    int[] v = gc.get(gr);
                    if (v == null) { row.append(" |"); continue; }
                    boolean wl = c.exempt(p.name) || c.allows(p.name, gr);
                    if (v[0] > 0) { any = true; grantedPriv += v[0]; }
                    row.append(" ").append(v[0] > 0 ? "**" + v[0] + "**" : "0").append("/").append(v[1]).append(wl ? " ✔" : "").append(" |");
                }
                row.append(" ").append(String.join(" ", opAllowed)).append(" |");
                if (any || !opAllowed.isEmpty()) pk++;
                wm.println(row);
            }
            wm.println();
            wm.println("合计：第三方 App 当前已授予的隐私类运行时权限 **" + grantedPriv + "** 项，涉及 " + pk + " 个 App（含白名单与豁免）。");
            if (d.pkgs.size() > d.third.size()) {
                wm.println();
                wm.println("## 系统 App（只报告）");
                wm.println();
                wm.println("| App | 已授予的隐私权限（非 SYSTEM_FIXED 的加粗） |");
                wm.println("|---|---|");
                for (Pkg p : d.pkgs.values()) {
                    if (d.managed(c, p)) continue;
                    List<String> l = new ArrayList<>();
                    for (Perm r : p.rt.values()) {
                        String gr = groupOf(r.name);
                        if (!r.granted || gr.equals("NOTIFICATIONS")) continue;
                        boolean fx = r.hasFlag("SYSTEM_FIXED") || r.hasFlag("POLICY_FIXED");
                        wc.println(csvRow(p.name, "0", "perm", r.name, gr, "granted", r.flags, "-"));
                        l.add(fx ? shortPerm(r.name) : "**" + shortPerm(r.name) + "**");
                    }
                    if (!l.isEmpty()) wm.println("| " + p.name + (p.sharedUser.isEmpty() ? "" : "（" + p.sharedUser + "）") + " | " + String.join(" ", l) + " |");
                }
            }
        }
    }
    static String csvRow(String... f) {
        StringBuilder b = new StringBuilder();
        for (int i = 0; i < f.length; i++) {
            if (i > 0) b.append(',');
            String s = f[i] == null ? "" : f[i];
            b.append(s.contains(",") || s.contains("\"") ? "\"" + s.replace("\"", "\"\"") + "\"" : s);
        }
        return b.toString();
    }

    /** 「关不掉」清单：权限模型管不住的部分，每项给建议。第三方 App 逐个排序；系统 App 按 UID 身份合并。 */
    static int writeUnfixable(Device d, Conf c, File md) throws IOException {
        Set<String> disabled = new HashSet<>(pkgList("-d"));
        List<String[]> rows = new ArrayList<>();   // 包, 问题, 建议, 排序分
        Map<String, List<Pkg>> sysById = new TreeMap<>();
        for (Pkg p : d.pkgs.values()) {
            int fixed = 0;
            for (Perm r : p.rt.values())
                if (r.granted && !groupOf(r.name).equals("NOTIFICATIONS") && (r.hasFlag("SYSTEM_FIXED") || r.hasFlag("POLICY_FIXED"))) fixed++;
            List<String> sp = d.special.get(p.name);
            if (!p.third) {
                if (fixed > 0 || p.qap || sp != null)
                    sysById.computeIfAbsent(p.sharedUser.isEmpty() ? p.name : p.sharedUser + "/" + p.appId, k -> new ArrayList<>()).add(p);
                continue;
            }
            List<String> why = new ArrayList<>();
            int score = 0;
            if (sp != null) { why.add("特殊权限：" + String.join("、", sp) + "（只报告，不自动改）"); score += 4; }
            if (p.qap) { why.add("QUERY_ALL_PACKAGES（安装时权限，收不回；MIUI 10022 只挡 getInstalledPackages 一条路）"); score += 3; }
            if (p.targetSdk >= 0 && p.targetSdk < 23) { why.add("targetSdk=" + p.targetSdk + "<23：运行时权限安装即授予，只能兼容模式 appop ignore"); score += 4; }
            else if (p.targetSdk >= 0 && p.targetSdk < 30) { why.add("targetSdk=" + p.targetSdk + "<30：不受包可见性过滤，等同看得到全部已装 App"); score += 2; }
            if (!p.sharedUser.isEmpty()) { why.add("sharedUserId=" + p.sharedUser + "：权限按 UID 共用"); score += 1; }
            if (fixed > 0) { why.add(fixed + " 项隐私权限 SYSTEM_FIXED"); score += Math.min(fixed, 5); }
            if (why.isEmpty()) continue;
            String advice;
            if (HARD_EXEMPT.contains(p.name)) advice = "保留（本方案组件；Clash 按包分流需要应用列表）";
            else if (disabled.contains(p.name)) advice = "卸载（已停用，`pm uninstall --user 0`，按 debloat 流程先查依赖）";
            else if (sp != null) advice = "保留但定期复核（特殊权限只能在系统设置里手动关）";
            else if (p.name.startsWith("com.google.") || p.name.equals("com.android.chrome")) advice = "保留（谷歌系；网络侧 GOOGLE_TELEMETRY 已拦遥测）";
            else advice = "不常用就卸载；要用就隔离到手机分身/工作资料";
            rows.add(new String[]{p.name, String.join("；", why), advice, String.valueOf(score)});
        }
        rows.sort((x, y) -> Integer.parseInt(y[3]) != Integer.parseInt(x[3]) ? Integer.parseInt(y[3]) - Integer.parseInt(x[3]) : x[0].compareTo(y[0]));
        try (PrintWriter w = new PrintWriter(new OutputStreamWriter(new FileOutputStream(md), StandardCharsets.UTF_8))) {
            w.println("# permguard —「关不掉」清单");
            w.println();
            w.println("## 第三方 App（按影响排序）");
            w.println();
            w.println("| # | App | 为什么权限模型管不住 | 建议 |");
            w.println("|---|---|---|---|");
            int i = 0;
            for (String[] r : rows) w.println("| " + (++i) + " | " + r[0] + " | " + esc(r[1]) + " | " + r[2] + " |");
            w.println();
            w.println("## 系统 App（按 UID 身份合并；只报告。SYSTEM_FIXED = shell 也收不了；能删的走 debloat 流程，KEEP.txt 禁删）");
            w.println();
            w.println("| 身份 | 包数 | QUERY_ALL_PACKAGES | 固定隐私权限（最多的那个包） | 特殊权限 | 成员（前 6 个） |");
            w.println("|---|---|---|---|---|---|");
            List<Map.Entry<String, List<Pkg>>> ids = new ArrayList<>(sysById.entrySet());
            ids.sort((x, y) -> y.getValue().size() - x.getValue().size());
            for (Map.Entry<String, List<Pkg>> e : ids) {
                int qap = 0, maxFixed = 0;
                Set<String> sp = new TreeSet<>();
                List<String> names = new ArrayList<>();
                for (Pkg p : e.getValue()) {
                    if (p.qap) qap++;
                    int f = 0;
                    for (Perm r : p.rt.values())
                        if (r.granted && !groupOf(r.name).equals("NOTIFICATIONS") && (r.hasFlag("SYSTEM_FIXED") || r.hasFlag("POLICY_FIXED"))) f++;
                    maxFixed = Math.max(maxFixed, f);
                    List<String> s = d.special.get(p.name);
                    if (s != null) for (String x : s) sp.add(p.name + "：" + x);
                    if (names.size() < 6) names.add(p.name);
                }
                w.println("| " + e.getKey() + " | " + e.getValue().size() + " | " + qap + " | " + maxFixed + " | " + String.join("；", sp) + " | " + String.join(" ", names) + (e.getValue().size() > 6 ? " …" : "") + " |");
            }
        }
        return rows.size();
    }

    // ---------- main ----------
    public static void main(String[] args) {
        int rc;
        try {
            rc = run(args);
        } catch (Throwable t) {
            t.printStackTrace(System.out);
            rc = 1;
        }
        System.out.flush();
        System.exit(rc);
    }

    static int run(String[] args) throws Exception {
        if (args.length == 0) { System.out.println("用法: Core plan|apply|verify|restore [--conf F|-] [--dir D] [--snapshot F] [--system]"); return 2; }
        String mode = args[0], confPath = null, snap = null;
        File dir = new File("/data/local/tmp/permguard");
        boolean withSystem = false;
        for (int i = 1; i < args.length; i++) {
            switch (args[i]) {
                case "--conf": confPath = args[++i]; break;
                case "--dir": dir = new File(args[++i]); break;
                case "--snapshot": snap = args[++i]; break;
                case "--system": withSystem = true; break;
                default: System.out.println("未知参数 " + args[i]); return 2;
            }
        }
        String ts = new SimpleDateFormat("yyyyMMdd-HHmmss", Locale.US).format(new Date());
        File state = new File(dir, "state"), out = new File(dir, "out");
        state.mkdirs();
        out.mkdirs();
        PrintStream o = System.out;
        o.println("permguard " + VERSION + " " + mode + " @ " + ts + " uid=" + sh("id", "-u").trim());

        if (mode.equals("opnames")) {   // 实测 MIUI 自有 op 编号 ↔ 常量名（反射框架里的 AppOpsManager）
            for (java.lang.reflect.Field f : Class.forName("android.app.AppOpsManager").getDeclaredFields()) {
                if (f.getType() != int.class || !java.lang.reflect.Modifier.isStatic(f.getModifiers()) || !f.getName().startsWith("OP_")) continue;
                f.setAccessible(true);
                int v = f.getInt(null);
                if (v >= 10000) o.println(v + "\t" + f.getName());
            }
            return 0;
        }
        if (mode.equals("restore")) {
            if (snap == null) {   // 默认用最新快照
                File[] fs = state.listFiles((x, n) -> n.startsWith("snapshot-") && n.endsWith(".tsv"));
                if (fs == null || fs.length == 0) { o.println("没有快照"); return 1; }
                Arrays.sort(fs);
                snap = fs[fs.length - 1].getPath();
            }
            return restore(new File(snap), o);
        }

        Conf conf;
        if (confPath == null) confPath = new File(dir, "whitelist.conf").getPath();
        try (Reader r = confPath.equals("-") ? new InputStreamReader(System.in, StandardCharsets.UTF_8)
                : new InputStreamReader(new FileInputStream(confPath), StandardCharsets.UTF_8)) {
            conf = Conf.parse(r);
        }
        for (String w : conf.warnings) o.println("WARN " + w);
        if (!conf.warnings.isEmpty() && mode.equals("apply")) { o.println("配置有误，拒绝 apply（先 plan 看警告）"); return 1; }

        Device d = Device.collect(conf, withSystem);
        o.println("采集: 第三方 " + d.third.size() + " / 系统 " + d.sys.size() + " / 已读 " + d.pkgs.size() + " 个包；角色持有者 " + d.roles.keySet() + "；前台 " + d.foreground);

        switch (mode) {
            case "plan": {
                List<Item> items = decide(d, conf, false);
                writeItemsTsv(items, new File(out, "plan.tsv"));
                writePlanMd(items, d, conf, new File(out, "plan.md"), "permguard plan（dry-run，未改任何东西）" + ts);
                printSummary(o, items);
                return 0;
            }
            case "apply": {
                File sf = new File(state, "snapshot-" + ts + ".tsv");
                writeSnapshot(d, sf, ts);
                o.println("快照: " + sf);
                List<Item> items = decide(d, conf, true);
                int ok = 0, fail = 0;
                for (Item it : items) {
                    if (it.act != Act.REVOKE) continue;
                    it.result = exec(it);
                    if (it.result.equals("OK")) ok++; else fail++;
                }
                // 回读核对（不信命令返回值）
                Set<String> touched = new HashSet<>();
                for (Item it : items) if (it.act == Act.REVOKE) touched.add(it.pkg);
                int verified = 0;
                for (String n : touched) {
                    Pkg p = readPkg(n);
                    if (p == null) continue;
                    for (Item it : items) {
                        if (it.act != Act.REVOKE || !it.pkg.equals(n) || !it.result.equals("OK")) continue;
                        boolean good;
                        if (it.kind.equals("perm")) {
                            Perm r = p.rt.get(it.name);
                            good = r != null && (!r.granted || it.target.startsWith("revoked-compat"));
                        } else {
                            OpState s = readOp(n, it.name);
                            good = !allowedMode(it.kind.equals("uidop") ? s.uidMode : s.pkgMode);
                        }
                        if (good) verified++;
                        else { it.result = "FAIL 回读仍为放行"; ok--; fail++; }
                    }
                }
                File jf = new File(state, "journal-" + ts + ".tsv");
                writeItemsTsv(items, jf);
                writePlanMd(items, d, conf, new File(out, "apply-" + ts + ".md"), "permguard apply " + ts);
                writePlanMd(items, d, conf, new File(out, "last-apply.md"), "permguard apply " + ts);
                printSummary(o, items);
                o.println("执行: 成功 " + ok + "（回读确认 " + verified + "），失败 " + fail + "；日志 " + jf);
                if (fail > 0) return 1;
                return count(items).get(Act.DEFER) > 0 ? 3 : 0;
            }
            case "verify": {
                writeVerify(d, conf, new File(out, "verify.csv"), new File(out, "verify.md"));
                int n = writeUnfixable(d, conf, new File(out, "unfixable.md"));
                List<Item> items = decide(d, conf, false);
                writeItemsTsv(items, new File(out, "verify-items.tsv"));
                printSummary(o, items);
                o.println("verify: 写出 out/verify.md、verify.csv、unfixable.md（关不掉 " + n + " 个）");
                return 0;
            }
            default:
                o.println("未知模式 " + mode);
                return 2;
        }
    }

    static void printSummary(PrintStream o, List<Item> items) {
        Map<Act, Integer> n = count(items);
        o.println("SUMMARY revoke=" + n.get(Act.REVOKE) + " apps=" + pkgCount(items, Act.REVOKE) + " defer=" + n.get(Act.DEFER)
                + " keep=" + n.get(Act.KEEP) + " report=" + n.get(Act.REPORT) + " fixed=" + n.get(Act.FIXED));
        for (Item it : items)
            if (it.act == Act.REVOKE || it.act == Act.DEFER)
                o.println("  " + it.act + "\t" + it.pkg + "\t" + (it.kind.equals("perm") ? shortPerm(it.name) : it.kind + ":" + it.name) + "\t" + it.cur + (it.result.isEmpty() ? "" : "\t" + it.result));
    }
}
