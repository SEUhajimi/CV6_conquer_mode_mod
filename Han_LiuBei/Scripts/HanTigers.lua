-- 桃园结义 · 五虎上将：建立首都时关羽、张飞加入，其余武将研究到对应科技后加入，都出现在首都旁。
-- 每位武将一局只送一次（送出时记玩家属性），阵亡后不再出现。
-- 另外负责五虎将「虎将之勇」的残血加成档位和关羽的「斩首」（见文件后半）。
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

-- 虎将之勇（五虎将通用）：生命值低于阈值时开启对应档位的加成能力，回到阈值以上时关闭。
-- 原版没有按自身生命值判断的战斗需求条件，所以在回合开始（回血之后）和每次战斗后由脚本刷新。
local RAGE_TIERS = {
  { Below = 75, Ability = "ABILITY_HAN_TIGER_RAGE_25", Promotion = "PROMOTION_HAN_ZHANG_FEI_6" },
  { Below = 50, Ability = "ABILITY_HAN_TIGER_RAGE_50" },
  { Below = 25, Ability = "ABILITY_HAN_TIGER_RAGE_75" },
}

local function IsTiger(unit)
  for _, tiger in ipairs(TIGERS) do
    local unitRow = GameInfo.Units[tiger.Unit]
    if unitRow ~= nil and unit:GetType() == unitRow.Index then return true end
  end
  return false
end

local function HasPromotion(unit, promotionType)
  local promotion = GameInfo.UnitPromotions[promotionType]
  return promotion ~= nil and unit:GetExperience():HasPromotion(promotion.Index)
end

local function UpdateRage(unit)
  if unit == nil or unit:IsDead() or not IsTiger(unit) then return end
  local hp = unit:GetMaxDamage() - unit:GetDamage()
  local ability = unit:GetAbility()
  for _, tier in ipairs(RAGE_TIERS) do
    local active = hp < tier.Below and (tier.Promotion == nil or HasPromotion(unit, tier.Promotion))
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

-- 关羽 · 斩首：关羽进攻后，被攻击的敌方作战单位若还活着且剩余生命值不高于斩首线，直接斩杀。
-- 斩首线 20，晋升「威震华夏」后 35。只对单位生效，不对城市 / 区域。
local GUAN_YU = "UNIT_HAN_GUAN_YU"
local EXECUTE_HP = 20
local EXECUTE_HP_PROMOTED = 35
local EXECUTE_PROMOTION = "PROMOTION_HAN_GUAN_YU_7"

-- 返回 true 表示防守方已被斩杀（之后不能再使用它）。
local function TryExecute(attacker, defender)
  local unitRow = GameInfo.Units[GUAN_YU]
  if attacker == nil or defender == nil or unitRow == nil then return false end
  if attacker:GetType() ~= unitRow.Index or attacker:IsDead() then return false end
  if defender:IsDead() or defender:IsDelayedDeath() or defender:GetOwner() == attacker:GetOwner() then return false end
  if defender:GetCombat() <= 0 then return false end
  local threshold = HasPromotion(attacker, EXECUTE_PROMOTION) and EXECUTE_HP_PROMOTED or EXECUTE_HP
  local hp = defender:GetMaxDamage() - defender:GetDamage()
  if hp > threshold then return false end
  print("[HanLiuBei] Turn " .. Game.GetCurrentGameTurn() .. " Guan Yu of player " .. attacker:GetOwner()
    .. " beheaded unit " .. defender:GetID() .. " of player " .. defender:GetOwner() .. " at " .. hp .. " HP")
  UnitManager.Kill(defender)
  return true
end

-- 关羽 · 威震华夏（终极晋升）：关羽在战斗中杀死敌方单位（进攻、防守、斩首都算）时，
-- 以关羽所在格为中心 9 格内、与关羽所属玩家交战的城市各 -20 忠诚度。
local AWE_RANGE = 9
local AWE_LOYALTY = -20
local MAX_PLAYERS = 64

local function IsGuanYu(unit)
  local unitRow = GameInfo.Units[GUAN_YU]
  return unit ~= nil and unitRow ~= nil and unit:GetType() == unitRow.Index and not unit:IsDead()
end

local function IsGone(unit)
  return unit == nil or unit:IsDead() or unit:IsDelayedDeath()
end

local function AweOverChina(guanYu)
  if not HasPromotion(guanYu, EXECUTE_PROMOTION) then return end
  local ownerID = guanYu:GetOwner()
  local diplomacy = Players[ownerID]:GetDiplomacy()
  local x, y = guanYu:GetX(), guanYu:GetY()
  -- 按玩家编号顺序遍历，各端结果一致。
  for playerID = 0, MAX_PLAYERS - 1 do
    local player = Players[playerID]
    if player ~= nil and playerID ~= ownerID and player:IsAlive() and diplomacy:IsAtWarWith(playerID) then
      for _, city in player:GetCities():Members() do
        if Map.GetPlotDistance(x, y, city:GetX(), city:GetY()) <= AWE_RANGE then
          city:ChangeLoyalty(AWE_LOYALTY)
          print("[HanLiuBei] Turn " .. Game.GetCurrentGameTurn() .. " Awe Over China: city " .. city:GetID()
            .. " of player " .. playerID .. " loyalty " .. AWE_LOYALTY)
          -- 飘字只是提示，失败不影响效果。
          pcall(function()
            Game.AddWorldViewText(0, Locale.Lookup("LOC_HAN_AWE_OVER_CHINA_FLYOVER", AWE_LOYALTY), city:GetX(), city:GetY())
          end)
        end
      end
    end
  end
end

local function OnCombatOccurred(attackerPlayerID, attackerUnitID, defenderPlayerID, defenderUnitID)
  local attacker = FindUnit(attackerPlayerID, attackerUnitID)
  local defender = FindUnit(defenderPlayerID, defenderUnitID)
  local defenderIsUnit = Players[defenderPlayerID] ~= nil and defenderUnitID ~= nil and defenderUnitID >= 0
  local attackerIsUnit = Players[attackerPlayerID] ~= nil and attackerUnitID ~= nil and attackerUnitID >= 0
  if TryExecute(attacker, defender) then defender = nil end
  -- 只算单位之间的击杀（打城市 / 区域不算）。
  if IsGuanYu(attacker) and defenderIsUnit and IsGone(defender) then
    AweOverChina(attacker)
  elseif IsGuanYu(defender) and attackerIsUnit and IsGone(attacker) then
    AweOverChina(defender)
  end
  if not IsGone(attacker) then UpdateRage(attacker) end
  if not IsGone(defender) then UpdateRage(defender) end
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
