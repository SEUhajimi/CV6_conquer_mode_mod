-- ===========================================================================
--	时代分速查
--	不替换游戏的时代面板（EraProgressPanel），而是在它打开时把“如何获得时代分”
--	挂到“下个时代需要的分数”下面。所有条目都从数据库的 Moments 表读取，
--	其他 MOD 新增的历史时刻也会自动出现（归入“其他”）。
--	只读取数据、不改动游戏状态，联机安全。
-- ===========================================================================
include("InstanceManager");

local PANEL_PATH	= "/InGame/PartialScreens/EraProgressPanel";
local MIN_INTEREST	= 1;	-- 能给时代分的时刻兴趣等级都 >= 1

-- 分类：按 MomentType 关键字归类，从上到下第一个匹配的生效
local GROUPS = {
	{ Key = "EXPLORE",	Patterns = { "FIND_", "CITY_BUILT_", "CIRCUMNAVIGATED", "GOODY_HUT", "MET_", "ARTIFACT_" } },
	{ Key = "RELIGION",	Patterns = { "PANTHEON", "RELIGION", "BELIEF", "INQUISITION" } },
	{ Key = "MILITARY",	Patterns = { "UNIT_KILLED", "UNIT_HIGH_LEVEL", "BARBARIAN", "FORMATION_", "WAR_", "CITY_TRANSFERRED", "EMERGENCY", "LEVIED", "UNIT_CREATED" } },
	{ Key = "BUILD",	Patterns = { "CITY_SIZE", "DISTRICT_", "BUILDING_", "IMPROVEMENT_", "ROUTE_", "CITY_POWER", "NATIONAL_PARK", "MITIGATED_", "PROJECT_" } },
	{ Key = "SCIENCE",	Patterns = { "TECH_", "CIVIC_", "GOVERNMENT_", "GOVERNOR_", "GREAT_PERSON", "TOURISM" } },
	{ Key = "DIPLO",	Patterns = { "ENVOY", "TRADING_POST", "CORPORATION", "INDUSTRY", "MONOPOLY", "DIPLOMATIC", "SPY_" } },
	{ Key = "OTHER",	Patterns = {} },
};

-- 古典进黄金路线：远古时代按顺序做的几步，Patterns 用来统计这一步本时代已拿的分
local ROUTE_STEPS = {
	{ Key = "SCOUT",	Patterns = { "MOMENT_GOODY_HUT_TRIGGERED", "MOMENT_FIND_NATURAL_WONDER", "MOMENT_PLAYER_MET_" } },
	{ Key = "BARB",		Patterns = { "MOMENT_BARBARIAN_CAMP_DESTROYED" } },
	{ Key = "UNIQUE",	Patterns = { "_FIRST_UNIQUE" } },
	{ Key = "WONDER",	Patterns = { "_ERA_WONDER" } },
	{ Key = "FAITH",	Patterns = { "MOMENT_PANTHEON_FOUNDED", "MOMENT_RELIGION_FOUNDED" } },
	{ Key = "ADJ",		Patterns = { "_HIGH_ADJACENCY_" } },
	{ Key = "MISC",		Patterns = { "MOMENT_CITY_BUILT_", "_IN_ERA_FIRST", "MOMENT_CITY_SIZE_", "MOMENT_GREAT_PERSON_CREATED_", "BECAME_SUZERAIN" } },
};

local m_Guide		= nil;		-- 挂进面板的 GuideInstance
local m_GroupIM		= nil;
local m_ShowAll		= false;	-- false：只显示当前时代还能拿的
local m_Expanded	= {};		-- 分类 Key -> 是否展开（关闭面板后保留）

-- ===========================================================================
local function EraIndex(eraType)
	local row = eraType and GameInfo.Eras[eraType];
	return row and row.Index or nil;
end

local function GroupOf(momentType)
	for _, group in ipairs(GROUPS) do
		for _, pattern in ipairs(group.Patterns) do
			if string.find(momentType, pattern, 1, true) then
				return group.Key;
			end
		end
	end
	return "OTHER";
end

local function IsWorldFirst(momentType)
	return string.find(momentType, "_IN_WORLD", 1, true) ~= nil;
end

-- 每个时代各能拿一次（如“本时代首个科技”）
local function IsOncePerEra(momentType)
	return string.find(momentType, "_IN_ERA_", 1, true) ~= nil;
end

-- 整局只能拿一次：名字带 FIRST 的，以及几个没带 FIRST 但只会发生一次的
local ONCE_PER_GAME = {
	MOMENT_RELIGION_FOUNDED = true,
	MOMENT_PANTHEON_FOUNDED = true,
	MOMENT_PLAYER_MET_ALL_MAJORS = true,
	MOMENT_WORLD_CIRCUMNAVIGATED = true,
	MOMENT_BELIEF_ADDED_MAX_BELIEFS_REACHED = true,
	MOMENT_TRADING_POST_CONSTRUCTED_IN_EVERY_CIV = true,
};
local function IsOncePerGame(momentType)
	if IsOncePerEra(momentType) then return false; end
	return ONCE_PER_GAME[momentType] or string.find(momentType, "_FIRST", 1, true) ~= nil;
end

-- 统计某个玩家获得过的时刻：{ [MomentType] = { Total = n, ThisEra = n } }
local function CollectMoments(playerID, currentEra)
	local result = {};
	local ok, moments = pcall(function()
		return Game.GetHistoryManager():GetAllMomentsData(playerID, MIN_INTEREST);
	end);
	if not ok or moments == nil then return result; end
	for _, data in ipairs(moments) do
		if data.Type then
			local entry = result[data.Type];
			if entry == nil then
				entry = { Total = 0, ThisEra = 0 };
				result[data.Type] = entry;
			end
			entry.Total = entry.Total + 1;
			if data.GameEra == currentEra then
				entry.ThisEra = entry.ThisEra + 1;
			end
		end
	end
	return result;
end

-- 其他主要文明已经拿走的“世界首次”
local function CollectTakenWorldFirsts(localPlayerID, currentEra)
	local taken = {};
	for _, pPlayer in ipairs(PlayerManager.GetWasEverAliveMajors()) do
		local playerID = pPlayer:GetID();
		if playerID ~= localPlayerID then
			for momentType, _ in pairs(CollectMoments(playerID, currentEra)) do
				if IsWorldFirst(momentType) then
					taken[momentType] = true;
				end
			end
		end
	end
	return taken;
end

-- ===========================================================================
--	数据：当前玩家视角下的全部条目，按分类整理
-- ===========================================================================
local function BuildEntries(localPlayerID)
	local currentEra	= Game.GetEras():GetCurrentEra();
	local mine			= CollectMoments(localPlayerID, currentEra);
	local taken			= CollectTakenWorldFirsts(localPlayerID, currentEra);

	local groups = {};
	for _, group in ipairs(GROUPS) do
		groups[group.Key] = {};
	end

	for row in GameInfo.Moments() do
		if row.EraScore ~= nil and row.EraScore > 0 then
			local minEra = EraIndex(row.MinimumGameEra);
			local maxEra = EraIndex(row.MaximumGameEra);
			local entry = {
				Row			= row,
				Score		= row.EraScore,
				WorldFirst	= IsWorldFirst(row.MomentType),
				Mine		= mine[row.MomentType],
				TakenByOther= taken[row.MomentType] == true,
				TooEarly	= minEra ~= nil and currentEra < minEra,
				TooLate		= maxEra ~= nil and currentEra > maxEra,
				MinEra		= row.MinimumGameEra,
				MaxEra		= row.MaximumGameEra,
			};
			entry.OncePerEra = IsOncePerEra(row.MomentType);
			entry.OncePerGame = IsOncePerGame(row.MomentType);
			-- 当前时代还能拿：在时代范围内、世界首次没被别人拿走、一次性的自己还没拿过
			local used = (entry.OncePerGame and entry.Mine ~= nil)
				or (entry.OncePerEra and entry.Mine ~= nil and entry.Mine.ThisEra > 0)
				or (entry.WorldFirst and entry.TakenByOther);
			entry.Available = not entry.TooEarly and not entry.TooLate and not used;
			table.insert(groups[GroupOf(row.MomentType)], entry);
		end
	end

	for _, list in pairs(groups) do
		table.sort(list, function(a, b)
			if a.Available ~= b.Available then return a.Available; end
			if a.Score ~= b.Score then return a.Score > b.Score; end
			return Locale.Lookup(a.Row.Name) < Locale.Lookup(b.Row.Name);
		end);
	end
	return groups;
end

-- ===========================================================================
--	文本
-- ===========================================================================
local function EraName(eraType)
	local row = eraType and GameInfo.Eras[eraType];
	return row and Locale.Lookup(row.Name) or "";
end

local function EntryText(entry)
	local row = entry.Row;
	local color = entry.Available and "[COLOR_Civ6Yellow]" or "[COLOR_Grey]";
	local text = color .. "+" .. entry.Score .. "[ENDCOLOR]  " .. Locale.Lookup(row.Name);
	if entry.WorldFirst then
		text = text .. "  [COLOR_Civ6Yellow]" .. Locale.Lookup("LOC_ESG_TAG_WORLD_FIRST") .. "[ENDCOLOR]";
	end

	-- 状态
	local notes = {};
	if entry.Mine ~= nil then
		if not entry.OncePerEra then
			table.insert(notes, "[COLOR_Green]" .. Locale.Lookup("LOC_ESG_STATE_EARNED", entry.Mine.Total) .. "[ENDCOLOR]");
		elseif entry.Mine.ThisEra > 0 then
			table.insert(notes, "[COLOR_Green]" .. Locale.Lookup("LOC_ESG_STATE_EARNED_THIS_ERA", entry.Mine.ThisEra) .. "[ENDCOLOR]");
		end
	end
	if entry.WorldFirst and entry.TakenByOther and entry.Mine == nil then
		table.insert(notes, "[COLOR_Red]" .. Locale.Lookup("LOC_ESG_STATE_TAKEN") .. "[ENDCOLOR]");
	end
	if entry.TooEarly then
		table.insert(notes, "[COLOR_Grey]" .. Locale.Lookup("LOC_ESG_STATE_FROM_ERA", EraName(entry.MinEra)) .. "[ENDCOLOR]");
	elseif entry.TooLate then
		table.insert(notes, "[COLOR_Grey]" .. Locale.Lookup("LOC_ESG_STATE_EXPIRED", EraName(entry.MaxEra)) .. "[ENDCOLOR]");
	elseif entry.MaxEra ~= nil then
		table.insert(notes, Locale.Lookup("LOC_ESG_STATE_UNTIL_ERA", EraName(entry.MaxEra)));
	end
	if #notes > 0 then
		text = text .. "  " .. table.concat(notes, " ");
	end

	local desc = Locale.Lookup(row.Description);
	if desc ~= nil and desc ~= "" and desc ~= row.Description then
		text = text .. "[NEWLINE][COLOR_Grey]" .. desc .. "[ENDCOLOR]";
	end
	return text;
end

-- 致辞：新时代开始时选择，普通时代下的效果大多是额外的时代分
local function DedicationText(localPlayerID)
	local pEras = Game.GetEras();
	local currentEra = pEras:GetCurrentEra();
	local active = {};
	local ok, list = pcall(function() return pEras:GetPlayerActiveCommemorations(localPlayerID); end);
	if ok and list then
		for _, eType in ipairs(list) do active[eType] = true; end
	end

	local lines, count = {}, 0;
	for row in GameInfo.CommemorationTypes() do
		local minEra = EraIndex(row.MinimumGameEra);
		local maxEra = EraIndex(row.MaximumGameEra);
		if (minEra == nil or currentEra >= minEra) and (maxEra == nil or currentEra <= maxEra) then
			local line = "[COLOR_Civ6Yellow]" .. Locale.Lookup(row.CategoryDescription) .. "[ENDCOLOR]";
			if active[row.Index] or active[row.Hash] then
				line = line .. "  [COLOR_Green]" .. Locale.Lookup("LOC_ESG_STATE_CHOSEN") .. "[ENDCOLOR]";
			end
			if row.NormalAgeBonusDescription then
				line = line .. "[NEWLINE]" .. Locale.Lookup(row.NormalAgeBonusDescription);
			end
			table.insert(lines, line);
			count = count + 1;
		end
	end
	if count == 0 then return nil, 0; end
	return Locale.Lookup("LOC_ESG_DEDICATION_NOTE") .. "[NEWLINE][NEWLINE]" .. table.concat(lines, "[NEWLINE][NEWLINE]"), count;
end

-- 古典进黄金：远古时代显示每一步本时代已拿的基础分，其他时代只当参考
local function RouteText(localPlayerID, isAncient)
	local mine = isAncient and CollectMoments(localPlayerID, Game.GetEras():GetCurrentEra()) or {};
	local lines = { Locale.Lookup(isAncient and "LOC_ESG_ROUTE_INTRO" or "LOC_ESG_ROUTE_INTRO_LATER") };
	local total = 0;
	for i, step in ipairs(ROUTE_STEPS) do
		local earned = 0;
		for momentType, entry in pairs(mine) do
			for _, pattern in ipairs(step.Patterns) do
				if string.find(momentType, pattern, 1, true) then
					local row = GameInfo.Moments[momentType];
					if row and row.EraScore then earned = earned + row.EraScore * entry.ThisEra; end
					break;
				end
			end
		end
		total = total + earned;
		local line = "[COLOR_Civ6Yellow]" .. i .. ". " .. Locale.Lookup("LOC_ESG_ROUTE_" .. step.Key .. "_TITLE") .. "[ENDCOLOR]";
		if isAncient then
			line = line .. "  " .. Locale.Lookup(earned > 0 and "LOC_ESG_ROUTE_EARNED" or "LOC_ESG_ROUTE_NONE", earned);
		end
		table.insert(lines, line .. "[NEWLINE]" .. Locale.Lookup("LOC_ESG_ROUTE_" .. step.Key .. "_BODY"));
	end
	table.insert(lines, Locale.Lookup("LOC_ESG_ROUTE_TIPS"));
	return table.concat(lines, "[NEWLINE][NEWLINE]"), total;
end

local function SummaryText(localPlayerID)
	local pEras = Game.GetEras();
	local score = pEras:GetPlayerCurrentScore(localPlayerID);
	local dark = pEras:GetPlayerDarkAgeThreshold(localPlayerID);
	local golden = pEras:GetPlayerGoldenAgeThreshold(localPlayerID);
	local text;
	if score >= golden then
		text = Locale.Lookup("LOC_ESG_SUMMARY_GOLDEN");
	elseif score >= dark then
		text = Locale.Lookup("LOC_ESG_SUMMARY_NORMAL", golden - score);
	else
		text = Locale.Lookup("LOC_ESG_SUMMARY_DARK", dark - score, golden - score);
	end
	return text .. "[NEWLINE][COLOR_Grey]" .. Locale.Lookup("LOC_ESG_SUMMARY_HINT") .. "[ENDCOLOR]";
end

-- ===========================================================================
--	界面
-- ===========================================================================
local function ResizePanel()
	if m_Guide == nil then return; end
	m_Guide.GroupStack:CalculateSize();
	m_Guide.Root:CalculateSize();
	local thresholdStack = ContextPtr:LookUpControl(PANEL_PATH .. "/ThresholdStack");
	if thresholdStack then
		thresholdStack:CalculateSize();
		local mainStack = thresholdStack:GetParent();
		if mainStack and mainStack.CalculateSize then mainStack:CalculateSize(); end
	end
	local scroll = ContextPtr:LookUpControl(PANEL_PATH .. "/BottomScrollPanel");
	if scroll then scroll:CalculateInternalSize(); end
end

local function AddGroup(key, title, bodyText, countText)
	local inst = m_GroupIM:GetInstance();
	inst.HeaderLabel:SetText(title);
	inst.HeaderCount:SetText(countText);
	inst.Body:SetText(bodyText);
	inst.Body:SetHide(not m_Expanded[key]);
	inst.Header:RegisterCallback(Mouse.eLClick, function()
		m_Expanded[key] = not m_Expanded[key];
		inst.Body:SetHide(not m_Expanded[key]);
		inst.Root:CalculateSize();
		ResizePanel();
	end);
	inst.Header:RegisterCallback(Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
end

local function Refresh()
	if m_Guide == nil then return; end
	local localPlayerID = Game.GetLocalPlayer();
	if localPlayerID == nil or localPlayerID < 0 then return; end

	m_Guide.Summary:SetText(SummaryText(localPlayerID));
	m_Guide.FilterLabel:SetText(Locale.Lookup(m_ShowAll and "LOC_ESG_FILTER_ALL" or "LOC_ESG_FILTER_AVAILABLE"));

	m_GroupIM:ResetInstances();

	-- 古典进黄金放最上面；远古时代默认展开（玩家手动收起后保持收起）
	local ancient = GameInfo.Eras["ERA_ANCIENT"];
	local isAncient = ancient ~= nil and Game.GetEras():GetCurrentEra() == ancient.Index;
	if m_Expanded.ROUTE == nil then m_Expanded.ROUTE = isAncient; end
	local routeText, routeTotal = RouteText(localPlayerID, isAncient);
	AddGroup("ROUTE", Locale.Lookup("LOC_ESG_GROUP_ROUTE"), routeText,
		isAncient and Locale.Lookup("LOC_ESG_ROUTE_COUNT", routeTotal) or Locale.Lookup("LOC_ESG_ROUTE_COUNT_LATER"));

	local groups = BuildEntries(localPlayerID);
	for _, group in ipairs(GROUPS) do
		local list = groups[group.Key];
		local lines, available = {}, 0;
		for _, entry in ipairs(list) do
			if entry.Available then available = available + 1; end
			if m_ShowAll or entry.Available then
				table.insert(lines, EntryText(entry));
			end
		end
		if #lines > 0 then
			AddGroup(group.Key, Locale.Lookup("LOC_ESG_GROUP_" .. group.Key),
				table.concat(lines, "[NEWLINE][NEWLINE]"),
				Locale.Lookup("LOC_ESG_GROUP_COUNT", available, #list));
		end
	end

	local dedication, count = DedicationText(localPlayerID);
	if dedication then
		AddGroup("DEDICATION", Locale.Lookup("LOC_ESG_GROUP_DEDICATION"), dedication, tostring(count));
	end

	ResizePanel();
end

-- 第一次打开时把区块挂进面板（面板 Open() 之后才会移到 PartialScreens 下）
local function EnsureAttached()
	if m_Guide ~= nil then return true; end
	local thresholdStack = ContextPtr:LookUpControl(PANEL_PATH .. "/ThresholdStack");
	if thresholdStack == nil then
		print("[EraScoreGuide] EraProgressPanel not found, guide not attached");
		return false;
	end
	m_Guide = {};
	ContextPtr:BuildInstanceForControl("GuideInstance", m_Guide, thresholdStack);
	m_GroupIM = InstanceManager:new("GroupInstance", "Root", m_Guide.GroupStack);
	m_Guide.FilterButton:RegisterCallback(Mouse.eLClick, function()
		m_ShowAll = not m_ShowAll;
		Refresh();
	end);
	m_Guide.FilterButton:RegisterCallback(Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	print("[EraScoreGuide] Attached to EraProgressPanel");
	return true;
end

local function OnEraPanelOpen()
	if EnsureAttached() then
		Refresh();
	end
end

-- ===========================================================================
function Initialize()
	ContextPtr:SetHide(true);
	LuaEvents.EraProgressPanel_Open.Add(OnEraPanelOpen);
end
Initialize();
