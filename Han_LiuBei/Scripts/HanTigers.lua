-- 桃园结义 · 五虎上将：建立首都时关羽、张飞加入，其余武将研究到对应科技后加入，诸葛亮在拥有 3 座城市时加入，
-- 都出现在首都旁。每位一局只送一次（送出时记玩家属性），阵亡后不再出现。
-- 另外负责五虎将「虎将之勇」的残血加成档位、统率光环的开关（诸葛亮「五虎齐心」后改为可叠加）、诸葛亮的借东风 / 空城计 / 草船借箭 / 舌战群儒 / 七星续命、五虎合体，
-- 以及五虎将不编成军团 / 军队、清零刘备的大将军点数、厚施恩德 10~18 格的远程忠诚度压力，关羽斩首、威震华夏、过五关斩六将，张飞丈八蛇矛，赵云白马银枪，赵云七进七出（含关羽、赵云破城），马超冲锋，黄忠万箭齐发（见文件后半）。
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

-- 五虎神将（五人合体）：在关羽（斩首、震慑、过五关斩六将）、赵云（七进七出、白马银枪）、马超（冲锋）的判断里算作本人，
-- 并视为学会了这几项对应的晋升；张飞的扇形和黄忠的万箭齐发不触发，改为自己的横扫千军（见 Sweep）。
local FUSION = "UNIT_HAN_WUHU"
local FUSION_PROMOTIONS = {
  PROMOTION_HAN_GUAN_YU_6 = true, PROMOTION_HAN_GUAN_YU_7 = true,
  PROMOTION_HAN_ZHAO_YUN_1 = true, PROMOTION_HAN_ZHAO_YUN_7 = true, PROMOTION_HAN_MA_CHAO_7 = true,
}

local function IsFusion(unit)
  local unitRow = GameInfo.Units[FUSION]
  return unit ~= nil and unitRow ~= nil and unit:GetType() == unitRow.Index and not unit:IsDead()
end

local function IsTiger(unit)
  if IsFusion(unit) then return true end
  for _, tiger in ipairs(TIGERS) do
    local unitRow = GameInfo.Units[tiger.Unit]
    if unitRow ~= nil and unit:GetType() == unitRow.Index then return true end
  end
  return false
end

local function HasPromotion(unit, promotionType)
  if IsFusion(unit) and FUSION_PROMOTIONS[promotionType] then return true end
  local promotion = GameInfo.UnitPromotions[promotionType]
  return promotion ~= nil and unit:GetExperience():HasPromotion(promotion.Index)
end

local function IsUnitType(unit, unitType)
  local unitRow = GameInfo.Units[unitType]
  return unit ~= nil and unitRow ~= nil and unit:GetType() == unitRow.Index and not unit:IsDead()
end

-- 关羽、赵云、马超各自的脚本效果，五虎神将也算。
local function IsGuanYu(unit) return IsUnitType(unit, "UNIT_HAN_GUAN_YU") or IsFusion(unit) end
local function IsZhaoYunLike(unit) return IsUnitType(unit, "UNIT_HAN_ZHAO_YUN") or IsFusion(unit) end
local function IsMaChaoLike(unit) return IsUnitType(unit, "UNIT_HAN_MA_CHAO") or IsFusion(unit) end

-- 五虎神将的跳跃距离 = 当前最大移动力 × 4：按 GetMaxMoves() 开 ABILITY_HAN_WUHU_JUMP_<k>（跳 4k 格）中的一档。
-- 移动力随统率、诸葛亮等变化，所以在回合开始、回合开始结算完和它移动后刷新。
local JUMP_TIERS = 40

local function UpdateJump(unit)
  if not IsFusion(unit) then return end
  local tier = math.max(1, math.min(unit:GetMaxMoves(), JUMP_TIERS))
  local ability = unit:GetAbility()
  for k = 1, JUMP_TIERS do
    local want = (k == tier) and 1 or 0
    local have = ability:GetAbilityCount("ABILITY_HAN_WUHU_JUMP_" .. k)
    if have ~= want then ability:ChangeAbilityCount("ABILITY_HAN_WUHU_JUMP_" .. k, want - have) end
  end
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
local EXECUTE_HP = 20
local EXECUTE_HP_PROMOTED = 35
local EXECUTE_PROMOTION = "PROMOTION_HAN_GUAN_YU_7"

-- 返回 true 表示防守方已被斩杀（之后不能再使用它）。
local function TryExecute(attacker, defender)
  if attacker == nil or defender == nil or not IsGuanYu(attacker) then return false end
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
-- 五虎神将 · 青龙偃月：18 格内 -40。
local FUSION_AWE_RANGE = 18
local FUSION_AWE_LOYALTY = -40
local MAX_PLAYERS = 64

local function IsGone(unit)
  return unit == nil or unit:IsDead() or unit:IsDelayedDeath()
end

-- 关羽 · 过五关斩六将（晋升）：单位属性 HAN_KILLS 累计一生的击杀数（学会之前的也算），学会后按击杀数开
-- ABILITY_HAN_GUAN_YU_KILLS_<1~KILL_TIERS> 中的一档（+N 战斗力）。
local KILLS_PROMOTION = "PROMOTION_HAN_GUAN_YU_6"
local PROP_KILLS = "HAN_KILLS"
local KILL_TIERS = 100

local function UpdateKillStrength(guanYu)
  local kills = HasPromotion(guanYu, KILLS_PROMOTION) and math.min(guanYu:GetProperty(PROP_KILLS) or 0, KILL_TIERS) or 0
  local ability = guanYu:GetAbility()
  for k = 1, KILL_TIERS do
    local want = (k == kills) and 1 or 0
    local have = ability:GetAbilityCount("ABILITY_HAN_GUAN_YU_KILLS_" .. k)
    if have ~= want then ability:ChangeAbilityCount("ABILITY_HAN_GUAN_YU_KILLS_" .. k, want - have) end
  end
end

local function CountKill(guanYu)
  local kills = (guanYu:GetProperty(PROP_KILLS) or 0) + 1
  guanYu:SetProperty(PROP_KILLS, kills)
  print("[HanLiuBei] Turn " .. Game.GetCurrentGameTurn() .. " Guan Yu kills: " .. kills)
  UpdateKillStrength(guanYu)
end

local function AweOverChina(guanYu)
  if not HasPromotion(guanYu, EXECUTE_PROMOTION) then return end
  local ownerID = guanYu:GetOwner()
  local diplomacy = Players[ownerID]:GetDiplomacy()
  local x, y = guanYu:GetX(), guanYu:GetY()
  local range, loyalty = AWE_RANGE, AWE_LOYALTY
  if IsFusion(guanYu) then range, loyalty = FUSION_AWE_RANGE, FUSION_AWE_LOYALTY end
  -- 按玩家编号顺序遍历，各端结果一致。
  for playerID = 0, MAX_PLAYERS - 1 do
    local player = Players[playerID]
    if player ~= nil and playerID ~= ownerID and player:IsAlive() and diplomacy:IsAtWarWith(playerID) then
      for _, city in player:GetCities():Members() do
        if Map.GetPlotDistance(x, y, city:GetX(), city:GetY()) <= range then
          city:ChangeLoyalty(loyalty)
          print("[HanLiuBei] Turn " .. Game.GetCurrentGameTurn() .. " Awe Over China: city " .. city:GetID()
            .. " of player " .. playerID .. " loyalty " .. loyalty)
          -- 飘字只是提示，失败不影响效果。
          pcall(function()
            Game.AddWorldViewText(0, Locale.Lookup("LOC_HAN_AWE_OVER_CHINA_FLYOVER", loyalty), city:GetX(), city:GetY())
          end)
        end
      end
    end
  end
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

-- 张飞 · 丈八蛇矛（终极晋升）：张飞攻击城墙全额伤害（修改器，见 Promotions.sql）；每次进攻（打单位或城市都算，
-- 不要求击杀），这一击对目标造成多少伤害，目标身后扇形区域里交战方的作战单位和城市 / 区域就各受同样多的伤害：
-- 单位伤害致死则阵亡；城市 / 区域先扣城墙（全额，不打折）、城墙打空后剩下的扣驻军。
-- 这一击的伤害 = 战斗后目标的伤害 - 战斗前的伤害（目标阵亡或城市被攻下时按战斗前剩余的生命值算）。
-- 战斗事件不带伤害数值，阵亡的目标也找不到了，所以只要有学会丈八蛇矛的张飞或学会白马银枪的赵云，
-- 就在回合开始、他们移动后和每次战斗后，把所有交战方的作战单位和区域按 ID 记下伤害和所在格（SEEN），
-- 同时记下张飞 / 赵云自己所在的格（发起攻击的格）。战斗后按 ID 查记录，得到目标所在格和这一击的伤害。
-- 记录是 Lua 表，只在 GameEvents 回调和脚本加载时更新，联机各端一致；没有记录时按 STRIKE_FALLBACK_DAMAGE 算。
-- 扇形：以目标为顶点、背向张飞的 120° 范围，深 2 格（紧贴目标的 3 格 + 再往后的 5 格，共 8 格），
-- 即满足「张飞到该格的距离 = 张飞到目标 + 目标到该格」的格子。
local ZHANG_FEI = "UNIT_HAN_ZHANG_FEI"
local PIERCE_PROMOTION = "PROMOTION_HAN_ZHANG_FEI_7"
local SECTOR_DEPTH = 2
local STRIKE_FALLBACK_DAMAGE = 30
-- 赵云 · 白马银枪（晋升）：攻击吸血，进攻时对目标造成多少伤害，自己恢复多少生命值。
local LIFESTEAL_UNIT = "UNIT_HAN_ZHAO_YUN"
local LIFESTEAL_PROMOTION = "PROMOTION_HAN_ZHAO_YUN_1"
-- units["玩家:单位ID"] = { 伤害, 格子 }；districts[格子] = { 城墙伤害, 城墙上限, 驻军伤害, 驻军上限 }；
-- places["玩家:区域ID"] / places["玩家:城市ID"] = 格子（城市被攻下后原主人那边就查不到了）；
-- origins["玩家:单位ID"] = { 当前格, 上一个格 }（张飞 / 赵云自己）。
local SEEN = { units = {}, districts = {}, places = {}, origins = {} }

-- 目标周围 SECTOR_DEPTH 格内、背向 fromPlot 的扇形格子，按相邻关系逐圈展开（顺序固定，各端一致）。
local function SectorPlots(fromPlot, targetPlot)
  local fx, fy, tx, ty = fromPlot:GetX(), fromPlot:GetY(), targetPlot:GetX(), targetPlot:GetY()
  local base = Map.GetPlotDistance(fx, fy, tx, ty)
  local result, seen, ring = {}, { [targetPlot:GetIndex()] = true }, { targetPlot }
  for _ = 1, SECTOR_DEPTH do
    local nextRing = {}
    for _, plot in ipairs(ring) do
      for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1 do
        local adjacent = Map.GetAdjacentPlot(plot:GetX(), plot:GetY(), direction)
        if adjacent ~= nil and not seen[adjacent:GetIndex()] then
          seen[adjacent:GetIndex()] = true
          table.insert(nextRing, adjacent)
          local ax, ay = adjacent:GetX(), adjacent:GetY()
          if Map.GetPlotDistance(fx, fy, ax, ay) == base + Map.GetPlotDistance(tx, ty, ax, ay) then
            table.insert(result, adjacent)
          end
        end
      end
    end
    ring = nextRing
  end
  return result
end

local function UnitKey(playerID, unitID) return playerID .. ":" .. unitID end

local function PlotIndexOf(object)
  local plot = Map.GetPlot(object:GetX(), object:GetY())
  return plot ~= nil and plot:GetIndex() or nil
end

-- 某格上与 playerID 交战的城市 / 区域（城市中心、兵营等）。
local function EnemyDistrictAt(plot, playerID)
  if plot == nil then return nil end
  local ownerID = plot:GetOwner()
  if ownerID == nil or ownerID < 0 or not IsAtWar(playerID, ownerID) then return nil end
  for _, district in Players[ownerID]:GetDistricts():Members() do
    if district:GetX() == plot:GetX() and district:GetY() == plot:GetY() then return district end
  end
  return nil
end

local function DefenseState(district)
  local outer, garrison = DefenseTypes.DISTRICT_OUTER, DefenseTypes.DISTRICT_GARRISON
  return { district:GetDamage(outer), district:GetMaxDamage(outer), district:GetDamage(garrison), district:GetMaxDamage(garrison) }
end

local function IsStriker(unit)
  return (IsUnitType(unit, ZHANG_FEI) and HasPromotion(unit, PIERCE_PROMOTION))
    or (IsUnitType(unit, LIFESTEAL_UNIT) and HasPromotion(unit, LIFESTEAL_PROMOTION))
    or IsFusion(unit)
end

-- 刷新记录。clear 时先清空；否则只覆盖还在的，已经阵亡的目标保留旧记录。
local function RecordSurroundings(clear)
  if clear then SEEN = { units = {}, districts = {}, places = {}, origins = SEEN.origins } end
  for playerID = 0, MAX_PLAYERS - 1 do
    local config = PlayerConfigurations[playerID]
    local player = Players[playerID]
    if player ~= nil and config ~= nil and config:GetLeaderTypeName() == LEADER then
      local any = false
      for _, unit in player:GetUnits():Members() do
        if IsStriker(unit) then
          any = true
          local key, index = UnitKey(playerID, unit:GetID()), PlotIndexOf(unit)
          local origin = SEEN.origins[key]
          if origin == nil then
            SEEN.origins[key] = { index, nil }
          elseif origin[1] ~= index then
            SEEN.origins[key] = { index, origin[1] }
          end
        end
      end
      if any then
        for otherID = 0, MAX_PLAYERS - 1 do
          local other = Players[otherID]
          if other ~= nil and IsAtWar(playerID, otherID) then
            for _, enemy in other:GetUnits():Members() do
              if not IsGone(enemy) and enemy:GetCombat() > 0 then
                SEEN.units[UnitKey(otherID, enemy:GetID())] = { enemy:GetDamage(), PlotIndexOf(enemy) }
              end
            end
            for _, district in other:GetDistricts():Members() do
              local index = PlotIndexOf(district)
              if index ~= nil then
                SEEN.districts[index] = DefenseState(district)
                SEEN.places[UnitKey(otherID, district:GetID())] = index
              end
            end
            for _, city in other:GetCities():Members() do
              SEEN.places[UnitKey(otherID, city:GetID())] = PlotIndexOf(city)
            end
          end
        end
      end
    end
  end
end

-- 被攻击的城市 / 区域：战斗事件给的 ID 可能是区域 ID，也可能是城市 ID，两种都试。
local function FindDefendingDistrict(playerID, districtID)
  local player = Players[playerID]
  if player == nil or districtID == nil or districtID < 0 then return nil end
  local district = player:GetDistricts():FindID(districtID)
  if district ~= nil then return district end
  local city = player:GetCities():FindID(districtID)
  if city == nil then return nil end
  for _, d in player:GetDistricts():Members() do
    if d:GetX() == city:GetX() and d:GetY() == city:GetY() then return d end
  end
  return nil
end

-- 返回目标所在格和这一击的伤害（没有记录时伤害为 nil）。
local function StrikeInfo(defenderPlayerID, defenderUnitID, defender, district, defenderDistrictID)
  if defenderUnitID ~= nil and defenderUnitID >= 0 then
    local before = SEEN.units[UnitKey(defenderPlayerID, defenderUnitID)]
    local index = (defender ~= nil and not IsGone(defender)) and PlotIndexOf(defender) or (before and before[2])
      or (defender ~= nil and PlotIndexOf(defender)) or nil
    if before == nil then return index, nil end
    if IsGone(defender) then return index, math.max(0, (defender ~= nil and defender:GetMaxDamage() or 100) - before[1]) end
    return index, defender:GetDamage() - before[1]
  end
  local index = nil
  if district ~= nil then
    index = PlotIndexOf(district)
  elseif defenderDistrictID ~= nil and defenderDistrictID >= 0 then
    index = SEEN.places[UnitKey(defenderPlayerID, defenderDistrictID)]
  end
  if index == nil then return nil, nil end
  local before = SEEN.districts[index]
  if before == nil then return index, nil end
  local plot = Map.GetPlotByIndex(index)
  if district ~= nil and plot:GetOwner() == defenderPlayerID then
    local now = DefenseState(district)
    return index, (now[1] - before[1]) + (now[3] - before[3])
  end
  -- 城市已被攻下：打掉的是战斗前剩下的全部城防。
  return index, (before[2] - before[1]) + (before[4] - before[3])
end

-- 张飞发起攻击的格：还没前进就是他现在的格；已前进到目标格时用记录里的上一个位置；
-- 都不相邻时取目标周围离记录位置最近的格。
local function StrikeOrigin(unit, targetIndex)
  local target = Map.GetPlotByIndex(targetIndex)
  local function adjacentTo(index)
    if index == nil or index == targetIndex then return false end
    local plot = Map.GetPlotByIndex(index)
    return Map.GetPlotDistance(plot:GetX(), plot:GetY(), target:GetX(), target:GetY()) == 1
  end
  local current = PlotIndexOf(unit)
  if adjacentTo(current) then return current end
  local origin = SEEN.origins[UnitKey(unit:GetOwner(), unit:GetID())] or {}
  if adjacentTo(origin[1]) then return origin[1] end
  if adjacentTo(origin[2]) then return origin[2] end
  local ref = origin[1] or origin[2]
  if ref == nil or ref == targetIndex then return nil end
  local refPlot = Map.GetPlotByIndex(ref)
  local best, bestDistance = nil, nil
  for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1 do
    local adjacent = Map.GetAdjacentPlot(target:GetX(), target:GetY(), direction)
    if adjacent ~= nil then
      local d = Map.GetPlotDistance(adjacent:GetX(), adjacent:GetY(), refPlot:GetX(), refPlot:GetY())
      if bestDistance == nil or d < bestDistance then best, bestDistance = adjacent:GetIndex(), d end
    end
  end
  return best
end

-- 城市 / 区域受 amount 点伤害：先扣城墙（全额），城墙打空后剩下的扣驻军。
local function DamageDistrict(district, amount)
  for _, defense in ipairs({ DefenseTypes.DISTRICT_OUTER, DefenseTypes.DISTRICT_GARRISON }) do
    local damage, max = district:GetDamage(defense), district:GetMaxDamage(defense)
    local take = math.min(amount, max - damage)
    if take > 0 then
      district:SetDamage(defense, damage + take)
      amount = amount - take
    end
  end
end

local function Lifesteal(zhaoYun, amount)
  if IsGone(zhaoYun) or not HasPromotion(zhaoYun, LIFESTEAL_PROMOTION) then return end
  if amount == nil then amount = STRIKE_FALLBACK_DAMAGE end
  local heal = math.min(amount, zhaoYun:GetDamage())
  if heal > 0 then
    zhaoYun:ChangeDamage(-heal)
    print("[HanLiuBei] Turn " .. Game.GetCurrentGameTurn() .. " Zhao Yun lifesteal +" .. heal)
  end
end

-- plots 里交战方的作战单位和城市 / 区域各受 amount 点伤害：单位致死则阵亡，城市 / 区域先扣城墙。
local function DamagePlots(ownerID, plots, amount, turn)
  if amount <= 0 then return end
  for _, plot in ipairs(plots) do
    for _, unit in ipairs(EnemyCombatUnitsAt(plot, ownerID)) do
      if unit:GetDamage() + amount >= unit:GetMaxDamage() then
        print(turn .. "killed unit " .. unit:GetID() .. " of player " .. unit:GetOwner())
        UnitManager.Kill(unit)
      else
        print(turn .. "hit unit " .. unit:GetID() .. " of player " .. unit:GetOwner() .. " for " .. amount)
        unit:ChangeDamage(amount)
        UpdateRage(unit)
      end
    end
    local district = EnemyDistrictAt(plot, ownerID)
    if district ~= nil then
      DamageDistrict(district, amount)
      print(turn .. "struck the defenses at " .. plot:GetX() .. "," .. plot:GetY() .. " for " .. amount)
    end
  end
end

local function Pierce(zhangFei, targetIndex, amount)
  if not HasPromotion(zhangFei, PIERCE_PROMOTION) then return end
  local turn = "[HanLiuBei] Turn " .. Game.GetCurrentGameTurn() .. " Zhang Fei "
  if targetIndex == nil then
    print(turn .. "spear: target not found")
    return
  end
  local targetPlot = Map.GetPlotByIndex(targetIndex)
  local fromIndex = StrikeOrigin(zhangFei, targetIndex)
  if fromIndex == nil then
    print(turn .. "spear: origin not found, target " .. targetPlot:GetX() .. "," .. targetPlot:GetY())
    return
  end
  local fromPlot = Map.GetPlotByIndex(fromIndex)
  if amount == nil then
    print(turn .. "spear: no record before the strike, using " .. STRIKE_FALLBACK_DAMAGE)
    amount = STRIKE_FALLBACK_DAMAGE
  end
  local plots = SectorPlots(fromPlot, targetPlot)
  print(turn .. "spear: from " .. fromPlot:GetX() .. "," .. fromPlot:GetY() .. " at " .. targetPlot:GetX() .. ","
    .. targetPlot:GetY() .. ", damage " .. amount .. ", " .. #plots .. " tiles")
  DamagePlots(zhangFei:GetOwner(), plots, amount, turn)
end

-- 五虎神将 · 横扫千军 / 百步穿杨：每次进攻（近战或远程，打单位或城市都算），目标相邻 6 格里交战方的作战单位和
-- 城市 / 区域各受与目标同等的伤害（算法同丈八蛇矛，只是范围换成目标周围一圈）。
local function Sweep(fusion, targetIndex, amount)
  local turn = "[HanLiuBei] Turn " .. Game.GetCurrentGameTurn() .. " Five Tigers "
  if targetIndex == nil then
    print(turn .. "sweep: target not found")
    return
  end
  if amount == nil then
    print(turn .. "sweep: no record before the strike, using " .. STRIKE_FALLBACK_DAMAGE)
    amount = STRIKE_FALLBACK_DAMAGE
  end
  local target = Map.GetPlotByIndex(targetIndex)
  local plots = {}
  for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1 do
    local adjacent = Map.GetAdjacentPlot(target:GetX(), target:GetY(), direction)
    if adjacent ~= nil then table.insert(plots, adjacent) end
  end
  print(turn .. "sweep: at " .. target:GetX() .. "," .. target:GetY() .. ", damage " .. amount)
  DamagePlots(fusion:GetOwner(), plots, amount, turn)
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
-- 诸葛亮一起合体的五虎神将：单位属性 HAN_WUHU_ZGL，统率 5 倍（ABILITY_HAN_WUHU_COMMAND）、七星续命。
local PROP_WUHU_ZGL = "HAN_WUHU_ZGL"
local FUSION_COMMAND = "ABILITY_HAN_WUHU_COMMAND"

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
      -- 五虎神将算作五位武将，五虎齐心时开全部五个光环；带着诸葛亮合体的改开 5 倍光环，其余都关。
      local fiveFold = IsFusion(unit) and unit:GetProperty(PROP_WUHU_ZGL) ~= nil
      if IsFusion(unit) then SetAbility(unit, FUSION_COMMAND, fiveFold) end
      for _, tiger in ipairs(TIGERS) do
        local unitRow = GameInfo.Units[tiger.Unit]
        if unitRow ~= nil and (unit:GetType() == unitRow.Index or IsFusion(unit)) then
          SetAbility(unit, SHARED_COMMAND, not stacking and not fiveFold)
          SetAbility(unit, "ABILITY_HAN_TIGER_COMMAND_" .. string.sub(tiger.Unit, 10), stacking and not fiveFold)
        end
      end
    end
  end
end

-- 诸葛亮（军师，远程作战单位）。
local ARROWS_PROMOTION = "PROMOTION_HAN_ZHUGE_LIANG_1"
local DEBATE_PROMOTION = "PROMOTION_HAN_ZHUGE_LIANG_2"
local FIRE_PROMOTION = "PROMOTION_HAN_ZHUGE_LIANG_6"
local QIXING_PROMOTION = "PROMOTION_HAN_ZHUGE_LIANG_8"

local function IsZhugeLiang(unit) return IsUnitType(unit, ZHUGE_LIANG) end

-- 借东风 · 火攻：诸葛亮远程攻击后，目标所在格和周围一格里交战方的作战单位被点燃（单位属性记剩余回合和每回合伤害），
-- 在被点燃单位的主人回合开始时受伤，伤害致死则阵亡。15 × 2 回合，火烧博望后 25 × 3 回合；重复点燃取较大值。
local BURN_DAMAGE, BURN_TURNS = 15, 2
local BURN_DAMAGE_PROMOTED, BURN_TURNS_PROMOTED = 25, 3
local PROP_BURN_TURNS = "HAN_BURN_TURNS"
local PROP_BURN_DAMAGE = "HAN_BURN_DAMAGE"

local function Ignite(zhugeLiang, targetX, targetY)
  local fierce = HasPromotion(zhugeLiang, FIRE_PROMOTION)
  local damage = fierce and BURN_DAMAGE_PROMOTED or BURN_DAMAGE
  local turns = fierce and BURN_TURNS_PROMOTED or BURN_TURNS
  local plots = { Map.GetPlot(targetX, targetY) }
  for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1 do
    table.insert(plots, Map.GetAdjacentPlot(targetX, targetY, direction))
  end
  for _, plot in ipairs(plots) do
    for _, unit in ipairs(EnemyCombatUnitsAt(plot, zhugeLiang:GetOwner())) do
      unit:SetProperty(PROP_BURN_TURNS, math.max(unit:GetProperty(PROP_BURN_TURNS) or 0, turns))
      unit:SetProperty(PROP_BURN_DAMAGE, math.max(unit:GetProperty(PROP_BURN_DAMAGE) or 0, damage))
      print("[HanLiuBei] Turn " .. Game.GetCurrentGameTurn() .. " East Wind: unit " .. unit:GetID() .. " of player "
        .. unit:GetOwner() .. " burning " .. damage .. " x " .. turns)
    end
  end
end

local function TickBurns(playerID)
  local player = Players[playerID]
  if player == nil then return end
  for _, unit in player:GetUnits():Members() do
    local turns = unit:GetProperty(PROP_BURN_TURNS)
    if turns ~= nil and turns > 0 and not IsGone(unit) then
      local damage = unit:GetProperty(PROP_BURN_DAMAGE) or BURN_DAMAGE
      if turns > 1 then
        unit:SetProperty(PROP_BURN_TURNS, turns - 1)
      else
        unit:SetProperty(PROP_BURN_TURNS, nil)
        unit:SetProperty(PROP_BURN_DAMAGE, nil)
      end
      print("[HanLiuBei] Turn " .. Game.GetCurrentGameTurn() .. " East Wind: unit " .. unit:GetID() .. " of player " .. playerID .. " burns for " .. damage)
      if unit:GetDamage() + damage >= unit:GetMaxDamage() then
        UnitManager.Kill(unit)
      else
        unit:ChangeDamage(damage)
        UpdateRage(unit)
      end
    end
  end
end

-- 空城计：刘备回合开始时，站在本方城市中心上的诸葛亮让这座城的城墙和驻军防御回满。
local function EmptyFort(playerID)
  local player = Players[playerID]
  local center = GameInfo.Districts["DISTRICT_CITY_CENTER"]
  if player == nil or center == nil then return end
  for _, unit in player:GetUnits():Members() do
    if IsZhugeLiang(unit) then
      for _, district in player:GetDistricts():Members() do
        if district:GetType() == center.Index and district:GetX() == unit:GetX() and district:GetY() == unit:GetY() then
          for _, defense in ipairs({ DefenseTypes.DISTRICT_OUTER, DefenseTypes.DISTRICT_GARRISON }) do
            if district:GetDamage(defense) > 0 then district:SetDamage(defense, 0) end
          end
        end
      end
    end
  end
end

-- 舌战群儒（晋升）：刘备回合开始时，诸葛亮 6 格内城邦和自由城市（非主要文明、非蛮族）的城市各 -5 忠诚度。
local DEBATE_RANGE = 6
local DEBATE_LOYALTY = -5

local function Debate(playerID)
  local player = Players[playerID]
  if player == nil then return end
  for _, unit in player:GetUnits():Members() do
    if IsZhugeLiang(unit) and HasPromotion(unit, DEBATE_PROMOTION) then
      -- 按玩家编号顺序遍历，各端一致。
      for otherID = 0, MAX_PLAYERS - 1 do
        local other = Players[otherID]
        if other ~= nil and otherID ~= playerID and other:IsAlive() and not other:IsMajor() and not other:IsBarbarian() then
          for _, city in other:GetCities():Members() do
            if Map.GetPlotDistance(unit:GetX(), unit:GetY(), city:GetX(), city:GetY()) <= DEBATE_RANGE then
              city:ChangeLoyalty(DEBATE_LOYALTY)
              print("[HanLiuBei] Turn " .. Game.GetCurrentGameTurn() .. " Debate: city " .. city:GetID() .. " of player " .. otherID .. " loyalty " .. DEBATE_LOYALTY)
            end
          end
        end
      end
    end
  end
end

-- 草船借箭（晋升）：诸葛亮受到远程攻击（远程单位或城市 / 区域）后，恢复这一击造成的生命值。
-- 战斗事件不带伤害，所以在回合开始、每次战斗后和读档时记下各诸葛亮的伤害（Lua 表，只读游戏状态）。
local ZGL_DAMAGE = {}

local function RecordZhugeLiang()
  ZGL_DAMAGE = {}
  for playerID = 0, MAX_PLAYERS - 1 do
    local player = Players[playerID]
    if player ~= nil then
      for _, unit in player:GetUnits():Members() do
        if IsZhugeLiang(unit) then ZGL_DAMAGE[UnitKey(playerID, unit:GetID())] = unit:GetDamage() end
      end
    end
  end
end

local function BorrowArrows(zhugeLiang, attacker, attackerIsUnit)
  if IsGone(zhugeLiang) or not HasPromotion(zhugeLiang, ARROWS_PROMOTION) then return end
  local ranged = not attackerIsUnit
  if attacker ~= nil then
    local row = GameInfo.Units[attacker:GetType()]
    ranged = row ~= nil and (row.RangedCombat > 0 or row.Bombard > 0)
  end
  local before = ZGL_DAMAGE[UnitKey(zhugeLiang:GetOwner(), zhugeLiang:GetID())]
  if not ranged or before == nil then return end
  local heal = zhugeLiang:GetDamage() - before
  if heal > 0 then
    zhugeLiang:ChangeDamage(-heal)
    print("[HanLiuBei] Turn " .. Game.GetCurrentGameTurn() .. " Borrowing Arrows +" .. heal)
  end
end

-- 七星续命：诸葛亮（晋升）和带着诸葛亮合体的五虎神将，每局各一次，阵亡时在首都重新出现，生命值全满。
-- 游戏没法阻止阵亡，所以在战斗事件里（阵亡的单位还能读到）记下经验、晋升和单位属性，在首都重建一个。
-- 晋升用 SetPromotion 恢复；游戏没有这个接口时只恢复经验，Lua.log 会提示。
local PROP_QIXING = "HAN_QIXING_"
local CARRIED_PROPERTIES = { PROP_KILLS, PROP_WUHU_ZGL }

local function CanProlongLife(unit)
  if unit == nil or not IsGone(unit) then return false end
  if IsZhugeLiang(unit) then return HasPromotion(unit, QIXING_PROMOTION) end
  local fusionRow = GameInfo.Units[FUSION]
  return fusionRow ~= nil and unit:GetType() == fusionRow.Index and unit:GetProperty(PROP_WUHU_ZGL) ~= nil
end

local function ProlongLife(unit)
  if not CanProlongLife(unit) then return end
  local playerID = unit:GetOwner()
  local player = Players[playerID]
  local unitRow = GameInfo.Units[unit:GetType()]
  local key = PROP_QIXING .. unitRow.UnitType
  if player == nil or player:GetProperty(key) ~= nil then return end
  local capital = player:GetCities():GetCapitalCity()
  if capital == nil then return end
  local experience = unit:GetExperience()
  local xp = experience:GetExperiencePoints()
  local promotions = {}
  for row in GameInfo.UnitPromotions() do
    if experience:HasPromotion(row.Index) then table.insert(promotions, row.Index) end
  end
  local carried = {}
  for _, name in ipairs(CARRIED_PROPERTIES) do carried[name] = unit:GetProperty(name) end
  local existing = {}
  for _, other in player:GetUnits():Members() do existing[other:GetID()] = true end
  UnitManager.InitUnitValidAdjacentHex(playerID, unitRow.UnitType, capital:GetX(), capital:GetY(), 1)
  local reborn = nil
  for _, other in player:GetUnits():Members() do
    if not existing[other:GetID()] and other:GetType() == unitRow.Index and not IsGone(other) then reborn = other end
  end
  if reborn == nil then
    print("[HanLiuBei] Turn " .. Game.GetCurrentGameTurn() .. " Seven Stars: could not place " .. unitRow.UnitType)
    return
  end
  player:SetProperty(key, Game.GetCurrentGameTurn())
  local newExperience = reborn:GetExperience()
  local missing = xp - newExperience:GetExperiencePoints()
  if missing > 0 then newExperience:ChangeExperience(missing) end
  for _, index in ipairs(promotions) do
    local ok = pcall(function() newExperience:SetPromotion(index) end)
    if not ok then
      print("[HanLiuBei] Seven Stars: SetPromotion is not available, promotions were not restored")
      break
    end
  end
  for name, value in pairs(carried) do reborn:SetProperty(name, value) end
  print("[HanLiuBei] Turn " .. Game.GetCurrentGameTurn() .. " Seven Stars: " .. unitRow.UnitType .. " of player " .. playerID .. " reborn in the capital")
  pcall(function()
    NotificationManager.SendNotification(playerID, NotificationTypes.USER_DEFINED_1,
      Locale.Lookup("LOC_HAN_QIXING_MESSAGE", unitRow.Name), Locale.Lookup("LOC_HAN_QIXING_SUMMARY", unitRow.Name, capital:GetName()),
      capital:GetX(), capital:GetY())
  end)
end

-- 马超 · 神威天将军（终极晋升）：西凉铁骑冲锋。回合开始记下位置、格数清零；每次移动累加走过的距离；
-- 按格数开 ABILITY_HAN_MA_CHAO_CHARGE_<1~30> 中的一档（各档是累计值，进攻 +4 × 格数）。
-- 不设上限：数据库预生成 30 档，一回合实际走不到 30 格。
-- 按走过的格数而不是消耗的移动力算：进入区域控制会清空移动力，不能因此吃满加成。
local CHARGE_PROMOTION = "PROMOTION_HAN_MA_CHAO_7"
local CHARGE_MAX_TILES = 30
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
local SEVEN_PROMOTION = "PROMOTION_HAN_ZHAO_YUN_7"

local function SevenInSevenOut(zhaoYun)
  if not HasPromotion(zhaoYun, SEVEN_PROMOTION) then return end
  local missing = zhaoYun:GetMaxMoves() - zhaoYun:GetMovesRemaining()
  if missing > 0 then zhaoYun:ChangeMovesRemaining(missing) end
end

-- 五虎将不编成军团 / 军队：祖鲁 Isibongo（文明征服模式可激活）等效果会在攻下城市时把攻城单位升为军团 / 军队，
-- 这是玩家级效果，数据里排除不了某个单位，所以在破城后和回合开始把五虎将（和诸葛亮）改回单兵。
local function KeepTigersStandard(playerID)
  local player = Players[playerID]
  if player == nil then return end
  for _, unit in player:GetUnits():Members() do
    if not IsGone(unit) and (IsTiger(unit) or IsUnitType(unit, ZHUGE_LIANG)) and unit:GetMilitaryFormation() ~= MilitaryFormationTypes.STANDARD_FORMATION then
      unit:SetMilitaryFormation(MilitaryFormationTypes.STANDARD_FORMATION)
      print("[HanLiuBei] Turn " .. Game.GetCurrentGameTurn() .. " reset " .. GameInfo.Units[unit:GetType()].UnitType .. " to a single unit")
    end
  end
end

-- 五虎合体：五位武将都还活着、都学会了终极晋升、都在关羽 1 格以内时，刘备回合开始把五人永久合为五虎神将（每局一次）。
-- 诸葛亮也在关羽 1 格以内的话一起合入（可选）：五虎神将记 HAN_WUHU_ZGL，统率 5 倍、获得七星续命。
-- 先在关羽旁放下五虎神将（同格放不下作战单位），放成功再移除五人；放不下就等下回合。
local PROP_FUSED = "HAN_WUHU"
local ULTIMATE = 7

local function HasUltimate(unit, tigerUnit)
  return HasPromotion(unit, "PROMOTION_HAN_" .. string.sub(tigerUnit, 10) .. "_" .. ULTIMATE)
end

local function TryFuse(playerID)
  local config = PlayerConfigurations[playerID]
  local player = Players[playerID]
  if config == nil or config:GetLeaderTypeName() ~= LEADER or player == nil then return end
  local fusionRow = GameInfo.Units[FUSION]
  if fusionRow == nil or player:GetProperty(PROP_FUSED) ~= nil then return end
  -- 按 TIGERS 顺序找人，各端一致。
  local members = {}
  for _, tiger in ipairs(TIGERS) do
    local unitRow = GameInfo.Units[tiger.Unit]
    local found = nil
    for _, unit in player:GetUnits():Members() do
      if unitRow ~= nil and not IsGone(unit) and unit:GetType() == unitRow.Index then found = unit end
    end
    if found == nil or not HasUltimate(found, tiger.Unit) then return end
    table.insert(members, found)
  end
  local x, y = members[1]:GetX(), members[1]:GetY()
  for _, unit in ipairs(members) do
    if Map.GetPlotDistance(x, y, unit:GetX(), unit:GetY()) > 1 then return end
  end
  local strategist = nil
  for _, unit in player:GetUnits():Members() do
    if IsZhugeLiang(unit) and not IsGone(unit) and Map.GetPlotDistance(x, y, unit:GetX(), unit:GetY()) <= 1 then strategist = unit end
  end
  local before = CountUnits(player, fusionRow.Index)
  UnitManager.InitUnitValidAdjacentHex(playerID, FUSION, x, y, 1)
  if CountUnits(player, fusionRow.Index) <= before then
    print("[HanLiuBei] Turn " .. Game.GetCurrentGameTurn() .. " player " .. playerID .. " could not place " .. FUSION .. ", retrying next turn")
    return
  end
  -- 过五关斩六将：继承关羽一生的击杀数，之后继续累计。
  local kills = members[1]:GetProperty(PROP_KILLS) or 0
  for _, unit in player:GetUnits():Members() do
    if IsFusion(unit) then
      unit:SetProperty(PROP_KILLS, kills)
      if strategist ~= nil then unit:SetProperty(PROP_WUHU_ZGL, Game.GetCurrentGameTurn()) end
      UpdateKillStrength(unit)
      UpdateJump(unit)
    end
  end
  for _, unit in ipairs(members) do UnitManager.Kill(unit) end
  if strategist ~= nil then
    UnitManager.Kill(strategist)
    print("[HanLiuBei] Turn " .. Game.GetCurrentGameTurn() .. " Zhuge Liang joined the merge")
  end
  UpdateCommand(playerID)
  player:SetProperty(PROP_FUSED, Game.GetCurrentGameTurn())
  print("[HanLiuBei] Turn " .. Game.GetCurrentGameTurn() .. " player " .. playerID .. " merged the Five Tigers into " .. FUSION)
  -- 通知只是提示，失败不影响合体。
  pcall(function()
    NotificationManager.SendNotification(playerID, NotificationTypes.USER_DEFINED_1,
      Locale.Lookup("LOC_HAN_WUHU_MESSAGE"), Locale.Lookup("LOC_HAN_WUHU_SUMMARY"), x, y)
  end)
end

-- 破城：关羽、赵云攻下城市也算一次击杀（威震华夏 / 七进七出照常要求终极晋升）。
-- 攻城的单位通常已站在城里；万一 CityConquered 早于前进，就看本回合打过这座城的记号。
local PROP_SIEGE = "HAN_SIEGE"

local function MarkSiege(unit, targetX, targetY)
  if not (IsGuanYu(unit) or IsZhaoYunLike(unit)) then return end
  unit:SetProperty(PROP_SIEGE, Game.GetCurrentGameTurn() * 100000 + Map.GetPlot(targetX, targetY):GetIndex())
end

local function OnCityConquered(capturerID, ownerID, cityID, cityX, cityY)
  local player = Players[capturerID]
  local plot = Map.GetPlot(cityX, cityY)
  if player == nil or plot == nil then return end
  local siege = Game.GetCurrentGameTurn() * 100000 + plot:GetIndex()
  for _, unit in player:GetUnits():Members() do
    if not IsGone(unit) and ((unit:GetX() == cityX and unit:GetY() == cityY) or unit:GetProperty(PROP_SIEGE) == siege) then
      if IsGuanYu(unit) then
        print("[HanLiuBei] Turn " .. Game.GetCurrentGameTurn() .. " Guan Yu took city " .. cityID .. " of player " .. ownerID)
        AweOverChina(unit)
      end
      -- 五虎神将两样都算。
      if IsZhaoYunLike(unit) then
        print("[HanLiuBei] Turn " .. Game.GetCurrentGameTurn() .. " Zhao Yun took city " .. cityID .. " of player " .. ownerID)
        SevenInSevenOut(unit)
      end
      unit:SetProperty(PROP_SIEGE, nil)
    end
  end
  KeepTigersStandard(capturerID)
end

-- 厚施恩德的远程部分：原版忠诚度压力只到 9 格，引擎没有按玩家调范围的效果，所以由脚本补上 10~18 格。
-- 刘备回合开始时，其他主要文明的每座城市按 10~18 格内汉城市的人口合计，每 2 人口 -1 忠诚度，每回合最多 -20（与原版每回合忠诚度变化的上限相同）。
-- 只扣数值，不进忠诚度面板的压力明细，也不参与「压力最高时直接归降」的判断。
local FAR_PRESSURE_MIN = 10
local FAR_PRESSURE_MAX = 18
local FAR_PRESSURE_POP_PER_LOYALTY = 2
local FAR_PRESSURE_CAP = 20

local function FarPressure(playerID)
  local config = PlayerConfigurations[playerID]
  local player = Players[playerID]
  if config == nil or config:GetLeaderTypeName() ~= LEADER or player == nil then return end
  local hanCities = {}
  for _, city in player:GetCities():Members() do
    table.insert(hanCities, { X = city:GetX(), Y = city:GetY(), Pop = city:GetPopulation() })
  end
  if #hanCities == 0 then return end
  -- 按玩家编号顺序遍历，各端结果一致。
  for otherID = 0, MAX_PLAYERS - 1 do
    local other = Players[otherID]
    if other ~= nil and otherID ~= playerID and other:IsAlive() and other:IsMajor() then
      for _, city in other:GetCities():Members() do
        local pop = 0
        for _, han in ipairs(hanCities) do
          local distance = Map.GetPlotDistance(han.X, han.Y, city:GetX(), city:GetY())
          if distance >= FAR_PRESSURE_MIN and distance <= FAR_PRESSURE_MAX then pop = pop + han.Pop end
        end
        local amount = math.min(math.floor(pop / FAR_PRESSURE_POP_PER_LOYALTY), FAR_PRESSURE_CAP)
        if amount > 0 then
          city:ChangeLoyalty(-amount)
          print("[HanLiuBei] Turn " .. Game.GetCurrentGameTurn() .. " far pressure: city " .. city:GetID()
            .. " of player " .. otherID .. " population " .. pop .. " loyalty -" .. amount)
        end
      end
    end
  end
end

-- 刘备不获得大将军点数：特性里的 -100% 修改器挡不住所有来源（政策、奇观、按击杀给点数的特色单位等），
-- 所以在回合开始、回合开始结算完和每次战斗后，把刘备的大将军点数直接清零，点数永远攒不到招募线。
local GENERAL_CLASS = "GREAT_PERSON_CLASS_GENERAL"
local warnedNoChangePoints = false

local function ClearGeneralPoints(playerID)
  local config = PlayerConfigurations[playerID]
  local player = Players[playerID]
  if config == nil or config:GetLeaderTypeName() ~= LEADER or player == nil then return end
  local class = GameInfo.GreatPersonClasses[GENERAL_CLASS]
  if class == nil then return end
  local points = player:GetGreatPeoplePoints()
  if points == nil then return end
  if points.ChangePointsTotal == nil then
    if not warnedNoChangePoints then
      warnedNoChangePoints = true
      print("[HanLiuBei] GetGreatPeoplePoints():ChangePointsTotal is not available, cannot clear Great General points")
    end
    return
  end
  local total = points:GetPointsTotal(class.Index)
  if total ~= nil and total > 0 then
    points:ChangePointsTotal(class.Index, -total)
    local perTurn = "?"
    pcall(function() perTurn = tostring(points:GetPointsPerTurn(class.Index)) end)
    print("[HanLiuBei] Turn " .. Game.GetCurrentGameTurn() .. " player " .. playerID .. " cleared " .. total
      .. " Great General points (per turn " .. perTurn .. ")")
  end
end

-- 调试：曼丁哥市场（文明征服模式激活）和蜀道在商业中心上是否叠加。刘备回合开始时每个商业中心打一行：
-- 金币产出、其中的相邻加成、相邻山脉 / 丘陵数、是否相邻圣地 / 修道院、是否临河。只读取，不改游戏状态。
local DEBUG_COMMERCIAL_HUBS = true

local function LogCommercialHubs(playerID)
  local config = PlayerConfigurations[playerID]
  local player = Players[playerID]
  if not DEBUG_COMMERCIAL_HUBS or config == nil or config:GetLeaderTypeName() ~= LEADER or player == nil then return end
  local hub, gold = GameInfo.Districts["DISTRICT_COMMERCIAL_HUB"], GameInfo.Yields["YIELD_GOLD"]
  if hub == nil or gold == nil then return end
  local holy, lavra = GameInfo.Districts["DISTRICT_HOLY_SITE"], GameInfo.Districts["DISTRICT_LAVRA"]
  for _, city in player:GetCities():Members() do
    for _, district in city:GetDistricts():Members() do
      if district:GetType() == hub.Index and district:IsComplete() then
        local x, y = district:GetX(), district:GetY()
        local plot = Map.GetPlot(x, y)
        local hills, holySite = 0, false
        for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1 do
          local adjacent = Map.GetAdjacentPlot(x, y, direction)
          if adjacent ~= nil then
            if adjacent:IsHills() or adjacent:IsMountain() then hills = hills + 1 end
            local t = adjacent:GetDistrictType()
            if (holy ~= nil and t == holy.Index) or (lavra ~= nil and t == lavra.Index) then holySite = true end
          end
        end
        local total, adjacency = "?", "?"
        pcall(function() total = tostring(district:GetYield(gold.Index)) end)
        pcall(function() adjacency = tostring(district:GetAdjacencyYield(gold.Index)) end)
        print("[HanLiuBei] Turn " .. Game.GetCurrentGameTurn() .. " commercial hub " .. Locale.Lookup(city:GetName())
          .. " at " .. x .. "," .. y .. ": gold " .. total .. " (adjacency " .. adjacency .. "), mountain/hills "
          .. hills .. ", holy site " .. tostring(holySite) .. ", river " .. tostring(plot:IsRiver()))
      end
    end
  end
end

local function OnUnitMoved(playerID, unitID)
  local unit = FindUnit(playerID, unitID)
  if IsStriker(unit) then RecordSurroundings(false) end
  if IsMaChaoLike(unit) then RecordCharge(unit) end
  UpdateJump(unit)
  if IsGuanYu(unit) then UpdateKillStrength(unit) end
  if IsUnitType(unit, ZHUGE_LIANG) then UpdateCommand(playerID) end
  -- 破城后单位前进进城时才会被编成军团的话，也在这里改回来。
  if unit ~= nil and IsTiger(unit) then KeepTigersStandard(playerID) end
end

local function OnCombatOccurred(attackerPlayerID, attackerUnitID, defenderPlayerID, defenderUnitID, attackerDistrictID, defenderDistrictID)
  local attacker = FindUnit(attackerPlayerID, attackerUnitID)
  local defender = FindUnit(defenderPlayerID, defenderUnitID)
  local defenderIsUnit = Players[defenderPlayerID] ~= nil and defenderUnitID ~= nil and defenderUnitID >= 0
  local attackerIsUnit = Players[attackerPlayerID] ~= nil and attackerUnitID ~= nil and attackerUnitID >= 0
  -- 草船借箭要用战斗前记下的伤害，先算。
  if IsZhugeLiang(defender) then BorrowArrows(defender, attacker, attackerIsUnit) end
  -- 目标位置：防守单位（阵亡的也还能取到）或被攻击的城市 / 区域。
  local targetX, targetY = nil, nil
  if defender ~= nil then
    targetX, targetY = defender:GetX(), defender:GetY()
  elseif Players[defenderPlayerID] ~= nil and defenderDistrictID ~= nil and defenderDistrictID >= 0 then
    local district = Players[defenderPlayerID]:GetDistricts():FindID(defenderDistrictID)
    if district ~= nil then targetX, targetY = district:GetX(), district:GetY() end
  end
  -- 张飞 / 赵云这一击的目标格和伤害要在其他效果（万箭齐发、斩首）改动之前算。
  local strikeIndex, strike = nil, nil
  if IsUnitType(attacker, ZHANG_FEI) or IsUnitType(attacker, LIFESTEAL_UNIT) or IsFusion(attacker) then
    local district = defenderIsUnit and nil or FindDefendingDistrict(defenderPlayerID, defenderDistrictID)
    strikeIndex, strike = StrikeInfo(defenderPlayerID, defenderUnitID, defender, district, defenderDistrictID)
    if targetX == nil and strikeIndex ~= nil then
      local plot = Map.GetPlotByIndex(strikeIndex)
      targetX, targetY = plot:GetX(), plot:GetY()
    end
  end
  if IsUnitType(attacker, HUANG_ZHONG) and targetX ~= nil then
    Volley(attacker, targetX, targetY)
  end
  if IsZhugeLiang(attacker) and targetX ~= nil then Ignite(attacker, targetX, targetY) end
  if TryExecute(attacker, defender) then defender = nil end
  if IsUnitType(attacker, ZHANG_FEI) then Pierce(attacker, strikeIndex, strike) end
  if IsFusion(attacker) then Sweep(attacker, strikeIndex, strike) end
  if attacker ~= nil and not defenderIsUnit and targetX ~= nil then MarkSiege(attacker, targetX, targetY) end
  -- 只算单位之间的击杀（打城市 / 区域不算）。
  if IsGuanYu(attacker) and defenderIsUnit and IsGone(defender) then
    CountKill(attacker)
    AweOverChina(attacker)
  elseif IsGuanYu(defender) and attackerIsUnit and IsGone(attacker) then
    CountKill(defender)
    AweOverChina(defender)
  end
  if IsZhaoYunLike(attacker) then Lifesteal(attacker, strike) end
  if IsZhaoYunLike(attacker) and defenderIsUnit and IsGone(defender) then
    SevenInSevenOut(attacker)
  end
  -- 七星续命：阵亡的单位在同一次战斗事件里还能读到。
  ProlongLife(attacker)
  ProlongLife(defender)
  if not IsGone(attacker) then UpdateRage(attacker) end
  if not IsGone(defender) then UpdateRage(defender) end
  UpdateCommand(attackerPlayerID)
  UpdateCommand(defenderPlayerID)
  RecordSurroundings(false)
  RecordZhugeLiang()
  ClearGeneralPoints(attackerPlayerID)
  ClearGeneralPoints(defenderPlayerID)
end

local function OnPlayerTurnStarted(playerID)
  ClearGeneralPoints(playerID)
  TickBurns(playerID)
  FarPressure(playerID)
  EmptyFort(playerID)
  Debate(playerID)
  -- 调试日志出错不能影响后面的发放和合体。
  local ok, err = pcall(LogCommercialHubs, playerID)
  if not ok then print("[HanLiuBei] commercial hub log failed: " .. tostring(err)) end
  KeepTigersStandard(playerID)
  TryGrant(playerID, nil)
  TryFuse(playerID)
  UpdatePlayerRage(playerID)
  UpdateCommand(playerID)
  local player = Players[playerID]
  if player == nil then return end
  for _, unit in player:GetUnits():Members() do
    if IsMaChaoLike(unit) then ResetCharge(unit) end
    UpdateJump(unit)
    if IsGuanYu(unit) then UpdateKillStrength(unit) end
  end
  RecordSurroundings(true)
end

-- 回合开始的回血结算完后再刷新残血档位、再记一次伤害。
local function OnPlayerTurnStartComplete(playerID)
  ClearGeneralPoints(playerID)
  UpdatePlayerRage(playerID)
  local player = Players[playerID]
  if player ~= nil then
    for _, unit in player:GetUnits():Members() do UpdateJump(unit) end
  end
  RecordSurroundings(false)
  RecordZhugeLiang()
end

local function OnCityBuilt(playerID, cityID, x, y)
  TryGrant(playerID, CityManager.GetCity(playerID, cityID))
  UpdateCommand(playerID)
end

GameEvents.CityBuilt.Add(OnCityBuilt)
GameEvents.PlayerTurnStarted.Add(OnPlayerTurnStarted)
-- 回合开始的回血可能在 PlayerTurnStarted 之后结算，结算完成后再刷新一次。
GameEvents.PlayerTurnStartComplete.Add(OnPlayerTurnStartComplete)
GameEvents.OnCombatOccurred.Add(OnCombatOccurred)
GameEvents.OnUnitMoved.Add(OnUnitMoved)
GameEvents.CityConquered.Add(OnCityConquered)
-- 读档后先记一次（只读取，不改游戏状态）。
RecordSurroundings(true)
RecordZhugeLiang()
print("[HanLiuBei] HanTigers loaded")
