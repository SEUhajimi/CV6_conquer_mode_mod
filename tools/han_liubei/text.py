# 生成 Han_LiuBei/Data/Text.xml（中英文本的唯一来源，不要手改生成结果）：python tools/han_liubei/text.py
# 晋升的名称和说明来自 promos.py。
import sys
from pathlib import Path
from xml.sax.saxutils import escape
sys.path.insert(0, str(Path(__file__).resolve().parent))

OUT = Path(__file__).resolve().parents[2] / 'Han_LiuBei' / 'Data' / 'Text.xml'
T = {}
def t(tag, zh, en): T[tag] = (zh, en)

t('LOC_CIVILIZATION_HAN_NAME', '汉帝国', 'Han Empire')
t('LOC_CIVILIZATION_HAN_DESCRIPTION', '汉帝国', 'Han Empire')
t('LOC_CIVILIZATION_HAN_ADJECTIVE', '汉', 'Han')
t('LOC_LEADER_LIU_BEI_NAME', '刘备', 'Liu Bei')

RES_ZH = '陆地作战单位迎战基础战斗力更强的单位时+5 [ICON_Strength] 战斗力。不是由本文明建立的城市每回合+3忠诚度。'
RES_EN = 'Land combat units receive +5 [ICON_Strength] Combat Strength when fighting a unit with higher base Combat Strength. Cities not founded by this civilization gain +3 Loyalty per turn.'
SHU_ZH = '陆地单位（含平民和支援单位）进入丘陵不额外消耗移动力。山脉为商业中心提供+1 [ICON_Gold] 金币、为工业区提供+1 [ICON_Production] 生产力的标准相邻加成。'
SHU_EN = 'Land units (including civilian and support units) ignore the movement cost of Hills. Mountains provide a standard adjacency bonus of +1 [ICON_Gold] Gold to Commercial Hubs and +1 [ICON_Production] Production to Industrial Zones.'
TUN_ZH = '每个单位的维护费-1 [ICON_Gold] 金币。兵营及其建筑不再产出大将军点数，改为兵营+2 [ICON_Production] 生产力、其中每座建筑再+2 [ICON_Production] 生产力。与兵营相邻的所有改良设施（农场、矿山、种植园、营地等）+1 [ICON_Food] 粮食、+1 [ICON_Production] 生产力。'
TUN_EN = 'Unit maintenance costs are reduced by 1 [ICON_Gold] Gold per unit. Encampments and their buildings no longer generate Great General points; instead the Encampment gains +2 [ICON_Production] Production and each of its buildings another +2 [ICON_Production] Production. All improvements adjacent to an Encampment (Farms, Mines, Plantations, Camps and so on) gain +1 [ICON_Food] Food and +1 [ICON_Production] Production.'
t('LOC_TRAIT_CIVILIZATION_HAN_RESTORATION_NAME', '兴复汉室', 'Restore the Han')
t('LOC_TRAIT_CIVILIZATION_HAN_RESTORATION_DESCRIPTION', RES_ZH, RES_EN)
t('LOC_TRAIT_CIVILIZATION_HAN_SHU_ROADS_NAME', '蜀道', 'Roads of Shu')
t('LOC_TRAIT_CIVILIZATION_HAN_SHU_ROADS_DESCRIPTION', SHU_ZH, SHU_EN)
t('LOC_TRAIT_CIVILIZATION_HAN_TUNTIAN_NAME', '屯田', 'Military Farms')
t('LOC_TRAIT_CIVILIZATION_HAN_TUNTIAN_DESCRIPTION', TUN_ZH, TUN_EN)
t('LOC_HAN_SETUP_ABILITY_NAME', '兴复汉室 / 蜀道 / 屯田', 'Restore the Han / Roads of Shu / Military Farms')
t('LOC_HAN_SETUP_ABILITY_DESCRIPTION',
  '兴复汉室：' + RES_ZH + '[NEWLINE][NEWLINE]蜀道：' + SHU_ZH + '[NEWLINE][NEWLINE]屯田：' + TUN_ZH,
  'Restore the Han: ' + RES_EN + '[NEWLINE][NEWLINE]Roads of Shu: ' + SHU_EN + '[NEWLINE][NEWLINE]Military Farms: ' + TUN_EN)
t('LOC_ABILITY_HAN_RESTORATION_DESCRIPTION', '迎战基础战斗力更强的单位时+5 [ICON_Strength] 战斗力。', '+5 [ICON_Strength] Combat Strength when fighting a unit with higher base Combat Strength.')
t('LOC_HAN_RESTORATION_PREVIEW', '+{1_Amount} 兴复汉室：迎战更强的单位', '+{1_Amount} Restore the Han: fighting a stronger unit')
t('LOC_ABILITY_HAN_SHU_ROADS_DESCRIPTION', '进入丘陵不额外消耗移动力。', 'Ignores the movement cost of Hills.')
t('LOC_HAN_SHU_ROADS_MOUNTAIN_GOLD', '+{1_num} [ICON_Gold] 金币来自相邻山脉（蜀道）。', '+{1_num} [ICON_Gold] Gold from adjacent Mountain {1_Num : plural 1?tile; other?tiles;} (Roads of Shu).')
t('LOC_HAN_SHU_ROADS_MOUNTAIN_PRODUCTION', '+{1_num} [ICON_Production] 生产力来自相邻山脉（蜀道）。', '+{1_num} [ICON_Production] Production from adjacent Mountain {1_Num : plural 1?tile; other?tiles;} (Roads of Shu).')

TIGERS_ZH = ('桃园结义：建立首都及研究特定科技时，五虎上将免费加入。所有单位战斗经验+100%。[NEWLINE]'
  '厚施恩德，以收众心：城市施加的忠诚度压力+50%。因忠诚度脱离其他文明的城市，在本文明施加的忠诚度压力最高时，跳过自由城市阶段直接加入本文明。')
TIGERS_EN = ('Oath of the Peach Garden: the Five Tiger Generals join for free when the [ICON_Capital] Capital is founded and as certain technologies are researched. All units gain +100% combat experience.[NEWLINE]'
  'Win Hearts with Generous Virtue: cities exert +50% Loyalty pressure. Cities rebelling from other civilizations join this civilization directly, skipping the Free City stage, when its Loyalty pressure on them is highest.')
t('LOC_TRAIT_LEADER_LIU_BEI_TIGERS_NAME', '桃园结义', 'Oath of the Peach Garden')
t('LOC_TRAIT_LEADER_LIU_BEI_TIGERS_DESCRIPTION', TIGERS_ZH, TIGERS_EN)
t('LOC_TRAIT_LEADER_LIU_BEI_TIGER_UNITS_NAME', '五虎上将', 'Five Tiger Generals')
t('LOC_TRAIT_LEADER_LIU_BEI_TIGER_UNITS_DESCRIPTION', '关羽、张飞、赵云、马超、黄忠。', 'Guan Yu, Zhang Fei, Zhao Yun, Ma Chao and Huang Zhong.')
t('LOC_ABILITY_HAN_TIGER_ERA_NAME', '随时代成长', 'Veteran of the Ages')
t('LOC_ABILITY_HAN_TIGER_ERA_DESCRIPTION', '本文明每进入一个新时代+8 [ICON_Strength] 战斗力。', '+8 [ICON_Strength] Combat Strength for each new era this civilization enters.')
for era, zh, en in [('CLASSICAL', '古典', 'Classical'), ('MEDIEVAL', '中世纪', 'Medieval'), ('RENAISSANCE', '文艺复兴', 'Renaissance'),
                    ('INDUSTRIAL', '工业', 'Industrial'), ('MODERN', '现代', 'Modern'), ('ATOMIC', '原子能', 'Atomic'),
                    ('INFORMATION', '信息', 'Information'), ('FUTURE', '未来', 'Future')]:
  t('LOC_HAN_TIGER_STRENGTH_PREVIEW_ERA_' + era, '+{1_Amount} 五虎上将：' + zh + '时代', '+{1_Amount} Five Tigers: ' + en + ' Era')

common_zh = '[NEWLINE]五虎上将之一：达成加入条件后在首都旁免费加入，不能训练或购买，阵亡后不再出现。统率：2格内（含自身）的己方陆地作战单位+5 [ICON_Strength] 战斗力、+1 [ICON_Movement] 移动力，可与大将军叠加。虎将之勇：生命值低于50时+7 [ICON_Strength] 战斗力，低于25时再+7。没有维护费，可以获得经验和晋升，但不能升级。本文明每进入一个新时代+8 [ICON_Strength] 战斗力（远程攻击同样生效）。'
common_en = '[NEWLINE]One of the Five Tiger Generals: joins for free next to the [ICON_Capital] Capital once its condition is met; cannot be trained or purchased and never returns once killed. Command: friendly land combat units within 2 tiles (including this unit) receive +5 [ICON_Strength] Combat Strength and +1 [ICON_Movement] Movement; stacks with Great Generals. Tiger\'s Courage: +7 [ICON_Strength] Combat Strength below 50 HP, and another +7 below 25 HP. No maintenance; earns experience and promotions but cannot upgrade. +8 [ICON_Strength] Combat Strength (ranged attacks included) for each new era this civilization enters.'
units = [
 ('GUAN_YU', '关羽', 'Guan Yu',
  '建立首都时加入的重骑兵，远古基础34 [ICON_Strength] 战斗力，4 [ICON_Movement] 移动力。',
  'Heavy cavalry that joins when the [ICON_Capital] Capital is founded. Ancient-era base 34 [ICON_Strength] Combat Strength, 4 [ICON_Movement] Movement.',
  '武圣：进攻时+5 [ICON_Strength] 战斗力。万军丛中：无视区域控制。斩首：进攻后，若敌方单位剩余生命值不高于20，直接将其斩杀。过五关斩六将：击杀敌方单位后恢复20生命值。',
  'God of War: +5 [ICON_Strength] Combat Strength when attacking. Through Ten Thousand: ignores Zone of Control. Beheading: after attacking, an enemy unit left with 20 HP or less is killed outright. Five Passes, Six Generals: heals 20 HP after killing a unit.'),
 ('ZHANG_FEI', '张飞', 'Zhang Fei',
  '建立首都时加入的抗骑兵单位，远古基础32 [ICON_Strength] 战斗力，3 [ICON_Movement] 移动力。',
  'Anti-cavalry unit that joins when the [ICON_Capital] Capital is founded. Ancient-era base 32 [ICON_Strength] Combat Strength, 3 [ICON_Movement] Movement.',
  '万人敌：防守时+7 [ICON_Strength] 战斗力。',
  'Match for Ten Thousand: +7 [ICON_Strength] Combat Strength when defending.'),
 ('ZHAO_YUN', '赵云', 'Zhao Yun',
  '研究骑术时加入的轻骑兵，远古基础30 [ICON_Strength] 战斗力，5 [ICON_Movement] 移动力。',
  'Light cavalry that joins with Horseback Riding. Ancient-era base 30 [ICON_Strength] Combat Strength, 5 [ICON_Movement] Movement.',
  '七进七出：无视区域控制，攻击后仍可移动。',
  'In and Out Seven Times: ignores Zone of Control and can move after attacking.'),
 ('MA_CHAO', '马超', 'Ma Chao',
  '研究马镫时加入的轻骑兵，远古基础32 [ICON_Strength] 战斗力，5 [ICON_Movement] 移动力。',
  'Light cavalry that joins with Stirrups. Ancient-era base 32 [ICON_Strength] Combat Strength, 5 [ICON_Movement] Movement.',
  '西凉铁骑：侧翼加成+100%。锦马超：对骑兵类单位+5 [ICON_Strength] 战斗力。',
  'Xiliang Cavalry: +100% flanking bonus. Splendid Ma Chao: +5 [ICON_Strength] Combat Strength against cavalry.'),
 ('HUANG_ZHONG', '黄忠', 'Huang Zhong',
  '研究机械时加入的远程单位，远古基础22 [ICON_Strength] 战斗力、32 [ICON_Ranged] 远程攻击力，射程2，3 [ICON_Movement] 移动力。',
  'Ranged unit that joins with Machinery. Ancient-era base 22 [ICON_Strength] Combat Strength, 32 [ICON_Ranged] Ranged Strength, Range 2, 3 [ICON_Movement] Movement.',
  '老当益壮：受伤不降低战斗力。定军山：对满生命值的单位+5 [ICON_Strength] 战斗力。',
  'Old but Vigorous: does not lose Combat Strength when damaged. Mount Dingjun: +5 [ICON_Strength] Combat Strength against units at full health.'),
]
previews = {
 'GUAN_YU': ('LOC_HAN_GUAN_YU_ATTACK_PREVIEW', '+{1_Amount} 武圣：进攻', '+{1_Amount} God of War: attacking'),
 'ZHANG_FEI': ('LOC_HAN_ZHANG_FEI_DEFENSE_PREVIEW', '+{1_Amount} 万人敌：防守', '+{1_Amount} Match for Ten Thousand: defending'),
 'MA_CHAO': ('LOC_HAN_MA_CHAO_VS_CAVALRY_PREVIEW', '+{1_Amount} 锦马超：对骑兵', '+{1_Amount} Splendid Ma Chao: vs. cavalry'),
 'HUANG_ZHONG': ('LOC_HAN_HUANG_ZHONG_VS_FULL_HEALTH_PREVIEW', '+{1_Amount} 定军山：对满生命值单位', '+{1_Amount} Mount Dingjun: vs. full-health unit'),
}
for key, zh, en, szh, sen, azh, aen in units:
  t('LOC_UNIT_HAN_%s_NAME' % key, zh, en)
  t('LOC_UNIT_HAN_%s_DESCRIPTION' % key, szh + azh + common_zh, sen + ' ' + aen + common_en)
  t('LOC_ABILITY_HAN_%s_DESCRIPTION' % key, azh, aen)
  if previews.get(key):
    t(*previews[key])

t('LOC_ABILITY_HAN_TIGER_COMMAND_NAME', '统率', 'Command')
t('LOC_ABILITY_HAN_TIGER_COMMAND_DESCRIPTION', '2格内（含自身）的己方陆地作战单位+5 [ICON_Strength] 战斗力、+1 [ICON_Movement] 移动力，不受时代限制。可与大将军叠加，多位武将之间不叠加。', 'Friendly land combat units within 2 tiles (including this unit) receive +5 [ICON_Strength] Combat Strength and +1 [ICON_Movement] Movement, with no era limit. Stacks with Great Generals but not with other Tiger Generals.')
t('LOC_ABILITY_HAN_TIGER_COMMANDED_DESCRIPTION', '在五虎上将2格范围内：+5 [ICON_Strength] 战斗力、+1 [ICON_Movement] 移动力。', 'Within 2 tiles of a Tiger General: +5 [ICON_Strength] Combat Strength and +1 [ICON_Movement] Movement.')
t('LOC_HAN_TIGER_COMMANDED_PREVIEW', '+{1_Amount} 五虎上将统率', '+{1_Amount} Commanded by a Tiger General')
for tier, hp in [(25, '75'), (50, '50'), (75, '25')]:
  t('LOC_HAN_TIGER_RAGE_%d_PREVIEW' % tier, '+{1_Amount} 虎将之勇：生命值低于' + hp, '+{1_Amount} Tiger\'s Courage: below ' + hp + ' HP')
t('LOC_ABILITY_HAN_TIGER_RAGE_NAME', '虎将之勇', 'Tiger\'s Courage')
t('LOC_ABILITY_HAN_TIGER_RAGE_DESCRIPTION', '残血加成生效中。', 'Low-health bonus active.')
t('LOC_HAN_AWE_OVER_CHINA_FLYOVER', '威震华夏 {1_Amount} [ICON_PressureDown] 忠诚度', 'Awe Over China {1_Amount} [ICON_PressureDown] Loyalty')
t('LOC_HAN_TIGER_JOINED_MESSAGE', '{1_Name}来投', '{1_Name} has joined')
t('LOC_HAN_TIGER_JOINED_SUMMARY', '五虎上将{1_Name}已在{2_City}旁加入你的军队。', 'Tiger General {1_Name} has joined your army near {2_City}.')

cities = [('CHENGDU', '成都', 'Chengdu'), ('HANZHONG', '汉中', 'Hanzhong'), ('JIANGLING', '江陵', 'Jiangling'),
          ('JIANGZHOU', '江州', 'Jiangzhou'), ('ZHUOXIAN', '涿县', 'Zhuoxian'), ('XINYE', '新野', 'Xinye'),
          ('XIAOPEI', '小沛', 'Xiaopei'), ('XIAPI', '下邳', 'Xiapi'), ('GONGAN', '公安', "Gong'an"),
          ('YONGAN', '永安', "Yong'an"), ('MIANZHU', '绵竹', 'Mianzhu'), ('ZITONG', '梓潼', 'Zitong'),
          ('LANGZHONG', '阆中', 'Langzhong'), ('FUCHENG', '涪城', 'Fucheng'), ('JIANNING', '建宁', 'Jianning'),
          ('YUEXI', '越嶲', 'Yuexi'), ('WUDU', '武都', 'Wudu'), ('YINPING', '阴平', 'Yinping'),
          ('BAIDI', '白帝', 'Baidi'), ('JIAMENG', '葭萌', 'Jiameng')]
for k, zh, en in cities:
  t('LOC_CITY_NAME_HAN_' + k, zh, en)

from promos import TREES
STRENGTH_KINDS = {'atk', 'def', 'district', 'cav', 'wounded', 'vsanticav'}
for key, (zh, en, promos) in TREES.items():
  t('LOC_PROMOTION_CLASS_HAN_%s_NAME' % key, zh, en)
  for n, (pzh, pen, effects, dzh, den) in enumerate(promos, 1):
    pid = 'PROMOTION_HAN_%s_%d' % (key, n)
    t('LOC_%s_NAME' % pid, pzh, pen)
    t('LOC_%s_DESCRIPTION' % pid, dzh, den)
    if any(k == 'debuff' for k, _ in effects):
      t('LOC_%s_PREVIEW' % pid, '{1_Amount} ' + zh + '·' + pzh, '{1_Amount} ' + en + ': ' + pen)
    elif any(k in STRENGTH_KINDS or k == 'auraplus' for k, _ in effects):
      t('LOC_%s_PREVIEW' % pid, '+{1_Amount} ' + pzh, '+{1_Amount} ' + pen)

out = ["<?xml version='1.0' encoding='utf-8'?>", '<GameData>', '  <LocalizedText>']
for tag, (zh, en) in T.items():
  for lang, txt in (('zh_Hans_CN', zh), ('en_US', en)):
    out += ['    <Row Tag="%s" Language="%s">' % (tag, lang), '      <Text>%s</Text>' % escape(txt), '    </Row>']
out += ['  </LocalizedText>', '</GameData>', '']
open(OUT, 'w', encoding='utf-8', newline='\n').write('\n'.join(out))
print(len(T), 'tags')
