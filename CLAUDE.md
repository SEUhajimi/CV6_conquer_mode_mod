# CLAUDE.md

文明六（Civ VI）游戏模式 mod「文明征服模式」：占领其他文明的原始首都后，可激活对方的文明特性、领袖能力和特色单位 / 建筑 / 区域 / 改良。玩法、实现原理和已知限制见 `README.md`（中英双语）。

## 仓库结构

- `CivConquestMode/`：本模式**唯一进游戏的文件夹**，复制到 `文档\My Games\Sid Meier's Civilization VI\Mods\` 使用。
  - `CivConquestMode.modinfo`：加载入口。所有 InGame 动作都带 `criteria="CivConquest_Mode"`，只在勾选该模式时加载。新增文件时要同时登记到对应 Action 和 `<Files>`。
  - `Data/CivConquest_Gameplay.sql`：`LoadOrder` 为 20000，在其他文明 mod 之后执行，用来收集所有特色项目，包括 mod 文明的。
    - 解锁修改器挂在原特性的 `TraitModifiers` 上，原文明也会拿到。特色单位的 `VALID_UNIT_BUILD` 对原文明生效时，会让被取代的基础单位重新可造（拜占庭能造骑士、跑马场送骑士），所以加了“玩家本身没有该特性”的条件（`CQ_REQSET_NOT_NATIVE_*`）。新增类似的解锁修改器时要考虑对原文明的副作用。
  - `Scripts/`、`UI/`：Lua。UI 通过 `UI.RequestPlayerOperation(... EXECUTE_SCRIPT ...)` 发请求，由 Gameplay 脚本校验执行，以保证联机同步。不要在 UI 侧直接改游戏状态。
    - Gameplay 脚本里也只能在 `GameEvents.*` 回调中改游戏状态。`Events.*`（如 `PlayerTurnActivated`）由各客户端各自派发，时机不一致，在里面改状态会导致联机不同步（OOS）。
    - 脚本加载时（`Initialize()` 里）也不能改状态：联机重新同步时只有被同步的那台电脑会重新加载脚本。读档后的补扫放在 `GameEvents.PlayerTurnStarted` 里做。
    - 会改状态的循环不要依赖 `pairs` 的遍历顺序，先排序。
    - 处理 UI 请求的 GameEvents 回调要先校验参数类型：参数来自网络。
    - 不要在 `GameEvents.CityConquered` 里做重活（挂修改器、`WorldBuilder` 改区域），记个标记，留到 `PlayerTurnStarted` 处理（AI 自动激活就是这样做的）。
    - 联机一致性检查：UI 对数据库算指纹（`CQ.GetFingerprint()`，表清单在 `CivConquest_Common.lua`），经 `EXECUTE_SCRIPT` 上报到玩家属性，各电脑的 UI 互相比对，不一致时弹窗。**改了 Lua 后把 `CQ.VERSION` 加 1**：只改 Lua 时数据库不变，靠它发现两边脚本版本不同。
  - `ArtDefs/Landmarks.artdef`：**生成文件，不要手改**，见下文。
- `tools/gen_landmarks.py`：开发脚本，不进游戏。
- `docs/modding-guide.md`：文明六 mod 机制新手教程（数据库、修改器、Lua 两个环境、联机同步、modinfo、ArtDef、调试），不进游戏。
- `Zhanguo_V3/`、`Communist_PeoplesWar/`：联机附带的独立 mod，从用户 `Mods\` 目录原样复制而来，和本模式无代码依赖。`Communist_PeoplesWar` 的开发源在 `E:\GitHub-Repos\leader1`，更新后要重新复制过来。联机时所有玩家的 mod 文件必须完全一致，否则会不同步。

## 红色感叹号（模型缺失）问题

现象：其他文明通过本模式建造某个特色改良 / 区域 / 建筑时，地图上显示红色感叹号，而不是模型。

原因：游戏 `Landmarks.artdef` 里，有些变体的 `Tag_Culture` 只登记了原文明（`Civilization:CIVILIZATION_XXX`），没有 `Culture:DEFAULT` 兜底。这类变体出现在两种根集合里：
- `Landmarks` → `Eras`：特色改良，如 `LM_PYRAMID`。
- `Districts` → `BuildingVariants`（按 `Tag_HeroBuilding` 区分）/ `BaseVariants`：区域内的特色建筑和特色区域，如工业区里的电子厂、Mbanza、Thanh。

修复：`tools/gen_landmarks.py` 扫描本体和非剧本 DLC 的 `Landmarks.artdef`，对“全部变体都只针对特定文明”的组复制一份 `Culture:DEFAULT` 版本（模型相同），输出到 `CivConquestMode/ArtDefs/Landmarks.artdef`，再通过 `CivConquest.dep` 加载。

```
python tools/gen_landmarks.py "D:\Steam\steamapps\common\Sid Meier's Civilization VI"
```

- 游戏安装目录：`D:\Steam\steamapps\common\Sid Meier's Civilization VI`（脚本默认值）。官方 artdef 在 `Base/ArtDefs/` 和 `DLC/*/ArtDefs/`，官方 dep 文件可以参考 `DLC/Expansion2/Expansion2.dep`。
- 再遇到红感叹号时，先在游戏 artdef 里 grep 对应的 `BUILDING_` / `DISTRICT_` / `LM_` 名称，确认它在哪个集合、哪个文化标签下，再改脚本、重新生成。不要手写 artdef。
- 游戏更新或新增 DLC 后要重新生成。

## 调试

日志在 `%LOCALAPPDATA%\Firaxis Games\Sid Meier's Civilization VI\Logs\`：
- `Lua.log`：搜索 `[CivConquest]` 或 `Runtime Error`。
  - `CQ.DEBUG_LOG`（`Scripts/CivConquest_Common.lua`）开启时，`UI/CivConquestDebug.lua` 会在单位训练/购买时写 `[CivConquest] Debug: turn N player P trained|purchased(<purchaseType>) UNIT_X in City | culture +Δ | CIVIC_Y 进度`。Δ 是与上一次快照（回合开始或上一条记录）的市政进度差；换了市政时显示 `?`。回合开始的快照不含当回合文化产出，所以每回合第一条会附带 `(net ... after turn yield ...)`，看 net 即可。
  - 这段放在 UI 环境：`PlayerCulture:GetProgressingCivic()` / `GetCulturalProgress()` 在 Gameplay 脚本里不可用，实测会失败。
  - 每个玩家回合开始时，Gameplay 脚本会写 `[CivConquest] Sync turn N player P unlocks=... traits=...`（只写有解锁、激活或上报过指纹的玩家），末尾的 `fp=` 是该玩家电脑上报的数据库指纹。联机不同步时，对比两台电脑同一回合的这一行，不一样就是本模式的状态分叉了。
  - `[CivConquest] Local fingerprint X` 是本机指纹；`[CivConquest] Mod mismatch!` 表示有玩家的指纹和本机不同，即两边加载的 mod 内容不一样。
- 修改 `.modinfo` 后需要重启游戏（或在「附加内容」里重新启用 mod）才会生效；只改 Lua / SQL 时重新读档即可。
- `Database.log`、`Modding.log`：数据和 mod 加载问题。

没有自动化测试，改动最终需要用户进游戏验证。

## 约定

- 代码注释、脚本说明用中文。`README.md` 中英双语，改一边要同步改另一边。
- 提交信息用英文，**不要添加 Claude 的 `Co-Authored-By` 署名**。
- 只在用户要求时提交。
