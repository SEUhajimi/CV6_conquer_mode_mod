print('[CommunistPW] v0.8: Long March leader ability; Hard Work and Communism civ abilities; Red Army with ranged attack replaces Musketman.')
local required={'SKIP_FREE_CITY','MAO_MOVE','MAO_STRENGTH','MAO_XP','MAO_KILL_HEAL','MAO_HEAL_AFTER_ACTION','COMMUNIST_DOUBLE_PLUNDER','COMMUNIST_OFFENSIVE_SPY_BONUS','COMMUNIST_PRODUCTION_PER_POPULATION','TRAIT_ADJUST_BUILDER_CHARGES','TRAIT_BUILDER_WONDER_PERCENT'}
for _,id in ipairs(required) do
 local row=GameInfo.Modifiers[id]
 print('[CommunistPW] '..id..': '..tostring(row and row.ModifierType or 'MISSING'))
end
for row in GameInfo.UnitOperations() do
 if string.find(row.OperationType,'SPY',1,true) then
  print('[CommunistPW] Espionage operation '..row.OperationType..' BaseProbability='..tostring(row.BaseProbability)..' LevelProbChange='..tostring(row.LevelProbChange))
 end
end
