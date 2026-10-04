# 文明征服模式 (Civilization Conquest Mode)

文明六游戏模式 mod。开局时在「游戏模式」里勾选（和结社模式、天启模式在同一处）。

## 玩法

- 左上角工具栏（科技树、市政树……）末尾多出一个「文明征服」按钮。
- 左侧列出领袖，可在 **本局领袖 / 所有领袖** 之间切换；未遇见的本局文明会隐藏身份。
- 右侧显示选中领袖的 **文明特性、领袖能力、特色单位 / 建筑 / 区域 / 改良设施**。
- **占领**某个主要文明的**原始首都**后，可以逐项「激活」或「全部激活」。占领后即永久解锁，之后丢失该城市也不影响。
- 有已解锁但还没激活的内容时，工具栏按钮上会出现提示标记。
- 高级选项「文明征服：AI 自动激活」（默认开启）：AI 占领原始首都后会自动激活全部内容。

## 实现方式

| 内容 | 机制 |
| --- | --- |
| 文明特性 / 领袖能力 | Gameplay 脚本把该 Trait 的所有 `TraitModifiers` 通过 `Player:AttachModifierByID` 挂到玩家身上 |
| 特色单位 | `MODIFIER_PLAYER_ADJUST_VALID_UNIT_BUILD`（结社模式“邪教徒”使用的同一机制） |
| 特色改良 | `MODIFIER_PLAYER_ADJUST_VALID_IMPROVEMENT`（城邦宗主独特改良使用的同一机制） |
| 特色建筑 | 去掉 `TraitType`，改为 `BuildingConditions.UnlocksFromEffect` + `MODIFIER_PLAYER_ADJUST_VALID_BUILDING`（结社模式建筑的做法）；原文明通过自身 Trait 照常获得 |
| 特色区域 | 引擎没有对应的解锁效果：先建造被取代的基础区域，建成后在回合开始时由脚本（`WorldBuilder.CityManager`）转换为特色区域并保留其中的建筑 |

UI 通过 `UI.RequestPlayerOperation(..., PlayerOperations.EXECUTE_SCRIPT, ...)` 发送激活请求，由 Gameplay 脚本校验并执行，因此联机同步安全。状态保存在玩家属性中（`CQ_UNLOCK_<Leader>`、`CQ_TRAIT_<Trait>`），随存档保存。

数据 SQL 的 `LoadOrder` 设为 20000，会在其他文明 mod 之后执行，所以自定义文明的特色内容一般也能被识别。

## 已知限制

- 少数能力是在游戏核心（DLL）里按 Trait 硬编码判定的，而不是通过修改器实现，这类能力激活后可能不生效或只部分生效。
- 特色区域无法直接在生产列表中选择（引擎没有按玩家解锁区域的效果），需要建造被取代的基础区域，建成后在回合开始时转换。
- 转换前会检查特色区域自身的地形/地貌要求（如书院、卫城只能在丘陵，蒙巴扎需要树林/雨林）；不满足则保留基础区域，且该地块不再尝试转换。
- 原本不可训练的特色单位（如大哥伦比亚的总指挥）不会解锁生产，只能通过激活对应能力按原机制获得。
- 修改器里如果带有“玩家拥有某 Trait”的需求条件，通过激活获得时该条件不满足。

## 文件

```
CivConquestMode.modinfo          模式定义、加载条件
Data/CivConquest_Config.xml      开局设置：游戏模式开关、AI 选项
Data/CivConquest_Icons.xml       模式图标（复用统治胜利图标）
Data/CivConquest_Gameplay.sql    特性/特色项目映射表、解锁修改器
Scripts/CivConquest_Common.lua   UI 和 Gameplay 共用逻辑
Scripts/CivConquest_Gameplay.lua 解锁检测、激活、区域转换
UI/CivConquestPanel.xml/.lua     工具栏按钮和领袖面板
Text/CivConquest_Text.xml        英文 / 简体中文文本
```

## 安装

把 `CivConquestMode` 文件夹放到 `文档\My Games\Sid Meier's Civilization VI\Mods\` 下，在游戏的「附加内容」中启用，然后在创建游戏时的「游戏模式」里勾选「文明征服模式」。

日志查看：`文档\My Games\Sid Meier's Civilization VI\Logs\Lua.log`（搜索 `[CivConquest]`）、`Database.log`、`Modding.log`。
