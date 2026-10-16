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
t('LOC_LOADING_INFO_LEADER_LIU_BEI',
  '玄德公，汉室倾颓，奸臣窃命，天下豪杰并起。您本是中山靖王之后，织席贩履，却胸怀匡扶天下之志。桃园之中，关羽、张飞与您结为兄弟，誓同生死；'
  '此后赵云、马超、黄忠相继来投，卧龙诸葛亮亦为您三顾之诚所动，出山相助。您待人以仁、以德服人，所到之处百姓归心。'
  '如今五虎在侧、军师在帐，正当兴复汉室、还于旧都。您能否终结这乱世，让大汉之名再次响彻天下？',
  'Lord Xuande, the house of Han has fallen into ruin, its throne usurped by treacherous ministers, and warlords rise across the land. '
  'A descendant of Prince Jing of Zhongshan who once wove mats and sold sandals, you have never lost your resolve to set the realm right. '
  'In the peach garden, Guan Yu and Zhang Fei swore to live and die as your brothers; Zhao Yun, Ma Chao and Huang Zhong followed, and the Sleeping Dragon Zhuge Liang left his cottage, moved by your three visits. '
  'You rule with benevolence and win hearts with virtue, and the people flock to your banner. With the Five Tigers at your side and your strategist in your tent, the time has come to restore the Han. '
  'Can you end this age of chaos and make the name of Han ring out across the world once more?')

RES_ZH = '陆地作战单位迎战基础战斗力更强的单位时+5 [ICON_Strength] 战斗力。不是由本文明建立的城市每回合+3忠诚度。'
RES_EN = 'Land combat units receive +5 [ICON_Strength] Combat Strength when fighting a unit with higher base Combat Strength. Cities not founded by this civilization gain +3 Loyalty per turn.'
SHU_ZH = '陆地单位（含平民和支援单位）进入丘陵不额外消耗移动力。每个相邻的山脉或丘陵为商业中心提供+1 [ICON_Gold] 金币、为工业区提供+1 [ICON_Production] 生产力的标准相邻加成。'
SHU_EN = 'Land units (including civilian and support units) ignore the movement cost of Hills. Each adjacent Mountain or Hills tile provides a standard adjacency bonus of +1 [ICON_Gold] Gold to Commercial Hubs and +1 [ICON_Production] Production to Industrial Zones.'
TUN_ZH = '每个单位的维护费-1 [ICON_Gold] 金币。兵营+3 [ICON_Food] 粮食、+3 [ICON_Production] 生产力；兵营、马厩再各+3，军械库+4，军事学院+6（粮食和生产力各加这么多）。与兵营相邻的所有改良设施（农场、矿山、种植园、营地等）+1 [ICON_Food] 粮食、+1 [ICON_Production] 生产力。'
TUN_EN = 'Unit maintenance costs are reduced by 1 [ICON_Gold] Gold per unit. Encampments gain +3 [ICON_Food] Food and +3 [ICON_Production] Production; Barracks and Stables add another +3, Armories +4 and Military Academies +6 of each. All improvements adjacent to an Encampment (Farms, Mines, Plantations, Camps and so on) gain +1 [ICON_Food] Food and +1 [ICON_Production] Production.'
t('LOC_TRAIT_CIVILIZATION_HAN_RESTORATION_NAME', '兴复汉室', 'Restore the Han')
t('LOC_TRAIT_CIVILIZATION_HAN_RESTORATION_DESCRIPTION', RES_ZH, RES_EN)
t('LOC_TRAIT_CIVILIZATION_HAN_SHU_ROADS_NAME', '蜀道', 'Roads of Shu')
t('LOC_TRAIT_CIVILIZATION_HAN_SHU_ROADS_DESCRIPTION', SHU_ZH, SHU_EN)
t('LOC_TRAIT_CIVILIZATION_HAN_TUNTIAN_NAME', '屯田', 'Military Farms')
t('LOC_TRAIT_CIVILIZATION_HAN_TUNTIAN_DESCRIPTION', TUN_ZH, TUN_EN)
t('LOC_HAN_SETUP_ABILITY_NAME', '兴复汉室 / 蜀道 / 屯田', 'Restore the Han / Roads of Shu / Military Farms')
# 开局选文明画面（Config.sql）用精简版，完整数值留给游戏内的特性、百科和单位说明。
t('LOC_HAN_SETUP_ABILITY_DESCRIPTION',
  '兴复汉室：迎战更强的单位+5 [ICON_Strength] 战斗力；非本文明建立的城市每回合+3忠诚度。[NEWLINE]'
  '蜀道：进入丘陵不额外消耗移动力；山脉和丘陵为商业中心、工业区提供相邻加成。[NEWLINE]'
  '屯田：单位维护费-1；兵营及其建筑产出 [ICON_Food] 粮食和 [ICON_Production] 生产力，兵营旁的改良设施+1 [ICON_Food] +1 [ICON_Production]。',
  'Restore the Han: +5 [ICON_Strength] vs. stronger units; +3 Loyalty per turn in cities you did not found.[NEWLINE]'
  'Roads of Shu: no extra movement cost on Hills; Mountains and Hills give adjacency to Commercial Hubs and Industrial Zones.[NEWLINE]'
  'Military Farms: -1 unit maintenance; Encampments and their buildings yield [ICON_Food] Food and [ICON_Production] Production, and improvements next to them +1 [ICON_Food] +1 [ICON_Production].')
t('LOC_HAN_SETUP_LEADER_ABILITY_DESCRIPTION',
  '桃园结义：五虎上将随建都和科技免费加入，拥有3座城市时诸葛亮出山；所有单位战斗经验+100%，不获得大将军点数。[NEWLINE]'
  '厚施恩德，以收众心：忠诚度压力+150%，还能削弱18格内的敌城；因忠诚度叛离的城市直接归降。',
  'Oath of the Peach Garden: the Five Tiger Generals join for free as you found your Capital and research technologies, and Zhuge Liang joins at 3 cities; +100% combat experience, no Great General points.[NEWLINE]'
  'Win Hearts with Generous Virtue: +150% Loyalty pressure that also reaches enemy cities up to 18 tiles away; cities that rebel join you directly.')
t('LOC_HAN_SETUP_TIGERS_NAME', '五虎上将', 'Five Tiger Generals')
t('LOC_HAN_SETUP_TIGERS_DESCRIPTION',
  '关羽、张飞、赵云、马超、黄忠随建都和科技免费加入，不能训练，阵亡后不再出现。各有专属晋升树和终极技能，每个时代变强，并统率身边的军队。',
  'Guan Yu, Zhang Fei, Zhao Yun, Ma Chao and Huang Zhong join for free as you found your Capital and research technologies; they cannot be trained and never return once killed. Each has a unique promotion tree and ultimate, grows stronger every era and commands nearby troops.')
t('LOC_HAN_SETUP_ZHUGE_LIANG_DESCRIPTION',
  '拥有3座城市时出山的军师，远程作战单位。借东风火攻灼烧敌军，八阵图困住附近敌军，空城计守城，七星续命起死回生；也可以和五虎一同合体。',
  'A strategist who joins at 3 cities, fighting at range. Borrowing the East Wind sets enemies ablaze, the Eight Formations hinder nearby foes, the Empty Fort holds cities, and the Seven Stars bring him back from death; he can also join the Five Tigers\' merge.')
t('LOC_HAN_SETUP_WUHU_DESCRIPTION',
  '五人都学会终极技能并聚到关羽身边时，永久合为一体。可远程可近战，每回合攻击7次，攻击吸血并波及目标周围，隐身，移动和跳跃极远。',
  'When all five have their ultimate and gather around Guan Yu, they merge for good. Ranged and melee, 7 attacks per turn, lifesteal and splash around every target, stealth, and huge movement and jump range.')
t('LOC_ABILITY_HAN_RESTORATION_DESCRIPTION', '迎战基础战斗力更强的单位时+5 [ICON_Strength] 战斗力。', '+5 [ICON_Strength] Combat Strength when fighting a unit with higher base Combat Strength.')
t('LOC_HAN_RESTORATION_PREVIEW', '+{1_Amount} 兴复汉室：迎战更强的单位', '+{1_Amount} Restore the Han: fighting a stronger unit')
t('LOC_ABILITY_HAN_SHU_ROADS_DESCRIPTION', '进入丘陵不额外消耗移动力。', 'Ignores the movement cost of Hills.')
t('LOC_HAN_SHU_ROADS_MOUNTAIN_GOLD', '+{1_num} [ICON_Gold] 金币来自相邻山脉（蜀道）。', '+{1_num} [ICON_Gold] Gold from adjacent Mountain {1_Num : plural 1?tile; other?tiles;} (Roads of Shu).')
t('LOC_HAN_SHU_ROADS_HILLS_GOLD', '+{1_num} [ICON_Gold] 金币来自相邻丘陵（蜀道）。', '+{1_num} [ICON_Gold] Gold from adjacent Hills {1_Num : plural 1?tile; other?tiles;} (Roads of Shu).')
t('LOC_HAN_SHU_ROADS_HILLS_PRODUCTION', '+{1_num} [ICON_Production] 生产力来自相邻丘陵（蜀道）。', '+{1_num} [ICON_Production] Production from adjacent Hills {1_Num : plural 1?tile; other?tiles;} (Roads of Shu).')
t('LOC_HAN_SHU_ROADS_MOUNTAIN_PRODUCTION', '+{1_num} [ICON_Production] 生产力来自相邻山脉（蜀道）。', '+{1_num} [ICON_Production] Production from adjacent Mountain {1_Num : plural 1?tile; other?tiles;} (Roads of Shu).')

TIGERS_ZH = ('桃园结义：建立首都及研究特定科技时，五虎上将免费加入；拥有3座城市时诸葛亮加入。所有单位战斗经验+100%。不获得大将军点数。[NEWLINE]'
  '厚施恩德，以收众心：城市施加的忠诚度压力+150%。10~18格内其他文明的城市，每回合按这一范围内本文明城市的人口合计每2人口-1忠诚度（最多-20）。因忠诚度脱离其他文明的城市，在本文明施加的忠诚度压力最高时，跳过自由城市阶段直接加入本文明。')
TIGERS_EN = ('Oath of the Peach Garden: the Five Tiger Generals join for free when the [ICON_Capital] Capital is founded and as certain technologies are researched, and Zhuge Liang joins once you have 3 cities. All units gain +100% combat experience. Earns no Great General points.[NEWLINE]'
  'Win Hearts with Generous Virtue: cities exert +150% Loyalty pressure. Cities of other civilizations 10-18 tiles away lose 1 Loyalty per turn for every 2 [ICON_Citizen] Citizens in cities of this civilization within that range (up to -20). Cities rebelling from other civilizations join this civilization directly, skipping the Free City stage, when its Loyalty pressure on them is highest.')
t('LOC_TRAIT_LEADER_LIU_BEI_TIGERS_NAME', '桃园结义', 'Oath of the Peach Garden')
t('LOC_TRAIT_LEADER_LIU_BEI_TIGERS_DESCRIPTION', TIGERS_ZH, TIGERS_EN)
t('LOC_TRAIT_LEADER_LIU_BEI_TIGER_UNITS_NAME', '五虎上将与诸葛亮', 'Five Tiger Generals and Zhuge Liang')
t('LOC_TRAIT_LEADER_LIU_BEI_TIGER_UNITS_DESCRIPTION', '关羽、张飞、赵云、马超、黄忠，以及支援他们的诸葛亮。', 'Guan Yu, Zhang Fei, Zhao Yun, Ma Chao and Huang Zhong, supported by Zhuge Liang.')
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
  '武圣：进攻时+5 [ICON_Strength] 战斗力。万军丛中：无视区域控制。破城：攻击所有城墙都造成全额伤害。斩首：进攻后，若敌方单位剩余生命值不高于20，直接将其斩杀。过五关斩六将：击杀敌方单位后恢复20生命值。',
  'God of War: +5 [ICON_Strength] Combat Strength when attacking. Through Ten Thousand: ignores Zone of Control. Siege Breaker: full damage against all walls. Beheading: after attacking, an enemy unit left with 20 HP or less is killed outright. Five Passes, Six Generals: heals 20 HP after killing a unit.'),
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
t('LOC_UNIT_HAN_ZHUGE_LIANG_NAME', '诸葛亮', 'Zhuge Liang')
ZGL_ABILITY_ZH = ('借东风 · 火攻：远程攻击后，目标和周围一格内的敌军被点燃，接下来2回合每回合受到15伤害。[NEWLINE]'
  '八阵图：2格内与你交战的敌方单位-5 [ICON_Strength] 战斗力。[NEWLINE]'
  '空城计：驻守本方城市时，这座城的城墙和驻军防御每回合回满。[NEWLINE]'
  '出师表：2格内（含同格）的五虎将每回合额外恢复15生命值、+1 [ICON_Movement] 移动力。')
ZGL_ABILITY_EN = ('Borrowing the East Wind: after a ranged attack, enemy units on and next to the target are set ablaze and take 15 damage per turn for 2 turns.[NEWLINE]'
  'Eight Formations: enemy units at war with you within 2 tiles receive -5 [ICON_Strength] Combat Strength.[NEWLINE]'
  'Empty Fort: while he stands in one of your cities, its walls and garrison are fully restored every turn.[NEWLINE]'
  'Memorial on the Expedition: Tiger Generals within 2 tiles (including this tile) heal an extra 15 HP per turn and receive +1 [ICON_Movement] Movement.')
t('LOC_ABILITY_HAN_ZHUGE_LIANG_DESCRIPTION', ZGL_ABILITY_ZH, ZGL_ABILITY_EN)
t('LOC_ABILITY_HAN_ZGL_SUPPORTED_DESCRIPTION', '出师表：在诸葛亮2格范围内，+1 [ICON_Movement] 移动力。', 'Memorial on the Expedition: within 2 tiles of Zhuge Liang, +1 [ICON_Movement] Movement.')
t('LOC_HAN_ZGL_BAGUA_PREVIEW', '{1_Amount} 诸葛亮：八阵图', '{1_Amount} Zhuge Liang: Eight Formations')
t('LOC_UNIT_HAN_ZHUGE_LIANG_DESCRIPTION',
  '军师，远程作战单位。拥有3座城市时（三顾茅庐）在首都旁加入，不能训练或购买，阵亡后不再出现，没有维护费。远古基础20 [ICON_Strength] 战斗力、30 [ICON_Ranged] 远程攻击力，射程2，3 [ICON_Movement] 移动力，随时代成长同五虎上将。[NEWLINE]' + ZGL_ABILITY_ZH
  + '[NEWLINE]五虎合体时若诸葛亮也在关羽1格以内，会一同合入：五虎神将的统率光环变为5倍，并获得七星续命。',
  'Strategist who fights at range. Joins next to the [ICON_Capital] Capital once you have 3 cities (Three Visits to the Cottage); cannot be trained or purchased, never returns once killed, and has no maintenance. Ancient-era base 20 [ICON_Strength] Combat Strength, 30 [ICON_Ranged] Ranged Strength, Range 2, 3 [ICON_Movement] Movement; grows with each era like the Tiger Generals.[NEWLINE]' + ZGL_ABILITY_EN
  + '[NEWLINE]If he stands within 1 tile of Guan Yu when the Five Tigers merge, he joins them: the Five Tigers United gain a five-fold Command aura and Prolonging Life by the Seven Stars.')
for key, zh, en in [('GUAN_YU', '关羽', 'Guan Yu'), ('ZHANG_FEI', '张飞', 'Zhang Fei'), ('ZHAO_YUN', '赵云', 'Zhao Yun'), ('MA_CHAO', '马超', 'Ma Chao'), ('HUANG_ZHONG', '黄忠', 'Huang Zhong')]:
  t('LOC_HAN_TIGER_COMMANDED_PREVIEW_' + key, '+{1_Amount} 五虎齐心：' + zh + '统率', '+{1_Amount} Five Tigers as One: ' + en)
for k in range(1, 31):
  t('LOC_HAN_MA_CHAO_CHARGE_%d_PREVIEW' % k, '+{1_Amount} 神威天将军：冲锋%d格' % k, '+{1_Amount} Divine General: charged %d tile%s' % (k, '' if k == 1 else 's'))
t('LOC_ABILITY_HAN_MA_CHAO_CHARGE_NAME', '西凉铁骑冲锋', 'Xiliang Charge')
for k in range(1, 101):
  t('LOC_HAN_GUAN_YU_KILLS_%d_PREVIEW' % k, '+{1_Amount} 过五关斩六将：斩将%d人' % k, '+{1_Amount} Five Passes, Six Generals: %d kill%s' % (k, '' if k == 1 else 's'))
t('LOC_ABILITY_HAN_GUAN_YU_KILLS_NAME', '过五关斩六将', 'Five Passes, Six Generals')
t('LOC_ABILITY_HAN_GUAN_YU_KILLS_DESCRIPTION', '每击杀一个敌方单位，永久+1战斗力。', 'Permanently +1 Combat Strength for each enemy unit killed.')
t('LOC_ABILITY_HAN_MA_CHAO_CHARGE_DESCRIPTION', '本回合已冲锋，进攻时战斗力提高。', 'Charging this turn: stronger when attacking.')
WUHU_ABILITY_ZH = ('五虎合一：无视区域控制，攻击后仍可移动，+1视野（长驱直入），隐身，只有相邻的单位能看到（汉水空营），攻击所有城墙都造成全额伤害，可跳跃越过山脉，跳跃距离为移动力的4倍，登船时也能作战，远程攻击城市和区域无惩罚，对空+100。[NEWLINE]'
  '青龙偃月（关羽）：进攻后，若敌方单位剩余生命值不高于35，直接将其斩杀。每杀死一个敌方单位或攻下一座城市，18格内与你交战的城市忠诚度-40。[NEWLINE]'
  '过五关斩六将（关羽）：继承关羽的击杀数，每击杀一个敌方单位永久+1 [ICON_Strength] 战斗力。[NEWLINE]'
  '横扫千军 · 百步穿杨（张飞、黄忠）：每次进攻（近战或远程），目标周围一格内交战方的单位、城市和区域都受到与目标同等的伤害。[NEWLINE]'
  '七进七出（赵云）：每回合可攻击7次。每杀死一个敌方单位或攻下一座城市，立刻恢复全部移动力。[NEWLINE]'
  '白马银枪（赵云）：攻击吸血，进攻时对目标造成多少伤害，自己就恢复多少生命值。[NEWLINE]'
  '神威天将军（马超）：本回合每移动1格，进攻时+4 [ICON_Strength] 战斗力。')
WUHU_ABILITY_EN = ('Five as One: ignores Zone of Control, can move after attacking, +1 sight (Deep Strike), stealth - only visible to adjacent units (Empty Camp at the Han River), deals full damage against all walls, can jump over Mountains with a jump range of 4 times its Movement, can fight while embarked, has no ranged penalty against cities and districts, and +100 anti-air.[NEWLINE]'
  'Green Dragon Crescent Blade (Guan Yu): after attacking, an enemy unit left with 35 HP or less is killed outright. Each enemy unit killed or city taken costs enemy cities within 18 tiles 40 Loyalty.[NEWLINE]'
  'Five Passes, Six Generals (Guan Yu): inherits Guan Yu\'s kills; permanently +1 [ICON_Strength] Combat Strength for each enemy unit killed.[NEWLINE]'
  'Sweep and Rain of Arrows (Zhang Fei, Huang Zhong): every attack, melee or ranged, deals the same damage to enemy units, cities and districts next to the target.[NEWLINE]'
  'In and Out Seven Times (Zhao Yun): 7 attacks per turn. Movement is fully restored after killing an enemy unit or taking a city.[NEWLINE]'
  'White Horse, Silver Spear (Zhao Yun): lifesteal - heals as much HP as the damage dealt when attacking.[NEWLINE]'
  'Divine General (Ma Chao): +4 [ICON_Strength] Combat Strength when attacking for each tile moved this turn.')
WUHU_ZGL_ZH = '军师合体（合体时诸葛亮在关羽1格以内才有）：统率光环变为5倍，2格内友军+25 [ICON_Strength] 战斗力、+5 [ICON_Movement] 移动力；七星续命：每局一次，阵亡时在首都重新出现，生命值全满。'
WUHU_ZGL_EN = 'With the Strategist (only if Zhuge Liang stood within 1 tile of Guan Yu at the merge): five-fold Command aura, +25 [ICON_Strength] Combat Strength and +5 [ICON_Movement] Movement to friendly units within 2 tiles; Prolonging Life by the Seven Stars: once per game, when killed, reappears in the [ICON_Capital] Capital at full health.'
t('LOC_UNIT_HAN_WUHU_NAME', '五虎神将', 'Five Tigers United')
t('LOC_PROMOTION_CLASS_HAN_WUHU_NAME', '五虎神将', 'Five Tigers United')
t('LOC_ABILITY_HAN_WUHU_DESCRIPTION', WUHU_ABILITY_ZH, WUHU_ABILITY_EN)
t('LOC_ABILITY_HAN_WUHU_JUMP_NAME', '五虎合一：跳跃', 'Five as One: Jump')
t('LOC_ABILITY_HAN_WUHU_JUMP_DESCRIPTION', '跳跃距离为移动力的4倍。', 'Jump range is 4 times Movement.')
t('LOC_HAN_WUHU_ANTI_AIR_PREVIEW', '+{1_Amount} 五虎合一：对空', '+{1_Amount} Five as One: anti-air')
t('LOC_UNIT_HAN_WUHU_DESCRIPTION',
  '五位武将都学会终极晋升、都在关羽1格以内时，下回合开始永久合为一体（每局一次）。可远程也可近战：远古基础90 [ICON_Strength] 战斗力、85 [ICON_Ranged] 远程攻击力，射程3，15 [ICON_Movement] 移动力，随时代成长同五虎上将，带统率和虎将之勇。[NEWLINE]' + WUHU_ABILITY_ZH + '[NEWLINE]' + WUHU_ZGL_ZH,
  'When all five generals have learned their ultimate promotion and stand within 1 tile of Guan Yu, they permanently merge at the start of the next turn (once per game). Both ranged and melee: Ancient-era base 90 [ICON_Strength] Combat Strength, 85 [ICON_Ranged] Ranged Strength, Range 3, 15 [ICON_Movement] Movement; grows with each era like the Tiger Generals and has Command and Tiger\'s Courage.[NEWLINE]' + WUHU_ABILITY_EN + '[NEWLINE]' + WUHU_ZGL_EN)
t('LOC_HAN_WUHU_MESSAGE', '五虎合一', 'The Five Tigers Unite')
t('LOC_ABILITY_HAN_WUHU_COMMAND_NAME', '五虎统率（军师合体）', 'Five Tigers Command (with the Strategist)')
t('LOC_ABILITY_HAN_WUHU_COMMAND_DESCRIPTION', '2格内（含自身）的己方陆地作战单位+25 [ICON_Strength] 战斗力、+5 [ICON_Movement] 移动力。', 'Friendly land combat units within 2 tiles (including this tile) receive +25 [ICON_Strength] Combat Strength and +5 [ICON_Movement] Movement.')
t('LOC_ABILITY_HAN_WUHU_COMMANDED_DESCRIPTION', '在五虎神将2格范围内：+25 [ICON_Strength] 战斗力、+5 [ICON_Movement] 移动力。', 'Within 2 tiles of the Five Tigers United: +25 [ICON_Strength] Combat Strength and +5 [ICON_Movement] Movement.')
t('LOC_HAN_WUHU_COMMANDED_PREVIEW', '+{1_Amount} 五虎神将统率', '+{1_Amount} Commanded by the Five Tigers United')
t('LOC_HAN_QIXING_MESSAGE', '{1_Name}七星续命', '{1_Name}: the Seven Stars')
t('LOC_HAN_QIXING_SUMMARY', '{1_Name}阵亡后借七星续命，在{2_City}重新出现。', '{1_Name} fell but returned through the Seven Stars, reappearing in {2_City}.')
t('LOC_HAN_WUHU_SUMMARY', '关羽、张飞、赵云、马超、黄忠合为五虎神将。', 'Guan Yu, Zhang Fei, Zhao Yun, Ma Chao and Huang Zhong have merged into the Five Tigers United.')
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
STRENGTH_KINDS = {'atk', 'def', 'district', 'cav', 'wounded', 'vsanticav', 'defranged'}
for key, (zh, en, promos) in TREES.items():
  t('LOC_PROMOTION_CLASS_HAN_%s_NAME' % key, zh, en)
  for n, (pzh, pen, effects, dzh, den) in enumerate(promos, 1):
    pid = 'PROMOTION_HAN_%s_%d' % (key, n)
    t('LOC_%s_NAME' % pid, pzh, pen)
    t('LOC_%s_DESCRIPTION' % pid, dzh, den)
    if any(k == 'debuff' for k, _ in effects):
      t('LOC_%s_PREVIEW' % pid, '{1_Amount} ' + zh + '·' + pzh, '{1_Amount} ' + en + ': ' + pen)
    elif any(k in STRENGTH_KINDS for k, _ in effects):
      t('LOC_%s_PREVIEW' % pid, '+{1_Amount} ' + pzh, '+{1_Amount} ' + pen)

out = ["<?xml version='1.0' encoding='utf-8'?>", '<GameData>', '  <LocalizedText>']
for tag, (zh, en) in T.items():
  for lang, txt in (('zh_Hans_CN', zh), ('en_US', en)):
    out += ['    <Row Tag="%s" Language="%s">' % (tag, lang), '      <Text>%s</Text>' % escape(txt), '    </Row>']
out += ['  </LocalizedText>', '</GameData>', '']
open(OUT, 'w', encoding='utf-8', newline='\n').write('\n'.join(out))
print(len(T), 'tags')
