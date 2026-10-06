local callback
GameEvents={OnPillage={Add=function(f) callback=f end}}
local damage=60
local unit={SetDamage=function(_,n) damage=n end}
local currentCiv='CIVILIZATION_COMMUNIST'
local population,changes,war,unitExists,cityExists,plotOwner,cityOwner=5,0,true,true,true,1,1
local city={GetPopulation=function() return population end,GetOwner=function() return cityOwner end,GetID=function() return 17 end,ChangePopulation=function(_,n) population=population+n;changes=changes+1 end}
local plot={GetOwner=function() return plotOwner end,GetX=function() return 3 end,GetY=function() return 4 end}
Players={[0]={GetUnits=function() return {FindID=function() return unitExists and unit or nil end} end,GetDiplomacy=function() return {IsAtWarWith=function() return war end} end}}
PlayerConfigurations={[0]={GetCivilizationTypeName=function() return currentCiv end}}
Map={GetPlotByIndex=function(i) if i==99 then return plot end end}
Cities={GetPlotPurchaseCity=function() return cityExists and city or nil end}
dofile('Communist_PeoplesWar/Scripts/PillagePopulation.lua')
local function reset()
 damage=60;currentCiv='CIVILIZATION_COMMUNIST';population=5;changes=0;war=true;unitExists=true;cityExists=true;plotOwner=1;cityOwner=1
end
local function pillage(i,b,d)callback(0,5,i or -1,b or -1,d or -1,99)end
local count=0
local function check(name,setup,action,want,delta)
 reset();setup();action();assert(population==want and changes==delta,name);count=count+1
end
check('improvement index zero',function()end,function()pillage(0)end,4,1)
check('district and building same event only once',function()end,function()pillage(-1,2,4)end,4,1)
check('repair then second successful pillage',function()end,function()pillage(1);pillage(1)end,3,2)
check('one population floor',function()population=1 end,function()pillage(1)end,1,0)
check('two population reaches floor',function()population=2 end,function()pillage(1)end,1,1)
check('other civilizations excluded',function()currentCiv='CIVILIZATION_CHINA' end,function()pillage(1)end,5,0)
check('own territory excluded',function()plotOwner=0 end,function()pillage(1)end,5,0)
check('neutral territory excluded',function()plotOwner=-1 end,function()pillage(1)end,5,0)
check('not at war excluded',function()war=false end,function()pillage(1)end,5,0)
check('cityless tile excluded',function()cityExists=false end,function()pillage(1)end,5,0)
check('roads excluded',function()end,function()pillage(-1,-1,-1)end,5,0)
check('stale unit excluded',function()unitExists=false end,function()pillage(1)end,5,0)
check('invalid plot excluded',function()end,function()callback(0,5,1,-1,-1,998)end,5,0)
check('city ownership mismatch excluded',function()cityOwner=2 end,function()pillage(1)end,5,0)
print('Pillage gameplay tests passed: '..count)

reset();pillage(1);assert(damage==0,'successful pillage heals to full')
reset();population=1;pillage(1);assert(damage==0,'population floor does not block healing')
reset();cityExists=false;pillage(1);assert(damage==0,'cityless pillage still heals')
reset();currentCiv='CIVILIZATION_CHINA';pillage(1);assert(damage==60,'other civilizations do not heal')
reset();pillage(-1,-1,-1);assert(damage==60,'unrelated event does not heal')
reset();callback(0,5,1,-1,-1,998);assert(damage==60,'invalid plot does not heal')
reset();damage=0;pillage(1);assert(damage==0,'full-health unit stays at full health')
print('Pillage full-heal tests passed: 7')
