-- Author: EnormousApplePie (modified)

include("Lekmod_utilities.lua")

local this_civ = GameInfoTypes["CIVILIZATION_AKSUM"]
local is_active = LekmodUtilities:is_civilization_active(this_civ)

-- Building/resource/tech types
local stone_works = GameInfoTypes["BUILDING_STONE_WORKS"]
local walls = GameInfoTypes["BUILDING_WALLS"]
local resource_stone = GameInfoTypes["RESOURCE_STONE"]
local tech_masonry = GameInfoTypes["TECH_MASONRY"]
local port_of_adulis = GameInfoTypes["BUILDING_AKSUM_PORT_OF_ADULIS"]

------------------------------------------------------------------------------------------------------------------------
-- Aksum UA. Settling on Stone (if Masonry researched) grants free Stone Works and Walls.
------------------------------------------------------------------------------------------------------------------------
function lekmod_aksum_ua_stone_settling(player_id, x, y)

   local player = Players[player_id]
   if not player:IsAlive() or player:GetCivilizationType() ~= this_civ then return end

   -- Check if player has Masonry
   if not Teams[player:GetTeam()]:IsHasTech(tech_masonry) then return end

   -- Get the city plot and check for Stone resource
   local plot = Map.GetPlot(x, y)
   if not plot then return end

   local resource_type = plot:GetResourceType()
   if resource_type ~= resource_stone then return end

   -- Get the city
   local city = plot:GetPlotCity()
   if not city then return end

   -- Grant free Stone Works and Walls
   city:SetNumRealBuilding(stone_works, 1)
   city:SetNumRealBuilding(walls, 1)

   -- Show notification to human player
   if player:IsHuman() and Game.GetActivePlayer() == player_id then
      local city_name = city:GetName()
      Events.GameplayAlertMessage(city_name .. " was founded on Stone and received a free Stone Works and Walls!")
   end

end

------------------------------------------------------------------------------------------------------------------------
-- Aksum UA. First coastal city receives Port of Adulis (free Lighthouse + trade bonuses + 33% caravan/cargo production).
------------------------------------------------------------------------------------------------------------------------
function lekmod_aksum_ua_port_of_adulis(player_id, x, y)

   local player = Players[player_id]
   if not player:IsAlive() or player:GetCivilizationType() ~= this_civ then return end

   local plot = Map.GetPlot(x, y)
   if not plot then return end

   -- Must be coastal
   if not plot:IsCoastalLand() then return end

   local city = plot:GetPlotCity()
   if not city then return end

   -- Count coastal cities (includes the one just founded); grant Port only if this is the first
   local coastal_count = 0
   for iCity = 0, player:GetNumCities() - 1 do
      local pCity = player:GetCityByID(iCity)
      if pCity then
         local pCityPlot = Map.GetPlot(pCity:GetX(), pCity:GetY())
         if pCityPlot and pCityPlot:IsCoastalLand() then
            coastal_count = coastal_count + 1
         end
      end
   end
   if coastal_count ~= 1 then return end

   -- Grant Port of Adulis (includes free Lighthouse via FreeBuildingThisCity)
   city:SetNumRealBuilding(port_of_adulis, 1)

   if player:IsHuman() and Game.GetActivePlayer() == player_id then
      local city_name = city:GetName()
      Events.GameplayAlertMessage(city_name .. " became the Port of Adulis! Received a free Lighthouse and trade bonuses.")
   end

end

------------------------------------------------------------------------------------------------------------------------
if is_active then
   GameEvents.PlayerCityFounded.Add(lekmod_aksum_ua_stone_settling)
   GameEvents.PlayerCityFounded.Add(lekmod_aksum_ua_port_of_adulis)
end