# 文明征服模式 · Civilization Conquest Mode

[中文](#中文) | [English](#english)

---

## 中文

文明六游戏模式 mod。开局时在「游戏模式」里勾选，和结社模式、天启模式在同一处。占领其他文明的原始首都后，可以把对方的文明特性、领袖能力和特色单位 / 建筑 / 区域 / 改良设施据为己有。

### 玩法

- 左上角工具栏（科技树、市政树……）末尾多出一个「文明征服」按钮。
- 左侧列出领袖，可在 **本局领袖 / 所有领袖** 之间切换；本局中未遇见的文明会隐藏身份。
- 右侧显示选中领袖的 **文明特性、领袖能力、特色单位 / 建筑 / 区域 / 改良设施**。
- **占领**某个主要文明的**原始首都**后，可以逐项「激活」或「全部激活」。占领即永久解锁，之后丢失该城市也不影响。
- 有已解锁但还没激活的内容时，工具栏按钮上会出现提示标记。
- 高级选项「文明征服：AI 自动激活」（默认开启）：AI 占领原始首都后会自动激活全部内容。

### 安装

1. 把 `CivConquestMode` 文件夹复制到 `文档\My Games\Sid Meier's Civilization VI\Mods\`。
2. 在游戏主菜单的「附加内容」中启用「文明征服模式」。
3. 创建游戏时，在「游戏模式」里勾选「文明征服模式」。

支持标准规则、迭起兴衰、风云变幻三种规则集。

### 实现方式

| 内容 | 机制 |
| --- | --- |
| 文明特性 / 领袖能力 | Gameplay 脚本把该 Trait 的所有 `TraitModifiers` 通过 `Player:AttachModifierByID` 挂到玩家身上 |
| 特色单位 | `MODIFIER_PLAYER_ADJUST_VALID_UNIT_BUILD`（结社模式「邪教徒」使用的同一机制） |
| 特色改良 | `MODIFIER_PLAYER_ADJUST_VALID_IMPROVEMENT`（城邦宗主独特改良使用的同一机制） |
| 特色建筑 | 去掉 `TraitType`，改为 `BuildingConditions.UnlocksFromEffect` + `MODIFIER_PLAYER_ADJUST_VALID_BUILDING`（结社模式建筑的做法）；原文明通过自身 Trait 照常获得 |
| 特色区域 | 引擎没有对应的解锁效果：先建造被取代的基础区域，建成后在回合开始时由脚本（`WorldBuilder.CityManager`）转换为特色区域，并保留其中的建筑 |

部分特色改良的模型只登记了原文明（如努比亚金字塔、波斯天堂花园、荷兰圩田、苏格兰高尔夫球场、克里 Mekewap），其他文明建造时会显示红色感叹号。`tools/gen_landmarks.py` 扫描本体与 DLC 的 `Landmarks.artdef`，为这些地标生成 `Culture = DEFAULT` 的同模型版本。

UI 通过 `UI.RequestPlayerOperation(..., PlayerOperations.EXECUTE_SCRIPT, ...)` 发送激活请求，由 Gameplay 脚本校验并执行，因此联机同步安全。状态保存在玩家属性中（`CQ_UNLOCK_<Leader>`、`CQ_TRAIT_<Trait>`），随存档保存。

数据 SQL 的 `LoadOrder` 设为 20000，会在其他文明 mod 之后执行，所以自定义文明的特色内容一般也能被识别。

### 已知限制

- 少数能力是在游戏核心（DLL）里按 Trait 硬编码判定的，而不是通过修改器实现，这类能力激活后可能不生效或只部分生效。
- 特色区域无法直接在生产列表中选择（引擎没有按玩家解锁区域的效果），需要建造被取代的基础区域，建成后在回合开始时转换。
- 转换前会检查特色区域自身的地形 / 地貌要求（如书院、卫城只能在丘陵，蒙巴扎需要树林 / 雨林）；不满足则保留基础区域，且该地块不再尝试转换。
- 原本不可训练的特色单位（如大哥伦比亚的总指挥）不会解锁生产，只能通过激活对应能力按原机制获得。
- 修改器里如果带有「玩家拥有某 Trait」的需求条件，通过激活获得时该条件不满足。

### 排查问题

日志位于 `%LOCALAPPDATA%\Firaxis Games\Sid Meier's Civilization VI\Logs\`：
- `Lua.log`：搜索 `[CivConquest]` 或 `Runtime Error`
- `Database.log`、`Modding.log`：数据加载与 mod 加载问题

---

## English

A game mode mod for Civilization VI. Enable it under **Game Modes** when setting up a game, next to Secret Societies, Apocalypse and the rest. Capture another civilization's original capital and you can take over its civilization ability, leader ability and unique units, buildings, districts and improvements.

### How to play

- A **Civilization Conquest** button is added to the end of the top-left Launch Bar (Tech Tree, Civics Tree, …).
- The left side lists leaders, switchable between **Leaders in This Game** and **All Leaders**. Civilizations you haven't met in this game stay hidden.
- The right side shows the selected leader's **civilization ability, leader ability and unique units / buildings / districts / improvements**.
- Once you **capture** a major civilization's **original capital**, you can activate its items one by one or with **Activate All**. The unlock is permanent, even if you lose the city later.
- The Launch Bar button shows a marker when something is unlocked but not yet activated.
- Advanced option **Conquest: AI Auto-Activates** (on by default): when an AI captures an original capital, it activates everything from that civilization automatically.

### Installation

1. Copy the `CivConquestMode` folder to `Documents\My Games\Sid Meier's Civilization VI\Mods\`.
2. Enable **Civilization Conquest Mode** under **Additional Content** in the main menu.
3. When creating a game, tick **Civilization Conquest Mode** under **Game Modes**.

Works with the Standard, Rise and Fall, and Gathering Storm rulesets.

### How it works

| Item | Mechanism |
| --- | --- |
| Civilization / leader abilities | A gameplay script attaches every `TraitModifiers` entry of the trait to the player via `Player:AttachModifierByID` |
| Unique units | `MODIFIER_PLAYER_ADJUST_VALID_UNIT_BUILD` (the same mechanism Secret Societies uses for the Cultist) |
| Unique improvements | `MODIFIER_PLAYER_ADJUST_VALID_IMPROVEMENT` (the same mechanism city-state suzerain improvements use) |
| Unique buildings | `TraitType` is cleared and replaced by `BuildingConditions.UnlocksFromEffect` + `MODIFIER_PLAYER_ADJUST_VALID_BUILDING` (as Secret Societies buildings do); the original civilization still gets them through its own trait |
| Unique districts | The engine has no effect that unlocks districts per player. Build the district it replaces; once completed, a script (`WorldBuilder.CityManager`) converts it into the unique district at the start of your turn, keeping its buildings |

Some unique improvements register their model only for the original civilization (Nubian Pyramid, Persian Pairidaeza, Dutch Polder, Scottish Golf Course, Cree Mekewap), so other civilizations building them see a red exclamation mark. `tools/gen_landmarks.py` scans the base game and DLC `Landmarks.artdef` files and generates a `Culture = DEFAULT` copy of those landmarks using the same model.

The UI sends activation requests through `UI.RequestPlayerOperation(..., PlayerOperations.EXECUTE_SCRIPT, ...)`, and the gameplay script validates and applies them, so multiplayer stays in sync. State is stored as player properties (`CQ_UNLOCK_<Leader>`, `CQ_TRAIT_<Trait>`) and is saved with the game.

The gameplay SQL runs with `LoadOrder` 20000, after other civilization mods, so unique items of custom civilizations are usually picked up as well.

### Known limitations

- A few abilities are hard-coded against the trait in the game core (DLL) instead of being implemented through modifiers; they may not work, or only partly work, when activated.
- Unique districts can't be picked directly from the production list (the engine has no per-player district unlock effect). Build the district they replace; it is converted at the start of your turn.
- Before converting, the unique district's own terrain / feature rules are checked (e.g. Seowon and Acropolis need hills, Mbanza needs woods / rainforest). If the plot doesn't qualify, the base district is kept and that plot is not tried again.
- Unique units that can't normally be trained (e.g. Gran Colombia's Comandante General) are not opened for production; you get them through the original mechanism by activating the matching ability.
- Modifiers that require "player has trait X" won't have that requirement met when the ability is gained through activation.

### Troubleshooting

Logs are in `%LOCALAPPDATA%\Firaxis Games\Sid Meier's Civilization VI\Logs\`:
- `Lua.log`: search for `[CivConquest]` or `Runtime Error`
- `Database.log`, `Modding.log`: data and mod loading issues

---

## 文件 · Files

```
tools/gen_landmarks.py               生成 ArtDefs/Landmarks.artdef · generates ArtDefs/Landmarks.artdef
CivConquestMode/
├─ CivConquestMode.modinfo           模式定义、加载条件 · mode definition, load criteria
├─ CivConquest.dep                   美术依赖 · art dependency file
├─ ArtDefs/Landmarks.artdef          特色地标的通用文化模型 · DEFAULT-culture models for civ-only landmarks
├─ Data/CivConquest_Config.xml       开局设置 · game setup: mode toggle, AI option
├─ Data/CivConquest_Icons.xml        模式图标 · mode icon (reuses Domination victory icon)
├─ Data/CivConquest_Gameplay.sql     特性映射与解锁修改器 · trait/item mapping, unlock modifiers
├─ Scripts/CivConquest_Common.lua    共用逻辑 · logic shared by UI and gameplay
├─ Scripts/CivConquest_Gameplay.lua  解锁、激活、区域转换 · unlocks, activation, district conversion
├─ UI/CivConquestPanel.xml / .lua    工具栏按钮与领袖面板 · Launch Bar button and leader panel
└─ Text/CivConquest_Text.xml         英文 / 简体中文 · English / Simplified Chinese text
```

## 许可 · License

[MIT](LICENSE)
