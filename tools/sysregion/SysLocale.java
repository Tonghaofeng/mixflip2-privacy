import java.lang.reflect.Method;
import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;

/**
 * 以 shell 身份（app_process）改系统 locale / 地区 —— 与「设置 → 语言与地区 → 地区」同一条系统路径：
 * RegionDialogFragment.updateRegion() → LocalePicker.updateLocales()
 *   → IActivityManager.updatePersistentConfigurationWithAttribution()（需 CHANGE_CONFIGURATION + WRITE_SETTINGS，shell 均已授予）
 *   → system_server 写 persist.sys.locale 与 Settings.System.system_locales（重启后仍生效）。
 *
 * 全部走反射，编译不依赖 android.jar。
 *   get                 打印当前系统 locale 列表
 *   set-region <CC>     把与首选 locale 同语言同文字的条目地区换成 CC（如 zh-CN → zh-Hans-SG），保留扩展
 *   set <tags>          精确设置（逗号分隔），用于回滚，如 set zh-CN
 */
public class SysLocale {
    static Class<?> cfgCls, llCls, iamCls;
    static Object am;

    public static void main(String[] args) throws Exception {
        cfgCls = Class.forName("android.content.res.Configuration");
        llCls = Class.forName("android.os.LocaleList");
        iamCls = Class.forName("android.app.IActivityManager");
        am = Class.forName("android.app.ActivityManager").getMethod("getService").invoke(null);

        String cmd = args.length > 0 ? args[0] : "get";
        List<Locale> cur = currentLocales();
        System.out.println("current=" + tags(cur));
        if (cmd.equals("get")) return;

        List<Locale> next;
        if (cmd.equals("set-region") && args.length == 2) {
            next = replaceRegion(cur, args[1].toUpperCase(Locale.ROOT));
        } else if (cmd.equals("set") && args.length == 2) {
            next = new ArrayList<>();
            for (String t : args[1].split(",")) next.add(Locale.forLanguageTag(t.trim()));
        } else {
            System.err.println("usage: get | set-region <CC> | set <tag1,tag2,...>");
            System.exit(2);
            return;
        }
        if (tags(next).equals(tags(cur))) {
            System.out.println("unchanged");
            return;
        }
        apply(next);
        System.out.println("new=" + tags(currentLocales()));
    }

    static List<Locale> currentLocales() throws Exception {
        Object cfg = iamCls.getMethod("getConfiguration").invoke(am);
        Object ll = cfgCls.getMethod("getLocales").invoke(cfg);
        int n = (Integer) llCls.getMethod("size").invoke(ll);
        List<Locale> out = new ArrayList<>();
        for (int i = 0; i < n; i++) out.add((Locale) llCls.getMethod("get", int.class).invoke(ll, i));
        return out;
    }

    /** 设置 App 的规则：同语言且同文字（任一方无文字也算同）的条目换地区，其余不动。 */
    static List<Locale> replaceRegion(List<Locale> cur, String cc) throws Exception {
        Locale primary = maximize(cur.get(0));
        LinkedHashSet<Locale> out = new LinkedHashSet<>();
        for (Locale l : cur) {
            Locale m = maximize(l);
            boolean same = m.getLanguage().equals(primary.getLanguage())
                    && (m.getScript().isEmpty() || primary.getScript().isEmpty() || m.getScript().equals(primary.getScript()));
            if (!same) { out.add(l); continue; }
            Locale.Builder b = new Locale.Builder().setLanguage(m.getLanguage()).setScript(m.getScript()).setRegion(cc);
            for (Character k : l.getExtensionKeys()) b.setExtension(k, l.getExtension(k));
            out.add(b.build());
        }
        return new ArrayList<>(out);
    }

    /** ICU 补全文字：zh-CN → zh-Hans-CN（设置 App 的地区列表给出的就是 zh-Hans-XX）。 */
    static Locale maximize(Locale l) throws Exception {
        Class<?> u = Class.forName("android.icu.util.ULocale");
        Object ul = u.getMethod("forLocale", Locale.class).invoke(null, l);
        Object max = u.getMethod("addLikelySubtags", u).invoke(null, ul);
        return (Locale) u.getMethod("toLocale").invoke(max);
    }

    static void apply(List<Locale> locales) throws Exception {
        Object arr = java.lang.reflect.Array.newInstance(Locale.class, locales.size());
        for (int i = 0; i < locales.size(); i++) java.lang.reflect.Array.set(arr, i, locales.get(i));
        Object ll = llCls.getConstructor(Locale[].class).newInstance(arr);
        Object cfg = cfgCls.getConstructor().newInstance();
        cfgCls.getMethod("setLocales", llCls).invoke(cfg, ll);
        cfgCls.getField("userSetLocale").setBoolean(cfg, true);
        try {
            Method m = iamCls.getMethod("updatePersistentConfigurationWithAttribution", cfgCls, String.class, String.class);
            m.invoke(am, cfg, "com.android.shell", null);
        } catch (NoSuchMethodException e) {
            iamCls.getMethod("updatePersistentConfiguration", cfgCls).invoke(am, cfg);
        }
    }

    static String tags(List<Locale> ls) {
        StringBuilder sb = new StringBuilder();
        for (Locale l : ls) sb.append(sb.length() == 0 ? "" : ",").append(l.toLanguageTag());
        return sb.toString();
    }
}
