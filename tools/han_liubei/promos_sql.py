# 生成 Han_LiuBei/Data/Promotions.sql（不要手改生成结果）：python tools/han_liubei/promos_sql.py
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from promos import SLOTS, PREREQS, TREES

OUT = Path(__file__).resolve().parents[2] / 'Han_LiuBei' / 'Data' / 'Promotions.sql'

STRENGTH_SETS = {'atk': 'HAN_UNIT_IS_ATTACKING', 'def': 'HAN_UNIT_IS_DEFENDING', 'district': 'HAN_OPPONENT_IS_DISTRICT',
                 'cav': 'ANTI_CAVALRY_OPPONENT_REQUIREMENTS', 'wounded': 'HAN_OPPONENT_WOUNDED',
                 'vsanticav': 'HAN_OPPONENT_ANTI_CAVALRY'}
# 光环类修改器的范围需求组：统率范围 / 医疗兵（相邻含自身）
SUBJECT_SETS = {'zglheal': 'HAN_ZGL_TIGER_IN_RANGE', 'zglmove': 'HAN_ZGL_TIGER_IN_RANGE', 'arrows': 'HAN_ZGL_TIGER_IN_RANGE',
                'bagua': 'HAN_TIGER_COMMAND_RANGE', 'moveaura': 'HAN_TIGER_COMMAND_RANGE', 'healaura': 'MEDIC_HEALING_REQUIREMENTS',
                'capturecav': 'ATTACKER_OPPONENT_IS_CAVALRY_UNIT_REQUIREMENTS'}
SIMPLE = {  # 类型: (ModifierType, [(参数名, 值或 None=用数值)])
 'move': ('MODIFIER_PLAYER_UNIT_ADJUST_MOVEMENT', [('Amount', None)]),
 'heal': ('MODIFIER_PLAYER_UNIT_ADJUST_HEAL_PER_TURN', [('Amount', None), ('Type', 'ALL')]),
 'healact': ('MODIFIER_PLAYER_UNIT_GRANT_HEAL_AFTER_ACTION', []),
 'attackmove': ('MODIFIER_PLAYER_UNIT_ADJUST_ATTACK_AND_MOVE', [('CanMove', '1')]),
 'ignorezoc': ('MODIFIER_PLAYER_UNIT_ADJUST_IGNORE_ZOC', [('Ignore', '1')]),
 'ignorerivers': ('MODIFIER_PLAYER_UNIT_ADJUST_IGNORE_RIVERS', [('Ignore', '1')]),
 'killheal': ('MODIFIER_PLAYER_UNIT_ADJUST_HEAL_FROM_COMBAT', [('Amount', None)]),
 'nowound': ('MODIFIER_PLAYER_UNIT_ADJUST_NO_REDUCTION_DAMAGE', [('NoReduction', '1')]),
 'flank': ('MODIFIER_PLAYER_UNIT_ADJUST_FLANKING_BONUS_MODIFIER', [('Percent', None)]),
 'range': ('MODIFIER_UNIT_ADJUST_ATTACK_RANGE', [('Amount', None)]),
 'attacks': ('MODIFIER_UNIT_ADJUST_NUM_ATTACKS', [('Amount', None)]),
 'nodistrictpenalty': ('MODIFIER_PLAYER_UNIT_IGNORE_RANGED_VS_DISTRICT_PENALTY', [('Ignore', '1')]),
 'moveaura': ('MODIFIER_PLAYER_UNITS_GRANT_ABILITY', [('AbilityType', 'ABILITY_HAN_TIGER_COMMANDED_MOVE')]),
 'healaura': ('MODIFIER_PLAYER_UNITS_ADJUST_HEAL_PER_TURN', [('Amount', None), ('Type', 'ALL')]),
 'capture': ('MODIFIER_UNIT_ADJUST_COMBAT_UNIT_CAPTURE', [('CanCapture', '1')]),
 'convertbarb': ('MODIFIER_PLAYER_UNIT_ADJUST_CONVERTS_BARBARIANS', [('Converts', '1')]),
 'stealth': ('MODIFIER_PLAYER_UNIT_ADJUST_HIDDEN_VISIBILITY', [('Hidden', '1')]),
 'pillage': ('MODIFIER_PLAYER_UNIT_ADJUST_ADVANCED_PILLAGING', [('UseAdvancedPillaging', '1')]),
 'capturecav': ('MODIFIER_UNIT_ADJUST_COMBAT_UNIT_CAPTURE', [('CanCapture', '1')]),
 'ignoreshores': ('MODIFIER_PLAYER_UNIT_ADJUST_IGNORE_SHORES', [('Ignore', '1')]),
 'sight': ('MODIFIER_PLAYER_UNIT_ADJUST_SIGHT', [('Amount', None)]),
 'wallattack': ('MODIFIER_PLAYER_UNIT_ADJUST_ENABLE_WALL_ATTACK', [('Enable', '1')]),
 'seehidden': ('MODIFIER_PLAYER_UNIT_ADJUST_SEE_HIDDEN', [('SeeHidden', '1')]),
 'zglheal': ('MODIFIER_PLAYER_UNITS_ADJUST_HEAL_PER_TURN', [('Amount', None), ('Type', 'ALL')]),
 'zglmove': ('MODIFIER_PLAYER_UNITS_GRANT_ABILITY', [('AbilityType', 'ABILITY_HAN_ZGL_MOVE2')]),
 'bagua': ('MODIFIER_PLAYER_UNITS_GRANT_ABILITY', [('AbilityType', 'ABILITY_HAN_ZGL_BAGUA')]),
 'arrows': ('MODIFIER_PLAYER_UNITS_GRANT_ABILITY', [('AbilityType', 'ABILITY_HAN_ZGL_ARROWS')]),
}

def q(v): return "'" + str(v).replace("'", "''") + "'"
rows = {k: [] for k in ['Types', 'UnitPromotionClasses', 'UnitPromotions', 'UnitPromotionPrereqs', 'Modifiers', 'ModifierArguments', 'ModifierStrings', 'UnitPromotionModifiers']}
updates = []
for key, (zh, en, promos) in TREES.items():
    cls = 'PROMOTION_CLASS_HAN_' + key
    rows['Types'].append((cls, 'KIND_PROMOTION_CLASS'))
    rows['UnitPromotionClasses'].append((cls, 'LOC_%s_NAME' % cls))
    updates.append("UPDATE Units SET PromotionClass=%s WHERE UnitType=%s;" % (q(cls), q('UNIT_HAN_' + key)))
    for n, ((level, col), (pzh, pen, effects, dzh, den)) in enumerate(zip(SLOTS, promos), 1):
        pid = 'PROMOTION_HAN_%s_%d' % (key, n)
        rows['Types'].append((pid, 'KIND_PROMOTION'))
        rows['UnitPromotions'].append((pid, 'LOC_%s_NAME' % pid, 'LOC_%s_DESCRIPTION' % pid, level, col, cls))
        for pre in PREREQS.get(n, []):
            rows['UnitPromotionPrereqs'].append((pid, 'PROMOTION_HAN_%s_%d' % (key, pre)))
        for kind, amount in effects:
            if kind in ('rage25', 'execute35', 'awe', 'pierce', 'volley', 'stack'):
                continue  # 纯 Lua 判断，晋升本身没有修改器
            mid = 'HAN_%s_%d_%s' % (key, n, kind.upper())
            if kind in STRENGTH_SETS:
                rows['Modifiers'].append((mid, 'MODIFIER_UNIT_ADJUST_COMBAT_STRENGTH', STRENGTH_SETS[kind]))
                rows['ModifierArguments'].append((mid, 'Amount', amount))
                rows['ModifierStrings'].append((mid, 'Preview', 'LOC_%s_PREVIEW' % pid))
            elif kind == 'debuff':
                # 同毛利 Toa：给相邻的交战敌方单位挂一个减战斗力的修改器。
                rows['Modifiers'].append((mid, 'MODIFIER_ALL_UNITS_ATTACH_MODIFIER', 'VARU_ADJACENT_AT_WAR_REQUIREMENTS'))
                rows['ModifierArguments'].append((mid, 'ModifierId', mid + '_EFFECT'))
                rows['Modifiers'].append((mid + '_EFFECT', 'MODIFIER_UNIT_ADJUST_COMBAT_STRENGTH', None))
                rows['ModifierArguments'].append((mid + '_EFFECT', 'Amount', -amount))
                rows['ModifierStrings'].append((mid + '_EFFECT', 'Preview', 'LOC_%s_PREVIEW' % pid))
            else:
                mtype, args = SIMPLE[kind]
                rows['Modifiers'].append((mid, mtype, SUBJECT_SETS.get(kind)))
                for name, value in args:
                    rows['ModifierArguments'].append((mid, name, amount if value is None else value))
            rows['UnitPromotionModifiers'].append((pid, mid))

cols = {'Types': 'Type,Kind', 'UnitPromotionClasses': 'PromotionClassType,Name',
        'UnitPromotions': 'UnitPromotionType,Name,Description,Level,"Column",PromotionClass',
        'UnitPromotionPrereqs': 'UnitPromotion,PrereqUnitPromotion', 'Modifiers': 'ModifierId,ModifierType,SubjectRequirementSetId',
        'ModifierArguments': 'ModifierId,Name,Value', 'ModifierStrings': 'ModifierId,Context,Text',
        'UnitPromotionModifiers': 'UnitPromotionType,ModifierId'}
out = ['-- 五虎上将专属晋升树：每位武将一棵，7 个晋升，层次和前置关系与原版重骑兵树相同。',
       '-- 由 tools/han_liubei/promos_sql.py 生成，不要手改；数值和说明见 README.md。武将改用各自的晋升类别（只影响晋升树；兵种克制按标签判断，不受影响）。',
       '',
       '-- 赵云「虎威将军」：统率范围内 +1 移动力（同大将军的移动加成）。',
       "INSERT INTO Types(Type,Kind) VALUES('ABILITY_HAN_TIGER_COMMANDED_MOVE','KIND_ABILITY');",
       "INSERT INTO UnitAbilities(UnitAbilityType,Name,Description,Inactive) VALUES('ABILITY_HAN_TIGER_COMMANDED_MOVE','LOC_PROMOTION_HAN_ZHAO_YUN_7_NAME','LOC_PROMOTION_HAN_ZHAO_YUN_7_DESCRIPTION',1);",
       "INSERT INTO TypeTags(Type,Tag) SELECT 'ABILITY_HAN_TIGER_COMMANDED_MOVE',Tag FROM TypeTags WHERE Type='ABILITY_GREAT_GENERAL_STRENGTH';",
       "INSERT INTO Modifiers(ModifierId,ModifierType) VALUES('HAN_TIGER_COMMANDED_MOVE_BONUS','MODIFIER_PLAYER_UNIT_ADJUST_MOVEMENT');",
       "INSERT INTO ModifierArguments(ModifierId,Name,Value) VALUES('HAN_TIGER_COMMANDED_MOVE_BONUS','Amount',1);",
       "INSERT INTO UnitAbilityModifiers(UnitAbilityType,ModifierId) VALUES('ABILITY_HAN_TIGER_COMMANDED_MOVE','HAN_TIGER_COMMANDED_MOVE_BONUS');",
       '-- 诸葛亮晋升授予的能力：木牛流马（范围内五虎将 +1 移动）、八阵图（2 格内全军防守 +7）、草船借箭（范围内五虎将防远程 +10）。',
       "INSERT INTO Types(Type,Kind) VALUES('ABILITY_HAN_ZGL_MOVE2','KIND_ABILITY'),('ABILITY_HAN_ZGL_BAGUA','KIND_ABILITY'),('ABILITY_HAN_ZGL_ARROWS','KIND_ABILITY');",
       "INSERT INTO UnitAbilities(UnitAbilityType,Name,Description,Inactive) VALUES('ABILITY_HAN_ZGL_MOVE2','LOC_PROMOTION_HAN_ZHUGE_LIANG_2_NAME','LOC_PROMOTION_HAN_ZHUGE_LIANG_2_DESCRIPTION',1),('ABILITY_HAN_ZGL_BAGUA','LOC_PROMOTION_HAN_ZHUGE_LIANG_3_NAME','LOC_PROMOTION_HAN_ZHUGE_LIANG_3_DESCRIPTION',1),('ABILITY_HAN_ZGL_ARROWS','LOC_PROMOTION_HAN_ZHUGE_LIANG_5_NAME','LOC_PROMOTION_HAN_ZHUGE_LIANG_5_DESCRIPTION',1);",
       "INSERT INTO TypeTags(Type,Tag) VALUES('ABILITY_HAN_ZGL_MOVE2','CLASS_HAN_TIGER'),('ABILITY_HAN_ZGL_ARROWS','CLASS_HAN_TIGER');",
       "INSERT INTO TypeTags(Type,Tag) SELECT 'ABILITY_HAN_ZGL_BAGUA',Tag FROM TypeTags WHERE Type='ABILITY_GREAT_GENERAL_STRENGTH';",
       "INSERT INTO RequirementSets(RequirementSetId,RequirementSetType) VALUES('HAN_DEFENDING_VS_RANGED','REQUIREMENTSET_TEST_ALL');",
       "INSERT INTO RequirementSetRequirements(RequirementSetId,RequirementId) VALUES('HAN_DEFENDING_VS_RANGED','HAN_REQ_IS_DEFENDING'),('HAN_DEFENDING_VS_RANGED','RANGED_COMBAT_REQUIREMENTS');",
       "INSERT INTO Modifiers(ModifierId,ModifierType,SubjectRequirementSetId) VALUES('HAN_ZGL_MOVE2_BONUS','MODIFIER_PLAYER_UNIT_ADJUST_MOVEMENT',NULL),('HAN_ZGL_BAGUA_DEFENSE','MODIFIER_UNIT_ADJUST_COMBAT_STRENGTH','HAN_UNIT_IS_DEFENDING'),('HAN_ZGL_ARROWS_DEFENSE','MODIFIER_UNIT_ADJUST_COMBAT_STRENGTH','HAN_DEFENDING_VS_RANGED');",
       "INSERT INTO ModifierArguments(ModifierId,Name,Value) VALUES('HAN_ZGL_MOVE2_BONUS','Amount',1),('HAN_ZGL_BAGUA_DEFENSE','Amount',7),('HAN_ZGL_ARROWS_DEFENSE','Amount',10);",
       "INSERT INTO ModifierStrings(ModifierId,Context,Text) VALUES('HAN_ZGL_BAGUA_DEFENSE','Preview','LOC_PROMOTION_HAN_ZHUGE_LIANG_3_PREVIEW'),('HAN_ZGL_ARROWS_DEFENSE','Preview','LOC_PROMOTION_HAN_ZHUGE_LIANG_5_PREVIEW');",
       "INSERT INTO UnitAbilityModifiers(UnitAbilityType,ModifierId) VALUES('ABILITY_HAN_ZGL_MOVE2','HAN_ZGL_MOVE2_BONUS'),('ABILITY_HAN_ZGL_BAGUA','HAN_ZGL_BAGUA_DEFENSE'),('ABILITY_HAN_ZGL_ARROWS','HAN_ZGL_ARROWS_DEFENSE');",
       '',
       '-- 晋升树用到的需求组（进攻 / 防守需求组在 Gameplay.sql 中定义）。',
       "INSERT INTO RequirementSets(RequirementSetId,RequirementSetType) VALUES('HAN_OPPONENT_IS_DISTRICT','REQUIREMENTSET_TEST_ALL'),('HAN_OPPONENT_WOUNDED','REQUIREMENTSET_TEST_ALL');",
       "INSERT INTO RequirementSetRequirements(RequirementSetId,RequirementId) VALUES('HAN_OPPONENT_IS_DISTRICT','OPPONENT_IS_DISTRICT'),('HAN_OPPONENT_WOUNDED','REQUIRES_OPPONENT_IS_WOUNDED');",
       "INSERT INTO Requirements(RequirementId,RequirementType) VALUES('HAN_REQ_OPPONENT_ANTI_CAVALRY','REQUIREMENT_OPPONENT_UNIT_TAG_MATCHES');",
       "INSERT INTO RequirementArguments(RequirementId,Name,Value) VALUES('HAN_REQ_OPPONENT_ANTI_CAVALRY','Tag','CLASS_ANTI_CAVALRY');",
       "INSERT INTO RequirementSets(RequirementSetId,RequirementSetType) VALUES('HAN_OPPONENT_ANTI_CAVALRY','REQUIREMENTSET_TEST_ALL');",
       "INSERT INTO RequirementSetRequirements(RequirementSetId,RequirementId) VALUES('HAN_OPPONENT_ANTI_CAVALRY','HAN_REQ_OPPONENT_ANTI_CAVALRY');",
       '']
for table, rs in rows.items():
    out.append('INSERT INTO %s(%s) VALUES' % (table, cols[table]))
    out.append(',\n'.join('(' + ','.join('NULL' if v is None else (str(v) if isinstance(v, int) else q(v)) for v in r) + ')' for r in rs) + ';')
    out.append('')
out += updates + ['']
open(OUT, 'w', encoding='utf-8', newline='\n').write('\n'.join(out))
print('promotions:', len(rows['UnitPromotions']), 'modifiers:', len(rows['Modifiers']))
