-- =============================================================================
--	文明征服模式 - Gameplay 脚本
--	* 记录“占领某领袖原始首都”的解锁状态
--	* 处理 UI 发来的激活请求（EXECUTE_SCRIPT），把特性的修改器挂到玩家身上
--	* 把旧版本转换出来的特色区域还原为基础区域（特色区域的效果改为加到基础区域上）
-- =============================================================================
include("CivConquest_Common");

local m_TraitModifiers		:table = {};	-- TraitType -> { ModifierId, ... }（原特性的 TraitModifiers）
local m_ActivationModifiers	:table = {};	-- TraitType -> { ModifierId, ... }（只在激活时挂的，见 CQ_ActivationModifiers）

local PROP_ACTIVATION_MOD = "CQ_AM_";	-- 玩家属性：CQ_AM_<ModifierId> = 1  已挂上该激活修改器

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
--	用 WorldBuilder 在城市中放置一座已完成的建筑。plotIndex 为建筑所在区域的格子
--	（城中心建筑传城中心格子）。返回是否放置成功，以及失败时的说明（写日志用）。
-- ===========================================================================
local function PlaceBuilding(pCity:table, buildingType:string, plotIndex:number)
	local info = GameInfo.Buildings[buildingType];
	if info == nil then return false, "unknown building"; end
	local ok, status, message = pcall(function()
		return WorldBuilder.CityManager():CreateBuilding(pCity, buildingType, 100, plotIndex);
	end);
	if pCity:GetBuildings():HasBuilding(info.Index) then return true, nil; end
	if not ok then return false, tostring(status); end
	-- 失败时引擎返回结果表（NeededDistrict、AlreadyExists 等），按键排序后写出
	if type(message) == "table" then
		local keys = {};
		for k, _ in pairs(message) do table.insert(keys, tostring(k)); end
		table.sort(keys);
		local parts = {};
		for _, k in ipairs(keys) do table.insert(parts, k .. "=" .. tostring(message[k])); end
		message = "{" .. table.concat(parts, ", ") .. "}";
	end
	return false, tostring(status) .. " " .. tostring(message);
end

-- ===========================================================================
local function IsAIAutoActivate()
	local value = GameConfiguration.GetValue("GAMEOPTION_CIV_CONQUEST_AI_AUTO");
	return value == nil or value == true or value == 1;
end

-- ===========================================================================
--	特色区域：激活者不建造特色区域，其效果以修改器的形式加到基础区域上（见 SQL 的 CQ_DistrictBonuses）。
--	旧版本会把激活者的基础区域转换为特色区域，但引擎不把转换来的特色区域当成基础区域，
--	里面造不了任何基础区域的建筑。这里在回合开始时把这些特色区域还原为基础区域，并保留其中的建筑。
-- ===========================================================================
--	已激活（非原生）的特色区域：{ {Unique = Index, Base = Index}, ... }，按特色区域 Index 排序
local function GetActivatedUniqueDistricts(playerID:number)
	local list = {};
	for _, info in ipairs(CQ.GetAllUniqueDistricts()) do
		if CQ.IsTraitActivated(playerID, info.TraitType) and not CQ.HasTraitNatively(playerID, info.TraitType) then
			local base = GameInfo.Districts[info.Replaces];
			local unique = GameInfo.Districts[info.Type];
			if base ~= nil and unique ~= nil then
				table.insert(list, { Unique = unique.Index, Base = base.Index });
			end
		end
	end
	table.sort(list, function(a, b) return a.Unique < b.Unique; end);
	return list;
end

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

--	把城市中的特色区域还原为基础区域，并放回其中的基础区域建筑
local function RevertDistrict(pCity:table, district:table, eUnique:number, eBase:number)
	local baseType = GameInfo.Districts[eBase].DistrictType;
	local uniqueType = GameInfo.Districts[eUnique].DistrictType;
	local plotIndex = Map.GetPlotIndex(district.X, district.Y);

	-- 先记录区域中的建筑；若无法读取则放弃，避免丢失建筑
	local buildings = {};
	local scanned, scanErr = pcall(function()
		local pBuildings = pCity:GetBuildings();
		for row in GameInfo.Buildings() do
			if not row.IsWonder and (row.PrereqDistrict == baseType or row.PrereqDistrict == uniqueType)
				and pBuildings:HasBuilding(row.Index) then
				table.insert(buildings, row.BuildingType);
			end
		end
	end);
	if not scanned then
		Log("Skip reverting", uniqueType, "- cannot read buildings:", scanErr);
		return;
	end

	local pManager = WorldBuilder.CityManager();
	local removed, removeErr = pcall(function() pManager:RemoveDistrict(district.Object); end);
	if not removed then
		Log("Could not remove", uniqueType, "in", pCity:GetName(), removeErr);
		return;
	end
	pcall(function() pManager:CreateDistrict(pCity, eBase, 100, plotIndex); end);
	if not pCity:GetDistricts():HasDistrict(eBase, true) then
		-- 基础区域建不起来：放回特色区域，至少不丢区域
		pcall(function() pManager:CreateDistrict(pCity, eUnique, 100, plotIndex); end);
		Log("Could not revert", uniqueType, "in", pCity:GetName(), "- kept it");
	end
	for _, buildingType in ipairs(buildings) do
		local placed, err = PlaceBuilding(pCity, buildingType, plotIndex);
		if not placed then Log("Could not restore", buildingType, "in", pCity:GetName(), err); end
	end
	Log("Reverted", uniqueType, "->", baseType, "in", pCity:GetName());
end

local function RevertConvertedDistricts(playerID:number)
	local pPlayer = Players[playerID];
	if pPlayer == nil or not pPlayer:IsMajor() then return; end
	local list = GetActivatedUniqueDistricts(playerID);
	if #list == 0 then return; end
	for _, pCity in pPlayer:GetCities():Members() do
		local pCityDistricts = pCity:GetDistricts();
		for _, entry in ipairs(list) do
			local district = FindCompletedDistrict(pCityDistricts, entry.Unique);
			if district ~= nil then
				RevertDistrict(pCity, district, entry.Unique, entry.Base);
			end
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
	local conflict = CQ.GetTraitConflict(playerID, traitType);
	if conflict ~= nil then
		Log("Rejected", traitType, "for player", playerID, "- already has", conflict.Type);
		return false;
	end

	for _, modifierId in ipairs(m_TraitModifiers[traitType] or {}) do
		pPlayer:AttachModifierByID(modifierId);
	end
	for _, modifierId in ipairs(m_ActivationModifiers[traitType] or {}) do
		pPlayer:AttachModifierByID(modifierId);
		pPlayer:SetProperty(PROP_ACTIVATION_MOD .. modifierId, 1);
	end
	pPlayer:SetProperty(CQ.PROP_TRAIT .. traitType, 1);
	Log("Player", playerID, "activated", traitType);
	return true;
end

-- ===========================================================================
--	补挂激活修改器：mod 更新后新增的激活修改器（如特色区域加到基础区域上的效果），
--	对更新前就已激活的特性补挂一次。在回合开始时调用。
--	更早版本激活时，单位解锁修改器是随 TraitModifiers 挂上的，没有记录属性，这里会再挂一次；
--	同一解锁效果重复挂载没有影响。
-- ===========================================================================
local function AttachMissingActivationModifiers(playerID:number)
	local pPlayer = Players[playerID];
	if pPlayer == nil or not pPlayer:IsMajor() or GameInfo.CQ_Traits == nil then return; end
	for row in GameInfo.CQ_Traits() do		-- 数据库顺序，各电脑一致
		local traitType = row.TraitType;
		if CQ.IsTraitActivated(playerID, traitType) and not CQ.HasTraitNatively(playerID, traitType) then
			for _, modifierId in ipairs(m_ActivationModifiers[traitType] or {}) do
				if pPlayer:GetProperty(PROP_ACTIVATION_MOD .. modifierId) ~= 1 then
					pPlayer:AttachModifierByID(modifierId);
					pPlayer:SetProperty(PROP_ACTIVATION_MOD .. modifierId, 1);
					Log("Player", playerID, "attached missing", modifierId);
				end
			end
		end
	end
end

-- ===========================================================================
local function ActivateLeader(playerID:number, leaderType:string, onlyTrait:string)
	if not CQ.IsLeaderUnlocked(playerID, leaderType) then
		Log("Rejected activation, leader not unlocked:", playerID, leaderType);
		return;
	end
	for _, entry in ipairs(CQ.GetLeaderTraitEntries(leaderType)) do
		if onlyTrait == nil or onlyTrait == "" or onlyTrait == entry.TraitType then
			ActivateTrait(playerID, entry.TraitType);
		end
	end
end

-- ===========================================================================
--	UI 请求：UI.RequestPlayerOperation(..., EXECUTE_SCRIPT, {OnStart="CQ_ActivateTrait", ...})
-- ===========================================================================
--	请求来自网络，参数先校验类型，避免脚本报错中断处理
local function IsValidRequester(playerID:number)
	local pPlayer = Players[playerID];
	return pPlayer ~= nil and pPlayer:IsMajor() and pPlayer:IsAlive();
end

local function OnActivateRequest(playerID:number, params:table)
	if not IsValidRequester(playerID) or params == nil then return; end
	if type(params.LeaderType) ~= "string" or GameInfo.Leaders[params.LeaderType] == nil then return; end
	local traitType = params.TraitType;
	if traitType ~= nil and type(traitType) ~= "string" then return; end
	ActivateLeader(playerID, params.LeaderType, traitType);
end

-- ===========================================================================
--	UI 请求：上报本机数据库指纹（见 CQ.GetFingerprint）
--	指纹作为操作参数同步到所有电脑，各电脑写入的值相同，不会造成不同步。
--	比较由各电脑的 UI 完成；序号用来区分本次进入游戏后的上报和存档里留下的旧值。
-- ===========================================================================
local function OnReportFingerprint(playerID:number, params:table)
	local pPlayer = Players[playerID];
	if pPlayer == nil or params == nil or type(params.Fingerprint) ~= "number" then return; end
	local seq = (Game:GetProperty(CQ.PROP_FINGERPRINT_SEQ) or 0) + 1;
	Game:SetProperty(CQ.PROP_FINGERPRINT_SEQ, seq);
	pPlayer:SetProperty(CQ.PROP_FINGERPRINT_SEQ, seq);
	pPlayer:SetProperty(CQ.PROP_FINGERPRINT, params.Fingerprint);
	Log("Player", playerID, "reported fingerprint", CQ.FormatFingerprint(params.Fingerprint));
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
	if Players[playerID] == nil or params == nil then return; end
	if type(params.OwnerID) ~= "number" or type(params.PlotIndex) ~= "number" then return; end
	local pOwner = Players[params.OwnerID];
	if pOwner == nil or not pOwner:IsMajor() then return; end
	local pPlot = Map.GetPlotByIndex(params.PlotIndex);
	if pPlot == nil then return; end
	local pCity = CityManager.GetCityAt(pPlot:GetX(), pPlot:GetY());
	SetOriginalCapital(params.OwnerID, pCity);
end

local PROP_AUTO_PENDING = "CQ_AUTO_";	-- 玩家属性：CQ_AUTO_<LeaderType> = 1  AI 已解锁、待自动激活

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
						-- 不在这里激活，留到该 AI 的回合开始（见 AutoActivateForAI）
						pPlayer:SetProperty(PROP_AUTO_PENDING .. leaderType, 1);
					end
				end
			end
		end
	end
end

-- ===========================================================================
--	AI 自动激活：占城时只记下待激活标记，到该 AI 的回合开始再统一激活。
--	不在 CityConquered 里激活：占城回调发生在城市易手的处理过程中，
--	此时给玩家挂大量修改器、用 WorldBuilder 重建区域（被占的城市本身也会被转换）风险大。
--	标记只在 AI 占城时设置，因此人类玩家掉线由 AI 接管时不会被自动激活。
-- ===========================================================================
local function AutoActivateForAI(playerID:number)
	local pPlayer = Players[playerID];
	if pPlayer == nil or not pPlayer:IsMajor() then return; end
	for _, leaderType in ipairs(CQ.GetAllLeaders()) do		-- 数据库顺序，各电脑一致
		if pPlayer:GetProperty(PROP_AUTO_PENDING .. leaderType) == 1 then
			pPlayer:SetProperty(PROP_AUTO_PENDING .. leaderType, 0);
			if not pPlayer:IsHuman() then
				ActivateLeader(playerID, leaderType, nil);
			end
		end
	end
end

-- ===========================================================================
local function OnCityConquered(capturerID:number, ownerID:number, cityID:number, x:number, y:number)
	ScanUnlocks(capturerID);
end

--	联机排查用：把该玩家的本模式状态写进 Lua.log。
--	不同步时对比两台电脑同一回合的这一行，不一样就说明本模式的状态分叉了。
local function LogSyncState(playerID:number)
	local pPlayer = Players[playerID];
	if pPlayer == nil or not pPlayer:IsMajor() then return; end
	local unlocks, traits = {}, {};
	for _, leaderType in ipairs(CQ.GetAllLeaders()) do
		if pPlayer:GetProperty(CQ.PROP_UNLOCK .. leaderType) == 1 then table.insert(unlocks, leaderType); end
	end
	if GameInfo.CQ_Traits ~= nil then
		for row in GameInfo.CQ_Traits() do
			if pPlayer:GetProperty(CQ.PROP_TRAIT .. row.TraitType) == 1 then table.insert(traits, row.TraitType); end
		end
	end
	local fp = pPlayer:GetProperty(CQ.PROP_FINGERPRINT);
	if #unlocks == 0 and #traits == 0 and fp == nil then return; end
	table.sort(unlocks);
	table.sort(traits);
	Log("Sync turn", Game.GetCurrentGameTurn(), "player", playerID,
		"unlocks=" .. table.concat(unlocks, ","), "traits=" .. table.concat(traits, ","),
		"fp=" .. (fp ~= nil and CQ.FormatFingerprint(fp) or "-"));
end

local function OnPlayerTurnStarted(playerID:number)
	RecordOriginalCapitals();
	ScanUnlocks(playerID);
	AutoActivateForAI(playerID);
	AttachMissingActivationModifiers(playerID);
	RevertConvertedDistricts(playerID);
	LogSyncState(playerID);
end

-- ===========================================================================
local function Initialize()
	for row in GameInfo.TraitModifiers() do
		m_TraitModifiers[row.TraitType] = m_TraitModifiers[row.TraitType] or {};
		table.insert(m_TraitModifiers[row.TraitType], row.ModifierId);
	end
	-- 单位解锁、特色区域加到基础区域上的效果不在原特性的 TraitModifiers 里（原文明不需要；
	-- 单位解锁还会让原文明重新能造被取代的基础单位），激活时额外挂上。数据库顺序固定，各客户端一致。
	if GameInfo.CQ_ActivationModifiers ~= nil then
		for row in GameInfo.CQ_ActivationModifiers() do
			m_ActivationModifiers[row.TraitType] = m_ActivationModifiers[row.TraitType] or {};
			table.insert(m_ActivationModifiers[row.TraitType], row.ModifierId);
		end
	end

	GameEvents[CQ.SCRIPT_ACTIVATE].Add(OnActivateRequest);
	GameEvents[CQ.SCRIPT_RECORD_CAPITAL].Add(OnRecordCapitalRequest);
	GameEvents[CQ.SCRIPT_REPORT_FINGERPRINT].Add(OnReportFingerprint);

	-- 只用 GameEvents 修改游戏状态：它在游戏逻辑中按固定顺序触发，各客户端一致。
	-- 不要在 Events.*（如 PlayerTurnActivated）里改状态：Events 由各客户端各自派发，时机不同，联机会不同步。
	GameEvents.CityConquered.Add(OnCityConquered);
	GameEvents.PlayerTurnStarted.Add(OnPlayerTurnStarted);

	-- 这里（脚本加载时）不要改游戏状态：联机重新同步时只有被同步的客户端会重新加载脚本，
	-- 在这里补扫解锁、挂修改器会只发生在那一台电脑上，导致再次不同步。
	-- 读档后的补扫交给各玩家回合开始时的 OnPlayerTurnStarted。
	Log("Initialized");
end
Initialize();
