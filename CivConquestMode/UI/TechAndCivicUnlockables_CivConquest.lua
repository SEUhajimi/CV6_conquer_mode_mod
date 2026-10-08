-- =============================================================================
--	文明征服模式 - 科技树 / 市政树的解锁项过滤
--	TechAndCivicUnlockables.lua 末尾会 include 所有 "TechAndCivicUnlockables_" 开头的文件。
--	本模式清空了特色建筑的 TraitType（改为效果解锁），官方逻辑会因此把所有文明的特色建筑
--	显示给每个玩家，并藏掉被取代的基础建筑。这里重写 GetFilteredUnlockableItems
--	（科技树、市政树、百科和提示都经过它，官方扩展没有改这个函数）：
--	在官方逻辑（完整列表 -> 按玩家去掉被取代的项）之前，先去掉玩家没有（原生或激活）的特色建筑。
-- =============================================================================
include("CivConquest_Common");

local m_UniqueBuildings :table = nil;	-- 特色建筑 -> 所属特性

local function BuildFilterCache()
	if m_UniqueBuildings ~= nil then return; end
	m_UniqueBuildings = {};
	if GameInfo.CQ_TraitItems ~= nil then
		for row in GameInfo.CQ_TraitItems() do
			if row.ItemKind == "BUILDING" then m_UniqueBuildings[row.ItemType] = row.TraitType; end
		end
	end
end

function GetFilteredUnlockableItems(playerId)
	-- 与官方实现相同：-1（NO_PLAYER）当作 nil
	if type(playerId) == "number" and playerId < 0 then
		playerId = nil;
	end
	BuildFilterCache();

	local unlockables = {};
	for _, v in ipairs(GetUnlockableItems(playerId)) do
		local trait = m_UniqueBuildings[v[2]];
		if trait == nil or playerId == nil or CQ.IsTraitOwned(playerId, trait) then
			table.insert(unlockables, v);
		end
	end

	if playerId ~= nil then
		unlockables = RemoveReplacedUnlockables(unlockables, playerId);
	end
	return unlockables;
end
