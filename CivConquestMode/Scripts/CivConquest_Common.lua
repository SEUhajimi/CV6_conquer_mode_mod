-- =============================================================================
--	文明征服模式 - UI 与 Gameplay 共用的数据/规则
-- =============================================================================

CQ = CQ or {};

CQ.PROP_UNLOCK		= "CQ_UNLOCK_";		-- 玩家属性：CQ_UNLOCK_<LeaderType> = 1  已占领该领袖的原始首都
CQ.PROP_TRAIT		= "CQ_TRAIT_";		-- 玩家属性：CQ_TRAIT_<TraitType>  = 1  已激活该特性
CQ.SCRIPT_ACTIVATE	= "CQ_ActivateTrait";	-- EXECUTE_SCRIPT 的 GameEvent 名
CQ.SCRIPT_RECORD_CAPITAL = "CQ_RecordCapital";	-- UI 上报原始首都位置

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
function CQ.GetAllUniqueDistricts()
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
