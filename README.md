# 文明征服模式 · Civilization Conquest Mode

[中文](#中文) | [English](#english)

---

## 中文

文明六游戏模式 mod。开局时在「游戏模式」里勾选，和结社模式、天启模式在同一处。占领其他文明的原始首都后，可以把对方的文明特性、领袖能力和特色单位 / 建筑 / 区域 / 改良设施据为己有。

### 玩法

- 左上角工具栏（科技树、市政树……）末尾多出一个「文明征服」按钮。
- 左侧列出领袖，可在 **本局领袖 / 所有领袖** 之间切换；本局中未遇见的文明会隐藏身份，在「所有领袖」里也看不出他们是否在本局。
- 右侧显示选中领袖的 **文明特性、领袖能力、特色单位 / 建筑 / 区域 / 改良设施**。特色区域条目先列出原版能力，再列出激活后实际获得的效果和未继承的部分，也可以用来查看对手的能力。
- **占领**某个主要文明的**原始首都**后，可以逐项「激活」或「全部激活」。占领即永久解锁，之后丢失该城市也不影响。**激活后无法撤销**，能力在本局中一直有效。
- 有已解锁但还没激活的内容时，工具栏按钮上会出现提示标记。
- 激活来的特色单位和特色改良会显示在科技树 / 市政树上对应的科技或市政里，方便看到需要研究什么才能建造（如澳大利亚的内陆牧场在「行会」）。特色区域仍显示基础区域，因为激活者建造的是基础区域。
- 高级选项「文明征服：AI 自动激活」（默认开启）：AI 占领原始首都后，会在它的下一个回合开始时自动激活全部内容。
- 高级选项「文明征服：负面效果」：有些能力带有负面效果（如越南的专业区域只能建在森林、雨林或沼泽上、马里的生产力 -30%），激活后同样无法撤销，可以选择：
  - **不激活负面效果**（默认）：征服者只拿到好处，负面效果不生效；原文明照常拥有。
  - **激活前确认**：能力照原样激活，激活带负面效果的能力前会弹窗列出这些效果，确认后才激活。「全部激活」时还可以选「只激活没有负面效果的」。

  面板上会在每个能力下列出它的负面效果，并注明激活后是否生效。

### 安装

1. 把 `CivConquestMode` 文件夹复制到 `文档\My Games\Sid Meier's Civilization VI\Mods\`。只需要这一个文件夹，仓库里的其他内容（`tools/`、`docs/`、`workshop/`、`README.md`、`LICENSE`）不用放进游戏。
2. 在游戏主菜单的「附加内容」中启用「文明征服模式」。
3. 创建游戏时，在「游戏模式」里勾选「文明征服模式」。

支持标准规则、迭起兴衰、风云变幻三种规则集。

### 联机常用的其他 mod

和本模式一起联机使用的独立 mod 放在各自的仓库里：[战国七雄地图](https://github.com/SEUhajimi/mapzg-cv6)、[汉帝国 · 刘备](https://github.com/SEUhajimi/cv6_liubei)。

联机时所有玩家的 mod 文件必须完全一致，否则从第一回合起就会不同步（OOS）并反复掉线。手动安装的 mod 不会像创意工坊那样自动更新，每次更新后都要重新分发给所有玩家。

联机房间只核对 mod 的 ID，不核对文件内容。本模式读档后会对整个游戏数据库（所有表、所有行）算一个指纹并互相比对；不一致时会弹窗提示，并在 `Lua.log` 里写 `[CivConquest] Mod mismatch!`。看到提示就说明各电脑加载的内容不同（任何 mod 都可能是原因，不只是本模式），先统一 mod 文件再继续。

### 开发

`tools/gen_landmarks.py` 是开发用脚本，游戏运行时不需要。它生成的 `CivConquestMode/ArtDefs/Landmarks.artdef` 已经包含在仓库里。只有在游戏更新或新增 DLC 后，才需要重新运行（需要 Python 3.9+）：

```
python tools/gen_landmarks.py "D:\Steam\steamapps\common\Sid Meier's Civilization VI"
```

参数是游戏安装目录，省略时使用脚本中的默认路径。

`python tools/build_workshop.py CivConquestMode` 按 `.modinfo` 登记的文件生成创意工坊上传文件夹 `dist/workshop/CivConquestMode/`；工坊预览图和介绍在 `workshop/CivConquestMode/`。`docs/modding-guide.md` 是文明六 mod 机制的入门教程。

### 实现方式

| 内容 | 机制 |
| --- | --- |
| 文明特性 / 领袖能力 | Gameplay 脚本把该 Trait 的所有 `TraitModifiers` 通过 `Player:AttachModifierByID` 挂到玩家身上。引擎只能挂、不能卸修改器，所以激活无法撤销 |
| 负面效果 | 登记在 `CQ_NegativeModifiers` 表（按修改器）。选「不激活负面效果」时，激活时跳过这些修改器；原文明的特性不受影响 |
| 特色单位 | `MODIFIER_PLAYER_ADJUST_VALID_UNIT_BUILD`（结社模式「邪教徒」使用的同一机制），只在征服者激活时由脚本挂上；不挂到原特性上，否则原文明会重新能造被取代的基础单位（如巴西尔的拜占庭能造骑士） |
| 特色改良 | `MODIFIER_PLAYER_ADJUST_VALID_IMPROVEMENT`（城邦宗主独特改良使用的同一机制） |
| 特色建筑 | 去掉 `TraitType`，改为 `BuildingConditions.UnlocksFromEffect` + `MODIFIER_PLAYER_ADJUST_VALID_BUILDING`（结社模式建筑的做法）；原文明通过自身 Trait 照常获得 |
| 特色区域 | 引擎只把原文明的特色区域当成基础区域（激活者的特色区域里造不了任何基础区域建筑），所以激活者不建造特色区域，而是把特色区域的效果以修改器的形式加到自己的基础区域上：区域自带修改器、相邻加成、自身产出、伟人点数、住房、宜居度、造价减半（建造该基础区域时生产力 +100%） |

**为什么不直接把基础区域转换成特色区域**：早期版本就是这么做的，但引擎只把原文明自己的特色区域当成基础区域（建筑的前置区域 `PrereqDistrict` 在引擎内部判定）。激活者转换得来的特色区域里造不了任何基础区域的建筑，例如转换来的越南 Thanh 里造不了兵营。试过的绕法都不行：去掉特色区域的 `TraitType`、用 `WorldBuilder` 直接放建筑（报 `NeededDistrict`）、副本建筑、标记建筑、`GRANT_BUILDING_IN_CITY_IGNORE`。所以改为建造基础区域，再把特色区域的效果以修改器的形式加上去。

部分特色改良、区域和建筑的模型只登记了原文明（如努比亚金字塔、波斯天堂花园、荷兰圩田、苏格兰高尔夫球场、克里 Mekewap、日本电子厂、蒙古 Ordu、马其顿 Basilikoi Paides、巴比伦 Palgum、刚果 Mbanza、越南 Thanh），其他文明建造时会显示红色感叹号。`tools/gen_landmarks.py` 扫描本体与 DLC 的 `Landmarks.artdef`（包括 `Landmarks` 与 `Districts` 两类集合），为这些变体生成 `Culture = DEFAULT` 的同模型版本。

UI 通过 `UI.RequestPlayerOperation(..., PlayerOperations.EXECUTE_SCRIPT, ...)` 发送激活请求，由 Gameplay 脚本校验并执行，因此联机同步安全。状态保存在玩家属性中（`CQ_UNLOCK_<Leader>`、`CQ_TRAIT_<Trait>`），随存档保存。

数据 SQL 的 `LoadOrder` 设为 20000，会在其他文明 mod 之后执行，所以自定义文明的特色内容一般也能被识别。

### 已知限制

- 少数能力是在游戏核心（DLL）里按 Trait 硬编码判定的，而不是通过修改器实现，这类能力激活后可能不生效或只部分生效。
- 激活无法撤销，包括负面效果（见上文「负面效果」选项）。
- 特色区域不会出现在生产列表中：建造被取代的基础区域即可，特色区域的效果会加到基础区域上。
- 同一个基础区域 / 基础建筑只能有一个特色版本：已拥有（原生或激活）书院时不能再激活天文台，已拥有 Prasat 时不能再激活木板教堂（都取代寺庙）。面板上会显示“已有 X”。
- 激活得来的特色区域没有自己的模型和放置限制，地图上仍是基础区域。相邻资源加成、专家和贸易路线产出、城防 / 区域控制、不占人口上限等效果无法迁移；基础区域原有的相邻加成会保留。
- 原本不可训练的特色单位（如大哥伦比亚的总指挥）不会解锁生产，只能通过激活对应能力按原机制获得。
- 修改器里如果带有「玩家拥有某 Trait」的需求条件，通过激活获得时该条件不满足。
- 有些原版效果不是修改器，而是引擎按「原生拥有该特性」判定的，激活后不会继承，好坏都一样：被取消的区域相邻加成（高卢、日本、巴西、立陶宛）、禁建区域和禁止获得的伟人（姆本巴不能建圣地、不能获得大先知，毛利不能获得大作家）、专属总督（苏莱曼的易卜拉欣）、外交能见度（凯瑟琳·德·美第奇）。面板上会在对应能力下列出。

### 排查问题

日志位于 `%LOCALAPPDATA%\Firaxis Games\Sid Meier's Civilization VI\Logs\`：
- `Lua.log`：搜索 `[CivConquest]` 或 `Runtime Error`
  - 调试日志（`CivConquest_Common.lua` 中的 `CQ.DEBUG_LOG`，默认开启）：单位训练或购买时会写一行 `[CivConquest] Debug: ...`，包含当回合文化进度的变化，可用来检查“训练单位获得文化”一类的能力
- `Database.log`、`Modding.log`：数据加载与 mod 加载问题

---

## English

A game mode mod for Civilization VI. Enable it under **Game Modes** when setting up a game, next to Secret Societies, Apocalypse and the rest. Capture another civilization's original capital and you can take over its civilization ability, leader ability and unique units, buildings, districts and improvements.

### How to play

- A **Civilization Conquest** button is added to the end of the top-left Launch Bar (Tech Tree, Civics Tree, …).
- The left side lists leaders, switchable between **Leaders in This Game** and **All Leaders**. Civilizations you haven't met in this game stay hidden, and the All Leaders list doesn't reveal whether they are in the game either.
- The right side shows the selected leader's **civilization ability, leader ability and unique units / buildings / districts / improvements**. Unique district entries list the original ability first, then what you actually get when activated and what is not inherited, so the panel also works as a quick look at your opponents' abilities.
- Once you **capture** a major civilization's **original capital**, you can activate its items one by one or with **Activate All**. The unlock is permanent, even if you lose the city later. **Activation cannot be undone**; the ability stays for the rest of the game.
- The Launch Bar button shows a marker when something is unlocked but not yet activated.
- Activated unique units and improvements appear in the tech and civic trees under the tech or civic that unlocks them, so you can see what to research before building them (for example, Australia's Outback Station under Guilds). Unique districts still show as the base district, since that is what the activating player builds.
- Advanced option **Conquest: AI Auto-Activates** (on by default): when an AI captures an original capital, it activates everything from that civilization automatically at the start of its next turn.
- Advanced option **Conquest: Negative Effects**: some abilities come with drawbacks (such as Vietnam's districts only on Woods, Rainforest or Marsh, or Mali's -30% Production), which can't be undone either once activated. Choose:
  - **Do Not Activate Drawbacks** (default): the conqueror gets only the benefits; the drawbacks never apply. The original civilization keeps them.
  - **Confirm Before Activating**: abilities activate as they are. Before activating one with drawbacks, a dialog lists them and asks you to confirm. **Activate All** also offers "Only Those Without Drawbacks".

  The panel lists each ability's drawbacks under it and says whether they will apply.

### Installation

1. Copy the `CivConquestMode` folder to `Documents\My Games\Sid Meier's Civilization VI\Mods\`. That folder is all the game needs; the rest of the repository (`tools/`, `docs/`, `workshop/`, `README.md`, `LICENSE`) stays out of the game.
2. Enable **Civilization Conquest Mode** under **Additional Content** in the main menu.
3. When creating a game, tick **Civilization Conquest Mode** under **Game Modes**.

Works with the Standard, Rise and Fall, and Gathering Storm rulesets.

### Other mods for multiplayer

Standalone mods often played together with this mode live in their own repositories: [Warring States China map](https://github.com/SEUhajimi/mapzg-cv6) and [Han Empire (Liu Bei)](https://github.com/SEUhajimi/cv6_liubei).

In multiplayer every player's mod files must match exactly; otherwise the game goes out of sync (OOS) from the first turn and keeps disconnecting. Manually installed mods don't update automatically like Workshop mods, so redistribute them to every player after each update.

The multiplayer lobby only checks mod IDs, not file contents. After loading, this mode computes a fingerprint of the entire game database (every table and row) on each computer and compares them; on a mismatch it shows a popup and writes `[CivConquest] Mod mismatch!` to `Lua.log`. That means the computers loaded different content (any mod can be the cause, not just this one); make the mod files identical before playing on.

### Development

`tools/gen_landmarks.py` is a development script and isn't needed at runtime. The file it generates, `CivConquestMode/ArtDefs/Landmarks.artdef`, is already committed. Re-run it only after a game update or a new DLC (requires Python 3.9+):

```
python tools/gen_landmarks.py "D:\Steam\steamapps\common\Sid Meier's Civilization VI"
```

The argument is the game install directory; without it the script uses the default path set inside it.

`python tools/build_workshop.py CivConquestMode` builds the Steam Workshop upload folder `dist/workshop/CivConquestMode/` from the files listed in the `.modinfo`; the Workshop preview image and description are in `workshop/CivConquestMode/`. `docs/modding-guide.md` is a beginner's guide (in Chinese) to how Civ VI modding works.

### How it works

| Item | Mechanism |
| --- | --- |
| Civilization / leader abilities | A gameplay script attaches every `TraitModifiers` entry of the trait to the player via `Player:AttachModifierByID`. The engine can attach modifiers but not detach them, which is why activation can't be undone |
| Drawbacks | Listed per modifier in the `CQ_NegativeModifiers` table. With "Do Not Activate Drawbacks" those modifiers are skipped on activation; the original civilization's trait is untouched |
| Unique units | `MODIFIER_PLAYER_ADJUST_VALID_UNIT_BUILD` (the same mechanism Secret Societies uses for the Cultist), attached by the script only when a conqueror activates the trait; it is not attached to the original trait, otherwise the original civilization could build the replaced base unit again (e.g. Basil's Byzantium could build Knights) |
| Unique improvements | `MODIFIER_PLAYER_ADJUST_VALID_IMPROVEMENT` (the same mechanism city-state suzerain improvements use) |
| Unique buildings | `TraitType` is cleared and replaced by `BuildingConditions.UnlocksFromEffect` + `MODIFIER_PLAYER_ADJUST_VALID_BUILDING` (as Secret Societies buildings do); the original civilization still gets them through its own trait |
| Unique districts | The engine only treats the original civilization's unique districts as their base district (no base-district building can be built in an activated one), so you don't build the unique district; its effects are added to your base districts as modifiers: the district's own modifiers, adjacency bonuses, base yields, Great Person points, housing, amenities, and the halved cost (+100% production toward that base district) |

**Why unique districts aren't converted**: early versions converted the base district into the unique one, but the engine only treats the original civilization's own unique districts as their base district (a building's `PrereqDistrict` is checked inside the engine). No base-district building could be built in a converted one; for example, a converted Vietnamese Thanh couldn't build Barracks. Nothing worked around it: clearing the district's `TraitType`, placing the building with `WorldBuilder` (fails with `NeededDistrict`), duplicate buildings, marker buildings, `GRANT_BUILDING_IN_CITY_IGNORE`. So you build the base district instead and the unique district's effects are added to it as modifiers.

Some unique improvements, districts and buildings register their model only for the original civilization (Nubian Pyramid, Persian Pairidaeza, Dutch Polder, Scottish Golf Course, Cree Mekewap, Japanese Electronics Factory, Mongolian Ordu, Macedonian Basilikoi Paides, Babylonian Palgum, Kongolese Mbanza, Vietnamese Thanh), so other civilizations building them see a red exclamation mark. `tools/gen_landmarks.py` scans the base game and DLC `Landmarks.artdef` files (both the `Landmarks` and `Districts` collections) and generates a `Culture = DEFAULT` copy of those variants using the same model.

The UI sends activation requests through `UI.RequestPlayerOperation(..., PlayerOperations.EXECUTE_SCRIPT, ...)`, and the gameplay script validates and applies them, so multiplayer stays in sync. State is stored as player properties (`CQ_UNLOCK_<Leader>`, `CQ_TRAIT_<Trait>`) and is saved with the game.

The gameplay SQL runs with `LoadOrder` 20000, after other civilization mods, so unique items of custom civilizations are usually picked up as well.

### Known limitations

- A few abilities are hard-coded against the trait in the game core (DLL) instead of being implemented through modifiers; they may not work, or only partly work, when activated.
- Activation can't be undone, drawbacks included (see the Negative Effects option above).
- Unique districts don't appear in the production list: build the district they replace and the unique district's effects are added to it.
- Each base district / base building can have only one unique version: once you have the Seowon (your own or activated) you can't activate the Observatory, and once you have the Prasat you can't activate the Stave Church (both replace the Temple). The panel shows "You already have X".
- Activated unique districts have no model or placement rules of their own; on the map they remain the base district. Resource adjacency, specialist and trade route yields, city defense / zone of control and not counting toward the population limit can't be carried over, and the base district keeps its own adjacency bonuses.
- Unique units that can't normally be trained (e.g. Gran Colombia's Comandante General) are not opened for production; you get them through the original mechanism by activating the matching ability.
- Modifiers that require "player has trait X" won't have that requirement met when the ability is gained through activation.
- Some original effects aren't modifiers but are checked by the engine against the native trait, so they are never inherited, good or bad: removed district adjacency rules (Gaul, Japan, Brazil, Lithuania), excluded districts and Great People (Mvemba can't build Holy Sites or earn Great Prophets, the Māori can't earn Great Writers), unique governors (Suleiman's Ibrahim) and diplomatic visibility (Catherine de Medici). The panel lists them under the ability.

### Troubleshooting

Logs are in `%LOCALAPPDATA%\Firaxis Games\Sid Meier's Civilization VI\Logs\`:
- `Lua.log`: search for `[CivConquest]` or `Runtime Error`
  - Debug log (`CQ.DEBUG_LOG` in `CivConquest_Common.lua`, on by default): each unit trained or purchased writes a `[CivConquest] Debug: ...` line with the change in civic progress, useful for checking abilities like "culture when training units"
- `Database.log`, `Modding.log`: data and mod loading issues

---

## 文件 · Files

```
tools/build_workshop.py              生成创意工坊上传文件夹 · builds the Steam Workshop upload folder
tools/gen_landmarks.py               生成 ArtDefs/Landmarks.artdef · generates ArtDefs/Landmarks.artdef
workshop/CivConquestMode/            工坊预览图与介绍 · Workshop preview image and description
docs/modding-guide.md                文明六 mod 入门教程 · beginner's guide to Civ VI modding (Chinese)
docs/CLAUDE.md                       开发笔记 · project notes for Claude Code
CivConquestMode/
├─ CivConquestMode.modinfo           模式定义、加载条件 · mode definition, load criteria
├─ CivConquest.dep                   美术依赖 · art dependency file
├─ ArtDefs/Landmarks.artdef          特色地标/区域/建筑的通用文化模型 · DEFAULT-culture models for civ-only landmarks, districts, buildings
├─ Data/CivConquest_Config.xml       开局设置 · game setup: mode toggle, AI and drawback options
├─ Data/CivConquest_Icons.xml        模式图标 · mode icon (reuses Domination victory icon)
├─ Data/CivConquest_Gameplay.sql     特性映射、解锁修改器、负面效果 · trait/item mapping, unlock modifiers, drawbacks
├─ Scripts/CivConquest_Common.lua    共用逻辑 · logic shared by UI and gameplay
├─ Scripts/CivConquest_Gameplay.lua  解锁与激活 · unlocks and activation
├─ UI/CivConquestPanel.xml / .lua    工具栏按钮与领袖面板 · Launch Bar button and leader panel
├─ UI/CivConquestDebug.lua           调试日志 · debug logging (CQ.DEBUG_LOG)
└─ Text/CivConquest_Text.xml         英文 / 简体中文 · English / Simplified Chinese text
```

## 许可 · License

[MIT](LICENSE)
