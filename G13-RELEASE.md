# N9 / G13 上架与签名清单

> 侧载调试不受本清单阻塞。市场通过以前不得把 N9 标成「已上架」。

## 当前工程

| 项 | 值 |
|----|----|
| 包名 | `com.clashohos.app` |
| 版本 | `0.1.0` / versionCode `100`（核心 mihomo 2.11.36） |
| VPN 扩展 | `ClashVpnExtensionAbility`，`type: vpn` |
| 权限 | INTERNET、GET_NETWORK_INFO（已写 reason / usedScene） |
| 现用签名 | `build-profile.json5` 的 `debugKey` 调试材料 |
| 隐私 | `PRIVACY.md`；应用内 `pages/About` |

## 开发者必须在联盟完成的步骤（本仓库无法代做）

1. 华为开发者联盟创建正式签名（.p12 / .cer / **release** .p7b），替换 `signingConfigs`，不要继续用 debugKey。
2. 申请受限能力 **VPN**（VpnExtensionAbility / type=vpn）。未批准：商店会拒，只能侧载。
3. 应用市场提交：应用介绍、截图、隐私政策 URL 或应用内隐私页、权限说明、GPL 源码获取方式。

## 应用介绍（可直接贴）

ClashOhos 是 HarmonyOS NEXT 上的本地代理客户端。在系统 VPN 扩展进程中加载 mihomo 核心，UI 进程不加载 Go。你自行导入订阅或 YAML，选择节点后由系统 VPN 转发流量。开发者不提供节点、不上传订阅。

## 权限说明（可直接贴）

- 网络：拉取订阅与代理访问。
- 网络信息：展示连接状态。
- VPN：仅在你点击启停并同意系统授权后创建隧道。

## 验收

| 结果 | 含义 |
|------|------|
| 调试 / 正式签名 HAP 能装到真机 | 打包与签名链路可用 |
| 联盟 VPN 能力 + 市场审核通过 | 才算 N9 上架完成 |
