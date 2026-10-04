-- =============================================================================
--	文明征服模式 - 领袖特性面板
--	* 在左上角 LaunchBar（科技树、市政树……）末尾追加一个入口按钮
--	* 左侧列出本局 / 所有领袖，右侧列出其文明特性、领袖能力和特色项目
--	* 占领该领袖原始首都后可逐项或一键激活
-- =============================================================================
include("InstanceManager");
include("CivConquest_Common");
include("CivConquestDebug");

-- ===========================================================================
--	常量 / 成员
-- ===========================================================================
local TAB_IN_GAME	:string = "IN_GAME";
local TAB_ALL		:string = "ALL";

local ITEM_ICON_SIZES	:table = { 64, 50, 80, 45, 38 };
local LEADER_ICON_SIZES	:table = { 45, 50, 55, 64, 32 };
local PORTRAIT_SIZES	:table = { 80, 64, 55, 50, 45 };
local CIV_ICON_SIZES	:table = { 36, 44, 30, 50 };

local CATEGORY_LABELS :table = {
	CIV_ABILITY		= "LOC_CQ_CATEGORY_CIV_ABILITY",
	LEADER_ABILITY	= "LOC_CQ_CATEGORY_LEADER_ABILITY",
	UNIT			= "LOC_CQ_CATEGORY_UNIT",
	BUILDING		= "LOC_CQ_CATEGORY_BUILDING",
	DISTRICT		= "LOC_CQ_CATEGORY_DISTRICT",
	IMPROVEMENT		= "LOC_CQ_CATEGORY_IMPROVEMENT",
};

local ITEM_TABLES :table = {
	UNIT		= "Units",
	BUILDING	= "Buildings",
	DISTRICT	= "Districts",
	IMPROVEMENT	= "Improvements",
};

local m_LeaderIM		:table = InstanceManager:new("LeaderRowInstance", "Button", Controls.LeaderStack);
local m_TraitIM			:table = InstanceManager:new("TraitRowInstance", "Root", Controls.DetailStack);

local m_CurrentTab		:string = TAB_IN_GAME;
local m_SelectedLeader	:string = nil;
local m_LaunchBarItem	:table = nil;
local m_RefreshTimer	:number = 0;

-- ===========================================================================
--	工具函数
-- ===========================================================================
local function SetIconWithFallback(control:table, iconName:string, sizes:table)
	if control == nil then return false; end
	if iconName ~= nil then
		for _, size in ipairs(sizes) do
			local x, y, sheet = IconManager:FindIconAtlas(iconName, size);
			if sheet ~= nil then
				control:SetSizeVal(size, size);
				control:SetIcon(iconName, size);
				control:SetHide(false);
				return true;
			end
		end
	end
	control:SetHide(true);
	return false;
end

local function LookupOr(tag:string, fallback:string)
	if tag == nil or tag == "" then return fallback or ""; end
	return Locale.Lookup(tag);
end

local function GetLocalPlayerID()
	local playerID = Game.GetLocalPlayer();
	if playerID == nil or playerID < 0 or Players[playerID] == nil then return nil; end
	return playerID;
end

local function GetLeaderName(leaderType:string)
	local info = GameInfo.Leaders[leaderType];
	return info and Locale.Lookup(info.Name) or leaderType;
end

local function GetCivName(leaderType:string)
	local civType = CQ.GetCivForLeader(leaderType);
	local info = civType and GameInfo.Civilizations[civType];
	return info and Locale.Lookup(info.Name) or "";
end

-- 本局中哪些领袖存在，以及本地玩家是否遇见过
local function GetInGameLeaderInfo()
	local result = {};
	local localID = GetLocalPlayerID();
	local pDiplo = localID and Players[localID]:GetDiplomacy();
	for _, info in ipairs(CQ.GetMajorPlayersInGame()) do
		local entry = result[info.LeaderType];
		if entry == nil then
			entry = { LeaderType = info.LeaderType, PlayerID = info.PlayerID, Met = false, IsLocal = false };
			result[info.LeaderType] = entry;
		end
		if info.PlayerID == localID then
			entry.IsLocal = true;
			entry.Met = true;
		elseif pDiplo ~= nil and pDiplo:HasMet(info.PlayerID) then
			entry.Met = true;
		end
	end
	return result;
end

-- 某领袖还有多少可激活但未拥有的特性
local function CountActivatable(playerID:number, leaderType:string)
	local total, owned = 0, 0;
	for _, entry in ipairs(CQ.GetLeaderTraitEntries(leaderType)) do
		total = total + 1;
		if CQ.IsTraitOwned(playerID, entry.TraitType) then
			owned = owned + 1;
		end
	end
	return total, owned;
end

-- ===========================================================================
--	LaunchBar 提示（有已解锁但未激活的内容时显示 [ICON_New]）
-- ===========================================================================
local function UpdateLaunchBarAlert()
	if m_LaunchBarItem == nil then return; end
	local playerID = GetLocalPlayerID();
	local hasPending = false;
	if playerID ~= nil then
		for _, info in ipairs(CQ.GetMajorPlayersInGame()) do
			if CQ.IsLeaderUnlocked(playerID, info.LeaderType) then
				local total, owned = CountActivatable(playerID, info.LeaderType);
				if owned < total then
					hasPending = true;
					break;
				end
			end
		end
	end
	m_LaunchBarItem.AlertIndicator:SetHide(not hasPending);
end

-- ===========================================================================
--	右侧详情
-- ===========================================================================
local function BuildEntryTexts(entry:table)
	local name, description, iconName;

	if #entry.Items == 0 then
		local trait = GameInfo.Traits[entry.TraitType];
		name = LookupOr(trait and trait.Name, entry.TraitType);
		description = LookupOr(trait and trait.Description, "");
		if entry.Category == "LEADER_ABILITY" then
			iconName = "ICON_" .. (m_SelectedLeader or "");
		else
			iconName = "ICON_" .. (CQ.GetCivForLeader(m_SelectedLeader) or "");
		end
	else
		local names, descriptions = {}, {};
		for _, item in ipairs(entry.Items) do
			local tableName = ITEM_TABLES[item.Kind];
			local info = tableName and GameInfo[tableName][item.Type];
			local itemName = LookupOr(info and info.Name, item.Type);
			table.insert(names, itemName);

			local itemDesc = LookupOr(info and info.Description, "");
			if item.Replaces ~= nil then
				local replacedInfo = GameInfo[tableName][item.Replaces];
				local replacedName = LookupOr(replacedInfo and replacedInfo.Name, item.Replaces);
				itemDesc = Locale.Lookup("LOC_CQ_REPLACES", replacedName) .. "[NEWLINE]" .. itemDesc;
				if item.Kind == "DISTRICT" then
					itemDesc = itemDesc .. "[NEWLINE][COLOR_Civ6Yellow]" .. Locale.Lookup("LOC_CQ_DISTRICT_NOTE", replacedName) .. "[ENDCOLOR]";
				end
			end
			if item.Kind == "UNIT" and info ~= nil and info.CanTrain == false then
				itemDesc = itemDesc .. "[NEWLINE][COLOR_Civ6Yellow]" .. Locale.Lookup("LOC_CQ_UNIT_UNTRAINABLE_NOTE") .. "[ENDCOLOR]";
			end
			if #entry.Items > 1 then
				itemDesc = itemName .. ": " .. itemDesc;
			end
			table.insert(descriptions, itemDesc);
		end
		name = table.concat(names, " / ");
		description = table.concat(descriptions, "[NEWLINE][NEWLINE]");
		iconName = "ICON_" .. entry.Items[1].Type;
	end
	return name, description, iconName;
end

local function RefreshDetail()
	m_TraitIM:ResetInstances();
	local playerID = GetLocalPlayerID();
	local leaderType = m_SelectedLeader;

	if leaderType == nil or playerID == nil then
		Controls.DetailHeader:SetHide(true);
		Controls.EmptyLabel:SetText(Locale.Lookup("LOC_CQ_SELECT_LEADER"));
		Controls.EmptyLabel:SetHide(false);
		return;
	end

	local inGame = GetInGameLeaderInfo();
	local gameInfo = inGame[leaderType];
	if m_CurrentTab == TAB_IN_GAME and gameInfo ~= nil and not gameInfo.Met then
		Controls.DetailHeader:SetHide(true);
		Controls.EmptyLabel:SetText(Locale.Lookup("LOC_CQ_UNMET_DETAIL"));
		Controls.EmptyLabel:SetHide(false);
		return;
	end

	Controls.DetailHeader:SetHide(false);
	Controls.EmptyLabel:SetHide(true);

	local isSelf = (CQ.GetPlayerLeaderType(playerID) == leaderType);
	local isUnlocked = CQ.IsLeaderUnlocked(playerID, leaderType);

	SetIconWithFallback(Controls.LeaderPortrait, "ICON_" .. leaderType, PORTRAIT_SIZES);
	SetIconWithFallback(Controls.CivIcon, "ICON_" .. (CQ.GetCivForLeader(leaderType) or ""), CIV_ICON_SIZES);
	Controls.DetailLeaderName:SetText(GetLeaderName(leaderType));
	Controls.DetailCivName:SetText(GetCivName(leaderType));

	local statusText;
	if isSelf then
		statusText = Locale.Lookup("LOC_CQ_STATUS_SELF");
	elseif isUnlocked then
		statusText = Locale.Lookup("LOC_CQ_STATUS_UNLOCKED_DETAIL");
	elseif gameInfo == nil then
		statusText = Locale.Lookup("LOC_CQ_STATUS_NOT_IN_GAME_DETAIL");
	else
		statusText = Locale.Lookup("LOC_CQ_STATUS_LOCKED_DETAIL");
	end
	Controls.DetailStatus:SetText(statusText);

	local entries = CQ.GetLeaderTraitEntries(leaderType);
	local anyActivatable = false;

	for _, entry in ipairs(entries) do
		local inst = m_TraitIM:GetInstance();
		local name, description, iconName = BuildEntryTexts(entry);

		inst.Category:SetText(Locale.Lookup(CATEGORY_LABELS[entry.Category] or "LOC_CQ_CATEGORY_CIV_ABILITY"));
		inst.Name:SetText(name);
		inst.Description:SetText(description);
		SetIconWithFallback(inst.Icon, iconName, ITEM_ICON_SIZES);

		local isNative = CQ.HasTraitNatively(playerID, entry.TraitType);
		local isActive = CQ.IsTraitActivated(playerID, entry.TraitType);

		inst.ActivateButton:SetHide(true);
		inst.StateLabel:SetHide(false);
		if isNative then
			inst.StateLabel:SetText(Locale.Lookup("LOC_CQ_STATE_NATIVE"));
		elseif isActive then
			inst.StateLabel:SetText(Locale.Lookup("LOC_CQ_STATE_ACTIVE"));
		elseif isUnlocked then
			anyActivatable = true;
			inst.StateLabel:SetHide(true);
			inst.ActivateButton:SetHide(false);
			inst.ActivateButton:SetDisabled(false);
			inst.ActivateButton:SetToolTipString(Locale.Lookup("LOC_CQ_ACTIVATE_TOOLTIP"));
			local traitType = entry.TraitType;
			inst.ActivateButton:RegisterCallback(Mouse.eLClick, function()
				OnRequestActivate(leaderType, traitType);
			end);
			inst.ActivateButton:RegisterCallback(Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
		else
			inst.StateLabel:SetText(Locale.Lookup("LOC_CQ_STATE_LOCKED"));
		end

		inst.TextStack:CalculateSize();
		inst.Root:SetSizeY(math.max(90, inst.TextStack:GetSizeY() + 18));
	end

	Controls.ActivateAllButton:SetHide(isSelf);
	Controls.ActivateAllButton:SetDisabled(not anyActivatable);
	if anyActivatable then
		Controls.ActivateAllButton:SetToolTipString(Locale.Lookup("LOC_CQ_ACTIVATE_ALL_TOOLTIP"));
	else
		Controls.ActivateAllButton:SetToolTipString(Locale.Lookup(isUnlocked and "LOC_CQ_ALL_ACTIVE_TOOLTIP" or "LOC_CQ_LOCKED_TOOLTIP"));
	end

	Controls.DetailStack:CalculateSize();
	Controls.DetailScroll:CalculateSize();
	Controls.DetailScroll:SetScrollValue(0);
end

-- ===========================================================================
--	左侧列表
-- ===========================================================================
local function RefreshLeaderList()
	m_LeaderIM:ResetInstances();
	local playerID = GetLocalPlayerID();
	if playerID == nil then return; end

	local inGame = GetInGameLeaderInfo();
	local rows = {};

	if m_CurrentTab == TAB_IN_GAME then
		for leaderType, info in pairs(inGame) do
			table.insert(rows, { LeaderType = leaderType, Info = info });
		end
	else
		for _, leaderType in ipairs(CQ.GetAllLeaders()) do
			table.insert(rows, { LeaderType = leaderType, Info = inGame[leaderType] });
		end
	end

	for _, row in ipairs(rows) do
		row.Hidden = (m_CurrentTab == TAB_IN_GAME and row.Info ~= nil and not row.Info.Met);
		row.SortName = row.Hidden and "~" or GetLeaderName(row.LeaderType);
		row.SortGroup = (row.Info ~= nil and row.Info.IsLocal) and 0 or 1;
	end
	table.sort(rows, function(a, b)
		if a.SortGroup ~= b.SortGroup then return a.SortGroup < b.SortGroup; end
		return a.SortName < b.SortName;
	end);

	-- 选中项不在当前列表中时，默认选第一个
	local selectedFound = false;
	for _, row in ipairs(rows) do
		if row.LeaderType == m_SelectedLeader then selectedFound = true; end
	end
	if not selectedFound then
		m_SelectedLeader = rows[1] and rows[1].LeaderType or nil;
	end

	for _, row in ipairs(rows) do
		local inst = m_LeaderIM:GetInstance();
		local leaderType = row.LeaderType;

		if row.Hidden then
			SetIconWithFallback(inst.LeaderIcon, "ICON_LEADER_DEFAULT", LEADER_ICON_SIZES);
			inst.LeaderName:SetText(Locale.Lookup("LOC_CQ_UNMET_LEADER"));
			inst.CivName:SetText("");
			inst.StatusLabel:SetText("");
		else
			SetIconWithFallback(inst.LeaderIcon, "ICON_" .. leaderType, LEADER_ICON_SIZES);
			inst.LeaderName:SetText(GetLeaderName(leaderType));
			inst.CivName:SetText(GetCivName(leaderType));

			local status;
			if row.Info ~= nil and row.Info.IsLocal then
				status = Locale.Lookup("LOC_CQ_STATUS_SELF_SHORT");
			elseif CQ.IsLeaderUnlocked(playerID, leaderType) then
				local total, owned = CountActivatable(playerID, leaderType);
				status = Locale.Lookup("LOC_CQ_STATUS_UNLOCKED_SHORT", owned, total);
			elseif row.Info == nil then
				status = Locale.Lookup("LOC_CQ_STATUS_NOT_IN_GAME_SHORT");
			else
				status = Locale.Lookup("LOC_CQ_STATUS_LOCKED_SHORT");
			end
			inst.StatusLabel:SetText(status);
		end

		inst.SelectedGlow:SetHide(leaderType ~= m_SelectedLeader);
		inst.Button:SetSelected(leaderType == m_SelectedLeader);
		inst.Button:RegisterCallback(Mouse.eLClick, function()
			m_SelectedLeader = leaderType;
			UI.PlaySound("Play_UI_Click");
			RefreshLeaderList();
			RefreshDetail();
		end);
		inst.Button:RegisterCallback(Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	end

	Controls.LeaderStack:CalculateSize();
	Controls.LeaderScroll:CalculateSize();
end

-- ===========================================================================
local function RefreshTabs()
	local inGame = (m_CurrentTab == TAB_IN_GAME);
	Controls.TabInGame:SetSelected(inGame);
	Controls.TabInGameSelected:SetHide(not inGame);
	Controls.TabAll:SetSelected(not inGame);
	Controls.TabAllSelected:SetHide(inGame);
end

local function RefreshAll()
	if ContextPtr:IsHidden() then return; end
	RefreshTabs();
	RefreshLeaderList();
	RefreshDetail();
end

-- ===========================================================================
--	把原始首都位置上报给 Gameplay 端（Gameplay 的城市对象没有 IsOriginalCapital，
--	对于开启记录前就已易手的首都需要由 UI 补全）
-- ===========================================================================
local m_ReportedCapitals :table = {};

local function ReportOriginalCapitals()
	local playerID = GetLocalPlayerID();
	if playerID == nil then return; end
	for _, ownerID in ipairs(PlayerManager.GetAliveIDs()) do
		local pOwner = Players[ownerID];
		if pOwner ~= nil then
			for _, pCity in pOwner:GetCities():Members() do
				if pCity:IsOriginalCapital() then
					local originalOwner = pCity:GetOriginalOwner();
					local recorded = nil;
					pcall(function() recorded = Game:GetProperty(CQ.PROP_ORIGINAL_CAPITAL .. originalOwner); end);
					if recorded == nil and not m_ReportedCapitals[originalOwner] then
						m_ReportedCapitals[originalOwner] = true;
						local kParameters = {};
						kParameters.OnStart		= CQ.SCRIPT_RECORD_CAPITAL;
						kParameters.OwnerID		= originalOwner;
						kParameters.PlotIndex	= Map.GetPlotIndex(pCity:GetX(), pCity:GetY());
						UI.RequestPlayerOperation(playerID, PlayerOperations.EXECUTE_SCRIPT, kParameters);
					end
				end
			end
		end
	end
end

-- ===========================================================================
--	激活请求（经 EXECUTE_SCRIPT 交给 Gameplay 脚本执行，联机同步安全）
-- ===========================================================================
function OnRequestActivate(leaderType:string, traitType:string)
	local playerID = GetLocalPlayerID();
	if playerID == nil then return; end

	ReportOriginalCapitals();	-- 保证 Gameplay 端校验时已有首都记录

	local kParameters = {};
	kParameters.OnStart		= CQ.SCRIPT_ACTIVATE;
	kParameters.LeaderType	= leaderType;
	kParameters.TraitType	= traitType or "";
	UI.RequestPlayerOperation(playerID, PlayerOperations.EXECUTE_SCRIPT, kParameters);
	UI.PlaySound("Confirm_Civic");

	-- 属性写入是异步的，稍后刷新界面
	m_RefreshTimer = 0.5;
	ContextPtr:SetUpdate(OnUpdate);
end

function OnUpdate(deltaTime:number)
	m_RefreshTimer = m_RefreshTimer - deltaTime;
	if m_RefreshTimer <= 0 then
		ContextPtr:ClearUpdate();
		RefreshAll();
		UpdateLaunchBarAlert();
	end
end

-- ===========================================================================
--	打开 / 关闭
-- ===========================================================================
function Open()
	if GetLocalPlayerID() == nil then return; end
	if not ContextPtr:IsHidden() then return; end
	UIManager:QueuePopup(ContextPtr, PopupPriority.Current);
	UI.PlaySound("UI_Screen_Open");
	RefreshAll();
end

function Close()
	if ContextPtr:IsHidden() then return; end
	ContextPtr:ClearUpdate();
	UIManager:DequeuePopup(ContextPtr);
	UI.PlaySound("UI_Screen_Close");
end

function Toggle()
	if ContextPtr:IsHidden() then Open(); else Close(); end
end

function OnInput(pInputStruct:table)
	if pInputStruct:GetMessageType() == KeyEvents.KeyUp and pInputStruct:GetKey() == Keys.VK_ESCAPE then
		Close();
		return true;
	end
	return false;
end

-- ===========================================================================
--	LaunchBar 入口按钮
-- ===========================================================================
local function RealizeLaunchBarBacking()
	local stack = ContextPtr:LookUpControl("/InGame/LaunchBar/ButtonStack");
	if stack == nil then return; end
	stack:CalculateSize();
	local width = stack:GetSizeX();

	local backing	= ContextPtr:LookUpControl("/InGame/LaunchBar/LaunchBacking");
	local tile		= ContextPtr:LookUpControl("/InGame/LaunchBar/LaunchBackingTile");
	local shadow	= ContextPtr:LookUpControl("/InGame/LaunchBar/LaunchBarDropShadow");
	if backing ~= nil then backing:SetSizeX(width + 116); end
	if tile ~= nil then tile:SetSizeX(width - 20); end
	if shadow ~= nil then shadow:SetSizeX(width); end

	LuaEvents.LaunchBar_Resize(width);
end

local function AttachLaunchBarButton()
	if m_LaunchBarItem ~= nil then return; end
	local stack = ContextPtr:LookUpControl("/InGame/LaunchBar/ButtonStack");
	if stack == nil then
		print("[CivConquest] LaunchBar ButtonStack not found");
		return;
	end

	local item = {};
	ContextPtr:BuildInstanceForControl("CQLaunchBarItem", item, stack);
	ContextPtr:BuildInstanceForControl("CQLaunchBarPin", {}, stack);

	item.LaunchItemButton:RegisterCallback(Mouse.eLClick, Toggle);
	item.LaunchItemButton:RegisterCallback(Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	item.LaunchItemButton:SetToolTipString(Locale.Lookup("LOC_CQ_LAUNCHBAR_TOOLTIP"));
	item.LaunchItemIcon:SetIcon("ICON_NOTIFICATION_CAPITAL_CAPTURED", 40);
	item.AlertIndicator:SetToolTipString(Locale.Lookup("LOC_CQ_LAUNCHBAR_ALERT_TOOLTIP"));

	m_LaunchBarItem = item;
	RealizeLaunchBarBacking();
	UpdateLaunchBarAlert();
end

-- ===========================================================================
--	事件
-- ===========================================================================
local function OnLoadGameViewStateDone()
	AttachLaunchBarButton();
	ReportOriginalCapitals();
end

local function OnTurnBegin()
	ReportOriginalCapitals();
	UpdateLaunchBarAlert();
	RefreshAll();
end

local function OnCityChanged()
	UpdateLaunchBarAlert();
	RefreshAll();
end

local function OnLocalPlayerChanged()
	Close();
	UpdateLaunchBarAlert();
end

function OnInit(isReload:boolean)
	if isReload then
		AttachLaunchBarButton();
	end
end

function OnShutdown()
	if m_LaunchBarItem ~= nil and m_LaunchBarItem.LaunchItemButton ~= nil then
		local stack = ContextPtr:LookUpControl("/InGame/LaunchBar/ButtonStack");
		if stack ~= nil then
			pcall(function() stack:DestroyChild(m_LaunchBarItem.LaunchItemButton); end);
		end
	end
	m_LaunchBarItem = nil;
end

-- ===========================================================================
function Initialize()
	ContextPtr:SetInitHandler(OnInit);
	ContextPtr:SetShutdown(OnShutdown);
	ContextPtr:SetInputHandler(OnInput, true);

	Controls.CloseButton:RegisterCallback(Mouse.eLClick, Close);
	Controls.CloseButton:RegisterCallback(Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.TabInGame:RegisterCallback(Mouse.eLClick, function()
		m_CurrentTab = TAB_IN_GAME;
		UI.PlaySound("Play_UI_Click");
		RefreshAll();
	end);
	Controls.TabAll:RegisterCallback(Mouse.eLClick, function()
		m_CurrentTab = TAB_ALL;
		UI.PlaySound("Play_UI_Click");
		RefreshAll();
	end);
	-- “全部激活”：逐个发送与单项激活相同的请求（单项激活路径已验证可用）
	Controls.ActivateAllButton:RegisterCallback(Mouse.eLClick, function()
		local playerID = GetLocalPlayerID();
		if m_SelectedLeader == nil or playerID == nil then return; end
		if not CQ.IsLeaderUnlocked(playerID, m_SelectedLeader) then return; end
		local count = 0;
		for _, entry in ipairs(CQ.GetLeaderTraitEntries(m_SelectedLeader)) do
			if not CQ.IsTraitOwned(playerID, entry.TraitType) then
				OnRequestActivate(m_SelectedLeader, entry.TraitType);
				count = count + 1;
			end
		end
		print("[CivConquest] Activate all " .. tostring(m_SelectedLeader) .. ": " .. tostring(count) .. " request(s)");
	end);
	Controls.ActivateAllButton:RegisterCallback(Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

	Events.LoadGameViewStateDone.Add(OnLoadGameViewStateDone);
	Events.LocalPlayerTurnBegin.Add(OnTurnBegin);
	Events.CityAddedToMap.Add(OnCityChanged);
	Events.LocalPlayerChanged.Add(OnLocalPlayerChanged);

	LuaEvents.CivConquest_Toggle.Add(Toggle);

	CQ.InitDebugLog();
end
Initialize();
