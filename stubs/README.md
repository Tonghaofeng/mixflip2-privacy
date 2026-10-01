# stubs/ —— 自写空壳 / 覆盖包工具

思路（用户 10-01 提出）：依赖方只认「某个包在不在 / 有没有应答」时，自己写一个无害空壳顶替有风险的原包。

- `build.sh <目录>`：aapt2 compile+link → zipalign → apksigner(v2+v3)，产物 `out/<目录>.apk`。
  需 `brew install --cask android-commandlinetools` + `sdkmanager "build-tools;36.0.0" "platforms;android-36"`，JDK 用 `/opt/homebrew/opt/openjdk`。
  签名钥匙 `stub.keystore` 首次自动生成，**不入库、不同步**（.gitignore + sync_to_repo.sh 排除）。
- `securitymanager/`：隐藏「设置→隐私与安全→安全→手机管家」入口的空壳。**结论：装不上**——MIUI 对小米保留包名签名强校验（`SIGNATURE FAIL`，安装器 -22）。留作记录。
- `rro_probe/`：验证自签 RRO 能否覆盖安全中心资源的探针（未能装上实测，adb 安装被 USB 安装闸拦下）。

无 root 下的可行边界（详见 `../debloat/antivirus_antifraud.md`）：
- ✅ 非小米保留的第三方包名
- ❌ 系统镜像已占用的包名（同名须同签名，authority 冲突）
- ❌ `com.miui.*` 等小米保留包名（签名强校验）
- ❌ 改他人 App 资源（未声明 overlayable 的目标；shell 禁造 fabricated overlay）
