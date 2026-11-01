# 门禁验证记录

**现行计划：`PLAN.md`（v2）。v1 的 G0–G13 作废，不得再当作已通过。**

更新时间：2026-10-31

## 作废记录（v1）

此前「代码已落入 harmony/」被写成 G2–G12 完成，与事实不符：未在 ARM 真机上验证 tunFd、也未验证 UI/扩展双进程下的核心加载。激活按钮上的多次修补属于错误架构上的症状修复。

## v2 门禁状态

| 门 | 状态 | 证据 |
|----|------|------|
| N0 废止与目录约定 | 文档已写 | `PLAN.md` |
| N1 UI 进程零 Go | 真机已过 | `62T0225C18006500` aarch64 安装成功；hilog `EntryAbility onCreate (no libclash in UI process)` |
| N2 扩展 clashLoad | 真机已过 | `62T0225C18006500` `dlopen ok libclash_core.so`；`clashLoad done err=ok` |
| N3 真机 tunFd | 数据面已过 | `tunFd=39`；`startTun rc=0` gw=`172.19.0.1/30`；随后 `mark_socket`。停止：此前有 `stopVpnExtensionAbility success` 且无 `:vpn` |
| N4 REST 控制面 | 真机已过 | UI 进程 GET `127.0.0.1:9090` `RespCode:200`（NETSTACK，约每秒一次 `/version`） |
| N5 选节点 REST | 真机已过 | `REST GET /proxies groups=1`；`PUT /proxies/GLOBAL -> 204`；`now=` 与 `want=` 同为所选节点 |
| N6 订阅（纯 UI） | 真机已过 | UI `Profiles.importUrl` 只 HTTP 写 `profiles/<uuid>/config.yaml`，无 `fetchAndValid`；真机 `clashLoad` 路径即该目录且 `err=ok`（含 base64 订阅解码） |
| N7 最小回归 | 真机已过 | 启停：`clashLoad done`+`startTun rc=0`+`onDestroy`；换节点：GLOBAL PUT 204，now 为 05/07/08；划掉 UI 后 `:vpn` 一并退出 |
| N8 REST 扩展功能 | REST 已过；测速待 protect 复测 | 已接 `VpnConnection.protect(fd)`；DNS 默认 `172.19.0.2`；首页读 `/connections` 流量；日志可清空。测速 503 待用户重连后再点 |
| N9 上架 | 材料已落，联盟未提交 | 权限 reason/usedScene；`pages/About`；`PRIVACY.md` / `G13-RELEASE.md`。现用 debugKey，VPN 能力与商店审核需开发者联盟账号，不能标已上架 |

环境备忘：Go 1.23.6；真机 `62T0225C18006500` USB Connected、`arm64-v8a`。N2/N3 需用户在手机上授权 VPN 后抓扩展进程 hilog。
