# 文明六 Mod 开发新手教程：从游戏文件看懂底层机制

> 编写于 2026-10-08，依据本机游戏安装目录和 `DebugGameplay.sqlite` 缓存核对。在线版（含架构图）：https://claude.ai/code/artifact/4398af4f-8718-402c-aa4a-487fcde4e857

## 先说清楚：能看到的“源代码”是什么

文明六的 C++ 引擎是闭源的，Firaxis 没有像文明五那样发布 DLL 源码，所以我们没法读到战斗公式、AI 决策这类底层实现。能看到的是引擎对外开放的三层：**Gameplay 数据库**（XML/SQL）、**Lua 脚本**（UI 和部分规则）、**美术定义**（ArtDefs）。本教程的所有结论都来自游戏安装目录 `D:\Steam\steamapps\common\Sid Meier's Civilization VI` 里的这些文件。

| 你想了解的 | 能不能看到 | 在哪里看 |
| --- | --- | --- |
| 数值、单位、建筑、科技树、文明能力 | 能，完整 | `Base/Assets/Gameplay/Data/*.xml`，DLC 在 `DLC/*/Data/` |
| 数据库表结构（有哪些表、哪些列） | 能，完整 | `Base/Assets/Gameplay/Data/Schema/01_GameplaySchema.sql` |
| 修改器能做哪些效果 | 能看到效果名清单和参数 | `Modifiers.xml`（`DynamicModifiers` 表） |
| 界面逻辑 | 能，完整 Lua | `Base/Assets/UI/`、各 DLC 的 `UI/` |
| 规则脚本（如部分剧本、模式） | 能，部分 Lua | DLC 和剧本的 `Scripts/` |
| 引擎内部公式、AI、寻路、存档格式 | 不能 | `GameCore_Base_FinalRelease.dll`，只能从数据和日志反推 |

结论：文明六 mod 的主力是**改数据**，不是写代码。大多数“机制”其实是数据库里的一行行记录，引擎只是按表执行。读懂表结构和修改器系统，就等于读懂了 80% 的游戏规则。

## 分层架构：规则在数据库，引擎负责执行

一个 mod 由四类文件组成，全部由 `.modinfo` 调度。它们各自进入闭源引擎的不同部分，彼此之间只能通过引擎提供的接口打交道。

```
                    .modinfo：按 criteria 决定加载哪些文件、何时加载
        │                  │                       │                    │
        ▼                  ▼    EXECUTE_SCRIPT     ▼                    ▼
 ┌─────────────┐   ┌───────────────┐        ┌─────────────┐    ┌──────────────┐
 │数据 XML/SQL │   │ Gameplay Lua  │◄───────│UI Lua + XML │    │ArtDef + .dep │
 │单位、建筑、 │   │每台电脑都运行，│        │只管本机界面 │    │模型和文化变体│
 │特性、修改器 │   │唯一能改状态的 │        │读状态、发请求│    │与规则完全分开│
 └──────┬──────┘   └───────┬───────┘        └──────▲──────┘    └──────┬───────┘
   启动时执行       GameEvents 中修改             只读             UpdateArt
 ┌──────┼──────────────────┼─ C++ 引擎 GameCore（闭源）┼──────────────────┼───────┐
 │      ▼                  ▼                         │                  ▼       │
 │ ┌──────────┐   ┌──────────────────────────────────┴───┐      ┌────────────┐ │
 │ │Gameplay  │──►│ 游戏状态（每台电脑各算一份）          │      │ 渲染       │ │
 │ │数据库    │   │ 玩家、城市、单位、已挂载的修改器、    │      │ 按文化标签 │ │
 │ │SQLite只读│   │ Property；引擎按规则推进回合并比对    │      │ 选模型     │ │
 │ └──────────┘   └──────────────────────────────────────┘      └────────────┘ │
 └─────────────────────────────────────────────────────────────────────────────┘
```

数据在启动时定下规则；运行中想改状态，只能由 Gameplay Lua 在 `GameEvents` 回调里做，UI 要改就通过 `EXECUTE_SCRIPT` 请它代劳。美术和规则完全分开，所以“能造但显示红感叹号”是美术层的问题，不是规则层的。

## Gameplay 数据库：游戏规则的本体

游戏启动时会把所有 XML/SQL 合并进一个 SQLite 数据库，引擎运行时只读这个库。合并后的库会落盘到 `%LOCALAPPDATA%\Firaxis Games\Sid Meier's Civilization VI\Cache\DebugGameplay.sqlite`，用 DB Browser for SQLite 打开就能直接查。本机当前缓存有 318 张表、3393 个 Type、1413 个修改器（反映的是最后一次加载的游戏配置）。

### 两个数据库

- **Configuration 库**（`Base/Assets/Configuration/Data/`）：开局前的设置界面用，如可选领袖、地图、游戏模式开关。对应 modinfo 里的 `FrontEndActions`。
- **Gameplay 库**（`Base/Assets/Gameplay/Data/`）：进入游戏后的全部规则。对应 `InGameActions`。

我们的模式开关 `GAMEMODE_CIV_CONQUEST` 就写在 Configuration 库里（`Data/CivConquest_Config.xml`），而解锁规则写在 Gameplay 库里。

### Types 和 Kinds：所有东西先要“注册”

任何游戏对象（单位、建筑、特性、修改器类型……）都必须先在 `Types` 表注册，指明它属于哪个 `Kind`。`02_AddTriggers.sql` 里的触发器会自动给它算一个 `Hash`，Lua 里的 `GameInfo.Units["UNIT_X"].Hash` 就是这个值。很多表的主键外键引用 `Types(Type)`，忘了注册就会报外键错误。

以希腊重装步兵为例，它在数据库里分散在这些地方（都在 `Base/Assets/Gameplay/Data/` 下）：

| 表 | 内容 | 文件 |
| --- | --- | --- |
| `Types` | `UNIT_GREEK_HOPLITE` 属于 `KIND_UNIT` | Units.xml |
| `Units` | 价格 65、战力 28、青铜器解锁、`TraitType="TRAIT_CIVILIZATION_UNIT_GREEK_HOPLITE"` | Units.xml |
| `UnitReplaces` | 取代 `UNIT_SPEARMAN` | Units.xml |
| `TypeTags` | 带标签 `CLASS_ANTI_CAVALRY`、`CLASS_HOPLITE` | Units.xml |
| `UnitAiInfos` | AI 把它当作近战、反骑兵用 | Units.xml |
| `UnitUpgrades` | 升级为 `UNIT_PIKEMAN` | Units.xml |
| `Traits` + `CivilizationTraits` | 特性本身，并分配给 `CIVILIZATION_GREECE` | Civilizations.xml |

### 写法：XML 和 SQL 等价

XML 里每个标签对应一张表，`<Row>` 是 INSERT，`<Update><Where/><Set/></Update>` 是 UPDATE，`<Delete/>` 是 DELETE，`<Replace/>` 是 INSERT OR REPLACE。资料片里都有实例，如 `DLC/Expansion2/Data/Expansion2_RemoveData.xml` 删掉了一批本体内容。

SQL 更灵活，可以用 `INSERT ... SELECT` 批量生成。我们的 `CivConquest_Gameplay.sql` 就是这样自动收集所有文明（包括 mod 文明）的特色项目的，而不是一个个手写。

### 加载顺序

每个 `UpdateDatabase` 动作有一个 `LoadOrder`，小的先执行；同一动作内的文件按 `Priority` 大的先执行。资料片二用 `LoadOrder=-100` 先跑自己的 Schema，我们用 `20000` 保证在其他 mod 之后执行。如果你要改别人的数据，就必须排在他后面。

### 新手入门路径

1. 先读 `Schema/01_GameplaySchema.sql`（3578 行、310 张表），只看你关心的表的列和外键。
2. 在 `DebugGameplay.sqlite` 里用 SQL 顺着外键查，比读 XML 快得多。
3. 想实现某个效果时，先找一个已有类似效果的官方内容，照着它的行拆开改。

## 修改器系统：几乎所有加成都走这套机制

文明能力、政策卡、建筑加成、单位能力、信仰……底层都是**修改器（Modifier）**。一个修改器回答四个问题：**挂在谁身上**（Owner）、**作用于哪些对象**（Collection）、**在什么条件下**（Requirements）、**做什么**（Effect + 参数）。

### 五张核心表

| 表 | 作用 | 规模（本体） |
| --- | --- | --- |
| `DynamicModifiers` | 定义修改器类型：`ModifierType` = `CollectionType` + `EffectType`。这是引擎暗操的“元件库” | 463 种类型、369 种效果、20 种集合 |
| `Modifiers` | 一个具体修改器实例，指定类型和两个条件集 | 1413 个 |
| `ModifierArguments` | 实例的参数，如 `Amount=10`、`YieldType=YIELD_FAITH` | — |
| `RequirementSets` + `RequirementSetRequirements` | 条件集，`TEST_ALL`（全部满足）或 `TEST_ANY`（任一满足） | 333 个 ALL、30 个 ANY |
| `Requirements` + `RequirementArguments` | 单个条件，如“相邻有友方重装步兵”，`Inverse=1` 可取反 | 238 种条件类型 |

### Owner 和 Subject 的区别

- `OwnerRequirementSetId`：测试修改器的**持有者**。不满足时整个修改器不生效。
- `SubjectRequirementSetId`：对 Collection 里的**每个对象**单独测试。比如“所有城市”里只有滨海城市得到加成。

常见的 Collection：`COLLECTION_OWNER`（持有者本身，占 276/463）、`COLLECTION_PLAYER_CITIES`（该玩家所有城市）、`COLLECTION_PLAYER_UNITS`、`COLLECTION_MAJOR_PLAYERS`、`COLLECTION_ALL_UNITS`。

### 实例一：柏拉图的理想国（最简单的形式）

```xml
<!-- Civilizations.xml -->
<TraitModifiers>
  <Row TraitType="TRAIT_CIVILIZATION_PLATOS_REPUBLIC" ModifierId="TRAIT_WILDCARD_GOVERNMENT_SLOT"/>
</TraitModifiers>
<Modifiers>
  <Row ModifierId="TRAIT_WILDCARD_GOVERNMENT_SLOT"
       ModifierType="MODIFIER_PLAYER_CULTURE_ADJUST_GOVERNMENT_SLOTS_MODIFIER"/>
</Modifiers>
<ModifierArguments>
  <Row ModifierId="TRAIT_WILDCARD_GOVERNMENT_SLOT" Name="GovernmentSlotType" Value="SLOT_WILDCARD"/>
</ModifierArguments>
```

这个类型在 `DynamicModifiers` 里是 `COLLECTION_OWNER` + `EFFECT_ADJUST_PLAYER_GOVERNMENT_SLOT_TYPE`：对持有特性的玩家自己加一个通配政策槽。没有条件集，所以一直生效。

### 实例二：重装步兵方阵（带条件 + 嵌套挂载）

重装步兵“相邻有另一个重装步兵时 +10 战力”是这样连起来的（都在 `UnitAbilities.xml`）：

1. 单位带标签 `CLASS_HOPLITE`，能力 `ABILITY_HOPLITE` 也挂在同一标签上，所以每个重装步兵自带这个能力。
2. `UnitAbilityModifiers`：能力→ `HOPLITE_NEIGHBOR_COMBAT`。
3. `HOPLITE_NEIGHBOR_COMBAT` 的类型是 `MODIFIER_SINGLE_UNIT_ATTACH_MODIFIER`，条件集 `HOPLITE_PLOT_IS_HOPLITE_REQUIREMENTS` 要求 `REQUIREMENT_PLOT_ADJACENT_FRIENDLY_UNIT_TYPE_MATCHES`（`UnitType=UNIT_GREEK_HOPLITE`）。
4. 条件满足时，它把参数 `ModifierId` 指向的 `HOPLITE_NEIGHBOR_COMBAT_MODIFIER` 挂上去：`MODIFIER_UNIT_ADJUST_COMBAT_STRENGTH`，`Amount=10`。

“挂载另一个修改器”（`EFFECT_ATTACH_MODIFIER`）是最重要的组合技巧：外层负责“对谁、何时”，内层负责“做什么”。比如“给所有城市的所有建筑……”就是一层层挂进去的。

### 修改器可以挂在哪里

引擎提供了 17 张“挂载表”，从名字就能看出来源：`TraitModifiers`、`PolicyModifiers`、`BuildingModifiers`、`DistrictModifiers`、`ImprovementModifiers`、`BeliefModifiers`、`GovernmentModifiers`、`TechnologyModifiers`、`CivicModifiers`、`UnitAbilityModifiers`、`UnitPromotionModifiers`、`GreatPersonIndividualActionModifiers` 等，以及全局生效的 `GameModifiers`。Lua 也能在运行时动态挂：`Player:AttachModifierByID("MODIFIER_ID")`，我们的模式就是这样给征服者激活对方特性的。

### 几个容易踩的属性

- `RunOnce`：只执行一次（如送一个单位）。不加会每次重新评估都触发。
- `Permanent`：条件不再满足时效果也不撤销。
- `NewOnly`：只对之后新加入集合的对象生效。
- 效果没有文档。参数名（`Amount`、`YieldType`……）只能从官方已有用法里照抄。先在数据库里 `SELECT * FROM ModifierArguments WHERE ModifierId IN (SELECT ModifierId FROM Modifiers WHERE ModifierType='你想用的类型')`。
- 副作用要单独考虑。我们就踩过：`VALID_UNIT_BUILD` 挂在拜占庭特性上时，让拜占庭重新能造被取代的骑士。先试了给修改器加“玩家本身没有该特性”的条件集，实测仍然能造骑士；最后改成不挂到原特性上，只在征服者激活时由 Lua 挂上（`CQ_ActivationModifiers` 表）。

## 文明、领袖与特色项目：一切都挂在 Trait 上

文明和领袖本身几乎不带规则，规则全在**特性（Trait）**上。一个玩家拥有的特性 = 文明的特性（`CivilizationTraits`）+ 领袖的特性（`LeaderTraits`）。城邦的加成（如 `MINOR_CIV_LA_VENTA_TRAIT`）和蛮族（`TRAIT_BARBARIAN`）也走同一套。

以希腊伯里克利为例（本体数据）：

| 来源 | 特性 | 作用方式 |
| --- | --- | --- |
| 文明 `CIVILIZATION_GREECE` | `TRAIT_CIVILIZATION_PLATOS_REPUBLIC` | `TraitModifiers` → 通配政策槽 |
| 文明 | `TRAIT_CIVILIZATION_UNIT_GREEK_HOPLITE` | `Units.TraitType` 指向它，只有拥有该特性的玩家能造重装步兵 |
| 文明 | `TRAIT_CIVILIZATION_DISTRICT_ACROPOLIS` | `Districts.TraitType` 指向它；`DistrictReplaces` 取代剧院广场 |
| 领袖 `LEADER_PERICLES` | `TRAIT_LEADER_SURROUNDED_BY_GLORY` | `TraitModifiers` → 每个宗主城邦 +文化 |
| 领袖 | `TRAIT_LEADER_CULTURAL_MAJOR_CIV` 等 | 给 AI 用的偏好标签，没有修改器 |

### 特色项目的两个开关

1. **能不能造**：`Units`、`Buildings`、`Districts`、`Improvements` 四张表都有 `TraitType` 列。非空时，引擎只允许拥有该特性的玩家建造。
2. **取代谁**：`UnitReplaces`、`BuildingReplaces`、`DistrictReplaces`。拥有特色版的玩家，基础版会从建造列表里消失。特色改良没有 Replaces，是独立新增的。

### 为什么我们的模式不能“直接加特性”

引擎没有提供运行时给玩家增加 Trait 的 API。开局后玩家的特性就固定了，所以我们分两条路绕：

- **能力**：用 Lua 把该特性的 `TraitModifiers` 逐个 `AttachModifierByID` 到征服者身上（`Scripts/CivConquest_Gameplay.lua`）。
- **特色单位**：用 `MODIFIER_PLAYER_ADJUST_VALID_UNIT_BUILD` 绕过 `TraitType` 限制。特色建筑和改良用 `VALID_BUILDING` / `VALID_IMPROVEMENT`。特色区域引擎没有按玩家解锁的效果，只能先建基础区域、回合开始时由 Lua 转换。都在 `Data/CivConquest_Gameplay.sql` 里。

这也解释了 README 里的已知限制：少数能力由 DLL 直接判断“玩家有没有这个 Trait”，不走修改器，激活后可能不生效；修改器里带有“玩家拥有某 Trait”条件的，通过激活获得时条件也不满足。

## Lua 脚本：两个互相隔离的环境

文明六的 Lua 跑在 Havok Script 上（`HavokScript_FinalRelease.dll`），语法是 Lua 5.1，额外支持 `playerID:number` 这样的类型标注。关键是：**Gameplay 脚本和 UI 脚本是两个不同的环境**，能调用的函数、能收到的事件都不一样，全局变量也不共享。

| | Gameplay 脚本 | UI 脚本 |
| --- | --- | --- |
| modinfo 动作 | `AddGameplayScripts` | `AddUserInterfaces`（XML + 同名 Lua）、`ReplaceUIScript` |
| 跑在哪 | 每台电脑都跑，属于游戏逻辑 | 每台电脑各自跑，只管本地显示 |
| 能不能改游戏状态 | 能：`AttachModifierByID`、`SetProperty`、创建单位、改区域…… | 不能（或不应该），只能读 + 发请求 |
| 主要事件 | `GameEvents.*`：`CityConquered`、`PlayerTurnStarted`、`UnitCreated`、`OnCombatOccurred` …… | `Events.*`：`LocalPlayerTurnBegin`、`CityProductionCompleted`、`CityAddedToMap` ……；`LuaEvents.*` 用于 UI 之间互通 |
| 只在这边有的 API | 大部分写操作 | `PlayerCulture:GetProgressingCivic()` 等部分查询（我们实测在 Gameplay 里调用会失败）、`City:IsOriginalCapital` |

两边都能用 `GameInfo.<表名>` 读数据库，如 `GameInfo.Units["UNIT_GREEK_HOPLITE"].Combat`，或 `for row in GameInfo.TraitModifiers() do ... end` 遍历。

### UI 如何请求 Gameplay 改状态

官方剧本（黑死病、海盗、文明大逃杀）和我们的模式都用同一套写法：

```lua
-- UI 侧（UI/CivConquestPanel.lua）
local kParameters = {};
kParameters.OnStart    = "CQ_ActivateTrait";   -- 要触发的 GameEvents 名
kParameters.LeaderType = leaderType;
UI.RequestPlayerOperation(playerID, PlayerOperations.EXECUTE_SCRIPT, kParameters);

-- Gameplay 侧（Scripts/CivConquest_Gameplay.lua）
GameEvents.CQ_ActivateTrait.Add(function(playerID, params)
    -- 在这里重新校验，再改状态
end);
```

`RequestPlayerOperation` 会把请求作为一条玩家操作广播给所有客户端，每台电脑在同一时刻触发 `GameEvents.CQ_ActivateTrait`，所以结果一致。Gameplay 侧一定要重新校验，不能信任 UI 发来的参数。

### 存数据：Property

脚本自己的 Lua 变量不会进存档。要持久化就用 `Game:SetProperty(key, value)`、`Player:SetProperty`、`Plot:SetProperty`，它们会随存档保存、随联机同步。UI 侧可以用 `GetProperty` 读。我们用它记录原始首都位置、已解锁和已激活的特性。

### 改官方 UI

`ReplaceUIScript` 可以替换官方 UI 的 Lua，官方 DLC 的 modinfo 里一共用了 119 次。但两个 mod 替换同一个文件会互相覆盖，所以能用 `AddUserInterfaces` 新增界面就不要替换。官方 UI 的代码（`Base/Assets/UI/`）是学习 UI API 的最好教材，比如想知道怎么取城市产出，就去看 `CitySupport.lua`。

## 联机同步：每台电脑都在算同一局游戏

文明六联机不是“主机算、客户端看”。每台电脑都完整运行游戏逻辑，只互相发送玩家操作，然后定期比对各自的状态。`net_message_debug.log` 里的 `local/remote values` 就是这种比对。状态一旦不同，就是**不同步（OOS）**，游戏会花约 30 秒重新同步，频繁发生就像一直在掉线。

所以任何改游戏状态的代码，都必须在每台电脑上、同一时刻、以同一顺序、得出同一结果。

### 写代码的规矩

| 规矩 | 原因 | 我们踩过的坑 |
| --- | --- | --- |
| 只在 `GameEvents.*` 里改状态 | `GameEvents` 在游戏逻辑中按固定顺序触发；`Events.*` 是各客户端自己派发的界面通知，时机不一致 | 曾在 `Events.PlayerTurnActivated` 里挂修改器（修于 a29e5c8） |
| 脚本加载时不改状态 | 重新同步时只有被同步的那台电脑会重新加载脚本 | 读档补扫放在 `Initialize()` 里（修于 848d560，改到 `PlayerTurnStarted`） |
| 不依赖 `pairs` 的遍历顺序 | 哈希表顺序在不同电脑上可能不同，先排序再循环 | — |
| 不用 `math.random` | 各电脑的随机种子不同；需要随机时用 `Game.GetRandNum(100, "说明")`，官方剧本就是这样用的 | — |
| UI 不直接改状态 | UI 只在本地运行，必须走 `EXECUTE_SCRIPT` | — |
| 处理 UI 请求先校验参数 | `EXECUTE_SCRIPT` 的参数来自网络，类型不对时脚本报错会中断处理 | — |
| 不在 `CityConquered` 里做重活 | 占城回调发生在城市易手的处理过程中，此时挂大量修改器、用 `WorldBuilder` 改区域风险大；先记标记，留到 `PlayerTurnStarted` 处理 | AI 占城后立即自动激活（改于 d83a94c，改到它的下一回合开始） |
| 所有玩家 mod 文件完全一致 | 数据库不同，计算结果必然不同 | 朋友解压时多了一层文件夹，导致 mod 重复、多出几百个 DynamicModifiers |

### 排查不同步

1. 先确认 mod 一致。联机房间只核对 mod 的 ID 和版本号，不核对文件内容，所以本模式读档后会对整个 Gameplay 数据库算指纹并互相比对：不一致时游戏内会弹窗，`Lua.log` 里有 `[CivConquest] Mod mismatch!`。也可以直接对比两台电脑 `Lua.log` 里的 `[CivConquest] Fingerprint XXXXXX (full: ...)` 行（`partial` 表示退回到了只算核心表的后备算法）。指纹只覆盖数据库，各 mod 的 Lua 脚本不同查不出来。
   要找出是哪个 mod：联机时加载的是主机的 mod 列表，看主机 `Modding.log` 里的 “Target Mods”。创意工坊的 mod 版本不同也会导致分叉。
2. 对比两台电脑 `Lua.log` 里同一回合的 `[CivConquest] Sync turn N ...` 行。不一样就是本模式的状态分叉了。
3. 在 `net_message_debug.log` 里逐项对比 `local/remote values`：数量不同是内容不同（如多了修改器），数量相同、值不同是数值分叉。偶尔一两条 `AI::CityBuild` 不一致会自己恢复，属于正常现象。

## .modinfo：告诉游戏“什么时候、加载哪个文件、做什么”

mod 没有入口函数，`.modinfo` 就是全部的加载说明。官方 DLC 也是用同样的格式加载的（如 `DLC/Expansion2/Expansion2.modinfo`），所以官方 modinfo 就是最全的参考。

### 结构

```xml
<Mod id="一个固定的 GUID" version="1">
  <Properties>名称、说明、AffectsSavedGames ……</Properties>
  <ActionCriteria>定义“条件”</ActionCriteria>
  <FrontEndActions>开局设置界面用的动作</FrontEndActions>
  <InGameActions>进入游戏后的动作（可引用 criteria）</InGameActions>
  <Files>所有用到的文件都要登记</Files>
</Mod>
```

### 常用动作（括号内为官方 DLC 的使用次数）

| 动作 | 作用 |
| --- | --- |
| `UpdateDatabase`（158） | 执行 XML/SQL，改数据库。可设 `LoadOrder` |
| `ReplaceUIScript`（119） | 替换官方 UI 的 Lua，需配 `LuaContext` / `LuaReplace` |
| `UpdateText`（79） | 本地化文本（`LOC_*`） |
| `UpdateIcons`（79） | 图标图集映射 |
| `UpdateColors`（69） | 玩家配色 |
| `UpdateArt`（67） | 加载 `.dep`，引入 ArtDefs 和美术资源 |
| `ImportFiles`（33） | 把文件放进虚拟文件系统，供 `include` 或其他文件引用 |
| `AddGameplayScripts`（10） | Gameplay Lua |
| `AddUserInterfaces`（8） | 新增 UI 界面（XML），需配 `Context`（如 `InGame`） |

### Criteria：动作的开关

每个动作可以带 `criteria="..."`，只在条件满足时生效。官方常用的条件有：

- `RuleSetInUse`：当前规则集，如风云变幻。
- `LeaderPlayable`：某个领袖可用（DLC 文明大量使用）。
- `ConfigurationValueMatches`：开局设置里的某个值匹配。游戏模式就用这个，我们的 `CivConquest_Mode` 检查 `GAMEMODE_CIV_CONQUEST = 1`。
- `ModInUse`、`GameCoreInUse`：另一个 mod 或某个游戏核心在用。

### 新手常见错误

- 新加了文件，只登记在 `<Files>` 或只登记在动作里。两边都要写。
- 修改 `.modinfo` 后只重新读档。modinfo 的改动要重启游戏（或在「附加内容」里重新启用 mod）才生效；只改 Lua/SQL 时重新读档即可。
- 改了 `id`。GUID 是 mod 的身份，改了等于另一个 mod，旧存档会找不到它。
- 把整个仓库复制进 `Mods\`。只复制 `CivConquestMode/` 文件夹，否则可能出现重复的 mod。

## 美术资源：ArtDef 决定“地图上画什么”

数据库里的 `BUILDING_ELECTRONICS_FACTORY` 只是规则，它在地图上长什么样由 **ArtDef** 决定。ArtDef 是一种嵌套的 XML，官方的在 `Base/ArtDefs/`（共 46 个，如 `Units.artdef`、`Districts.artdef`、`Landmarks.artdef`）和 `DLC/*/ArtDefs/`。模型、贴图本身是打包好的 BLP 文件（`Base/Platforms/Windows/BLPs/`），用官方美术工具才能制作，不在本教程范围内。

### 加载链

`modinfo` 的 `UpdateArt` → `.dep` 文件 → `.artdef`。`.dep` 声明了哪个消费者（如 `Landmarks`）要读哪些 artdef，以及它依赖哪些官方 artdef。我们的 `CivConquest.dep` 只引入了一个生成的 `Landmarks.artdef`。官方写法可参考 `DLC/Expansion2/Expansion2.dep`。

### 文化标签与红色感叹号

ArtDef 里的变体用 `Tag_Culture` 按文明或文化圈选择模型。引擎为某个玩家画东西时，会找匹配该玩家文明的变体，找不到就用 `Culture:DEFAULT`。有些特色项目只登记了 `Civilization:CIVILIZATION_XXX`，没有 DEFAULT 兜底，其他文明造出来就只能显示**红色感叹号**。

这是只有“让别人造特色项目”的 mod 才会遇到的问题。对应的两类位置：

- `Landmarks` → `Eras`：特色改良，如 `LM_PYRAMID`。
- `Districts` → `BuildingVariants` / `BaseVariants`：区域内的特色建筑和特色区域，如电子厂、Mbanza。

我们的做法：`tools/gen_landmarks.py` 扫描官方 artdef，给这些组复制一份 DEFAULT 版本，生成 `CivConquestMode/ArtDefs/Landmarks.artdef`（约 2950 行）。**不要手写 artdef**，结构嵌套深，很容易写错。游戏更新或新增 DLC 后要重新生成。

再遇到红感叹号时，先在官方 artdef 里 grep 对应的 `BUILDING_` / `DISTRICT_` / `LM_` 名称，确认它在哪个集合、哪个文化标签下，再改脚本。`ArtDef.log` 也会记录加载问题。

## 调试：没有断点，靠日志和数据库

引擎闭源，不能下断点。日志和合并后的数据库就是主要的调试手段。日志在 `%LOCALAPPDATA%\Firaxis Games\Sid Meier's Civilization VI\Logs\`，每次启动游戏会覆盖。

| 问题 | 先看哪里 | 搜什么 |
| --- | --- | --- |
| mod 没加载 / 动作没执行 | `Modding.log` | mod 名、`Target Mods`、动作 id |
| SQL/XML 报错、数据没生效 | `Database.log` | `ERROR`，常见的是 `UNIQUE constraint failed`（重复插入）和 `FOREIGN KEY constraint failed`（引用了不存在的 Type） |
| Lua 报错 | `Lua.log` | `Runtime Error`、`[CivConquest]` |
| 模型不显示 | `ArtDef.log` | 对应的 artdef 名 |
| 联机不同步 | `net_message_debug.log` | `local/remote values` |

注意：数据库一旦某条语句失败，同一个文件里后面的内容可能都不会生效。所以“效果没出来”时先查 `Database.log`，不要先怀疑逻辑。

### 查最终数据库

进一局开了模式的游戏，然后用 SQLite 工具打开 `Cache\DebugGameplay.sqlite`，就能看到我们的 SQL 执行后的结果：

```sql
-- 我们生成了哪些解锁修改器
SELECT * FROM Modifiers WHERE ModifierId LIKE 'CQ_%';
-- 某个特性挂了哪些修改器、各是什么效果
SELECT tm.ModifierId, m.ModifierType, d.CollectionType, d.EffectType
FROM TraitModifiers tm
JOIN Modifiers m ON m.ModifierId = tm.ModifierId
JOIN DynamicModifiers d ON d.ModifierType = m.ModifierType
WHERE tm.TraitType = 'TRAIT_CIVILIZATION_PLATOS_REPUBLIC';
```

缓存反映的是最后一次加载的游戏；如果查不到 `CQ_` 开头的修改器，说明那一局没开本模式。

### FireTuner（可选）

FireTuner 是官方调试控制台，可以在游戏运行时执行 Lua、看实时输出。它随 Steam 上的「Sid Meier's Civilization VI Development Tools」安装；游戏目录 `Debug/` 下已有它的插件和面板（`Civ6TunerPlugin.dll`、`*.ltp`）。启用方法：把 `%LOCALAPPDATA%\Firaxis Games\Sid Meier's Civilization VI\AppOptions.txt` 里的 `EnableTuner 0` 改成 `1`。先开 FireTuner，再开游戏。

### 自己加日志

Lua 里的 `print()` 会写进 `Lua.log`。给自己的日志加固定前缀（我们用 `[CivConquest]`），方便搜索。对联机问题，每回合输出一行关键状态，两台电脑一对比就能定位分叉点。

## 新手练习：由浅入深的 5 步

每个练习都建一个独立的小 mod 文件夹（一个 `.modinfo` + 一两个文件），放进 `文档\My Games\Sid Meier's Civilization VI\Mods\`，练完就删。不要在 CivConquestMode 里做实验。

- [ ] **练习 1：改一个数值**。用 `UpdateDatabase` + 一个 SQL 文件把重装步兵的战力从 28 改成 40：`UPDATE Units SET Combat = 40 WHERE UnitType = 'UNIT_GREEK_HOPLITE';`。进游戏看百科，再去 `DebugGameplay.sqlite` 里确认。学会：modinfo 最小结构、数据库修改、验证方法。
- [ ] **练习 2：给一个文明加一个简单加成**。新建一个修改器，类型用 `MODIFIER_PLAYER_CITIES_ADJUST_CITY_YIELD_CHANGE`（所有城市产出），挂到 `TRAIT_CIVILIZATION_PLATOS_REPUBLIC` 的 `TraitModifiers` 上。参数名从数据库里已有的同类型修改器照抄。学会：Modifiers / ModifierArguments / TraitModifiers。
- [ ] **练习 3：加条件**。把练习 2 的加成改成“只有滨海城市”。在数据库里找一个官方已有的“滨海”条件（`SELECT * FROM Requirements WHERE RequirementType LIKE '%COAST%'`），配一个 `RequirementSet`，填到 `SubjectRequirementSetId`。学会：Owner 与 Subject 条件。
- [ ] **练习 4：第一个 Gameplay 脚本**。用 `AddGameplayScripts` 加一个 Lua，在 `GameEvents.CityConquered` 里 `print` 出征服者和城市名，再给征服者 `AttachModifierByID` 练习 2 的修改器。在 `Lua.log` 里确认。学会：Gameplay 环境、事件、动态挂修改器。
- [ ] **练习 5：UI 按钮 → Gameplay**。用 `AddUserInterfaces` 加一个只有一个按钮的界面，点击后用 `EXECUTE_SCRIPT` 请求 Gameplay 脚本给本玩家加 100 金币（`pPlayer:GetTreasury():ChangeGoldBalance(100)`）。两个人联机试一下，并故意在 UI 里直接加金币对比。学会：两个环境如何通信、为什么会不同步。

做完这 5 步，再读 `CivConquestMode/` 的全部代码，应该每一行都能看懂它在做什么。

## 参考：值得反复看的文件

游戏目录记为 `G` = `D:\Steam\steamapps\common\Sid Meier's Civilization VI`，本地数据记为 `L` = `%LOCALAPPDATA%\Firaxis Games\Sid Meier's Civilization VI`。

| 文件 | 用途 |
| --- | --- |
| `G\Base\Assets\Gameplay\Data\Schema\01_GameplaySchema.sql` | 全部表结构和外键 |
| `G\Base\Assets\Gameplay\Data\Modifiers.xml` | `DynamicModifiers` 全表，查有哪些效果可用 |
| `G\Base\Assets\Gameplay\Data\Civilizations.xml` | 文明特性及其修改器实例 |
| `G\Base\Assets\Gameplay\Data\UnitAbilities.xml` | 带条件、嵌套挂载的修改器实例 |
| `G\DLC\Expansion2\Expansion2.modinfo` | 最完整的官方 modinfo |
| `G\DLC\Expansion2\Data\` | 资料片如何增删改本体数据（`Update` / `Delete` / `Replace`） |
| `G\DLC\BlackDeathScenario\Scripts\` 等剧本脚本 | 官方 Gameplay Lua 和 `EXECUTE_SCRIPT` 用法 |
| `G\Base\Assets\UI\` | 官方 UI Lua，学 UI API 的教材 |
| `G\Base\ArtDefs\`、`G\DLC\Expansion2\Expansion2.dep` | 美术定义和依赖声明 |
| `L\Cache\DebugGameplay.sqlite` | 最后一次加载的合并数据库 |
| `L\Logs\` | 全部日志 |
| `L\AppOptions.txt` | 调试开关（`EnableTuner`、`EnableDebugMenu`） |
| 仓库 `CLAUDE.md`、`README.md` | 本项目的约定、实现原理和已知限制 |
