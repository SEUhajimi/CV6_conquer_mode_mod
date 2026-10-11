-- 桃园结义 · 五虎上将：建立首都时关羽、张飞加入，其余武将研究到对应科技后加入，诸葛亮在拥有 3 座城市时加入，
-- 都出现在首都旁。每位一局只送一次（送出时记玩家属性），阵亡后不再出现。
-- 另外负责五虎将「虎将之勇」的残血加成档位、统率光环的开关（诸葛亮「五虎齐心」后改为可叠加）、诸葛亮的经验，
-- 以及关羽斩首、威震华夏，张飞丈八蛇矛，赵云七进七出，马超冲锋，黄忠万箭齐发（见文件后半）。
-- 只在 GameEvents 回调里改游戏状态，联机各端时机一致；放不下或读档后由回合开始补发。
local LEADER = "LEADER_LIU_BEI"
-- 顺序即同一回合内的出场顺序。Tech / Cities 都没有表示有城市就送。
local TIGERS = {
  { Unit = "UNIT_HAN_GUAN_YU" },
  { Unit = "UNIT_HAN_ZHANG_FEI" },
  { Unit = "UNIT_HAN_ZHAO_YUN",    Tech = "TECH_HORSEBACK_RIDING" },
  { Unit = "UNIT_HAN_HUANG_ZHONG", Tech = "TECH_MACHINERY" },
  { Unit = "UNIT_HAN_MA_CHAO",     Tech = "TECH_STIRRUPS" },
}
local ZHUGE_LIANG = "UNIT_HAN_ZHUGE_LIANG"
-- 三顾茅庐：拥有 3 座城市时诸葛亮加入。
local HEROES = {}
for _, tiger in ipairs(TIGERS) do table.insert(HEROES, tiger) end
table.insert(HEROES, { Unit = ZHUGE_LIANG, Cities = 3 })

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
  for _, tiger in ipairs(HEROES) do
    local key = "HAN_TIGER_" .. tiger.Unit
    local unitRow = GameInfo.Units[tiger.Unit]
    local unlocked = true
    if tiger.Tech ~= nil then
      local tech = GameInfo.Technologies[tiger.Tech]
      unlocked = tech ~= nil and techs:HasTech(tech.Index)
    end
    if tiger.Cities ~= nil then
      unlocked = unlocked and player:GetCities():GetCount() >= tiger.Cities
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

-- 关羽 · 威震华夏（终极晋升）：另有攻击城墙全额伤害（修改器，见 Promotions.sql）；关羽在战斗中杀死敌方单位（进攻、防守、斩首都算）时，
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

local function IsUnitType(unit, unitType)
  local unitRow = GameInfo.Units[unitType]
  return unit ~= nil and unitRow ~= nil and unit:GetType() == unitRow.Index and not unit:IsDead()
end

local function IsAtWar(playerID, otherID)
  local player = Players[playerID]
  return player ~= nil and otherID ~= playerID and player:GetDiplomacy():IsAtWarWith(otherID)
end

-- 返回某格上与 playerID 交战的、还活着的作战单位（按 GetUnitsInPlot 的顺序，各端一致）。
local function EnemyCombatUnitsAt(plot, playerID)
  local result = {}
  if plot == nil then return result end
  for _, unit in ipairs(Units.GetUnitsInPlot(plot)) do
    if not IsGone(unit) and unit:GetCombat() > 0 and IsAtWar(playerID, unit:GetOwner()) then
      table.insert(result, unit)
    end
  end
  return result
end

-- 张飞 · 丈八蛇矛（终极晋升）：张飞进攻并击杀敌军后，被杀者身后一格（沿“张飞 → 被杀者”方向）里
-- 与张飞交战的作战单位直接刺死。
-- 近战击杀后张飞可能已前进到被杀者的格子，算不出方向，所以每次移动后把他最近两步的位置
-- 记在单位属性里（随存档、联机同步），用来找出他发起攻击的格子。
local ZHANG_FEI = "UNIT_HAN_ZHANG_FEI"
local PIERCE_PROMOTION = "PROMOTION_HAN_ZHANG_FEI_7"
local PROP_POS = "HAN_POS"
local PROP_PREV_POS = "HAN_PREV_POS"

local function RecordPosition(unit)
  local plot = Map.GetPlot(unit:GetX(), unit:GetY())
  if plot == nil then return end
  local index = plot:GetIndex()
  local current = unit:GetProperty(PROP_POS)
  if current ~= index then
    unit:SetProperty(PROP_PREV_POS, current)
    unit:SetProperty(PROP_POS, index)
  end
end

local function Pierce(zhangFei, targetX, targetY)
  if not HasPromotion(zhangFei, PIERCE_PROMOTION) then return end
  local targetPlot = Map.GetPlot(targetX, targetY)
  if targetPlot == nil then return end
  local targetIndex = targetPlot:GetIndex()
  local fromIndex = Map.GetPlot(zhangFei:GetX(), zhangFei:GetY()):GetIndex()
  if fromIndex == targetIndex then
    -- 已前进到目标格：取前进之前的位置（前进的移动事件可能早于或晚于战斗事件）。
    local current = zhangFei:GetProperty(PROP_POS)
    fromIndex = (current ~= nil and current ~= targetIndex) and current or zhangFei:GetProperty(PROP_PREV_POS)
  end
  if fromIndex == nil or fromIndex == targetIndex then return end
  local fromPlot = Map.GetPlotByIndex(fromIndex)
  for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1 do
    local adjacent = Map.GetAdjacentPlot(fromPlot:GetX(), fromPlot:GetY(), direction)
    if adjacent ~= nil and adjacent:GetIndex() == targetIndex then
      local behind = Map.GetAdjacentPlot(targetX, targetY, direction)
      for _, unit in ipairs(EnemyCombatUnitsAt(behind, zhangFei:GetOwner())) do
        print("[HanLiuBei] Turn " .. Game.GetCurrentGameTurn() .. " Zhang Fei pierced unit " .. unit:GetID()
          .. " of player " .. unit:GetOwner())
        UnitManager.Kill(unit)
      end
      return
    end
  end
end

-- 黄忠 · 万箭齐发（终极晋升）：黄忠远程攻击后，目标（单位、城市或区域）周围一格内与黄忠交战的
-- 作战单位各受 20 点伤害，伤害致死则直接阵亡。
local HUANG_ZHONG = "UNIT_HAN_HUANG_ZHONG"
local VOLLEY_PROMOTION = "PROMOTION_HAN_HUANG_ZHONG_7"
local VOLLEY_DAMAGE = 20

local function Volley(huangZhong, targetX, targetY)
  if not HasPromotion(huangZhong, VOLLEY_PROMOTION) then return end
  for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1 do
    local adjacent = Map.GetAdjacentPlot(targetX, targetY, direction)
    for _, unit in ipairs(EnemyCombatUnitsAt(adjacent, huangZhong:GetOwner())) do
      if unit:GetDamage() + VOLLEY_DAMAGE >= unit:GetMaxDamage() then
        print("[HanLiuBei] Turn " .. Game.GetCurrentGameTurn() .. " Huang Zhong volley killed unit " .. unit:GetID())
        UnitManager.Kill(unit)
      else
        unit:ChangeDamage(VOLLEY_DAMAGE)
        UpdateRage(unit)
      end
    end
  end
end

-- 统率光环开关：平时开共用的 ABILITY_HAN_TIGER_COMMAND（多位武将不叠加）；玩家有学会「五虎齐心」的
-- 诸葛亮时，改开每位武将自己的 ABILITY_HAN_TIGER_COMMAND_<武将>（互相叠加）。
-- 在回合开始、送出武将、战斗（诸葛亮可能阵亡）和移动后刷新；刚选完晋升到下一次刷新之间还是旧状态。
local SHARED_COMMAND = "ABILITY_HAN_TIGER_COMMAND"
local STACK_PROMOTION = "PROMOTION_HAN_ZHUGE_LIANG_7"

local function SetAbility(unit, abilityType, on)
  local ability = unit:GetAbility()
  local want = on and 1 or 0
  local have = ability:GetAbilityCount(abilityType)
  if have ~= want then ability:ChangeAbilityCount(abilityType, want - have) end
end

local function UpdateCommand(playerID)
  local player = Players[playerID]
  if player == nil then return end
  local stacking = false
  for _, unit in player:GetUnits():Members() do
    if IsUnitType(unit, ZHUGE_LIANG) and HasPromotion(unit, STACK_PROMOTION) then stacking = true end
  end
  for _, unit in player:GetUnits():Members() do
    if not IsGone(unit) and IsTiger(unit) then
      for _, tiger in ipairs(TIGERS) do
        local unitRow = GameInfo.Units[tiger.Unit]
        if unitRow ~= nil and unit:GetType() == unitRow.Index then
          SetAbility(unit, SHARED_COMMAND, not stacking)
          SetAbility(unit, "ABILITY_HAN_TIGER_COMMAND_" .. string.sub(tiger.Unit, 10), stacking)
        end
      end
    end
  end
end

-- 诸葛亮的经验：支援单位不参与战斗，2 格内的五虎将每打一仗，诸葛亮 +8 经验。
local ZGL_RANGE = 2
local ZGL_XP_PER_BATTLE = 8

local function GrantZhugeLiangXP(tiger)
  if tiger == nil or not IsTiger(tiger) then return end
  local player = Players[tiger:GetOwner()]
  if player == nil then return end
  for _, unit in player:GetUnits():Members() do
    if IsUnitType(unit, ZHUGE_LIANG)
      and Map.GetPlotDistance(unit:GetX(), unit:GetY(), tiger:GetX(), tiger:GetY()) <= ZGL_RANGE then
      unit:GetExperience():ChangeExperience(ZGL_XP_PER_BATTLE)
    end
  end
end

-- 马超 · 神威天将军（终极晋升）：西凉铁骑冲锋。回合开始记下位置、格数清零；每次移动累加走过的距离；
-- 按格数开 ABILITY_HAN_MA_CHAO_CHARGE_<1~5> 中的一档（各档是累计值，进攻 +4 × 格数）。
-- 按走过的格数而不是消耗的移动力算：进入区域控制会清空移动力，不能因此吃满加成。
local MA_CHAO = "UNIT_HAN_MA_CHAO"
local CHARGE_PROMOTION = "PROMOTION_HAN_MA_CHAO_7"
local CHARGE_MAX_TILES = 5
local PROP_CHARGE_POS = "HAN_CHARGE_POS"
local PROP_CHARGE_TILES = "HAN_CHARGE_TILES"

local function UpdateChargeAbility(unit)
  local tiles = HasPromotion(unit, CHARGE_PROMOTION) and math.min(unit:GetProperty(PROP_CHARGE_TILES) or 0, CHARGE_MAX_TILES) or 0
  for k = 1, CHARGE_MAX_TILES do
    SetAbility(unit, "ABILITY_HAN_MA_CHAO_CHARGE_" .. k, k == tiles)
  end
end

local function ResetCharge(unit)
  unit:SetProperty(PROP_CHARGE_POS, Map.GetPlot(unit:GetX(), unit:GetY()):GetIndex())
  unit:SetProperty(PROP_CHARGE_TILES, 0)
  UpdateChargeAbility(unit)
end

local function RecordCharge(unit)
  local plot = Map.GetPlot(unit:GetX(), unit:GetY())
  local last = unit:GetProperty(PROP_CHARGE_POS)
  if last ~= nil and last ~= plot:GetIndex() then
    local lastPlot = Map.GetPlotByIndex(last)
    local tiles = (unit:GetProperty(PROP_CHARGE_TILES) or 0) + Map.GetPlotDistance(lastPlot:GetX(), lastPlot:GetY(), plot:GetX(), plot:GetY())
    unit:SetProperty(PROP_CHARGE_TILES, tiles)
  end
  unit:SetProperty(PROP_CHARGE_POS, plot:GetIndex())
  UpdateChargeAbility(unit)
end

-- 赵云 · 七进七出（终极晋升）：每回合可攻击七次（修改器，见 Promotions.sql）；赵云进攻并击杀敌方单位后，立刻恢复全部移动力。
local ZHAO_YUN = "UNIT_HAN_ZHAO_YUN"
local SEVEN_PROMOTION = "PROMOTION_HAN_ZHAO_YUN_7"

local function SevenInSevenOut(zhaoYun)
  if not HasPromotion(zhaoYun, SEVEN_PROMOTION) then return end
  local missing = zhaoYun:GetMaxMoves() - zhaoYun:GetMovesRemaining()
  if missing > 0 then zhaoYun:ChangeMovesRemaining(missing) end
end

local function OnUnitMoved(playerID, unitID)
  local unit = FindUnit(playerID, unitID)
  if IsUnitType(unit, ZHANG_FEI) then RecordPosition(unit) end
  if IsUnitType(unit, MA_CHAO) then RecordCharge(unit) end
  if IsUnitType(unit, ZHUGE_LIANG) then UpdateCommand(playerID) end
end

local function OnCombatOccurred(attackerPlayerID, attackerUnitID, defenderPlayerID, defenderUnitID, attackerDistrictID, defenderDistrictID)
  local attacker = FindUnit(attackerPlayerID, attackerUnitID)
  local defender = FindUnit(defenderPlayerID, defenderUnitID)
  local defenderIsUnit = Players[defenderPlayerID] ~= nil and defenderUnitID ~= nil and defenderUnitID >= 0
  local attackerIsUnit = Players[attackerPlayerID] ~= nil and attackerUnitID ~= nil and attackerUnitID >= 0
  -- 目标位置：防守单位（阵亡的也还能取到）或被攻击的城市 / 区域。
  local targetX, targetY = nil, nil
  if defender ~= nil then
    targetX, targetY = defender:GetX(), defender:GetY()
  elseif Players[defenderPlayerID] ~= nil and defenderDistrictID ~= nil and defenderDistrictID >= 0 then
    local district = Players[defenderPlayerID]:GetDistricts():FindID(defenderDistrictID)
    if district ~= nil then targetX, targetY = district:GetX(), district:GetY() end
  end
  if IsUnitType(attacker, HUANG_ZHONG) and targetX ~= nil then
    Volley(attacker, targetX, targetY)
  end
  if TryExecute(attacker, defender) then defender = nil end
  -- 阵亡的防守单位找不到时，近战击杀者已前进到它的格子上。
  if IsUnitType(attacker, ZHANG_FEI) and defenderIsUnit and IsGone(defender) then
    if targetX == nil then targetX, targetY = attacker:GetX(), attacker:GetY() end
    Pierce(attacker, targetX, targetY)
  end
  -- 只算单位之间的击杀（打城市 / 区域不算）。
  if IsGuanYu(attacker) and defenderIsUnit and IsGone(defender) then
    AweOverChina(attacker)
  elseif IsGuanYu(defender) and attackerIsUnit and IsGone(attacker) then
    AweOverChina(defender)
  end
  if IsUnitType(attacker, ZHAO_YUN) and defenderIsUnit and IsGone(defender) then
    SevenInSevenOut(attacker)
  end
  -- 阵亡的武将也还能取到位置（同一次战斗里），照样给诸葛亮经验。
  GrantZhugeLiangXP(attacker)
  GrantZhugeLiangXP(defender)
  if not IsGone(attacker) then UpdateRage(attacker) end
  if not IsGone(defender) then UpdateRage(defender) end
  UpdateCommand(attackerPlayerID)
  UpdateCommand(defenderPlayerID)
end

local function OnPlayerTurnStarted(playerID)
  TryGrant(playerID, nil)
  UpdatePlayerRage(playerID)
  UpdateCommand(playerID)
  -- 回合开始时记下张飞的位置，原地发起攻击也能算出方向。
  local player = Players[playerID]
  if player == nil then return end
  for _, unit in player:GetUnits():Members() do
    if IsUnitType(unit, ZHANG_FEI) then RecordPosition(unit) end
    if IsUnitType(unit, MA_CHAO) then ResetCharge(unit) end
  end
end

local function OnCityBuilt(playerID, cityID, x, y)
  TryGrant(playerID, CityManager.GetCity(playerID, cityID))
  UpdateCommand(playerID)
end

GameEvents.CityBuilt.Add(OnCityBuilt)
GameEvents.PlayerTurnStarted.Add(OnPlayerTurnStarted)
-- 回合开始的回血可能在 PlayerTurnStarted 之后结算，结算完成后再刷新一次。
GameEvents.PlayerTurnStartComplete.Add(UpdatePlayerRage)
GameEvents.OnCombatOccurred.Add(OnCombatOccurred)
GameEvents.OnUnitMoved.Add(OnUnitMoved)
print("[HanLiuBei] HanTigers loaded")
