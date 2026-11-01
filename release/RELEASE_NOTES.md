## ClashOhos 0.1.0

HarmonyOS NEXT 侧载首版。内置代理核心为 mihomo **2.11.36**（与 Clash Meta for Android 2.11.36 同源构建）。

### 安装

1. 下载 **`clash-ohos-0.1.0-signed.hap`**
2. 真机安装（`hdc install` 或文件管理器）
3. 应用内 **设置 → 订阅** 导入并激活配置，首页连接 VPN

### 签名

本 HAP 使用 **DevEco 自动调试签名**，仅供个人测试，**非**华为商店正式包。

### 源码

- 本页 **Source code (zip / tar.gz)** 为 GPL 对应源码
- 构建说明：仓库 [`harmony/README.md`](../README.md)
- 许可：GPL-3.0，见根目录 `LICENSE`

### 架构

- UI 进程：ArkUI + REST（不加载 Go）
- VPN 扩展：`ClashVpnExtensionAbility` + `libclash_core.so`

### 已知限制

- 修改订阅后需 **断开并重连 VPN** 才能加载新 YAML
- YAML 若配置 REST `secret`，当前 UI 未带 Authorization，可能影响部分 REST 功能
- 华为应用市场上架需 VPN 受限能力与正式签名，见 `harmony/G13-RELEASE.md`
