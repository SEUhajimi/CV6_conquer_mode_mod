-- =============================================================================
-- 文明征服模式 (Civilization Conquest Mode) - Gameplay 数据
--
-- 思路：
--   * 文明/领袖能力：由 Lua 把该特性 (Trait) 的 TraitModifiers 逐个 AttachModifierByID 到玩家身上。
--   * 特色单位：  MODIFIER_PLAYER_ADJUST_VALID_UNIT_BUILD（与结社模式“邪教徒”同一机制，可绕过 TraitType 限制）。
--   * 特色改良：  MODIFIER_PLAYER_ADJUST_VALID_IMPROVEMENT（与城邦宗主独特改良同一机制）。
--   * 特色建筑：  沿用结社模式建筑的做法 —— 去掉 TraitType，改为 BuildingConditions.UnlocksFromEffect，
--                 再用 MODIFIER_PLAYER_ADJUST_VALID_BUILDING 解锁；原文明通过自身特性继续获得。
--   * 特色区域：  引擎没有对应的解锁效果，由 Lua 在基础区域建成时将其转换为特色区域。
--
-- 上面的“解锁”修改器都会挂到原特性的 TraitModifiers 上，因此 Lua 激活某个特性时会一并获得。
-- =============================================================================

-- 本模式关心的特性：所有完整文明的文明特性 + 其领袖的领袖特性
CREATE TABLE IF NOT EXISTS CQ_Traits (
	TraitType TEXT NOT NULL,
	SourceKind TEXT NOT NULL,		-- 'CIV' | 'LEADER'
	PRIMARY KEY (TraitType)
);

INSERT OR IGNORE INTO CQ_Traits (TraitType, SourceKind)
	SELECT ct.TraitType, 'CIV'
	FROM CivilizationTraits ct
	JOIN Civilizations c ON c.CivilizationType = ct.CivilizationType
	JOIN Traits t ON t.TraitType = ct.TraitType
	WHERE c.StartingCivilizationLevelType = 'CIVILIZATION_LEVEL_FULL_CIV' AND t.InternalOnly = 0;

INSERT OR IGNORE INTO CQ_Traits (TraitType, SourceKind)
	SELECT lt.TraitType, 'LEADER'
	FROM LeaderTraits lt
	JOIN CivilizationLeaders cl ON cl.LeaderType = lt.LeaderType
	JOIN Civilizations c ON c.CivilizationType = cl.CivilizationType
	JOIN Traits t ON t.TraitType = lt.TraitType
	WHERE c.StartingCivilizationLevelType = 'CIVILIZATION_LEVEL_FULL_CIV' AND t.InternalOnly = 0;

-- 特性 -> 特色项目 映射（在清空建筑 TraitType 之前记录下来，供 UI 和 Lua 使用）
CREATE TABLE IF NOT EXISTS CQ_TraitItems (
	TraitType TEXT NOT NULL,
	ItemKind TEXT NOT NULL,			-- 'UNIT' | 'BUILDING' | 'DISTRICT' | 'IMPROVEMENT'
	ItemType TEXT NOT NULL,
	ReplacesType TEXT,
	PRIMARY KEY (TraitType, ItemType)
);

INSERT OR IGNORE INTO CQ_TraitItems (TraitType, ItemKind, ItemType, ReplacesType)
	SELECT u.TraitType, 'UNIT', u.UnitType, r.ReplacesUnitType
	FROM Units u LEFT JOIN UnitReplaces r ON r.CivUniqueUnitType = u.UnitType
	WHERE u.TraitType IN (SELECT TraitType FROM CQ_Traits);

INSERT OR IGNORE INTO CQ_TraitItems (TraitType, ItemKind, ItemType, ReplacesType)
	SELECT b.TraitType, 'BUILDING', b.BuildingType, r.ReplacesBuildingType
	FROM Buildings b LEFT JOIN BuildingReplaces r ON r.CivUniqueBuildingType = b.BuildingType
	WHERE b.TraitType IN (SELECT TraitType FROM CQ_Traits);

INSERT OR IGNORE INTO CQ_TraitItems (TraitType, ItemKind, ItemType, ReplacesType)
	SELECT d.TraitType, 'DISTRICT', d.DistrictType, r.ReplacesDistrictType
	FROM Districts d LEFT JOIN DistrictReplaces r ON r.CivUniqueDistrictType = d.DistrictType
	WHERE d.TraitType IN (SELECT TraitType FROM CQ_Traits);

INSERT OR IGNORE INTO CQ_TraitItems (TraitType, ItemKind, ItemType, ReplacesType)
	SELECT i.TraitType, 'IMPROVEMENT', i.ImprovementType, NULL
	FROM Improvements i
	WHERE i.TraitType IN (SELECT TraitType FROM CQ_Traits);

-- -----------------------------------------------------------------------------
-- 特色单位
-- -----------------------------------------------------------------------------
INSERT OR IGNORE INTO Modifiers (ModifierId, ModifierType)
	SELECT 'CQ_VALID_' || ItemType, 'MODIFIER_PLAYER_ADJUST_VALID_UNIT_BUILD'
	FROM CQ_TraitItems WHERE ItemKind = 'UNIT';

INSERT OR IGNORE INTO ModifierArguments (ModifierId, Name, Value)
	SELECT 'CQ_VALID_' || ItemType, 'UnitType', ItemType
	FROM CQ_TraitItems WHERE ItemKind = 'UNIT';

-- 原本不可训练的特色单位（CanTrain = 0，如大哥伦比亚的总指挥，由领袖能力按时代授予）：
-- VALID_UNIT_BUILD 会绕过 CanTrain 让其可随意生产，因此这些单位不发放解锁修改器，
-- 只能通过激活对应的文明/领袖能力、按原机制获得。
-- 修改器定义仍保留（旧存档里可能已挂载），但加上永不满足的条件使其失效。
CREATE TABLE IF NOT EXISTS CQ_UntrainableUnits (
	UnitType TEXT NOT NULL,
	PRIMARY KEY (UnitType)
);

INSERT OR IGNORE INTO CQ_UntrainableUnits (UnitType)
	SELECT ti.ItemType FROM CQ_TraitItems ti JOIN Units u ON u.UnitType = ti.ItemType
	WHERE ti.ItemKind = 'UNIT' AND u.CanTrain = 0;

INSERT OR IGNORE INTO Requirements (RequirementId, RequirementType)
	VALUES ('CQ_REQ_NEVER_FOR_MAJORS', 'REQUIREMENT_PLAYER_IS_MINOR');

INSERT OR IGNORE INTO RequirementSets (RequirementSetId, RequirementSetType)
	VALUES ('CQ_REQSET_NEVER', 'REQUIREMENTSET_TEST_ALL');

INSERT OR IGNORE INTO RequirementSetRequirements (RequirementSetId, RequirementId)
	VALUES ('CQ_REQSET_NEVER', 'CQ_REQ_NEVER_FOR_MAJORS');

UPDATE Modifiers SET SubjectRequirementSetId = 'CQ_REQSET_NEVER'
	WHERE ModifierId IN (SELECT 'CQ_VALID_' || UnitType FROM CQ_UntrainableUnits);

-- -----------------------------------------------------------------------------
-- 特色改良
-- -----------------------------------------------------------------------------
INSERT OR IGNORE INTO Modifiers (ModifierId, ModifierType)
	SELECT 'CQ_VALID_' || ItemType, 'MODIFIER_PLAYER_ADJUST_VALID_IMPROVEMENT'
	FROM CQ_TraitItems WHERE ItemKind = 'IMPROVEMENT';

INSERT OR IGNORE INTO ModifierArguments (ModifierId, Name, Value)
	SELECT 'CQ_VALID_' || ItemType, 'ImprovementType', ItemType
	FROM CQ_TraitItems WHERE ItemKind = 'IMPROVEMENT';

-- -----------------------------------------------------------------------------
-- 特色建筑
-- -----------------------------------------------------------------------------
INSERT OR IGNORE INTO Modifiers (ModifierId, ModifierType)
	SELECT 'CQ_VALID_' || ItemType, 'MODIFIER_PLAYER_ADJUST_VALID_BUILDING'
	FROM CQ_TraitItems WHERE ItemKind = 'BUILDING';

INSERT OR IGNORE INTO ModifierArguments (ModifierId, Name, Value)
	SELECT 'CQ_VALID_' || ItemType, 'BuildingType', ItemType
	FROM CQ_TraitItems WHERE ItemKind = 'BUILDING';

INSERT OR IGNORE INTO ModifierArguments (ModifierId, Name, Value)
	SELECT 'CQ_VALID_' || ItemType, 'BuildingTypeToReplace', ReplacesType
	FROM CQ_TraitItems WHERE ItemKind = 'BUILDING' AND ReplacesType IS NOT NULL;

INSERT OR REPLACE INTO BuildingConditions (BuildingType, UnlocksFromEffect)
	SELECT ItemType, 1 FROM CQ_TraitItems WHERE ItemKind = 'BUILDING';

UPDATE Buildings SET TraitType = NULL
	WHERE BuildingType IN (SELECT ItemType FROM CQ_TraitItems WHERE ItemKind = 'BUILDING');

-- -----------------------------------------------------------------------------
-- 把解锁修改器挂到原特性上：原文明照常拥有，激活该特性的征服者也一并获得
-- -----------------------------------------------------------------------------
INSERT OR IGNORE INTO TraitModifiers (TraitType, ModifierId)
	SELECT TraitType, 'CQ_VALID_' || ItemType
	FROM CQ_TraitItems WHERE ItemKind IN ('UNIT', 'IMPROVEMENT', 'BUILDING')
		AND ItemType NOT IN (SELECT UnitType FROM CQ_UntrainableUnits);
