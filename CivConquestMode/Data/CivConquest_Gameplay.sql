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
-- 建筑、改良的“解锁”修改器挂到原特性的 TraitModifiers 上，Lua 激活某个特性时会一并获得；
-- 单位的解锁修改器只登记在 CQ_ActivationModifiers，由 Lua 在激活时额外挂上，原文明不会拿到。
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

-- 单位解锁修改器不挂到原特性上（见文件末尾），只在征服者激活该特性时由 Lua 挂上。
-- 原文明不需要它（特色单位的 TraitType 未改动，原文明本来就能训练），而对原文明生效时
-- 会让被取代的基础单位重新可造（如巴西尔的拜占庭在马镫就能造骑士、跑马场送骑士）。
-- 曾试过挂在原特性上、再加“玩家本身没有该特性”的条件排除原文明，实测无效，已弃用。
CREATE TABLE IF NOT EXISTS CQ_ActivationModifiers (
	TraitType TEXT NOT NULL,
	ModifierId TEXT NOT NULL,
	PRIMARY KEY (TraitType, ModifierId)
);

INSERT OR IGNORE INTO CQ_ActivationModifiers (TraitType, ModifierId)
	SELECT TraitType, 'CQ_VALID_' || ItemType
	FROM CQ_TraitItems WHERE ItemKind = 'UNIT'
		AND ItemType NOT IN (SELECT UnitType FROM CQ_UntrainableUnits);

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
-- 同一个基础建筑只能有一个特色版本（如 Prasat、木板教堂都取代寺庙，只能选一个）：
-- 引擎的取代映射只保证一个，由 Lua 在激活时校验（CQ.GetTraitConflict）。
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
-- 特色区域：效果加到激活者的基础区域上
-- -----------------------------------------------------------------------------
-- 引擎只把原文明的特色区域当成基础区域（实测：转换来的、甚至去掉 TraitType 的 Thanh 里都造不了兵营，
-- WorldBuilder 也放不进去），所以激活者不建造特色区域，而是把特色区域的效果加到自己的基础区域上，
-- 基础区域里的建筑照常建造。修改器登记在 CQ_ActivationModifiers，激活时由 Lua 挂上，原文明拿不到。
-- 能迁移：区域自带修改器、相邻加成（相邻区域 / 改良 / 地貌 / 地形 / 河流；相邻特定区域改为固定产出；
--         相邻资源近似为“旁边有某类资源时固定产出”，每类资源算一次）、区域自身产出、伟人点数、
--         住房、宜居度、造价（换算为建造该基础区域的生产力加成）。
-- 不能迁移（引擎没有对应效果）：城防 / 区域控制、不占人口上限、更早解锁、放置限制、模型；
--         基础区域原有的相邻加成也去不掉。
-- 每条加成在 CQ_DistrictBonusInfo 里记一行说明数据，面板据此生成“实际获得的效果”文字。
CREATE TABLE IF NOT EXISTS CQ_DistrictBonuses (
	ModifierId TEXT NOT NULL,
	TraitType TEXT NOT NULL,
	PRIMARY KEY (ModifierId)
);

-- 面板说明用：Kind 见下方各节；Target 为改良 / 地貌 / 地形 / 区域 / 资源类别 / 伟人类别
CREATE TABLE IF NOT EXISTS CQ_DistrictBonusInfo (
	ModifierId TEXT NOT NULL,
	DistrictType TEXT NOT NULL,
	Kind TEXT NOT NULL,
	YieldType TEXT,
	Amount INTEGER,
	Target TEXT,
	TilesRequired INTEGER,
	PRIMARY KEY (ModifierId)
);

-- 特色区域 U、所属特性、基础区域 D
CREATE TABLE IF NOT EXISTS CQ_UniqueDistricts (
	DistrictType TEXT NOT NULL,
	TraitType TEXT NOT NULL,
	BaseDistrictType TEXT NOT NULL,
	PRIMARY KEY (DistrictType)
);

INSERT OR IGNORE INTO CQ_UniqueDistricts (DistrictType, TraitType, BaseDistrictType)
	SELECT ItemType, TraitType, ReplacesType FROM CQ_TraitItems
	WHERE ItemKind = 'DISTRICT' AND ReplacesType IS NOT NULL;

-- 自定义修改器类型：对玩家的每个区域挂载另一个修改器（官方只有“所有区域”版本）
INSERT OR IGNORE INTO Types (Type, Kind) VALUES ('MODIFIER_CQ_PLAYER_DISTRICTS_ATTACH_MODIFIER', 'KIND_MODIFIER');
INSERT OR IGNORE INTO DynamicModifiers (ModifierType, CollectionType, EffectType)
	VALUES ('MODIFIER_CQ_PLAYER_DISTRICTS_ATTACH_MODIFIER', 'COLLECTION_PLAYER_DISTRICTS', 'EFFECT_ATTACH_MODIFIER');

-- 条件：区域类型是 D
INSERT OR IGNORE INTO Requirements (RequirementId, RequirementType)
	SELECT DISTINCT 'CQ_REQ_DISTRICT_IS_' || BaseDistrictType, 'REQUIREMENT_DISTRICT_TYPE_MATCHES' FROM CQ_UniqueDistricts;
INSERT OR IGNORE INTO RequirementArguments (RequirementId, Name, Value)
	SELECT DISTINCT 'CQ_REQ_DISTRICT_IS_' || BaseDistrictType, 'DistrictType', BaseDistrictType FROM CQ_UniqueDistricts;
INSERT OR IGNORE INTO RequirementSets (RequirementSetId, RequirementSetType)
	SELECT DISTINCT 'CQ_REQSET_DISTRICT_IS_' || BaseDistrictType, 'REQUIREMENTSET_TEST_ALL' FROM CQ_UniqueDistricts;
INSERT OR IGNORE INTO RequirementSetRequirements (RequirementSetId, RequirementId)
	SELECT DISTINCT 'CQ_REQSET_DISTRICT_IS_' || BaseDistrictType, 'CQ_REQ_DISTRICT_IS_' || BaseDistrictType FROM CQ_UniqueDistricts;

-- 1. 区域自带修改器：原样挂到 D 上
INSERT OR IGNORE INTO Modifiers (ModifierId, ModifierType, SubjectRequirementSetId)
	SELECT 'CQ_DB_' || u.DistrictType || '_' || dm.ModifierId, 'MODIFIER_CQ_PLAYER_DISTRICTS_ATTACH_MODIFIER',
		'CQ_REQSET_DISTRICT_IS_' || u.BaseDistrictType
	FROM CQ_UniqueDistricts u JOIN DistrictModifiers dm ON dm.DistrictType = u.DistrictType;
INSERT OR IGNORE INTO ModifierArguments (ModifierId, Name, Value)
	SELECT 'CQ_DB_' || u.DistrictType || '_' || dm.ModifierId, 'ModifierId', dm.ModifierId
	FROM CQ_UniqueDistricts u JOIN DistrictModifiers dm ON dm.DistrictType = u.DistrictType;
INSERT OR IGNORE INTO CQ_DistrictBonuses (ModifierId, TraitType)
	SELECT 'CQ_DB_' || u.DistrictType || '_' || dm.ModifierId, u.TraitType
	FROM CQ_UniqueDistricts u JOIN DistrictModifiers dm ON dm.DistrictType = u.DistrictType;
INSERT OR IGNORE INTO CQ_DistrictBonusInfo (ModifierId, DistrictType, Kind)
	SELECT 'CQ_DB_' || u.DistrictType || '_' || dm.ModifierId, u.DistrictType, 'SPECIAL'
	FROM CQ_UniqueDistricts u JOIN DistrictModifiers dm ON dm.DistrictType = u.DistrictType;

-- 2. 相邻加成：只迁移 U 有、D 没有的规则
CREATE TABLE IF NOT EXISTS CQ_DistrictAdjacencies (
	Id TEXT NOT NULL,				-- CQ_DB_<U>_<相邻规则 ID>
	DistrictType TEXT NOT NULL,
	TraitType TEXT NOT NULL,
	BaseDistrictType TEXT NOT NULL,
	AdjacencyId TEXT NOT NULL,
	PRIMARY KEY (Id)
);

INSERT OR IGNORE INTO CQ_DistrictAdjacencies (Id, DistrictType, TraitType, BaseDistrictType, AdjacencyId)
	SELECT 'CQ_DB_' || u.DistrictType || '_' || da.YieldChangeId, u.DistrictType, u.TraitType, u.BaseDistrictType, da.YieldChangeId
	FROM CQ_UniqueDistricts u JOIN District_Adjacencies da ON da.DistrictType = u.DistrictType
	WHERE da.YieldChangeId NOT IN (SELECT YieldChangeId FROM District_Adjacencies WHERE DistrictType = u.BaseDistrictType);

-- 2a. 相邻任意区域
INSERT OR IGNORE INTO Modifiers (ModifierId, ModifierType)
	SELECT x.Id, 'MODIFIER_PLAYER_CITIES_DISTRICT_ADJACENCY'
	FROM CQ_DistrictAdjacencies x JOIN Adjacency_YieldChanges a ON a.ID = x.AdjacencyId WHERE a.OtherDistrictAdjacent = 1;

-- 2b. 相邻改良
INSERT OR IGNORE INTO Modifiers (ModifierId, ModifierType)
	SELECT x.Id, 'MODIFIER_PLAYER_CITIES_IMPROVEMENT_ADJACENCY'
	FROM CQ_DistrictAdjacencies x JOIN Adjacency_YieldChanges a ON a.ID = x.AdjacencyId WHERE a.AdjacentImprovement IS NOT NULL;
INSERT OR IGNORE INTO ModifierArguments (ModifierId, Name, Value)
	SELECT x.Id, 'ImprovementType', a.AdjacentImprovement
	FROM CQ_DistrictAdjacencies x JOIN Adjacency_YieldChanges a ON a.ID = x.AdjacencyId WHERE a.AdjacentImprovement IS NOT NULL;

-- 2c. 相邻地貌
INSERT OR IGNORE INTO Modifiers (ModifierId, ModifierType)
	SELECT x.Id, 'MODIFIER_PLAYER_CITIES_FEATURE_ADJACENCY'
	FROM CQ_DistrictAdjacencies x JOIN Adjacency_YieldChanges a ON a.ID = x.AdjacencyId WHERE a.AdjacentFeature IS NOT NULL;
INSERT OR IGNORE INTO ModifierArguments (ModifierId, Name, Value)
	SELECT x.Id, 'FeatureType', a.AdjacentFeature
	FROM CQ_DistrictAdjacencies x JOIN Adjacency_YieldChanges a ON a.ID = x.AdjacencyId WHERE a.AdjacentFeature IS NOT NULL;

-- 2d. 相邻地形
INSERT OR IGNORE INTO Modifiers (ModifierId, ModifierType)
	SELECT x.Id, 'MODIFIER_PLAYER_CITIES_TERRAIN_ADJACENCY'
	FROM CQ_DistrictAdjacencies x JOIN Adjacency_YieldChanges a ON a.ID = x.AdjacencyId WHERE a.AdjacentTerrain IS NOT NULL;
INSERT OR IGNORE INTO ModifierArguments (ModifierId, Name, Value)
	SELECT x.Id, 'TerrainType', a.AdjacentTerrain
	FROM CQ_DistrictAdjacencies x JOIN Adjacency_YieldChanges a ON a.ID = x.AdjacencyId WHERE a.AdjacentTerrain IS NOT NULL;

-- 2e. 相邻河流
INSERT OR IGNORE INTO Modifiers (ModifierId, ModifierType)
	SELECT x.Id, 'MODIFIER_PLAYER_CITIES_RIVER_ADJACENCY'
	FROM CQ_DistrictAdjacencies x JOIN Adjacency_YieldChanges a ON a.ID = x.AdjacencyId WHERE a.AdjacentRiver = 1;

-- 2a-2e 的公共参数
INSERT OR IGNORE INTO ModifierArguments (ModifierId, Name, Value)
	SELECT x.Id, 'DistrictType', x.BaseDistrictType
	FROM CQ_DistrictAdjacencies x JOIN Modifiers m ON m.ModifierId = x.Id;
INSERT OR IGNORE INTO ModifierArguments (ModifierId, Name, Value)
	SELECT x.Id, 'YieldType', a.YieldType
	FROM CQ_DistrictAdjacencies x JOIN Adjacency_YieldChanges a ON a.ID = x.AdjacencyId JOIN Modifiers m ON m.ModifierId = x.Id;
INSERT OR IGNORE INTO ModifierArguments (ModifierId, Name, Value)
	SELECT x.Id, 'Amount', a.YieldChange
	FROM CQ_DistrictAdjacencies x JOIN Adjacency_YieldChanges a ON a.ID = x.AdjacencyId JOIN Modifiers m ON m.ModifierId = x.Id;
INSERT OR IGNORE INTO ModifierArguments (ModifierId, Name, Value)
	SELECT x.Id, 'TilesRequired', a.TilesRequired
	FROM CQ_DistrictAdjacencies x JOIN Adjacency_YieldChanges a ON a.ID = x.AdjacencyId JOIN Modifiers m ON m.ModifierId = x.Id
	WHERE m.ModifierType IN ('MODIFIER_PLAYER_CITIES_IMPROVEMENT_ADJACENCY', 'MODIFIER_PLAYER_CITIES_TERRAIN_ADJACENCY') AND a.TilesRequired > 1;
INSERT OR IGNORE INTO ModifierArguments (ModifierId, Name, Value)
	SELECT x.Id, 'Description', a.Description
	FROM CQ_DistrictAdjacencies x JOIN Adjacency_YieldChanges a ON a.ID = x.AdjacencyId JOIN Modifiers m ON m.ModifierId = x.Id
	WHERE a.Description IS NOT NULL;
INSERT OR IGNORE INTO CQ_DistrictBonuses (ModifierId, TraitType)
	SELECT x.Id, x.TraitType FROM CQ_DistrictAdjacencies x JOIN Modifiers m ON m.ModifierId = x.Id;
INSERT OR IGNORE INTO CQ_DistrictBonusInfo (ModifierId, DistrictType, Kind, YieldType, Amount, Target, TilesRequired)
	SELECT x.Id, x.DistrictType,
		CASE m.ModifierType
			WHEN 'MODIFIER_PLAYER_CITIES_DISTRICT_ADJACENCY' THEN 'ADJ_DISTRICT'
			WHEN 'MODIFIER_PLAYER_CITIES_IMPROVEMENT_ADJACENCY' THEN 'ADJ_IMPROVEMENT'
			WHEN 'MODIFIER_PLAYER_CITIES_FEATURE_ADJACENCY' THEN 'ADJ_FEATURE'
			WHEN 'MODIFIER_PLAYER_CITIES_TERRAIN_ADJACENCY' THEN 'ADJ_TERRAIN'
			ELSE 'ADJ_RIVER' END,
		a.YieldType, a.YieldChange, COALESCE(a.AdjacentImprovement, a.AdjacentFeature, a.AdjacentTerrain), a.TilesRequired
	FROM CQ_DistrictAdjacencies x JOIN Adjacency_YieldChanges a ON a.ID = x.AdjacencyId JOIN Modifiers m ON m.ModifierId = x.Id;

-- 2f. 区域自身产出（Self）和相邻特定区域：改为 D 的固定产出（相邻特定区域时才给）
INSERT OR IGNORE INTO Modifiers (ModifierId, ModifierType)
	SELECT x.Id || '_YIELD', 'MODIFIER_PLAYER_DISTRICT_ADJUST_BASE_YIELD_CHANGE'
	FROM CQ_DistrictAdjacencies x JOIN Adjacency_YieldChanges a ON a.ID = x.AdjacencyId
	WHERE a.Self = 1 OR a.AdjacentDistrict IS NOT NULL;
INSERT OR IGNORE INTO ModifierArguments (ModifierId, Name, Value)
	SELECT x.Id || '_YIELD', 'YieldType', a.YieldType
	FROM CQ_DistrictAdjacencies x JOIN Adjacency_YieldChanges a ON a.ID = x.AdjacencyId
	WHERE a.Self = 1 OR a.AdjacentDistrict IS NOT NULL;
INSERT OR IGNORE INTO ModifierArguments (ModifierId, Name, Value)
	SELECT x.Id || '_YIELD', 'Amount', a.YieldChange
	FROM CQ_DistrictAdjacencies x JOIN Adjacency_YieldChanges a ON a.ID = x.AdjacencyId
	WHERE a.Self = 1 OR a.AdjacentDistrict IS NOT NULL;

INSERT OR IGNORE INTO Requirements (RequirementId, RequirementType)
	SELECT DISTINCT 'CQ_REQ_ADJACENT_' || a.AdjacentDistrict, 'REQUIREMENT_PLOT_ADJACENT_DISTRICT_TYPE_MATCHES'
	FROM CQ_DistrictAdjacencies x JOIN Adjacency_YieldChanges a ON a.ID = x.AdjacencyId WHERE a.AdjacentDistrict IS NOT NULL;
INSERT OR IGNORE INTO RequirementArguments (RequirementId, Name, Value)
	SELECT DISTINCT 'CQ_REQ_ADJACENT_' || a.AdjacentDistrict, 'DistrictType', a.AdjacentDistrict
	FROM CQ_DistrictAdjacencies x JOIN Adjacency_YieldChanges a ON a.ID = x.AdjacencyId WHERE a.AdjacentDistrict IS NOT NULL;
INSERT OR IGNORE INTO RequirementSets (RequirementSetId, RequirementSetType)
	SELECT x.Id || '_REQS', 'REQUIREMENTSET_TEST_ALL'
	FROM CQ_DistrictAdjacencies x JOIN Adjacency_YieldChanges a ON a.ID = x.AdjacencyId WHERE a.AdjacentDistrict IS NOT NULL;
INSERT OR IGNORE INTO RequirementSetRequirements (RequirementSetId, RequirementId)
	SELECT x.Id || '_REQS', 'CQ_REQ_DISTRICT_IS_' || x.BaseDistrictType
	FROM CQ_DistrictAdjacencies x JOIN Adjacency_YieldChanges a ON a.ID = x.AdjacencyId WHERE a.AdjacentDistrict IS NOT NULL;
INSERT OR IGNORE INTO RequirementSetRequirements (RequirementSetId, RequirementId)
	SELECT x.Id || '_REQS', 'CQ_REQ_ADJACENT_' || a.AdjacentDistrict
	FROM CQ_DistrictAdjacencies x JOIN Adjacency_YieldChanges a ON a.ID = x.AdjacencyId WHERE a.AdjacentDistrict IS NOT NULL;

INSERT OR IGNORE INTO Modifiers (ModifierId, ModifierType, SubjectRequirementSetId)
	SELECT x.Id, 'MODIFIER_CQ_PLAYER_DISTRICTS_ATTACH_MODIFIER',
		CASE WHEN a.AdjacentDistrict IS NOT NULL THEN x.Id || '_REQS' ELSE 'CQ_REQSET_DISTRICT_IS_' || x.BaseDistrictType END
	FROM CQ_DistrictAdjacencies x JOIN Adjacency_YieldChanges a ON a.ID = x.AdjacencyId
	WHERE a.Self = 1 OR a.AdjacentDistrict IS NOT NULL;
INSERT OR IGNORE INTO ModifierArguments (ModifierId, Name, Value)
	SELECT x.Id, 'ModifierId', x.Id || '_YIELD'
	FROM CQ_DistrictAdjacencies x JOIN Adjacency_YieldChanges a ON a.ID = x.AdjacencyId
	WHERE a.Self = 1 OR a.AdjacentDistrict IS NOT NULL;
INSERT OR IGNORE INTO CQ_DistrictBonuses (ModifierId, TraitType)
	SELECT x.Id, x.TraitType
	FROM CQ_DistrictAdjacencies x JOIN Adjacency_YieldChanges a ON a.ID = x.AdjacencyId
	WHERE a.Self = 1 OR a.AdjacentDistrict IS NOT NULL;
INSERT OR IGNORE INTO CQ_DistrictBonusInfo (ModifierId, DistrictType, Kind, YieldType, Amount, Target)
	SELECT x.Id, x.DistrictType, CASE WHEN a.Self = 1 THEN 'YIELD' ELSE 'NEXT_TO_DISTRICT' END,
		a.YieldType, a.YieldChange, a.AdjacentDistrict
	FROM CQ_DistrictAdjacencies x JOIN Adjacency_YieldChanges a ON a.ID = x.AdjacencyId
	WHERE a.Self = 1 OR a.AdjacentDistrict IS NOT NULL;

-- 2g. 相邻资源（近似）：引擎没有“每相邻一个资源”的修改器，只能判断“旁边有没有某类资源”。
-- 相邻任意资源（如汉萨）拆成加成 / 战略 / 奢侈三类，旁边有该类资源就给一次；
-- 相邻指定类别（如 Oppidum 的战略资源）旁边有就给一次。
CREATE TABLE IF NOT EXISTS CQ_DistrictResourceAdjacencies (
	Id TEXT NOT NULL,
	DistrictType TEXT NOT NULL,
	TraitType TEXT NOT NULL,
	BaseDistrictType TEXT NOT NULL,
	ResourceClassType TEXT NOT NULL,
	YieldType TEXT NOT NULL,
	Amount INTEGER NOT NULL,
	PRIMARY KEY (Id)
);

INSERT OR IGNORE INTO CQ_DistrictResourceAdjacencies (Id, DistrictType, TraitType, BaseDistrictType, ResourceClassType, YieldType, Amount)
	SELECT x.Id || '_' || rc.ResourceClassType, x.DistrictType, x.TraitType, x.BaseDistrictType, rc.ResourceClassType, a.YieldType, a.YieldChange
	FROM CQ_DistrictAdjacencies x JOIN Adjacency_YieldChanges a ON a.ID = x.AdjacencyId
	JOIN (SELECT 'RESOURCECLASS_BONUS' AS ResourceClassType UNION ALL SELECT 'RESOURCECLASS_STRATEGIC'
		UNION ALL SELECT 'RESOURCECLASS_LUXURY') rc
		ON (a.AdjacentResource = 1 AND (a.AdjacentResourceClass IS NULL OR a.AdjacentResourceClass = 'NO_RESOURCECLASS'))
		OR a.AdjacentResourceClass = rc.ResourceClassType;

INSERT OR IGNORE INTO Requirements (RequirementId, RequirementType)
	SELECT DISTINCT 'CQ_REQ_ADJACENT_' || ResourceClassType, 'REQUIREMENT_PLOT_ADJACENT_RESOURCE_CLASS_TYPE_MATCHES'
	FROM CQ_DistrictResourceAdjacencies;
INSERT OR IGNORE INTO RequirementArguments (RequirementId, Name, Value)
	SELECT DISTINCT 'CQ_REQ_ADJACENT_' || ResourceClassType, 'ResourceClassType', ResourceClassType
	FROM CQ_DistrictResourceAdjacencies;
INSERT OR IGNORE INTO RequirementSets (RequirementSetId, RequirementSetType)
	SELECT Id || '_REQS', 'REQUIREMENTSET_TEST_ALL' FROM CQ_DistrictResourceAdjacencies;
INSERT OR IGNORE INTO RequirementSetRequirements (RequirementSetId, RequirementId)
	SELECT Id || '_REQS', 'CQ_REQ_DISTRICT_IS_' || BaseDistrictType FROM CQ_DistrictResourceAdjacencies;
INSERT OR IGNORE INTO RequirementSetRequirements (RequirementSetId, RequirementId)
	SELECT Id || '_REQS', 'CQ_REQ_ADJACENT_' || ResourceClassType FROM CQ_DistrictResourceAdjacencies;

INSERT OR IGNORE INTO Modifiers (ModifierId, ModifierType)
	SELECT Id || '_YIELD', 'MODIFIER_PLAYER_DISTRICT_ADJUST_BASE_YIELD_CHANGE' FROM CQ_DistrictResourceAdjacencies;
INSERT OR IGNORE INTO ModifierArguments (ModifierId, Name, Value)
	SELECT Id || '_YIELD', 'YieldType', YieldType FROM CQ_DistrictResourceAdjacencies;
INSERT OR IGNORE INTO ModifierArguments (ModifierId, Name, Value)
	SELECT Id || '_YIELD', 'Amount', Amount FROM CQ_DistrictResourceAdjacencies;
INSERT OR IGNORE INTO Modifiers (ModifierId, ModifierType, SubjectRequirementSetId)
	SELECT Id, 'MODIFIER_CQ_PLAYER_DISTRICTS_ATTACH_MODIFIER', Id || '_REQS' FROM CQ_DistrictResourceAdjacencies;
INSERT OR IGNORE INTO ModifierArguments (ModifierId, Name, Value)
	SELECT Id, 'ModifierId', Id || '_YIELD' FROM CQ_DistrictResourceAdjacencies;
INSERT OR IGNORE INTO CQ_DistrictBonuses (ModifierId, TraitType)
	SELECT Id, TraitType FROM CQ_DistrictResourceAdjacencies;
INSERT OR IGNORE INTO CQ_DistrictBonusInfo (ModifierId, DistrictType, Kind, YieldType, Amount, Target)
	SELECT Id, DistrictType, 'NEXT_TO_RESOURCE', YieldType, Amount, ResourceClassType FROM CQ_DistrictResourceAdjacencies;

-- 3. 伟人点数：按伟人类型取差值
CREATE TABLE IF NOT EXISTS CQ_DistrictGreatPeople (
	Id TEXT NOT NULL,
	TraitType TEXT NOT NULL,
	BaseDistrictType TEXT NOT NULL,
	GreatPersonClassType TEXT NOT NULL,
	Amount INTEGER NOT NULL,
	PRIMARY KEY (Id)
);

INSERT OR IGNORE INTO CQ_DistrictGreatPeople (Id, TraitType, BaseDistrictType, GreatPersonClassType, Amount)
	SELECT 'CQ_DB_' || u.DistrictType || '_' || g.GreatPersonClassType, u.TraitType, u.BaseDistrictType, g.GreatPersonClassType,
		IFNULL((SELECT PointsPerTurn FROM District_GreatPersonPoints WHERE DistrictType = u.DistrictType AND GreatPersonClassType = g.GreatPersonClassType), 0)
		- IFNULL((SELECT PointsPerTurn FROM District_GreatPersonPoints WHERE DistrictType = u.BaseDistrictType AND GreatPersonClassType = g.GreatPersonClassType), 0)
	FROM CQ_UniqueDistricts u
	JOIN (SELECT DISTINCT DistrictType, GreatPersonClassType FROM District_GreatPersonPoints) g
		ON g.DistrictType IN (u.DistrictType, u.BaseDistrictType);

DELETE FROM CQ_DistrictGreatPeople WHERE Amount = 0;

INSERT OR IGNORE INTO Modifiers (ModifierId, ModifierType, SubjectRequirementSetId)
	SELECT Id, 'MODIFIER_PLAYER_DISTRICTS_ADJUST_GREAT_PERSON_POINTS', 'CQ_REQSET_DISTRICT_IS_' || BaseDistrictType FROM CQ_DistrictGreatPeople;
INSERT OR IGNORE INTO ModifierArguments (ModifierId, Name, Value)
	SELECT Id, 'GreatPersonClassType', GreatPersonClassType FROM CQ_DistrictGreatPeople;
INSERT OR IGNORE INTO ModifierArguments (ModifierId, Name, Value)
	SELECT Id, 'Amount', Amount FROM CQ_DistrictGreatPeople;
INSERT OR IGNORE INTO CQ_DistrictBonuses (ModifierId, TraitType)
	SELECT Id, TraitType FROM CQ_DistrictGreatPeople;
INSERT OR IGNORE INTO CQ_DistrictBonusInfo (ModifierId, DistrictType, Kind, Amount, Target)
	SELECT g.Id, u.DistrictType, 'GREAT_PERSON', g.Amount, g.GreatPersonClassType
	FROM CQ_DistrictGreatPeople g JOIN CQ_UniqueDistricts u
		ON u.TraitType = g.TraitType AND g.Id = 'CQ_DB_' || u.DistrictType || '_' || g.GreatPersonClassType;

-- 4. 住房、宜居度：取差值
INSERT OR IGNORE INTO Modifiers (ModifierId, ModifierType, SubjectRequirementSetId)
	SELECT 'CQ_DB_' || u.DistrictType || '_HOUSING', 'MODIFIER_PLAYER_DISTRICTS_ADJUST_HOUSING', 'CQ_REQSET_DISTRICT_IS_' || u.BaseDistrictType
	FROM CQ_UniqueDistricts u JOIN Districts du ON du.DistrictType = u.DistrictType JOIN Districts db ON db.DistrictType = u.BaseDistrictType
	WHERE du.Housing <> db.Housing;
INSERT OR IGNORE INTO ModifierArguments (ModifierId, Name, Value)
	SELECT 'CQ_DB_' || u.DistrictType || '_HOUSING', 'Amount', du.Housing - db.Housing
	FROM CQ_UniqueDistricts u JOIN Districts du ON du.DistrictType = u.DistrictType JOIN Districts db ON db.DistrictType = u.BaseDistrictType
	WHERE du.Housing <> db.Housing;

INSERT OR IGNORE INTO Modifiers (ModifierId, ModifierType, SubjectRequirementSetId)
	SELECT 'CQ_DB_' || u.DistrictType || '_AMENITY', 'MODIFIER_PLAYER_DISTRICTS_ADJUST_DISTRICT_AMENITY', 'CQ_REQSET_DISTRICT_IS_' || u.BaseDistrictType
	FROM CQ_UniqueDistricts u JOIN Districts du ON du.DistrictType = u.DistrictType JOIN Districts db ON db.DistrictType = u.BaseDistrictType
	WHERE du.Entertainment <> db.Entertainment;
INSERT OR IGNORE INTO ModifierArguments (ModifierId, Name, Value)
	SELECT 'CQ_DB_' || u.DistrictType || '_AMENITY', 'Amount', du.Entertainment - db.Entertainment
	FROM CQ_UniqueDistricts u JOIN Districts du ON du.DistrictType = u.DistrictType JOIN Districts db ON db.DistrictType = u.BaseDistrictType
	WHERE du.Entertainment <> db.Entertainment;

-- 5. 造价：U 比 D 便宜时，建造 D 的生产力按比例提高（造价减半 = +100%）
INSERT OR IGNORE INTO Modifiers (ModifierId, ModifierType)
	SELECT 'CQ_DB_' || u.DistrictType || '_COST', 'MODIFIER_PLAYER_CITIES_ADJUST_DISTRICT_PRODUCTION'
	FROM CQ_UniqueDistricts u JOIN Districts du ON du.DistrictType = u.DistrictType JOIN Districts db ON db.DistrictType = u.BaseDistrictType
	WHERE du.Cost > 0 AND du.Cost < db.Cost;
INSERT OR IGNORE INTO ModifierArguments (ModifierId, Name, Value)
	SELECT 'CQ_DB_' || u.DistrictType || '_COST', 'DistrictType', u.BaseDistrictType
	FROM CQ_UniqueDistricts u JOIN Districts du ON du.DistrictType = u.DistrictType JOIN Districts db ON db.DistrictType = u.BaseDistrictType
	WHERE du.Cost > 0 AND du.Cost < db.Cost;
INSERT OR IGNORE INTO ModifierArguments (ModifierId, Name, Value)
	SELECT 'CQ_DB_' || u.DistrictType || '_COST', 'Amount', db.Cost * 100 / du.Cost - 100
	FROM CQ_UniqueDistricts u JOIN Districts du ON du.DistrictType = u.DistrictType JOIN Districts db ON db.DistrictType = u.BaseDistrictType
	WHERE du.Cost > 0 AND du.Cost < db.Cost;

INSERT OR IGNORE INTO CQ_DistrictBonuses (ModifierId, TraitType)
	SELECT m.ModifierId, u.TraitType FROM CQ_UniqueDistricts u JOIN Modifiers m
		ON m.ModifierId IN ('CQ_DB_' || u.DistrictType || '_HOUSING', 'CQ_DB_' || u.DistrictType || '_AMENITY', 'CQ_DB_' || u.DistrictType || '_COST');

INSERT OR IGNORE INTO CQ_DistrictBonusInfo (ModifierId, DistrictType, Kind, Amount)
	SELECT m.ModifierId, u.DistrictType,
		CASE m.ModifierId
			WHEN 'CQ_DB_' || u.DistrictType || '_HOUSING' THEN 'HOUSING'
			WHEN 'CQ_DB_' || u.DistrictType || '_AMENITY' THEN 'AMENITY'
			ELSE 'COST' END,
		CAST(a.Value AS INTEGER)
	FROM CQ_UniqueDistricts u
	JOIN Modifiers m ON m.ModifierId IN ('CQ_DB_' || u.DistrictType || '_HOUSING', 'CQ_DB_' || u.DistrictType || '_AMENITY', 'CQ_DB_' || u.DistrictType || '_COST')
	JOIN ModifierArguments a ON a.ModifierId = m.ModifierId AND a.Name = 'Amount';

INSERT OR IGNORE INTO CQ_ActivationModifiers (TraitType, ModifierId)
	SELECT TraitType, ModifierId FROM CQ_DistrictBonuses;

-- -----------------------------------------------------------------------------
-- 把建筑、改良的解锁修改器挂到原特性上：原文明照常拥有，激活该特性的征服者也一并获得
-- （单位的解锁修改器不挂在这里，见上文 CQ_ActivationModifiers）
-- -----------------------------------------------------------------------------
INSERT OR IGNORE INTO TraitModifiers (TraitType, ModifierId)
	SELECT TraitType, 'CQ_VALID_' || ItemType
	FROM CQ_TraitItems WHERE ItemKind IN ('IMPROVEMENT', 'BUILDING');
