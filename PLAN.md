# Clash Meta HarmonyOS NEXT 移植计划（v2）

**状态：现行。v1（G0–G13 / NAPI 对齐全部 JNI `//export`）作废。**

更新：2026-10-31

---

## 1. 废止声明

下列内容不再作为进度依据，也不得再按它们实现：

- 把 CMFA 的 JNI 表面（`load(completable)`、`complete_func`、`queryGroup`、`healthCheck` 等）逐个做成 NAPI。
- 在 **UI Ability 进程**里 `dlopen` libclash / 调用 `ClashCore.init|load`。
- 以 x86_64 模拟器上的「激活成功」代替 ARM 真机 VPN。
- `VERIFICATION.md` 里把 G2–G12 标成「代码已落入即完成」。
- 在绑定层未通之前做 Providers、Override、按应用接管、上架材料当主路径。

v1 留下的 `harmony/` 工程可作参考（页面、文件存储、VpnExtension 骨架），**内核调用约定全部作废**，按本文件重建。

---

## 2. 为什么推翻

| v1 假设 | HarmonyOS NEXT 事实 |
|---------|---------------------|
| UI 与 VPN 同进程，激活即 load 进当前核心 | `EntryAbility` 与 `VpnExtensionAbility` 是不同进程 |
| JNI 回调是内核 ABI | NAPI 不能从 Go 线程碰 `napi_env`；扩展进程还要单独加载 so |
| `libclash.so` 可直接进包 | 安装器拒绝 Go c-shared（9568347），只能 c-archive 打进 NAPI so |
| 功能对齐 = 包完所有 `//export` | mihomo 已有 HTTP 控制面，不应再做第二套 JNI |
| `GOOS=linux` + OHOS clang 等于官方 OHOS Go | 无官方 `GOOS=openharmony`，tun/DNS/uid 会持续打补丁 |

激活按钮反复修不好，是这个模型的症状，不是单点 bug。

---

## 3. 目标与非目标

**目标（MVP）**

- 用户在 UI 里导入/订阅 YAML、选中一份配置。
- 点连接后，**仅 VpnExtension 进程**加载核心、拿 `tunFd`、跑代理。
- UI 用 HTTP 问流量、节点、模式；切节点走 REST，不走 JNI。
- 验收以 **ARM 真机**为准。

**非目标（本阶段不做）**

- 与 CMFA 功能 1:1。
- UI 进程内预热/预加载核心。
- 为每个 Go `//export` 保留 NAPI。
- 模拟器上验证 TUN（可编包，不算过门）。
- 应用市场上架与 VPN 能力审批（放到最后单独阶段）。

---

## 4. 架构

```
┌─────────────────────────────┐
│  UI Ability（零 Go）         │
│  配置文件 / 订阅 HTTP        │
│  选中 uuid / 启停 VPN        │
│  http://127.0.0.1:<port>     │
└─────────────┬───────────────┘
              │ 只传配置目录 + 开关
              ▼
┌─────────────────────────────┐
│  VpnExtensionAbility         │
│  唯一 dlopen libclash_ohos   │
│  clashLoad(dir) 同步 C       │
│  startTun(fd) / stopTun      │
│  external-controller 本机    │
└─────────────────────────────┘
```

**Go 只保留同步 C ABI（扩展进程）：**

- `coreInit(home, version, git, sdk)`
- `clashLoad(dir) -> char*`（空串成功）
- `startTun(...) -> int`
- `stopTun()`
- 以及为 REST 服务所需的、在 `clashLoad` 里随配置启动的 mihomo hub（external-controller）

**禁止：** `load(completable*)`、`complete_func`、UI 侧 `queryGroup` / `queryNow` 等 NAPI。

**打包：** 仍用 c-archive + `--whole-archive` 链进扩展所用的 `.so`。HAP 可含 arm64；x86_64 仅为可选模拟器编包，不是门禁。

---

## 5. 阶段与门禁

每门必须留下 **hilog 原文或 hdc 截图/命令输出**，否则不得进入下一门。不得把「代码写了」当成通过。

### N0 废止与目录约定

- [ ] 本文件为唯一计划；v1 门禁表作废。
- [ ] 约定配置根目录：`filesDir/profiles/<uuid>/config.yaml`；激活只写 `activeUuid`。
- [ ] 约定控制器：仅监听 `127.0.0.1`，secret 随机生成并写入扩展可读文件，UI 只在 VPN 已连接后读取。

**验证：** 文档存在；仓库内不再把 G4–G12 当 TODO 完成态。

### N1 UI 进程零 Go

- [ ] `EntryAbility`、所有 `pages/*.ets` **删除** `ClashCore` / `libclash_ohos.so` 引用。
- [ ] 「激活」只 `setActiveUuid` + UI「使用中」。
- [ ] 「连接」只 `startVpnExtensionAbility`，参数为配置**目录**。
- [ ] 首页探测改为「UI 未加载 native」或简单展示选中配置名，禁止 `clashOhos.ping` 当核心证据。

**验证：** 反编译/搜索 UI 源码无 `libclash`；点激活不出现 native 异常；hilog 无 UI 进程 `ClashAdapter`。

### N2 扩展进程：so 可加载 + clashLoad

- [ ] 仅 `ClashVpnExtensionAbility` 链接/导入 native。
- [ ] 同步 `clashLoad(dir)`，`napi_async_work` 可选（扩展内也可同步，只要不在 UI 线程卡死系统）。
- [ ] 用 **≤30 行本地 YAML**（direct 模式即可），不要大订阅。

**验证（ARM 真机优先；无真机则记「阻塞」不得标过）：**  
hilog 含 `clashLoad done err=ok` 或可读错误；错误不得是 `complete_func` / `load of undefined`。

### N3 tunFd + startTun + 防环路

- [ ] `protectProcessNet` 成功或明确记录不可用原因。
- [ ] `createVpnConnection` 拿到 fd，交给 `startTun`。
- [ ] 停止后 fd/VPN 图标消失，无残留。

**验证：** 真机授权 VPN；hilog `tunFd>=0`；断开后系统 VPN 列表为空。模拟器成功不算过门。

### N4 控制面 REST

- [ ] 配置里打开 `external-controller: 127.0.0.1:<port>`。
- [ ] UI 在连接后对 `/version` 或 `/configs` GET 成功。
- [ ] 流量展示改走 `/traffic` 或等价接口；去掉 UI 的 `queryTrafficNow` NAPI。

**验证：** 真机上 UI 显示非零或至少通的 JSON；hdc 抓一条 HTTP 200。

### N5 选节点（REST）

- [ ] UI 代理页：`GET /proxies`，切换 `PUT /proxies/:name`。
- [ ] 不再调用 `patchSelector` NAPI。

**验证：** 真机切换节点后 REST 返回的 `now` 变化。

### N6 订阅（纯 UI）

- [ ] HTTPS 拉订阅、写入 `profiles/<uuid>/config.yaml`。
- [ ] 不在 UI 里 `fetchAndValid` JNI。
- [ ] 更新后需重新「连接」让扩展进程 `clashLoad`。

**验证：** 导入后文件存在；再走 N3–N5。

### N7 最小回归（真机）

必须连续成功：

1. 冷启动 → 选中配置 → 连接 → 有 tun → REST `/version` 通  
2. 切一个 selector → 再切回来  
3. 断开 → VPN 消失 → 再连接恢复  
4. 杀 UI 进程，扩展按系统策略存活或干净退出（记录实际行为，不编造）

**验证：** 上述四条 hilog + 现象记录。未做完不得扩 Providers/Override。

### N8 扩展功能（可选，走 REST）

仅当 N7 通过后：Providers 更新、健康检查、日志、Override。全部 HTTP，不加 NAPI。

### N9 上架

VPN 能力申请、签名、隐私协议。与内核移植解耦，N7 通过后再做。

---

## 6. 真机与模拟器

| 环境 | 用途 |
|------|------|
| ARM 真机 | N2–N7 唯一验收 |
| x86_64 模拟器 | 可选编包、UI 流程；**不能**过 N3 |
| USB `Offline` | 记阻塞，不记通过 |

---

## 7. 对现有代码的处置

| 路径 | 处置 |
|------|------|
| `pages/*` + `ProfileStore` | 保留 UI，去掉 ClashCore |
| `ClashVpnExtensionAbility` | 重写为唯一 native 宿主 |
| `ClashCore.ets` / 大量 NAPI export | 缩成 init/clashLoad/startTun/stopTun，且仅扩展使用 |
| `complete_func` 异步 `load` | 删除 OHOS 调用路径 |
| Providers/Logs/Override 页 | N7 前可隐藏或显示「需先连接」 |
| `G13-RELEASE.md` | 推迟到 N9 |

---

## 8. 执行顺序

先 N1（UI 去 Go），再 N2（扩展 clashLoad），再 N3（真机 TUN），再 N4–N5（REST），最后 N6–N7。  
**没有真机时停在 N2 的「阻塞」状态，不把后面阶段标完成。**
