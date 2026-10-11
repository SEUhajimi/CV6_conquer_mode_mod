-- =============================================================================
--	文明征服模式 - 科技树 / 市政树的解锁项
--	TechAndCivicUnlockables.lua 末尾会 include 所有 "TechAndCivicUnlockables_" 开头的文件。
--	科技树（GetFilteredUnlockableItems）和市政树（GetUnlockablesForCivic）都从 GetUnlockableItems 取完整列表，
--	官方只按玩家原生的特性筛选。这里包装 GetUnlockableItems（做法同风云变幻的 TechAndCivicUnlockables_Expansion2）：
--	  * 特色建筑：本模式清空了它们的 TraitType（改为效果解锁），官方会把所有文明的特色建筑显示给每个玩家，
--	    这里只留玩家拥有（原生或激活）的；
--	  * 激活来的特色单位、特色改良：加进列表，让它们出现在各自的科技 / 市政上；
--	  * 特色区域不加：激活者建造的仍是基础区域（效果加到基础区域上），树上应显示基础区域。
--	激活来的特色单位不取代基础单位（两者都能造），所以还要让 RemoveReplacedUnlockables 不因它们藏掉基础单位。
-- =============================================================================
include("CivConquest_Common");

local m_UniqueBuildings	:table = nil;	-- 特色建筑 -> 所属特性
local m_ActivatableItems:table = nil;	-- 特性 -> { { Kind, Type }, ... }：激活后加进树的单位 / 改良

local function BuildFilterCache()
	if m_UniqueBuildings ~= nil then return; end
	m_UniqueBuildings = {};
	m_ActivatableItems = {};
	local untrainable = {};
	if GameInfo.CQ_UntrainableUnits ~= nil then
		for row in GameInfo.CQ_UntrainableUnits() do untrainable[row.UnitType] = true; end
	end
	if GameInfo.CQ_TraitItems ~= nil then
		for row in GameInfo.CQ_TraitItems() do
			if row.ItemKind == "BUILDING" then
				m_UniqueBuildings[row.ItemType] = row.TraitType;
			elseif row.ItemKind == "IMPROVEMENT" or (row.ItemKind == "UNIT" and not untrainable[row.ItemType]) then
				m_ActivatableItems[row.TraitType] = m_ActivatableItems[row.TraitType] or {};
				table.insert(m_ActivatableItems[row.TraitType], { Kind = row.ItemKind, Type = row.ItemType });
			end
		end
	end
end

-- 玩家激活（不是原生拥有）的特色单位 / 改良：类型 -> true
local function GetActivatedItems(playerId)
	local result = {};
	for traitType, items in pairs(m_ActivatableItems) do
		if CQ.IsTraitActivated(playerId, traitType) and not CQ.HasTraitNatively(playerId, traitType) then
			for _, item in ipairs(items) do result[item.Type] = item.Kind; end
		end
	end
	return result;
end

-- 激活来的特色单位不取代基础单位：先把它们拿出来，交给当时生效的 RemoveReplacedUnlockables，再放回去。
-- 埃塞俄比亚 DLC 整个重写了 RemoveReplacedUnlockables，各文件的 include 顺序不确定，
-- 所以在第一次取列表时（所有文件都已加载）才包装当时的那个函数。
local m_WrappedRemove = nil;
local function WrapRemoveReplaced()
	if RemoveReplacedUnlockables == m_WrappedRemove then return; end
	local baseRemove = RemoveReplacedUnlockables;
	m_WrappedRemove = function(unlockables, playerId)
		if playerId == nil then return baseRemove(unlockables, playerId); end
		local activated = GetActivatedItems(playerId);
		local kept, held = {}, {};
		for _, v in ipairs(unlockables) do
			if activated[v[2]] == "UNIT" then table.insert(held, v); else table.insert(kept, v); end
		end
		local results = baseRemove(kept, playerId);
		for _, v in ipairs(held) do table.insert(results, v); end
		return results;
	end
	RemoveReplacedUnlockables = m_WrappedRemove;
end

local CQ_BASE_GetUnlockableItems = GetUnlockableItems;

function GetUnlockableItems(playerId)
	BuildFilterCache();
	WrapRemoveReplaced();
	local unlockables = CQ_BASE_GetUnlockableItems(playerId);
	if playerId == nil then return unlockables; end

	local results = {};
	local listed = {};
	for _, v in ipairs(unlockables) do
		local trait = m_UniqueBuildings[v[2]];
		if trait == nil or CQ.IsTraitOwned(playerId, trait) then
			table.insert(results, v);
			listed[v[2]] = true;
		end
	end

	-- 按类型排序后再加，保证顺序稳定。
	local activated = GetActivatedItems(playerId);
	local types = {};
	for itemType, _ in pairs(activated) do table.insert(types, itemType); end
	table.sort(types);
	for _, itemType in ipairs(types) do
		if not listed[itemType] then
			local row = (activated[itemType] == "UNIT") and GameInfo.Units[itemType] or GameInfo.Improvements[itemType];
			if row ~= nil then
				table.insert(results, { row, itemType, row.Name, itemType });
			end
		end
	end
	return results;
end
