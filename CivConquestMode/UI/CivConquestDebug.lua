-- =============================================================================
--	文明征服模式 - 调试日志（CQ.DEBUG_LOG）
--	单位训练/购买时，把该玩家的市政进度变化写入 Lua.log。
--	放在 UI 环境：GetProgressingCivic / GetCulturalProgress 只在 UI 环境可用。
--	引擎事件在效果结算之后才派发，因此与上一次快照比较即可看到这次获得的文化；
--	快照在回合开始和每次记录后更新，期间若有其他文化来源也会计入差值。只读，不改游戏状态。
--	实测回合开始的快照不含当回合文化产出，所以每回合第一条记录额外给出扣除产出后的净值（net）。
-- =============================================================================

local m_CultureSnapshot	:table = {};	-- PlayerID -> { Civic, Progress, TurnStart }

local function Log(...)
	local parts = { "[CivConquest] Debug:" };
	for i = 1, select("#", ...) do
		table.insert(parts, tostring(select(i, ...)));
	end
	print(table.concat(parts, " "));
end

local function IsMajor(playerID:number)
	local pPlayer = Players[playerID];
	return pPlayer ~= nil and pPlayer:IsMajor();
end

local function GetCultureState(playerID:number)
	local pCulture = Players[playerID]:GetCulture();
	local civic = pCulture:GetProgressingCivic();
	if civic == nil or civic < 0 then
		return { Civic = -1, Progress = 0 };
	end
	return { Civic = civic, Progress = pCulture:GetCulturalProgress(civic) };
end

local function Snapshot(playerID:number)
	if IsMajor(playerID) then
		local state = GetCultureState(playerID);
		state.TurnStart = true;
		m_CultureSnapshot[playerID] = state;
	end
end

local function GetObjectName(objectType)
	for _, tbl in ipairs({ GameInfo.Units, GameInfo.Buildings, GameInfo.Districts, GameInfo.Projects }) do
		local row = tbl[objectType];
		if row ~= nil then
			return row.UnitType or row.BuildingType or row.DistrictType or row.ProjectType;
		end
	end
	return tostring(objectType);
end

local function LogCultureChange(playerID:number, cityID:number, how:string, objectType)
	if not IsMajor(playerID) then return; end

	local before = m_CultureSnapshot[playerID];
	local after = GetCultureState(playerID);
	local delta = "?";
	if before ~= nil then
		if before.Civic == after.Civic then
			local diff = after.Progress - before.Progress;
			delta = string.format("%+.1f", diff);
			if before.TurnStart then
				local yield = Players[playerID]:GetCulture():GetCultureYield();
				delta = delta .. string.format(" (net %+.1f after turn yield %.1f)", diff - yield, yield);
			end
		else
			delta = "?(civic changed)";
		end
	end

	local cityName = "?";
	local pCity = CityManager.GetCity(playerID, cityID);
	if pCity ~= nil then cityName = Locale.Lookup(pCity:GetName()); end

	local civicName = "-";
	if after.Civic >= 0 and GameInfo.Civics[after.Civic] ~= nil then
		civicName = GameInfo.Civics[after.Civic].CivicType;
	end
	Log("turn", Game.GetCurrentGameTurn(), "player", playerID, how, GetObjectName(objectType),
		"in", cityName, "| culture", delta, "|", civicName, string.format("%.1f", after.Progress));
	m_CultureSnapshot[playerID] = after;
end

local function OnCityProductionCompleted(playerID:number, cityID:number, orderType:number, objectType, canceled:boolean)
	if canceled or orderType ~= 0 then return; end		-- 0 = OrderTypes.ORDER_TRAIN
	LogCultureChange(playerID, cityID, "trained", objectType);
end

local function OnCityMadePurchase(playerID:number, cityID:number, x:number, y:number, purchaseType, objectType)
	-- 只关心单位。官方脚本只用到 EventSubTypes.PLOT，UNIT 不一定存在，因此日志里附上原始 purchaseType 以便核对
	if EventSubTypes ~= nil then
		if purchaseType == EventSubTypes.PLOT then return; end
		if EventSubTypes.UNIT ~= nil and purchaseType ~= EventSubTypes.UNIT then return; end
	end
	LogCultureChange(playerID, cityID, "purchased(" .. tostring(purchaseType) .. ")", objectType);
end

-- 调试代码出错只记录，不影响面板其他功能
local function Safe(func)
	return function(...)
		local ok, err = pcall(func, ...);
		if not ok then print("[CivConquest] Debug log error: " .. tostring(err)); end
	end
end

function CQ.InitDebugLog()
	if not CQ.DEBUG_LOG then return; end
	Events.CityProductionCompleted.Add(Safe(OnCityProductionCompleted));
	Events.CityMadePurchase.Add(Safe(OnCityMadePurchase));
	Events.PlayerTurnActivated.Add(Safe(function(playerID, isFirstTime) Snapshot(playerID); end));
	Safe(function()
		for _, playerID in ipairs(PlayerManager.GetAliveMajorIDs()) do
			Snapshot(playerID);
		end
	end)();
end
