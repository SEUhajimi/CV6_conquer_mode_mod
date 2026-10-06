-- =============================================================================
--	文明征服模式 - Gameplay 脚本
--	* 记录“占领某领袖原始首都”的解锁状态
--	* 处理 UI 发来的激活请求（EXECUTE_SCRIPT），把特性的修改器挂到玩家身上
--	* 把已激活特色区域对应的基础区域转换为特色区域
-- =============================================================================
include("CivConquest_Common");

local m_TraitModifiers	:table = {};	-- TraitType -> { ModifierId, ... }

-- ===========================================================================
-- 游戏内的 print 只接受字符串参数，这里统一 tostring 后拼接
local function Log(...)
	local parts = { "[CivConquest]" };
	for i = 1, select("#", ...) do
		table.insert(parts, tostring(select(i, ...)));
	end
	print(table.concat(parts, " "));
end

-- ===========================================================================
local function IsAIAutoActivate()
	local value = GameConfiguration.GetValue("GAMEOPTION_CIV_CONQUEST_AI_AUTO");
	return value == nil or value == true or value == 1;
end

-- ===========================================================================
--	已激活（非原生）的特色区域：基础区域 Index -> 特色区域 Index
-- ===========================================================================
local function GetDistrictReplacements(playerID:number)
	local map = {};
	for _, info in ipairs(CQ.GetAllUniqueDistricts()) do
		if CQ.IsTraitActivated(playerID, info.TraitType) and not CQ.HasTraitNatively(playerID, info.TraitType) then
			local base = GameInfo.Districts[info.Replaces];
			local unique = GameInfo.Districts[info.Type];
			if base ~= nil and unique ~= nil and map[base.Index] == nil then
				map[base.Index] = unique.Index;
			end
		end
	end
	return map;
end

-- ===========================================================================
--	特色区域自身的放置限制（如书院/卫城只能在丘陵、蒙巴扎需要树林/雨林）
--	不满足时不转换，保留基础区域
-- ===========================================================================
local PROP_NO_CONVERT = "CQ_NO_CONVERT";	-- 地块属性：该地块的区域不再尝试转换

local m_DistrictTerrains	:table = {};	-- DistrictType -> { [TerrainIndex] = true }
local m_DistrictFeatures	:table = {};	-- DistrictType -> { [FeatureIndex] = true }

local function BuildPlacementCache()
	if GameInfo.District_ValidTerrains ~= nil then
		for row in GameInfo.District_ValidTerrains() do
			local terrain = GameInfo.Terrains[row.TerrainType];
			if terrain ~= nil then
				m_DistrictTerrains[row.DistrictType] = m_DistrictTerrains[row.DistrictType] or {};
				m_DistrictTerrains[row.DistrictType][terrain.Index] = true;
			end
		end
	end
	if GameInfo.District_RequiredFeatures ~= nil then
		for row in GameInfo.District_RequiredFeatures() do
			local feature = GameInfo.Features[row.FeatureType];
			if feature ~= nil then
				m_DistrictFeatures[row.DistrictType] = m_DistrictFeatures[row.DistrictType] or {};
				m_DistrictFeatures[row.DistrictType][feature.Index] = true;
			end
		end
	end
end

local function CanHostDistrict(districtType:string, x:number, y:number)
	local pPlot = Map.GetPlot(x, y);
	if pPlot == nil then return false; end
	local terrains = m_DistrictTerrains[districtType];
	if terrains ~= nil and not terrains[pPlot:GetTerrainType()] then return false; end
	local features = m_DistrictFeatures[districtType];
	if features ~= nil and not features[pPlot:GetFeatureType()] then return false; end
	return true;
end

local function IsNoConvert(x:number, y:number)
	local pPlot = Map.GetPlot(x, y);
	return pPlot ~= nil and pPlot:GetProperty(PROP_NO_CONVERT) == 1;
end

local function MarkNoConvert(x:number, y:number)
	local pPlot = Map.GetPlot(x, y);
	if pPlot ~= nil then pPlot:SetProperty(PROP_NO_CONVERT, 1); end
end

-- ===========================================================================
--	把城市中一个已建成的基础区域替换为特色区域，并保留其中的建筑
-- ===========================================================================
--	返回城市中已建成的某类区域：{ Object, X, Y }，没有则返回 nil
--	（Gameplay 端的城市区域对象没有 Members()，只能按类型查询）
local function FindCompletedDistrict(pCityDistricts:table, eDistrict:number)
	if pCityDistricts == nil then return nil; end
	if not pCityDistricts:HasDistrict(eDistrict, true) then return nil; end	-- true = 只算已建成

	local x, y = pCityDistricts:GetDistrictLocation(eDistrict);
	if x == nil or y == nil then return nil; end

	local pDistrict = nil;
	pcall(function() pDistrict = pCityDistricts:GetDistrict(eDistrict); end);
	if pDistrict == nil then
		pcall(function() pDistrict = CityManager.GetDistrictAt(Map.GetPlot(x, y)); end);
	end
	if pDistrict == nil then
		Log("Cannot get district object", GameInfo.Districts[eDistrict].DistrictType, "at", x, y);
		return nil;
	end
	return { Object = pDistrict, X = x, Y = y };
end

local function ConvertDistrict(pCity:table, district:table, eBase:number, eUnique:number)
	local baseInfo = GameInfo.Districts[eBase];
	if baseInfo == nil then return; end
	local pDistrict = district.Object;
	local plotIndex = Map.GetPlotIndex(district.X, district.Y);

	-- 先记录区域中的建筑；若无法读取则放弃转换，避免丢失建筑
	local buildings = {};
	local scanned, scanErr = pcall(function()
		local pBuildings = pCity:GetBuildings();
		for row in GameInfo.Buildings() do
			if not row.IsWonder and row.PrereqDistrict == baseInfo.DistrictType and pBuildings:HasBuilding(row.Index) then
				table.insert(buildings, row.BuildingType);
			end
		end
	end);
	if not scanned then
		Log("Skip conversion, cannot read buildings:", scanErr);
		return;
	end

	local uniqueType = GameInfo.Districts[eUnique].DistrictType;
	local pManager = WorldBuilder.CityManager();

	local function RestoreBuildings()
		for _, buildingType in ipairs(buildings) do
			pcall(function() pManager:CreateBuilding(pCity, buildingType, 100, plotIndex); end);
		end
	end

	local removed, removeErr = pcall(function() pManager:RemoveDistrict(pDistrict); end);
	if not removed then
		Log("District conversion failed (remove):", removeErr);
		return;
	end

	pcall(function() pManager:CreateDistrict(pCity, eUnique, 100, plotIndex); end);
	local created = false;
	pcall(function() created = pCity:GetDistricts():HasDistrict(eUnique, true); end);

	if created then
		RestoreBuildings();
		Log("Converted", baseInfo.DistrictType, "->", uniqueType, "in", pCity:GetName());
	else
		-- 特色区域没能建立：原样恢复基础区域与建筑，并标记该地块不再尝试
		pcall(function() pManager:CreateDistrict(pCity, eBase, 100, plotIndex); end);
		RestoreBuildings();
		MarkNoConvert(district.X, district.Y);
		Log("Could not create", uniqueType, "in", pCity:GetName(), "- restored", baseInfo.DistrictType);
	end
end

-- ===========================================================================
local function ConvertDistrictsForPlayer(playerID:number)
	local pPlayer = Players[playerID];
	if pPlayer == nil then return; end
	local map = GetDistrictReplacements(playerID);
	if next(map) == nil then return; end

	-- Gameplay 端的城市区域对象没有 Members()，只能按区域类型查询
	for _, pCity in pPlayer:GetCities():Members() do
		local pCityDistricts = pCity:GetDistricts();
		local toConvert = {};
		for eBase, eUnique in pairs(map) do
			local district = FindCompletedDistrict(pCityDistricts, eBase);
			if district ~= nil and not IsNoConvert(district.X, district.Y) then
				local uniqueType = GameInfo.Districts[eUnique].DistrictType;
				if CanHostDistrict(uniqueType, district.X, district.Y) then
					table.insert(toConvert, { District = district, Base = eBase, Unique = eUnique });
				else
					MarkNoConvert(district.X, district.Y);
					Log("Keep", GameInfo.Districts[eBase].DistrictType, "in", pCity:GetName(), "- plot not valid for", uniqueType);
				end
			end
		end
		for _, entry in ipairs(toConvert) do
			ConvertDistrict(pCity, entry.District, entry.Base, entry.Unique);
		end
	end
end

-- ===========================================================================
--	激活一个特性
-- ===========================================================================
local function ActivateTrait(playerID:number, traitType:string)
	local pPlayer = Players[playerID];
	if pPlayer == nil then return false; end
	if CQ.IsTraitOwned(playerID, traitType) then return false; end

	for _, modifierId in ipairs(m_TraitModifiers[traitType] or {}) do
		pPlayer:AttachModifierByID(modifierId);
	end
	pPlayer:SetProperty(CQ.PROP_TRAIT .. traitType, 1);
	Log("Player", playerID, "activated", traitType);
	return true;
end

-- ===========================================================================
local function ActivateLeader(playerID:number, leaderType:string, onlyTrait:string)
	if not CQ.IsLeaderUnlocked(playerID, leaderType) then
		Log("Rejected activation, leader not unlocked:", playerID, leaderType);
		return;
	end
	local anyDistrict = false;
	for _, entry in ipairs(CQ.GetLeaderTraitEntries(leaderType)) do
		if onlyTrait == nil or onlyTrait == "" or onlyTrait == entry.TraitType then
			if ActivateTrait(playerID, entry.TraitType) and entry.Category == "DISTRICT" then
				anyDistrict = true;
			end
		end
	end
	if anyDistrict then
		ConvertDistrictsForPlayer(playerID);
	end
end

-- ===========================================================================
--	UI 请求：UI.RequestPlayerOperation(..., EXECUTE_SCRIPT, {OnStart="CQ_ActivateTrait", ...})
-- ===========================================================================
local function OnActivateRequest(playerID:number, params:table)
	if params == nil or params.LeaderType == nil then return; end
	ActivateLeader(playerID, params.LeaderType, params.TraitType);
end

-- ===========================================================================
local function SendUnlockNotification(playerID:number, leaderType:string, pCity:table)
	pcall(function()
		local leaderName = Locale.Lookup(GameInfo.Leaders[leaderType].Name);
		local title = Locale.Lookup("LOC_CQ_NOTIFICATION_UNLOCK_TITLE");
		local body = Locale.Lookup("LOC_CQ_NOTIFICATION_UNLOCK_BODY", leaderName, pCity:GetName());
		NotificationManager.SendNotification(playerID, NotificationTypes.USER_DEFINED_1, title, body, pCity:GetX(), pCity:GetY());
	end);
end

-- ===========================================================================
--	记录原始首都位置（Gameplay 端的城市对象没有 IsOriginalCapital）
-- ===========================================================================
local function SetOriginalCapital(ownerID:number, pCity:table)
	local key = CQ.PROP_ORIGINAL_CAPITAL .. ownerID;
	if pCity == nil or Game:GetProperty(key) ~= nil then return; end
	if pCity:GetOriginalOwner() ~= ownerID then return; end
	Game:SetProperty(key, Map.GetPlotIndex(pCity:GetX(), pCity:GetY()));
	Log("Original capital of player", ownerID, "is", pCity:GetName());
end

local function FindOriginalCapital(ownerID:number)
	local pOwner = Players[ownerID];
	if pOwner == nil then return nil; end

	-- 1) 引擎接口（若 Gameplay 端有绑定）
	local ok, pCity = pcall(function() return pOwner:GetCities():GetOriginalCapitalCity(); end);
	if ok and pCity ~= nil then return pCity; end

	-- 2) 该玩家从未失去过自己建立的城市 => 当前首都就是原始首都（宫殿不能主动迁移）
	local pCapital = pOwner:GetCities():GetCapitalCity();
	if pCapital == nil or pCapital:GetOriginalOwner() ~= ownerID then return nil; end
	for _, info in ipairs(CQ.GetAllPlayerIDs()) do
		if info ~= ownerID then
			for _, pOther in Players[info]:GetCities():Members() do
				if pOther:GetOriginalOwner() == ownerID then
					return nil;
				end
			end
		end
	end
	return pCapital;
end

local function RecordOriginalCapitals()
	for _, info in ipairs(CQ.GetMajorPlayersInGame()) do
		if Game:GetProperty(CQ.PROP_ORIGINAL_CAPITAL .. info.PlayerID) == nil then
			SetOriginalCapital(info.PlayerID, FindOriginalCapital(info.PlayerID));
		end
	end
end

-- UI 端（有 IsOriginalCapital）上报的原始首都位置，用于补全旧存档
local function OnRecordCapitalRequest(playerID:number, params:table)
	if params == nil or params.OwnerID == nil or params.PlotIndex == nil then return; end
	local pPlot = Map.GetPlotByIndex(params.PlotIndex);
	if pPlot == nil then return; end
	local pCity = CityManager.GetCityAt(pPlot:GetX(), pPlot:GetY());
	SetOriginalCapital(params.OwnerID, pCity);
end

-- ===========================================================================
--	检查某玩家当前持有的原始首都，记录新的解锁
-- ===========================================================================
local function ScanUnlocks(playerID:number)
	local pPlayer = Players[playerID];
	if pPlayer == nil or not pPlayer:IsMajor() then return; end

	for _, pCity in pPlayer:GetCities():Members() do
		if CQ.IsOriginalCapital(pCity) then
			local originalOwner = pCity:GetOriginalOwner();
			local pOriginal = Players[originalOwner];
			if originalOwner ~= playerID and pOriginal ~= nil and pOriginal:IsMajor() then
				local leaderType = CQ.GetPlayerLeaderType(originalOwner);
				if leaderType ~= nil and leaderType ~= CQ.GetPlayerLeaderType(playerID)
					and pPlayer:GetProperty(CQ.PROP_UNLOCK .. leaderType) ~= 1 then

					pPlayer:SetProperty(CQ.PROP_UNLOCK .. leaderType, 1);
					Log("Player", playerID, "unlocked", leaderType, "by holding", pCity:GetName());

					if pPlayer:IsHuman() then
						SendUnlockNotification(playerID, leaderType, pCity);
					elseif IsAIAutoActivate() then
						ActivateLeader(playerID, leaderType, nil);
					end
				end
			end
		end
	end
end

-- ===========================================================================
local function OnCityConquered(capturerID:number, ownerID:number, cityID:number, x:number, y:number)
	ScanUnlocks(capturerID);
end

local function OnPlayerTurnStarted(playerID:number)
	RecordOriginalCapitals();
	ScanUnlocks(playerID);
	ConvertDistrictsForPlayer(playerID);
end

-- ===========================================================================
local function Initialize()
	BuildPlacementCache();
	for row in GameInfo.TraitModifiers() do
		m_TraitModifiers[row.TraitType] = m_TraitModifiers[row.TraitType] or {};
		table.insert(m_TraitModifiers[row.TraitType], row.ModifierId);
	end

	GameEvents[CQ.SCRIPT_ACTIVATE].Add(OnActivateRequest);
	GameEvents[CQ.SCRIPT_RECORD_CAPITAL].Add(OnRecordCapitalRequest);

	-- 只用 GameEvents 修改游戏状态：它在游戏逻辑中按固定顺序触发，各客户端一致。
	-- 不要在 Events.*（如 PlayerTurnActivated）里改状态：Events 由各客户端各自派发，时机不同，联机会不同步。
	GameEvents.CityConquered.Add(OnCityConquered);
	GameEvents.PlayerTurnStarted.Add(OnPlayerTurnStarted);

	-- 读档/开局时补扫一次
	RecordOriginalCapitals();
	for _, info in ipairs(CQ.GetMajorPlayersInGame()) do
		ScanUnlocks(info.PlayerID);
	end
	Log("Initialized");
end
Initialize();
