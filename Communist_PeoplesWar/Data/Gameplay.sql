-- Gameplay core: Gathering Storm only. No global edits to other leaders.
INSERT INTO Types(Type, Kind) VALUES
('CIVILIZATION_COMMUNIST','KIND_CIVILIZATION'),
('TRAIT_COMMUNIST_SPARK','KIND_TRAIT'),
('LEADER_MAO_ZEDONG','KIND_LEADER'),
('TRAIT_MAO_PEOPLES_WAR','KIND_TRAIT'),
('TRAIT_MAO_RED_ARMY','KIND_TRAIT'),
('UNIT_MAO_RED_ARMY','KIND_UNIT'),
('ABILITY_MAO_PEOPLES_WAR','KIND_ABILITY'),
('ABILITY_MAO_RED_ARMY','KIND_ABILITY');
INSERT INTO Leaders(LeaderType,Name,InheritFrom,SceneLayers)
VALUES('LEADER_MAO_ZEDONG','LOC_LEADER_MAO_ZEDONG_NAME','LEADER_DEFAULT',0);
INSERT INTO Civilizations(CivilizationType,Name,Description,Adjective,StartingCivilizationLevelType,Ethnicity)
VALUES('CIVILIZATION_COMMUNIST','LOC_CIVILIZATION_COMMUNIST_NAME','LOC_CIVILIZATION_COMMUNIST_DESCRIPTION','LOC_CIVILIZATION_COMMUNIST_ADJECTIVE','CIVILIZATION_LEVEL_FULL_CIV','ETHNICITY_ASIAN');
INSERT INTO CivilizationLeaders(LeaderType,CivilizationType,CapitalName)
VALUES('LEADER_MAO_ZEDONG','CIVILIZATION_COMMUNIST','LOC_CITY_NAME_COMMUNIST_RUIJIN');
-- Reuse citizen naming conventions only; do not inherit China's gameplay traits.
INSERT INTO CivilizationCitizenNames(CivilizationType,CitizenName,Female,Modern)
SELECT 'CIVILIZATION_COMMUNIST',CitizenName,Female,Modern FROM CivilizationCitizenNames WHERE CivilizationType='CIVILIZATION_CHINA';
INSERT INTO CityNames(CivilizationType,CityName) VALUES
('CIVILIZATION_COMMUNIST','LOC_CITY_NAME_COMMUNIST_RUIJIN'),
('CIVILIZATION_COMMUNIST','LOC_CITY_NAME_COMMUNIST_YANAN'),
('CIVILIZATION_COMMUNIST','LOC_CITY_NAME_COMMUNIST_JINGGANGSHAN'),
('CIVILIZATION_COMMUNIST','LOC_CITY_NAME_COMMUNIST_XIBAIPO');
INSERT INTO Traits(TraitType,Name,Description) VALUES
('TRAIT_COMMUNIST_SPARK','LOC_TRAIT_COMMUNIST_SPARK_NAME','LOC_TRAIT_COMMUNIST_SPARK_DESCRIPTION');
INSERT INTO Traits(TraitType,Name,Description) VALUES
('TRAIT_MAO_PEOPLES_WAR','LOC_TRAIT_MAO_NAME','LOC_TRAIT_MAO_DESCRIPTION'),
('TRAIT_MAO_RED_ARMY','LOC_UNIT_MAO_RED_ARMY_NAME','LOC_UNIT_MAO_RED_ARMY_DESCRIPTION');
INSERT INTO LeaderTraits(LeaderType,TraitType) VALUES
('LEADER_MAO_ZEDONG','TRAIT_MAO_PEOPLES_WAR');
INSERT INTO CivilizationTraits(CivilizationType,TraitType) VALUES
('CIVILIZATION_COMMUNIST','TRAIT_COMMUNIST_SPARK'),('CIVILIZATION_COMMUNIST','TRAIT_MAO_RED_ARMY');
INSERT INTO UnitAbilities(UnitAbilityType,Name,Description,Inactive) VALUES
('ABILITY_MAO_PEOPLES_WAR','LOC_TRAIT_MAO_NAME','LOC_TRAIT_MAO_DESCRIPTION',1),
('ABILITY_MAO_RED_ARMY','LOC_UNIT_MAO_RED_ARMY_NAME','LOC_UNIT_MAO_RED_ARMY_DESCRIPTION',0);
INSERT INTO TypeTags(Type,Tag) VALUES
('ABILITY_MAO_PEOPLES_WAR','CLASS_MELEE'),
('ABILITY_MAO_PEOPLES_WAR','CLASS_ANTI_CAVALRY');
INSERT INTO Tags(Tag,Vocabulary) VALUES('CLASS_MAO_RED_ARMY','ABILITY_CLASS');
INSERT INTO TypeTags(Type,Tag) VALUES
('ABILITY_MAO_RED_ARMY','CLASS_MAO_RED_ARMY'),('UNIT_MAO_RED_ARMY','CLASS_MAO_RED_ARMY');
INSERT INTO Modifiers(ModifierId,ModifierType) VALUES
('MAO_GRANT_WAR','MODIFIER_PLAYER_UNITS_GRANT_ABILITY'),
('MAO_MOVE','MODIFIER_PLAYER_UNIT_ADJUST_MOVEMENT'),
('MAO_HOME','MODIFIER_PLAYER_UNIT_ADJUST_FRIENDLY_TERRITORY_COMBAT'),
('MAO_XP','MODIFIER_PLAYER_UNIT_ADJUST_UNIT_EXPERIENCE_MODIFIER'),
('MAO_KILL_HEAL','MODIFIER_PLAYER_UNIT_ADJUST_HEAL_FROM_COMBAT'),
('MAO_ENEMY_HEAL','MODIFIER_PLAYER_UNIT_ADJUST_HEAL_PER_TURN'),
('MAO_HEAL_AFTER_ACTION','MODIFIER_PLAYER_UNIT_GRANT_HEAL_AFTER_ACTION');
INSERT INTO Modifiers(ModifierId,ModifierType,SubjectRequirementSetId)
SELECT 'MAO_WOUNDED',ModifierType,SubjectRequirementSetId FROM Modifiers
WHERE ModifierId='TOMYRIS_BONUS_VS_WOUNDED_UNITS';
INSERT INTO ModifierArguments(ModifierId,Name,Value) VALUES
('MAO_GRANT_WAR','AbilityType','ABILITY_MAO_PEOPLES_WAR'),
('MAO_MOVE','Amount',1),('MAO_HOME','Amount',5),('MAO_XP','Amount',50),
('MAO_WOUNDED','Amount',5),('MAO_KILL_HEAL','Amount',20),
('MAO_ENEMY_HEAL','Amount',5),('MAO_ENEMY_HEAL','Type','ENEMY');
INSERT INTO TraitModifiers(TraitType,ModifierId) VALUES('TRAIT_MAO_PEOPLES_WAR','MAO_GRANT_WAR');
INSERT INTO UnitAbilityModifiers(UnitAbilityType,ModifierId) VALUES
('ABILITY_MAO_PEOPLES_WAR','MAO_MOVE'),('ABILITY_MAO_PEOPLES_WAR','MAO_HOME'),
('ABILITY_MAO_PEOPLES_WAR','MAO_WOUNDED'),('ABILITY_MAO_PEOPLES_WAR','MAO_XP'),
('ABILITY_MAO_RED_ARMY','MAO_KILL_HEAL'),('ABILITY_MAO_RED_ARMY','MAO_ENEMY_HEAL'),
('ABILITY_MAO_RED_ARMY','MAO_HEAL_AFTER_ACTION');
INSERT INTO ModifierStrings(ModifierId,Context,Text) VALUES
('MAO_HOME','Preview','LOC_MAO_HOME_PREVIEW'),('MAO_WOUNDED','Preview','LOC_MAO_WOUNDED_PREVIEW');

-- Copy current Musketman stats; preserve tech, cost, maintenance, resource and upgrade conditions.
INSERT INTO Units(UnitType,Name,BaseSightRange,BaseMoves,Combat,RangedCombat,Range,Bombard,Domain,FormationClass,Cost,PopulationCost,FoundCity,FoundReligion,MakeTradeRoute,EvangelizeBelief,LaunchInquisition,RequiresInquisition,BuildCharges,ReligiousStrength,ReligionEvictPercent,SpreadCharges,ReligiousHealCharges,ExtractsArtifacts,Description,Flavor,CanCapture,CanRetreatWhenCaptured,TraitType,AllowBarbarians,CostProgressionModel,CostProgressionParam1,PromotionClass,InitialLevel,NumRandomChoices,PrereqTech,PrereqCivic,PrereqDistrict,PrereqPopulation,LeaderType,CanTrain,StrategicResource,PurchaseYield,MustPurchase,Maintenance,Stackable,AirSlots,CanTargetAir,PseudoYieldType,ZoneOfControl,AntiAirCombat,Spy,WMDCapable,ParkCharges,IgnoreMoves,TeamVisibility,ObsoleteTech,ObsoleteCivic,MandatoryObsoleteTech,MandatoryObsoleteCivic,AdvisorType,EnabledByReligion,TrackReligion,DisasterCharges,UseMaxMeleeTrainedStrength,ImmediatelyName,CanEarnExperience)
SELECT 'UNIT_MAO_RED_ARMY','LOC_UNIT_MAO_RED_ARMY_NAME',BaseSightRange,BaseMoves + 1,Combat,RangedCombat,Range,Bombard,Domain,FormationClass,Cost,PopulationCost,FoundCity,FoundReligion,MakeTradeRoute,EvangelizeBelief,LaunchInquisition,RequiresInquisition,BuildCharges,ReligiousStrength,ReligionEvictPercent,SpreadCharges,ReligiousHealCharges,ExtractsArtifacts,'LOC_UNIT_MAO_RED_ARMY_DESCRIPTION',Flavor,CanCapture,CanRetreatWhenCaptured,'TRAIT_MAO_RED_ARMY',AllowBarbarians,CostProgressionModel,CostProgressionParam1,PromotionClass,InitialLevel,NumRandomChoices,PrereqTech,PrereqCivic,PrereqDistrict,PrereqPopulation,LeaderType,CanTrain,StrategicResource,PurchaseYield,MustPurchase,Maintenance,Stackable,AirSlots,CanTargetAir,PseudoYieldType,ZoneOfControl,AntiAirCombat,Spy,WMDCapable,ParkCharges,IgnoreMoves,TeamVisibility,ObsoleteTech,ObsoleteCivic,MandatoryObsoleteTech,MandatoryObsoleteCivic,AdvisorType,EnabledByReligion,TrackReligion,DisasterCharges,UseMaxMeleeTrainedStrength,ImmediatelyName,CanEarnExperience FROM Units WHERE UnitType='UNIT_MUSKETMAN';
INSERT INTO TypeTags(Type,Tag) SELECT 'UNIT_MAO_RED_ARMY',Tag FROM TypeTags WHERE Type='UNIT_MUSKETMAN';
INSERT INTO UnitAiInfos(UnitType,AiType) SELECT 'UNIT_MAO_RED_ARMY',AiType FROM UnitAiInfos WHERE UnitType='UNIT_MUSKETMAN';
INSERT INTO UnitReplaces(CivUniqueUnitType,ReplacesUnitType) VALUES('UNIT_MAO_RED_ARMY','UNIT_MUSKETMAN');
INSERT INTO UnitUpgrades(Unit,UpgradeUnit) SELECT 'UNIT_MAO_RED_ARMY',UpgradeUnit FROM UnitUpgrades WHERE Unit='UNIT_MUSKETMAN';
INSERT INTO Units_XP2(UnitType,ResourceCost,ResourceMaintenanceType,ResourceMaintenanceAmount)
SELECT 'UNIT_MAO_RED_ARMY',ResourceCost,ResourceMaintenanceType,ResourceMaintenanceAmount
FROM Units_XP2 WHERE UnitType='UNIT_MUSKETMAN';

-- Reuse only Eleanor's direct loyalty transfer. No Great Work pressure is granted.
INSERT INTO TraitModifiers(TraitType,ModifierId)
SELECT 'TRAIT_COMMUNIST_SPARK',ModifierId FROM Modifiers WHERE ModifierId='SKIP_FREE_CITY';

-- +100% is a native plunder-yield bonus. It is civilization-wide.
INSERT INTO Modifiers(ModifierId,ModifierType)
VALUES('COMMUNIST_DOUBLE_PLUNDER','MODIFIER_PLAYER_UNITS_ADJUST_PLUNDER_YIELDS');
INSERT INTO ModifierArguments(ModifierId,Name,Value) VALUES('COMMUNIST_DOUBLE_PLUNDER','Amount',100);
INSERT INTO TraitModifiers(TraitType,ModifierId) VALUES('TRAIT_COMMUNIST_SPARK','COMMUNIST_DOUBLE_PLUNDER');

-- Native espionage bonus, also used by Cryptography and Wu Zetian.
-- Only offensive missions; the engine keeps normal mission checks and outcomes.
INSERT INTO Modifiers(ModifierId,ModifierType)
VALUES('COMMUNIST_OFFENSIVE_SPY_BONUS','MODIFIER_PLAYER_ADJUST_SPY_BONUS');
INSERT INTO ModifierArguments(ModifierId,Name,Value) VALUES
('COMMUNIST_OFFENSIVE_SPY_BONUS','Offense','true'),('COMMUNIST_OFFENSIVE_SPY_BONUS','Amount',2);
INSERT INTO TraitModifiers(TraitType,ModifierId) VALUES('TRAIT_COMMUNIST_SPARK','COMMUNIST_OFFENSIVE_SPY_BONUS');

INSERT INTO CityNames(CivilizationType,CityName) VALUES
('CIVILIZATION_COMMUNIST','LOC_CITY_NAME_COMMUNIST_WAYAOBAO'),
('CIVILIZATION_COMMUNIST','LOC_CITY_NAME_COMMUNIST_XINGGUO'),
('CIVILIZATION_COMMUNIST','LOC_CITY_NAME_COMMUNIST_YUDU'),
('CIVILIZATION_COMMUNIST','LOC_CITY_NAME_COMMUNIST_HUICHANG'),
('CIVILIZATION_COMMUNIST','LOC_CITY_NAME_COMMUNIST_NINGDU'),
('CIVILIZATION_COMMUNIST','LOC_CITY_NAME_COMMUNIST_YONGXIN'),
('CIVILIZATION_COMMUNIST','LOC_CITY_NAME_COMMUNIST_CHANGTING'),
('CIVILIZATION_COMMUNIST','LOC_CITY_NAME_COMMUNIST_SHANGHANG'),
('CIVILIZATION_COMMUNIST','LOC_CITY_NAME_COMMUNIST_ZUNYI'),
('CIVILIZATION_COMMUNIST','LOC_CITY_NAME_COMMUNIST_WUQI'),
('CIVILIZATION_COMMUNIST','LOC_CITY_NAME_COMMUNIST_BAOAN'),
('CIVILIZATION_COMMUNIST','LOC_CITY_NAME_COMMUNIST_NANNIWAN'),
('CIVILIZATION_COMMUNIST','LOC_CITY_NAME_COMMUNIST_YANCHUAN'),
('CIVILIZATION_COMMUNIST','LOC_CITY_NAME_COMMUNIST_YANCHANG'),
('CIVILIZATION_COMMUNIST','LOC_CITY_NAME_COMMUNIST_GANQUAN'),
('CIVILIZATION_COMMUNIST','LOC_CITY_NAME_COMMUNIST_FUXIAN');

-- v0.4: reuse Qin's original builder modifiers without granting his whole trait.
INSERT INTO TraitModifiers(TraitType,ModifierId) VALUES
('TRAIT_COMMUNIST_SPARK','TRAIT_ADJUST_BUILDER_CHARGES'),
('TRAIT_COMMUNIST_SPARK','TRAIT_BUILDER_WONDER_PERCENT');
-- Every citizen contributes one additional point of production in every owned city.
-- No governor requirement: new, captured and growing cities are handled natively.
INSERT INTO Modifiers(ModifierId,ModifierType) VALUES
('COMMUNIST_PRODUCTION_PER_POPULATION','MODIFIER_PLAYER_CITIES_ADJUST_CITY_YIELD_PER_POPULATION');
INSERT INTO ModifierArguments(ModifierId,Name,Value) VALUES
('COMMUNIST_PRODUCTION_PER_POPULATION','YieldType','YIELD_PRODUCTION'),
('COMMUNIST_PRODUCTION_PER_POPULATION','Amount',1);
INSERT INTO TraitModifiers(TraitType,ModifierId) VALUES
('TRAIT_COMMUNIST_SPARK','COMMUNIST_PRODUCTION_PER_POPULATION');

-- v0.6: Marx Institute replaces Campus, at the original Campus cost.
INSERT INTO Types(Type,Kind) VALUES
('DISTRICT_COMMUNIST_MARX_INSTITUTE','KIND_DISTRICT'),('TRAIT_COMMUNIST_MARX_INSTITUTE','KIND_TRAIT');
INSERT INTO Traits(TraitType,Name,Description) VALUES
('TRAIT_COMMUNIST_MARX_INSTITUTE','LOC_DISTRICT_MARX_INSTITUTE_NAME','LOC_DISTRICT_MARX_INSTITUTE_DESCRIPTION');
INSERT INTO CivilizationTraits(CivilizationType,TraitType) VALUES
('CIVILIZATION_COMMUNIST','TRAIT_COMMUNIST_MARX_INSTITUTE');
INSERT INTO Districts(DistrictType,Name,PrereqTech,PrereqCivic,Coast,Description,Cost,RequiresPlacement,RequiresPopulation,NoAdjacentCity,CityCenter,Aqueduct,InternalOnly,ZOC,FreeEmbark,HitPoints,CaptureRemovesBuildings,CaptureRemovesCityDefenses,PlunderType,PlunderAmount,TradeEmbark,MilitaryDomain,CostProgressionModel,CostProgressionParam1,TraitType,Appeal,Housing,Entertainment,OnePerCity,AllowsHolyCity,Maintenance,AirSlots,CitizenSlots,TravelTime,CityStrengthModifier,AdjacentToLand,CanAttack,AdvisorType,CaptureRemovesDistrict,MaxPerPlayer)
SELECT 'DISTRICT_COMMUNIST_MARX_INSTITUTE','LOC_DISTRICT_MARX_INSTITUTE_NAME',PrereqTech,PrereqCivic,Coast,'LOC_DISTRICT_MARX_INSTITUTE_DESCRIPTION',Cost,RequiresPlacement,RequiresPopulation,NoAdjacentCity,CityCenter,Aqueduct,InternalOnly,ZOC,FreeEmbark,HitPoints,CaptureRemovesBuildings,CaptureRemovesCityDefenses,PlunderType,PlunderAmount,TradeEmbark,MilitaryDomain,CostProgressionModel,CostProgressionParam1,'TRAIT_COMMUNIST_MARX_INSTITUTE',Appeal,Housing,Entertainment,OnePerCity,AllowsHolyCity,Maintenance,AirSlots,CitizenSlots,TravelTime,CityStrengthModifier,AdjacentToLand,CanAttack,AdvisorType,CaptureRemovesDistrict,MaxPerPlayer FROM Districts WHERE DistrictType='DISTRICT_CAMPUS';
INSERT INTO DistrictReplaces(CivUniqueDistrictType,ReplacesDistrictType) VALUES('DISTRICT_COMMUNIST_MARX_INSTITUTE','DISTRICT_CAMPUS');
INSERT INTO District_Adjacencies(DistrictType,YieldChangeId)
SELECT 'DISTRICT_COMMUNIST_MARX_INSTITUTE',YieldChangeId FROM District_Adjacencies WHERE DistrictType='DISTRICT_CAMPUS';
INSERT INTO District_GreatPersonPoints(DistrictType,GreatPersonClassType,PointsPerTurn)
SELECT 'DISTRICT_COMMUNIST_MARX_INSTITUTE',GreatPersonClassType,PointsPerTurn FROM District_GreatPersonPoints WHERE DistrictType='DISTRICT_CAMPUS';
INSERT INTO District_CitizenYieldChanges(DistrictType,YieldType,YieldChange)
SELECT 'DISTRICT_COMMUNIST_MARX_INSTITUTE',YieldType,YieldChange FROM District_CitizenYieldChanges WHERE DistrictType='DISTRICT_CAMPUS';
INSERT INTO District_CitizenGreatPersonPoints(DistrictType,GreatPersonClassType,PointsPerTurn)
SELECT 'DISTRICT_COMMUNIST_MARX_INSTITUTE',GreatPersonClassType,PointsPerTurn FROM District_CitizenGreatPersonPoints WHERE DistrictType='DISTRICT_CAMPUS';
INSERT INTO District_TradeRouteYields(DistrictType,YieldType,YieldChangeAsOrigin,YieldChangeAsDomesticDestination,YieldChangeAsInternationalDestination)
SELECT 'DISTRICT_COMMUNIST_MARX_INSTITUTE',YieldType,YieldChangeAsOrigin,YieldChangeAsDomesticDestination,YieldChangeAsInternationalDestination FROM District_TradeRouteYields WHERE DistrictType='DISTRICT_CAMPUS';
INSERT INTO DistrictModifiers(DistrictType,ModifierId)
SELECT 'DISTRICT_COMMUNIST_MARX_INSTITUTE',ModifierId FROM DistrictModifiers WHERE DistrictType='DISTRICT_CAMPUS';
INSERT INTO District_RequiredFeatures(DistrictType,FeatureType)
SELECT 'DISTRICT_COMMUNIST_MARX_INSTITUTE',FeatureType FROM District_RequiredFeatures WHERE DistrictType='DISTRICT_CAMPUS';
INSERT INTO District_ValidTerrains(DistrictType,TerrainType)
SELECT 'DISTRICT_COMMUNIST_MARX_INSTITUTE',TerrainType FROM District_ValidTerrains WHERE DistrictType='DISTRICT_CAMPUS';
INSERT INTO District_GreatPersonPoints(DistrictType,GreatPersonClassType,PointsPerTurn) VALUES
('DISTRICT_COMMUNIST_MARX_INSTITUTE','GREAT_PERSON_CLASS_PROPHET',1),
('DISTRICT_COMMUNIST_MARX_INSTITUTE','GREAT_PERSON_CLASS_ENGINEER',1);
-- Same native adjacency-mirroring effect as Hildegard / Work Ethic.
INSERT INTO Modifiers(ModifierId,ModifierType) VALUES
('MARX_SCIENCE_ADJACENCY_AS_FAITH','MODIFIER_PLAYER_DISTRICT_ADJUST_YIELD_BASED_ON_ADJACENCY_BONUS'),
('MARX_SCIENCE_ADJACENCY_AS_PRODUCTION','MODIFIER_PLAYER_DISTRICT_ADJUST_YIELD_BASED_ON_ADJACENCY_BONUS');
INSERT INTO ModifierArguments(ModifierId,Name,Value) VALUES
('MARX_SCIENCE_ADJACENCY_AS_FAITH','YieldTypeToMirror','YIELD_SCIENCE'),
('MARX_SCIENCE_ADJACENCY_AS_FAITH','YieldTypeToGrant','YIELD_FAITH'),
('MARX_SCIENCE_ADJACENCY_AS_PRODUCTION','YieldTypeToMirror','YIELD_SCIENCE'),
('MARX_SCIENCE_ADJACENCY_AS_PRODUCTION','YieldTypeToGrant','YIELD_PRODUCTION');
INSERT INTO DistrictModifiers(DistrictType,ModifierId) VALUES
('DISTRICT_COMMUNIST_MARX_INSTITUTE','MARX_SCIENCE_ADJACENCY_AS_FAITH'),
('DISTRICT_COMMUNIST_MARX_INSTITUTE','MARX_SCIENCE_ADJACENCY_AS_PRODUCTION');

-- Additional major science adjacency from each adjacent Industrial Zone.
INSERT INTO Adjacency_YieldChanges(ID,Description,YieldType,YieldChange,TilesRequired,AdjacentDistrict)
VALUES('MARX_INDUSTRIAL_ZONE_SCIENCE','LOC_MARX_INDUSTRIAL_ZONE_ADJACENCY','YIELD_SCIENCE',2,1,'DISTRICT_INDUSTRIAL_ZONE');
INSERT INTO District_Adjacencies(DistrictType,YieldChangeId)
VALUES('DISTRICT_COMMUNIST_MARX_INSTITUTE','MARX_INDUSTRIAL_ZONE_SCIENCE');
