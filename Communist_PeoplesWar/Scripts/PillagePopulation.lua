-- Authoritative gameplay hook. One city-population change per successful pillage event.
-- Reference signature: GameEvents.OnPillage(player, unit, improvement, building, district, plotIndex).
local CIVILIZATION = "CIVILIZATION_COMMUNIST"
local function IsValidType(index)
  return type(index) == "number" and index >= 0
end
local function OnPillage(playerID, unitID, improvementID, buildingID, districtID, plotIndex)
  local player = Players[playerID]
  local config = PlayerConfigurations[playerID]
  if not player or not config or config:GetCivilizationTypeName() ~= CIVILIZATION then return end
  -- Roads, trade-route plunder and unrelated events do not reduce population.
  if not (IsValidType(improvementID) or IsValidType(buildingID) or IsValidType(districtID)) then return end
  local unit = player:GetUnits():FindID(unitID)
  if not unit then return end
  local plot = Map.GetPlotByIndex(plotIndex)
  if not plot then return end
  -- The event follows a successful pillage; healing does not require an owned city.
  unit:SetDamage(0)
  local owner = plot:GetOwner()
  if owner == nil or owner < 0 or owner == playerID then return end
  if not player:GetDiplomacy():IsAtWarWith(owner) then return end
  -- Use the city that owns this tile, never the nearest city.
  local city = Cities.GetPlotPurchaseCity(plot:GetX(), plot:GetY())
  if not city or city:GetOwner() ~= owner then return end
  if city:GetPopulation() <= 1 then return end
  city:ChangePopulation(-1)
  print("[CommunistPW] Pillage: city " .. tostring(city:GetID()) .. " owner " .. tostring(owner) .. " population -1")
end
GameEvents.OnPillage.Add(OnPillage)
