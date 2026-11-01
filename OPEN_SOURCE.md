# 开源合规说明（ClashOhos）

本文档供维护者与下载 HAP 的用户参考，**不构成法律意见**。如有疑问请咨询专业律师。

## 1. 是否满足开源要求？

| 要求 | 本项目做法 |
|------|------------|
| GPL-3.0 源码可获得 | 公开 Git 仓库包含 ArkTS/C++ 与构建脚本；Go 核心通过 `core/` + `harmony/scripts/build-libclash-ohos.ps1` 可复现 `libclash.a` |
| 保留版权与许可证 | 根目录 [`LICENSE`](../LICENSE)、[`NOTICE`](../NOTICE)、[`harmony/NOTICE.md`](./NOTICE.md) |
| 修改说明 | README / 本文件标明 HarmonyOS 移植与上游关系 |
| 分发二进制时提供源码 | GitHub Release 的 **Source code (zip/tar.gz)** + 仓库 URL；HAP 附件旁注明源码地址 |

**注意**：`harmony/build-profile.json5`（签名密码）与 `prebuilt/*.a` 默认不进 Git；用户需按 README 自行签名与编译核心，这 **不** 免除你发布 HAP 时提供对应源码的义务——对应源码即 tagged 提交 + 文档中的构建步骤。

## 2. 是否侵权？

**通常可开源的部分（在遵守 GPL 前提下）：**

- 基于 GPL 发布的 **Clash Meta for Android** 与 **mihomo** 进行二次开发并 **同样以 GPL 发布**，符合 copyleft 一般要求。
- HarmonyOS **应用源码**（不含 SDK 本身）可由你上传。

**需要留意的风险点（非 exhaustive）：**

| 话题 | 说明 |
|------|------|
| **商标** | 不要在商店描述中暗示「MetaCubeX 官方」。应用名为 **ClashOhos**，包名 **`com.clashohos.app`**，与上游 CMFA 包名无关。 |
| **mihomo 命名** | 上游 README 要求非 MetaCubeX  affiliated 下游项目名 **不要包含 “mihomo”**；本应用名未使用 mihomo，符合。 |
| **华为 SDK** | 仅在你本机/DevEco 使用；**不要**把 SDK 打进 Git 或 Release。 |
| **VPN 能力** | 开源不违法；在华为 **应用市场** 发布需单独申请 VPN 受限能力。 |
| **用户用途** | 客户端可用于合法代理；开发者不运营节点，但应在 README/隐私政策中说明用户自负合规。 |
| **上游版权** | 保留 CMFA / mihomo 版权声明；不要移除 LICENSE 文件。 |

**结论（工程角度）**：在 **GPL 全源码公开、保留 NOTICE、不捆绑华为 SDK、不冒充官方** 的前提下，上传到 GitHub 并附 HAP **一般符合常见开源分发做法**；商标表述与商店政策需你自行把握。

## 3. 建议上架 / 发布前检查清单

- [ ] `build-profile.json5` 未进入 Git（已 `.gitignore`）
- [ ] Release 页写明：debug 签名、侧载用途、源码链接
- [ ] [`PRIVACY.md`](./PRIVACY.md) 与 About 页一致
- [ ] Tag 与 `app.json5` 版本号一致
- [ ] 可选：在 About 页填写本仓库 GitHub URL
