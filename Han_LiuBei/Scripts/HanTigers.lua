-- 桃园结义 · 五虎上将：建立首都时关羽、张飞加入，其余武将研究到对应科技后加入，都出现在首都旁。
-- 每位武将一局只送一次（送出时记玩家属性），阵亡后不再出现。
-- 另外负责张飞「万人敌」的残血加成档位（见文件后半）。
-- 只在 GameEvents 回调里改游戏状态，联机各端时机一致；放不下或读档后由回合开始补发。
local LEADER = "LEADER_LIU_BEI"
-- 顺序即同一回合内的出场顺序。Tech 为 nil 表示有城市就送。
local TIGERS = {
  { Unit = "UNIT_HAN_GUAN_YU" },
  { Unit = "UNIT_HAN_ZHANG_FEI" },
  { Unit = "UNIT_HAN_ZHAO_YUN",    Tech = "TECH_HORSEBACK_RIDING" },
  { Unit = "UNIT_HAN_HUANG_ZHONG", Tech = "TECH_MACHINERY" },
  { Unit = "UNIT_HAN_MA_CHAO",     Tech = "TECH_STIRRUPS" },
}

local function Notify(playerID, unitRow, city)
  -- 通知只是提示，失败不影响发放。
  pcall(function()
    local name = Locale.Lookup(unitRow.Name)
    NotificationManager.SendNotification(playerID, NotificationTypes.USER_DEFINED_1,
      Locale.Lookup("LOC_HAN_TIGER_JOINED_MESSAGE", name),
      Locale.Lookup("LOC_HAN_TIGER_JOINED_SUMMARY", name, city:GetName()),
      city:GetX(), city:GetY())
  end)
end

-- InitUnitValidAdjacentHex 的返回值原版从不使用，不依赖它；用发放前后的数量判断是否成功。
local function CountUnits(player, unitIndex)
  local n = 0
  for _, unit in player:GetUnits():Members() do
    if unit:GetType() == unitIndex then n = n + 1 end
  end
  return n
end

local function TryGrant(playerID, city)
  local config = PlayerConfigurations[playerID]
  if config == nil or config:GetLeaderTypeName() ~= LEADER then return end
  local player = Players[playerID]
  if player == nil or not player:IsAlive() then return end
  -- 优先放在首都旁；建第一座城的那一刻首都可能还没登记，就用刚建的城。都没有就等以后的回合。
  city = player:GetCities():GetCapitalCity() or city
  if city == nil then return end
  local techs = player:GetTechs()
  for _, tiger in ipairs(TIGERS) do
    local key = "HAN_TIGER_" .. tiger.Unit
    local unitRow = GameInfo.Units[tiger.Unit]
    local unlocked = tiger.Tech == nil
    if not unlocked then
      local tech = GameInfo.Technologies[tiger.Tech]
      unlocked = tech ~= nil and techs:HasTech(tech.Index)
    end
    if player:GetProperty(key) == nil and unitRow ~= nil and unlocked then
      local before = CountUnits(player, unitRow.Index)
      UnitManager.InitUnitValidAdjacentHex(playerID, tiger.Unit, city:GetX(), city:GetY(), 1)
      if CountUnits(player, unitRow.Index) > before then
        player:SetProperty(key, Game.GetCurrentGameTurn())
        print("[HanLiuBei] Turn " .. Game.GetCurrentGameTurn() .. " player " .. playerID .. " recruited " .. tiger.Unit)
        Notify(playerID, unitRow, city)
      else
        print("[HanLiuBei] Turn " .. Game.GetCurrentGameTurn() .. " player " .. playerID .. " could not place " .. tiger.Unit .. ", retrying next turn")
      end
    end
  end
end

-- 张飞 · 万人敌：生命值低于阈值时开启对应档位的加成能力，回到阈值以上时关闭。
-- 原版没有按自身生命值判断的战斗需求条件，所以在回合开始（回血之后）和每次战斗后由脚本刷新。
local ZHANG_FEI = "UNIT_HAN_ZHANG_FEI"
local RAGE_TIERS = {
  { Below = 75, Ability = "ABILITY_HAN_ZHANG_FEI_RAGE_25", Promotion = "PROMOTION_HAN_ZHANG_FEI_6" },
  { Below = 50, Ability = "ABILITY_HAN_ZHANG_FEI_RAGE_50" },
  { Below = 25, Ability = "ABILITY_HAN_ZHANG_FEI_RAGE_75" },
}

local function UpdateRage(unit)
  local unitRow = GameInfo.Units[ZHANG_FEI]
  if unit == nil or unitRow == nil or unit:GetType() ~= unitRow.Index or unit:IsDead() then return end
  local hp = unit:GetMaxDamage() - unit:GetDamage()
  local ability = unit:GetAbility()
  for _, tier in ipairs(RAGE_TIERS) do
    local active = hp < tier.Below
    if active and tier.Promotion ~= nil then
      local promotion = GameInfo.UnitPromotions[tier.Promotion]
      active = promotion ~= nil and unit:GetExperience():HasPromotion(promotion.Index)
    end
    local want = active and 1 or 0
    local have = ability:GetAbilityCount(tier.Ability)
    if have ~= want then
      ability:ChangeAbilityCount(tier.Ability, want - have)
    end
  end
end

local function UpdatePlayerRage(playerID)
  local player = Players[playerID]
  if player == nil then return end
  for _, unit in player:GetUnits():Members() do
    UpdateRage(unit)
  end
end

local function FindUnit(playerID, unitID)
  local player = Players[playerID]
  if player == nil or unitID == nil or unitID < 0 then return nil end
  return player:GetUnits():FindID(unitID)
end

local function OnCombatOccurred(attackerPlayerID, attackerUnitID, defenderPlayerID, defenderUnitID)
  UpdateRage(FindUnit(attackerPlayerID, attackerUnitID))
  UpdateRage(FindUnit(defenderPlayerID, defenderUnitID))
end

local function OnPlayerTurnStarted(playerID)
  TryGrant(playerID, nil)
  UpdatePlayerRage(playerID)
end

local function OnCityBuilt(playerID, cityID, x, y)
  TryGrant(playerID, CityManager.GetCity(playerID, cityID))
end

GameEvents.CityBuilt.Add(OnCityBuilt)
GameEvents.PlayerTurnStarted.Add(OnPlayerTurnStarted)
-- 回合开始的回血可能在 PlayerTurnStarted 之后结算，结算完成后再刷新一次。
GameEvents.PlayerTurnStartComplete.Add(UpdatePlayerRage)
GameEvents.OnCombatOccurred.Add(OnCombatOccurred)
print("[HanLiuBei] HanTigers loaded")
