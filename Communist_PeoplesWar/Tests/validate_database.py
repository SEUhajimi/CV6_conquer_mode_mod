"""Static validation using external reference data; does not replace a Civ6 runtime test."""
import sqlite3,xml.etree.ElementTree as E,zlib
from pathlib import Path
p=Path('Communist_PeoplesWar');base=Path('reference/Base/Assets/Gameplay/Data')
db=sqlite3.connect(':memory:');db.executescript((base/'Schema/01_GameplaySchema.sql').read_text());db.create_function('Make_Hash',1,lambda s:zlib.crc32(s.encode()));db.executescript((base/'Schema/02_AddTriggers.sql').read_text());db.execute('PRAGMA foreign_keys=OFF')
for f in base.glob('*.xml'):
 for table in E.parse(f).getroot():
  if not db.execute("SELECT 1 FROM sqlite_master WHERE type='table' AND name=?",(table.tag,)).fetchone():continue
  for row in table:
   if row.tag not in ('Row','Replace'):continue
   fields=dict(row.attrib);fields.update({c.tag:c.text for c in row})
   if not fields:continue
   fields={k:(0 if str(v).lower()=='false' else 1 if str(v).lower()=='true' else v) for k,v in fields.items()}
   try:db.execute('INSERT OR REPLACE INTO "'+table.tag+'" ('+','.join('"'+k+'"' for k in fields)+') VALUES ('+','.join('?' for k in fields)+')',list(fields.values()))
   except sqlite3.Error:pass
# Fixture only: the installed Gathering Storm database is unavailable.
db.executescript('CREATE TABLE Units_XP2(UnitType TEXT PRIMARY KEY,ResourceCost INTEGER,ResourceMaintenanceType TEXT,ResourceMaintenanceAmount INTEGER); INSERT INTO Units_XP2 VALUES("UNIT_MUSKETMAN",20,NULL,0); INSERT INTO Modifiers(ModifierId,ModifierType) VALUES("SKIP_FREE_CITY","MODIFIER_PLAYER_ADJUST_SKIP_FREE_CITY_STEP");')
db.executescript((p/'Data/Gameplay.sql').read_text())
def arg(mod,name):return db.execute('SELECT Value FROM ModifierArguments WHERE ModifierId=? AND Name=?',(mod,name)).fetchone()[0]
assert arg('COMMUNIST_PRODUCTION_PER_POPULATION','Amount')=='1'
assert arg('COMMUNIST_PRODUCTION_PER_POPULATION','YieldType')=='YIELD_PRODUCTION'
assert db.execute("SELECT SubjectRequirementSetId FROM Modifiers WHERE ModifierId='COMMUNIST_PRODUCTION_PER_POPULATION'").fetchone()[0] is None
for m,a in [('TRAIT_ADJUST_BUILDER_CHARGES','1'),('TRAIT_BUILDER_WONDER_PERCENT','15'),('COMMUNIST_OFFENSIVE_SPY_BONUS','2'),('COMMUNIST_DOUBLE_PLUNDER','100')]:
 assert arg(m,'Amount')==a
 assert db.execute("SELECT count(*) FROM TraitModifiers WHERE TraitType='TRAIT_COMMUNIST_SPARK' AND ModifierId=?",(m,)).fetchone()[0]==1
assert db.execute("SELECT CivilizationType FROM CivilizationLeaders WHERE LeaderType='LEADER_MAO_ZEDONG'").fetchone()[0]=='CIVILIZATION_COMMUNIST'
original=db.execute("SELECT BaseMoves,Combat,Cost,PrereqTech FROM Units WHERE UnitType='UNIT_MUSKETMAN'").fetchone()
red=db.execute("SELECT BaseMoves,Combat,Cost,PrereqTech FROM Units WHERE UnitType='UNIT_MAO_RED_ARMY'").fetchone()
assert red==(original[0]+1,*original[1:])
assert db.execute("SELECT ReplacesUnitType FROM UnitReplaces WHERE CivUniqueUnitType='UNIT_MAO_RED_ARMY'").fetchone()[0]=='UNIT_MUSKETMAN'
d=sqlite3.connect(':memory:');d.executescript(Path('reference/Base/Assets/Configuration/Data/Schema/AdditionalTables.sql').read_text());d.executescript((p/'Data/Config.sql').read_text());assert d.execute('SELECT CivilizationType FROM Players').fetchone()[0]=='CIVILIZATION_COMMUNIST'
for f in list(p.rglob('*.xml'))+list(p.glob('ArtDefs/*.artdef')):E.parse(f)
r=E.parse(p/'Communist_PeoplesWar.modinfo').getroot();assert r.get('version')=='7'
for f in r.findall('./Files/File'):assert (p/f.text).is_file()
assert db.execute("SELECT count(*) FROM CivilizationTraits WHERE CivilizationType='CIVILIZATION_COMMUNIST'").fetchone()[0]==3
print('PASS: v0.7 SQL, Qin modifiers +1 charge / 15% wonder, unrestricted +1 production per population, existing civ and unit setup, XML and manifest.')

assert db.execute("SELECT ReplacesDistrictType FROM DistrictReplaces WHERE CivUniqueDistrictType='DISTRICT_COMMUNIST_MARX_INSTITUTE'").fetchone()[0]=='DISTRICT_CAMPUS'
for gp in ['PROPHET','ENGINEER','SCIENTIST']:
 assert db.execute("SELECT PointsPerTurn FROM District_GreatPersonPoints WHERE DistrictType='DISTRICT_COMMUNIST_MARX_INSTITUTE' AND GreatPersonClassType=?",('GREAT_PERSON_CLASS_'+gp,)).fetchone()[0]==1
for m,y in [('MARX_SCIENCE_ADJACENCY_AS_FAITH','YIELD_FAITH'),('MARX_SCIENCE_ADJACENCY_AS_PRODUCTION','YIELD_PRODUCTION')]:
 assert arg(m,'YieldTypeToMirror')=='YIELD_SCIENCE' and arg(m,'YieldTypeToGrant')==y
assert db.execute("SELECT COUNT(*) FROM District_Adjacencies WHERE DistrictType='DISTRICT_COMMUNIST_MARX_INSTITUTE'").fetchone()[0]==db.execute("SELECT COUNT(*) FROM District_Adjacencies WHERE DistrictType='DISTRICT_CAMPUS'").fetchone()[0]+1
print('PASS: Campus replacement, original adjacency rules, faith/production mirroring and three Great Person point classes.')

assert db.execute("SELECT YieldChange,TilesRequired,AdjacentDistrict FROM Adjacency_YieldChanges WHERE ID='MARX_INDUSTRIAL_ZONE_SCIENCE'").fetchone()==(2,1,'DISTRICT_INDUSTRIAL_ZONE')
print('PASS: +2 additional science adjacency per Industrial Zone.')
