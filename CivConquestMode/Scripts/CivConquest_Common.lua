-- =============================================================================
--	文明征服模式 - UI 与 Gameplay 共用的数据/规则
-- =============================================================================

CQ = CQ or {};

CQ.PROP_UNLOCK		= "CQ_UNLOCK_";		-- 玩家属性：CQ_UNLOCK_<LeaderType> = 1  已占领该领袖的原始首都
CQ.PROP_TRAIT		= "CQ_TRAIT_";		-- 玩家属性：CQ_TRAIT_<TraitType>  = 1  已激活该特性
CQ.SCRIPT_ACTIVATE	= "CQ_ActivateTrait";	-- EXECUTE_SCRIPT 的 GameEvent 名
CQ.SCRIPT_RECORD_CAPITAL = "CQ_RecordCapital";	-- UI 上报原始首都位置
CQ.SCRIPT_REPORT_FINGERPRINT = "CQ_ReportFingerprint";	-- UI 上报本机数据库指纹（联机一致性检查）

CQ.PROP_FINGERPRINT		= "CQ_FP";		-- 玩家属性：该玩家电脑上报的指纹
CQ.PROP_FINGERPRINT_SEQ	= "CQ_FP_SEQ";	-- 玩家属性：上报时的序号；Game 属性：全局上报计数

-- 本模式脚本版本，计入指纹。改了 Lua 后加 1：只改 Lua 时数据库不变，靠它发现两边脚本不一致
CQ.VERSION			= 2;

CQ.DEBUG_LOG		= true;				-- 调试日志：单位训练/购买时把文化进度变化写入 Lua.log

CQ.CATEGORY_ORDER = {
	CIV_ABILITY		= 1,
	LEADER_ABILITY	= 2,
	UNIT			= 3,
	BUILDING		= 4,
	DISTRICT		= 5,
	IMPROVEMENT		= 6,
};

local m_bCacheBuilt		:boolean = false;
local m_TraitSource		:table = {};	-- TraitType -> 'CIV' | 'LEADER'
local m_TraitItems		:table = {};	-- TraitType -> { {Kind, Type, Replaces}, ... }
local m_CivTraits		:table = {};	-- CivilizationType -> { TraitType, ... }
local m_LeaderTraits	:table = {};	-- LeaderType -> { TraitType, ... }
local m_LeaderCiv		:table = {};	-- LeaderType -> CivilizationType
local m_AllLeaders		:table = {};	-- { LeaderType, ... }（可游玩的主要领袖）

-- ===========================================================================
local function BuildCache()
	if m_bCacheBuilt then return; end
	m_bCacheBuilt = true;

	if GameInfo.CQ_Traits ~= nil then
		for row in GameInfo.CQ_Traits() do
			m_TraitSource[row.TraitType] = row.SourceKind;
		end
	end

	if GameInfo.CQ_TraitItems ~= nil then
		for row in GameInfo.CQ_TraitItems() do
			local list = m_TraitItems[row.TraitType];
			if list == nil then
				list = {};
				m_TraitItems[row.TraitType] = list;
			end
			table.insert(list, { Kind = row.ItemKind, Type = row.ItemType, Replaces = row.ReplacesType });
		end
	end

	for row in GameInfo.CivilizationTraits() do
		if m_TraitSource[row.TraitType] ~= nil then
			m_CivTraits[row.CivilizationType] = m_CivTraits[row.CivilizationType] or {};
			table.insert(m_CivTraits[row.CivilizationType], row.TraitType);
		end
	end

	for row in GameInfo.LeaderTraits() do
		if m_TraitSource[row.TraitType] ~= nil then
			m_LeaderTraits[row.LeaderType] = m_LeaderTraits[row.LeaderType] or {};
			table.insert(m_LeaderTraits[row.LeaderType], row.TraitType);
		end
	end

	for row in GameInfo.CivilizationLeaders() do
		local civ = GameInfo.Civilizations[row.CivilizationType];
		local leader = GameInfo.Leaders[row.LeaderType];
		if civ ~= nil and leader ~= nil and civ.StartingCivilizationLevelType == "CIVILIZATION_LEVEL_FULL_CIV"
			and m_LeaderCiv[row.LeaderType] == nil then
			m_LeaderCiv[row.LeaderType] = row.CivilizationType;
			table.insert(m_AllLeaders, row.LeaderType);
		end
	end
end

-- ===========================================================================
function CQ.GetCivForLeader(leaderType:string)
	BuildCache();
	return m_LeaderCiv[leaderType];
end

-- ===========================================================================
--	所有可游玩的主要领袖（按名称排序由 UI 负责）
-- ===========================================================================
function CQ.GetAllLeaders()
	BuildCache();
	return m_AllLeaders;
end

-- ===========================================================================
--	某领袖可被激活的全部特性条目，已排序：
--	{ TraitType, Category, Source, Items = { {Kind, Type, Replaces}, ... } }
-- ===========================================================================
function CQ.GetLeaderTraitEntries(leaderType:string)
	BuildCache();
	local entries	:table = {};
	local seen		:table = {};

	local function AddTrait(traitType:string, source:string)
		if seen[traitType] then return; end
		seen[traitType] = true;
		local items = m_TraitItems[traitType] or {};
		local category = (source == "LEADER") and "LEADER_ABILITY" or "CIV_ABILITY";
		if #items > 0 then
			category = items[1].Kind;
		end
		table.insert(entries, { TraitType = traitType, Category = category, Source = source, Items = items });
	end

	local civType = m_LeaderCiv[leaderType];
	if civType ~= nil and m_CivTraits[civType] ~= nil then
		for _, t in ipairs(m_CivTraits[civType]) do AddTrait(t, "CIV"); end
	end
	if m_LeaderTraits[leaderType] ~= nil then
		for _, t in ipairs(m_LeaderTraits[leaderType]) do AddTrait(t, "LEADER"); end
	end

	table.sort(entries, function(a, b)
		local oa = CQ.CATEGORY_ORDER[a.Category] or 99;
		local ob = CQ.CATEGORY_ORDER[b.Category] or 99;
		if oa ~= ob then return oa < ob; end
		return a.TraitType < b.TraitType;
	end);
	return entries;
end

-- ===========================================================================
--	所有“特色区域”条目：{ TraitType, Type, Replaces }
-- ===========================================================================
local m_UniqueDistricts :table = nil;

function CQ.GetAllUniqueDistricts()
	if m_UniqueDistricts ~= nil then return m_UniqueDistricts; end
	BuildCache();
	local list = {};
	for traitType, items in pairs(m_TraitItems) do
		for _, item in ipairs(items) do
			if item.Kind == "DISTRICT" and item.Replaces ~= nil then
				table.insert(list, { TraitType = traitType, Type = item.Type, Replaces = item.Replaces });
			end
		end
	end
	-- pairs 的遍历顺序没有保证；Gameplay 端按此顺序改状态，排序后各客户端一致
	table.sort(list, function(a, b)
		if a.TraitType ~= b.TraitType then return a.TraitType < b.TraitType; end
		return a.Type < b.Type;
	end);
	m_UniqueDistricts = list;	-- 只依赖数据库，算一次即可（每个玩家回合开始都会用到）
	return list;
end

-- ===========================================================================
function CQ.GetPlayerLeaderType(playerID:number)
	local pConfig = PlayerConfigurations[playerID];
	if pConfig == nil then return nil; end
	return pConfig:GetLeaderTypeName();
end

-- ===========================================================================
--	该玩家是否本来就拥有这个特性（自身文明/领袖）
-- ===========================================================================
function CQ.HasTraitNatively(playerID:number, traitType:string)
	BuildCache();
	local pConfig = PlayerConfigurations[playerID];
	if pConfig == nil then return false; end
	local leaderType = pConfig:GetLeaderTypeName();
	local civType = pConfig:GetCivilizationTypeName();
	for _, t in ipairs(m_LeaderTraits[leaderType] or {}) do
		if t == traitType then return true; end
	end
	for _, t in ipairs(m_CivTraits[civType] or {}) do
		if t == traitType then return true; end
	end
	return false;
end

-- ===========================================================================
function CQ.IsTraitActivated(playerID:number, traitType:string)
	local pPlayer = Players[playerID];
	if pPlayer == nil then return false; end
	return pPlayer:GetProperty(CQ.PROP_TRAIT .. traitType) == 1;
end

function CQ.IsTraitOwned(playerID:number, traitType:string)
	return CQ.IsTraitActivated(playerID, traitType) or CQ.HasTraitNatively(playerID, traitType);
end

-- ===========================================================================
--	本局所有存活玩家 ID（含城邦、蛮族，用于遍历所有城市）
-- ===========================================================================
function CQ.GetAllPlayerIDs()
	return PlayerManager.GetAliveIDs();
end

-- ===========================================================================
--	本局所有主要文明玩家：{ {PlayerID, LeaderType}, ... }
-- ===========================================================================
function CQ.GetMajorPlayersInGame()
	local list = {};
	for playerID = 0, 63 do
		local pPlayer = Players[playerID];
		local pConfig = PlayerConfigurations[playerID];
		if pPlayer ~= nil and pConfig ~= nil and pPlayer:IsMajor() then
			local everAlive = true;
			if pPlayer.WasEverAlive ~= nil then everAlive = pPlayer:WasEverAlive(); end
			local leaderType = pConfig:GetLeaderTypeName();
			if everAlive and leaderType ~= nil and GameInfo.Leaders[leaderType] ~= nil then
				table.insert(list, { PlayerID = playerID, LeaderType = leaderType });
			end
		end
	end
	return list;
end

-- ===========================================================================
--	是否为原始首都。
--	UI 端的城市对象有 IsOriginalCapital()，Gameplay 端没有，
--	因此 Gameplay 端使用自己记录在 Game 属性中的原始首都位置（见 RecordOriginalCapitals）。
-- ===========================================================================
CQ.PROP_ORIGINAL_CAPITAL = "CQ_OC_";	-- Game 属性：CQ_OC_<PlayerID> = 原始首都所在地块索引

function CQ.IsOriginalCapital(pCity:table)
	if pCity == nil then return false; end
	if pCity.IsOriginalCapital ~= nil then
		return pCity:IsOriginalCapital();
	end
	local plotIndex = Game:GetProperty(CQ.PROP_ORIGINAL_CAPITAL .. pCity:GetOriginalOwner());
	return plotIndex ~= nil and plotIndex == Map.GetPlotIndex(pCity:GetX(), pCity:GetY());
end

-- ===========================================================================
--	返回该玩家当前占有的、属于 leaderType 的原始首都（若有）
-- ===========================================================================
function CQ.FindHeldOriginalCapital(playerID:number, leaderType:string)
	local pPlayer = Players[playerID];
	if pPlayer == nil then return nil; end
	for _, pCity in pPlayer:GetCities():Members() do
		if CQ.IsOriginalCapital(pCity) then
			local originalOwner = pCity:GetOriginalOwner();
			if originalOwner ~= playerID and CQ.GetPlayerLeaderType(originalOwner) == leaderType then
				local pOriginal = Players[originalOwner];
				if pOriginal ~= nil and pOriginal:IsMajor() then
					return pCity;
				end
			end
		end
	end
	return nil;
end

-- ===========================================================================
--	是否已解锁（曾经占领过该领袖的原始首都）
-- ===========================================================================
function CQ.IsLeaderUnlocked(playerID:number, leaderType:string)
	local pPlayer = Players[playerID];
	if pPlayer == nil or leaderType == nil then return false; end
	if CQ.GetPlayerLeaderType(playerID) == leaderType then return false; end
	if pPlayer:GetProperty(CQ.PROP_UNLOCK .. leaderType) == 1 then return true; end
	return CQ.FindHeldOriginalCapital(playerID, leaderType) ~= nil;
end

-- ===========================================================================
--	联机一致性检查：数据库指纹
--	引擎在联机房间里只核对 mod 的 ID 和版本号，不核对文件内容。两台电脑的 mod 文件不同时
--	（旧版本、重复安装、创意工坊版本不同），数据库就不同，修改器和各表的 Index 会对不上，
--	游戏会反复不同步。这里对整个 Gameplay 数据库算一个指纹，两边不同就说明加载的内容不一样。
--	只在 UI 环境调用（读档时算一次并缓存）；Gameplay 脚本只存储上报的数字。
-- ===========================================================================

-- 取模用小于 2^31 的质数：h * 31 + 255 不超过 2^53，double 运算保持精确，各电脑结果一致
local HASH_MOD :number = 2147483629;

local function HashString(h:number, s:string)
	for i = 1, #s do
		h = (h * 31 + string.byte(s, i)) % HASH_MOD;
	end
	return (h * 31 + 1) % HASH_MOD;	-- 分隔符：避免 "ab"+"c" 与 "a"+"bc" 相同
end

-- 长文本（说明、百科）只取首尾各 48 个字符和长度，控制耗时；ID、数值这类短值完整计入
local LONG_VALUE :number = 96;

local function HashValue(h:number, value)
	local s = tostring(value);
	local n = #s;
	if n > LONG_VALUE then
		s = string.sub(s, 1, 48) .. string.sub(s, -48) .. "#" .. n;
	end
	return HashString(h, s);
end

--	全库版本：用 DB.Query 列出所有表，逐行计入。
--	行按 SELECT 的默认顺序（rowid，即插入顺序）依次计入，行顺序不同也会体现出来；
--	一行内的各列用加法合并，与 pairs 的遍历顺序无关。值为 NULL 的列不出现在行里，两边一致。
--	返回 指纹, 表数, 行数；DB.Query 不可用或查不到表时返回 nil。
local function FingerprintAllTables()
	if DB == nil or DB.Query == nil then return nil; end
	local ok, tables = pcall(DB.Query,
		"SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' ORDER BY name");
	if not ok or tables == nil or #tables == 0 then return nil; end

	local h = HashString(0, "ALL");
	local rowCount = 0;
	for _, t in ipairs(tables) do
		local name = t.name;
		h = HashString(h, name);
		local okRows, rows = pcall(DB.Query, 'SELECT * FROM "' .. name .. '"');
		if okRows and rows ~= nil then
			for _, row in ipairs(rows) do
				local rowHash = 0;
				for column, value in pairs(row) do
					rowHash = (rowHash + HashValue(HashString(0, column), value)) % HASH_MOD;
				end
				h = (h * 31 + rowHash) % HASH_MOD;
			end
			rowCount = rowCount + #rows;
			h = HashString(h, tostring(#rows));
		else
			h = HashString(h, "?");
		end
	end
	return h, #tables, rowCount;
end

--	后备：DB.Query 不可用时，只对与玩法最相关的几张表的关键列计算
local FALLBACK_TABLES :table = {
	{ "Modifiers", "ModifierId", "ModifierType", "RunOnce", "Permanent", "OwnerRequirementSetId", "SubjectRequirementSetId" },
	{ "ModifierArguments", "ModifierId", "Name", "Value" },
	{ "DynamicModifiers", "ModifierType", "CollectionType", "EffectType" },
	{ "Requirements", "RequirementId", "RequirementType", "Inverse" },
	{ "RequirementArguments", "RequirementId", "Name", "Value" },
	{ "RequirementSets", "RequirementSetId", "RequirementSetType" },
	{ "RequirementSetRequirements", "RequirementSetId", "RequirementId" },
	{ "TraitModifiers", "TraitType", "ModifierId" },
	{ "Units", "UnitType", "Cost", "Combat", "RangedCombat", "Bombard", "Range", "BaseMoves", "PrereqTech", "PrereqCivic", "TraitType" },
	{ "Buildings", "BuildingType", "Cost", "PrereqDistrict", "PrereqTech", "PrereqCivic", "TraitType" },
	{ "Districts", "DistrictType", "Cost", "PrereqTech", "PrereqCivic", "TraitType" },
	{ "Improvements", "ImprovementType", "PrereqTech", "PrereqCivic", "TraitType" },
	{ "Resources", "ResourceType", "ResourceClassType", "Frequency" },
	{ "Resource_Harvests", "ResourceType", "YieldType", "Amount", "PrereqTech" },
	{ "Features", "FeatureType", "Removable", "Impassable" },
	{ "Technologies", "TechnologyType", "Cost" },
	{ "Civics", "CivicType", "Cost" },
	{ "GlobalParameters", "Name", "Value" },
};

local function FingerprintFallbackTables()
	local h = HashString(0, "PARTIAL");
	local rowCount = 0;
	for _, spec in ipairs(FALLBACK_TABLES) do
		h = HashString(h, spec[1]);
		local ok, tbl = pcall(function() return GameInfo[spec[1]]; end);
		if ok and tbl ~= nil then
			local count = 0;
			for row in tbl() do
				count = count + 1;
				for i = 2, #spec do
					h = HashValue(h, row[spec[i]]);
				end
			end
			rowCount = rowCount + count;
			h = HashString(h, tostring(count));
		end
	end
	return h, #FALLBACK_TABLES, rowCount;
end

local m_Fingerprint :number = nil;

--	返回数字指纹（属性里存数字比存字符串稳妥）；结果缓存，每次进入游戏只遍历一次数据库
function CQ.GetFingerprint()
	if m_Fingerprint ~= nil then return m_Fingerprint; end
	local clock = (os ~= nil and os.clock ~= nil) and os.clock or nil;
	local startTime = clock and clock();

	local mode = "full";
	local ok, h, tableCount, rowCount = pcall(FingerprintAllTables);
	if not ok or h == nil then
		mode = "partial";
		h, tableCount, rowCount = FingerprintFallbackTables();
	end
	h = HashString(h, tostring(CQ.VERSION));

	-- 指纹要经 EXECUTE_SCRIPT 参数传输，不确定引擎按整数还是单精度浮点序列化，
	-- 压到 2^24 以内，两种情况下都能精确传递
	m_Fingerprint = h % 16777213;

	local elapsed = startTime and string.format(" in %.2fs", clock() - startTime) or "";
	print(string.format("[CivConquest] Fingerprint %06X (%s: %d tables, %d rows%s)",
		m_Fingerprint, mode, tableCount or 0, rowCount or 0, elapsed));
	return m_Fingerprint;
end

function CQ.FormatFingerprint(fp)
	if type(fp) ~= "number" then return tostring(fp); end
	return string.format("%06X", fp);
end
