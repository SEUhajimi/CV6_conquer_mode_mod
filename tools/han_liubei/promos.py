# 五虎上将专属晋升树数据，供 promos_sql.py 和 text.py 使用。改晋升后依次运行这两个脚本。
# 每棵树 7 个晋升，位置和前置关系照原版：(层, 列)
SLOTS = [(1, 1), (1, 3), (2, 1), (2, 3), (3, 1), (3, 3), (4, 2)]
# 第 n 个晋升的前置（任意一个即可），与原版重骑兵树相同
PREREQS = {3: [1, 4], 4: [2, 3], 5: [3], 6: [4], 7: [5, 6]}

# 效果：(类型, 数值)
#   atk 进攻 / def 防守 / district 对城市和区域 / cav 对骑兵 / wounded 对受伤单位：战斗力
#   move 移动力 / heal 每回合额外回血 / healact 行动后也回血 / attackmove 攻击后可移动 / ignorezoc 无视区域控制
#   ignorerivers 渡河不耗移动 / killheal 击杀回血 / nowound 受伤不降战斗力 / flank 侧翼加成% / range 射程
#   attacks 额外攻击次数 / nodistrictpenalty 远程攻城无惩罚
#   机制：healaura 自身和相邻回血 / capture 收降击败的单位 / debuff 相邻敌军减战斗力 / stealth 隐身
#         moveaura 统率范围 +1 移动 / convertbarb 收编蛮族 / pillage 劫掠只耗 1 移动
#         capturecav 进攻击败骑兵时俘获 / vsanticav 对抗骑兵 / ignoreshores 登船上岸不耗移动 / sight 视野
#         rage25 残血加成多一档 / execute35 关羽斩首线提高 / awe 关羽杀敌扣周围城市忠诚 / pierce 张飞刺穿身后 /
#         volley 黄忠溅射 / stack 诸葛亮五虎齐心（都由 Scripts/HanTigers.lua 判断，没有修改器）
#   诸葛亮：zglheal 范围内五虎将回血 / zglmove 范围内五虎将移动 / bagua 2 格内全军防守 / arrows 范围内五虎将防远程 / seehidden 看见隐身
#         wallattack 攻击城墙不受削弱
TREES = {
 'GUAN_YU': ('关羽', 'Guan Yu', [
  ('温酒斩华雄', 'Slaying Hua Xiong', [('atk', 7)], '进攻时+7 [ICON_Strength] 战斗力。', '+7 [ICON_Strength] Combat Strength when attacking.'),
  ('刮骨疗毒', 'Bone Scraping', [('healaura', 20)], '自身和相邻的己方单位每回合额外恢复20生命值（同医疗兵）。', 'This unit and adjacent friendly units heal an extra 20 HP per turn (like a Medic).'),
  ('斩颜良诛文丑', 'Slaying Yan Liang', [('attackmove', 0)], '攻击后仍可移动：斩将之后脱身。', 'Can move after attacking, to break away after a kill.'),
  ('单刀赴会', 'Alone to the Feast', [('def', 10)], '防守时+10 [ICON_Strength] 战斗力。', '+10 [ICON_Strength] Combat Strength when defending.'),
  ('水淹七军', 'Flooding the Seven Armies', [('district', 15)], '与城市和区域作战时+15 [ICON_Strength] 战斗力。', '+15 [ICON_Strength] Combat Strength when fighting cities and districts.'),
  ('过五关斩六将', 'Five Passes, Six Generals', [('move', 1)], '+1 [ICON_Movement] 移动力。', '+1 [ICON_Movement] Movement.'),
  ('威震华夏', 'Awe Over China', [('attacks', 1), ('execute35', 0), ('awe', 0), ('wallattack', 0)], '每回合可攻击两次，斩首线提高到35生命值，攻击城墙造成全额伤害（同攻城槌）。每杀死一个敌方单位，9格内与你交战的城市忠诚度-20。', 'Can attack twice per turn, Beheading triggers at 35 HP or less, and full damage against walls (like a Battering Ram). Each enemy unit he kills costs enemy cities at war with you within 9 tiles 20 Loyalty.'),
 ]),
 'ZHANG_FEI': ('张飞', 'Zhang Fei', [
  ('怒鞭督邮', 'Flogging the Inspector', [('atk', 7)], '进攻时+7 [ICON_Strength] 战斗力。', '+7 [ICON_Strength] Combat Strength when attacking.'),
  ('燕人张翼德', 'Zhang Yide of Yan', [('def', 7)], '防守时+7 [ICON_Strength] 战斗力。', '+7 [ICON_Strength] Combat Strength when defending.'),
  ('义释严颜', 'Sparing Yan Yan', [('capture', 0)], '击败敌方作战单位时将其收降，成为己方单位（同私掠船「战利品」的俘获机制）。', 'Captures defeated enemy combat units, which join your army (the same capture mechanic as the Privateer Prize promotion).'),
  ('怒发冲冠', 'Bristling with Rage', [('nowound', 0)], '受伤不降低战斗力，虎将之勇的残血加成全额生效。', 'Does not lose Combat Strength when damaged, so Tiger\'s Courage applies in full.'),
  ('喝断当阳桥', 'Roar at Dangyang Bridge', [('debuff', 7)], '相邻的交战敌方单位-7 [ICON_Strength] 战斗力（同毛利 Toa 的机制）。', 'Adjacent enemy units at war with you receive -7 [ICON_Strength] Combat Strength (the same mechanic as the Maori Toa).'),
  ('血战不退', 'No Retreat', [('rage25', 0)], '虎将之勇多一档：生命值低于75时也+7 [ICON_Strength] 战斗力。', 'Tiger\'s Courage gains a tier: +7 [ICON_Strength] Combat Strength already below 75 HP.'),
  ('丈八蛇矛', 'Serpent Spear', [('pierce', 0)], '一矛贯阵：进攻并击杀敌军后，被杀者身后一格里的交战敌方作战单位也被直接刺死。', 'Run Through: after killing an enemy while attacking, enemy combat units in the tile directly behind it are killed as well.'),
 ]),
 'ZHAO_YUN': ('赵云', 'Zhao Yun', [
  ('白马银枪', 'White Horse, Silver Spear', [('move', 1)], '+1 [ICON_Movement] 移动力。', '+1 [ICON_Movement] Movement.'),
  ('截江夺斗', 'Seizing the River', [('ignorerivers', 0), ('ignoreshores', 0)], '渡河、登船和上岸都不额外消耗移动力。', 'No extra Movement cost to cross rivers, embark or disembark.'),
  ('一身是胆', 'All Courage', [('atk', 7)], '进攻时+7 [ICON_Strength] 战斗力。', '+7 [ICON_Strength] Combat Strength when attacking.'),
  ('长坂救主', 'Rescue at Changban', [('killheal', 30)], '击杀敌方单位后恢复30生命值。', 'Heals 30 HP after killing a unit.'),
  ('汉水空营', 'Empty Camp at the Han', [('stealth', 0)], '隐身：只有相邻的单位能看到他。', 'Stealth: only visible to adjacent units.'),
  ('长驱直入', 'Deep Strike', [('move', 1), ('sight', 1)], '+1 [ICON_Movement] 移动力，+1视野。', '+1 [ICON_Movement] Movement and +1 Sight.'),
  ('虎威将军', 'Tiger-Might General', [('attacks', 1), ('moveaura', 1)], '每回合可攻击两次。统率范围内的单位再+1 [ICON_Movement] 移动力。', 'Can attack twice per turn. Units under his Command receive an additional +1 [ICON_Movement] Movement.'),
 ]),
 'MA_CHAO': ('马超', 'Ma Chao', [
  ('渭水奔袭', 'Raid on the Wei', [('cav', 7)], '对骑兵类单位再+7 [ICON_Strength] 战斗力。', 'An additional +7 [ICON_Strength] Combat Strength against cavalry.'),
  ('羌胡归心', 'Loyalty of the Qiang', [('move', 1), ('convertbarb', 0)], '+1 [ICON_Movement] 移动力。击败蛮族单位时将其收编（同秦始皇（一统天下）的机制）。', '+1 [ICON_Movement] Movement. Defeated barbarian units join your army (the same mechanic as Qin Shi Huang the Unifier).'),
  ('收服庞德', 'Winning Over Pang De', [('capturecav', 0)], '进攻并击败骑兵类单位时将其俘获，成为己方单位（同成吉思汗的机制）。', 'Captures cavalry units he defeats while attacking (the same mechanic as Genghis Khan).'),
  ('冲阵破枪', 'Breaking the Spear Wall', [('vsanticav', 10)], '对抗骑兵单位+10 [ICON_Strength] 战斗力，抵消其克制。', '+10 [ICON_Strength] Combat Strength against anti-cavalry units, offsetting their bonus.'),
  ('西凉旧部', 'Xiliang Raiders', [('ignorezoc', 0), ('pillage', 0)], '无视区域控制。劫掠只消耗1点移动力（同「掠夺」晋升）。', 'Ignores Zone of Control. Pillaging costs only 1 Movement (like the Depredation promotion).'),
  ('冀城血战', 'Siege of Ji', [('killheal', 30)], '击杀敌方单位后恢复30生命值。', 'Heals 30 HP after killing a unit.'),
  ('神威天将军', 'Divine General', [('cav', 10), ('move', 1)], '对骑兵类单位再+10 [ICON_Strength] 战斗力，+1 [ICON_Movement] 移动力。', 'An additional +10 [ICON_Strength] Combat Strength against cavalry and +1 [ICON_Movement] Movement.'),
 ]),
 'HUANG_ZHONG': ('黄忠', 'Huang Zhong', [
  ('百步穿杨', 'Hundred-Pace Archery', [('atk', 7)], '进攻时+7 [ICON_Strength] 战斗力。', '+7 [ICON_Strength] Combat Strength when attacking.'),
  ('老将坚守', 'Veteran Defense', [('def', 10)], '防守时+10 [ICON_Strength] 战斗力。', '+10 [ICON_Strength] Combat Strength when defending.'),
  ('长沙箭术', 'Archery of Changsha', [('nodistrictpenalty', 0)], '远程攻击城市和区域时不受惩罚。', 'No penalty when making ranged attacks against cities and districts.'),
  ('宝刀未老', 'Blade Not Yet Dull', [('heal', 10), ('healact', 0)], '每回合额外恢复10生命值，移动或行动后也能恢复。', '+10 HP healed per turn, even after moving or acting.'),
  ('神射', 'Divine Archer', [('range', 1)], '+1射程。', '+1 Range.'),
  ('定军山斩夏侯渊', 'Slaying Xiahou Yuan', [('attacks', 1)], '每回合可攻击两次。', 'Can attack twice per turn.'),
  ('万箭齐发', 'Ten Thousand Arrows', [('volley', 0)], '远程攻击后，目标周围一格内的交战敌方作战单位各受20点伤害（打城市和区域也算）。', 'After a ranged attack, enemy combat units within 1 tile of the target each take 20 damage (also when attacking cities and districts).'),
 ]),
 'ZHUGE_LIANG': ('诸葛亮', 'Zhuge Liang', [
  ('隆中对', 'Longzhong Plan', [('zglheal', 10)], '范围内的五虎将每回合再恢复10生命值。', 'Tiger Generals in range heal another 10 HP per turn.'),
  ('木牛流马', 'Wooden Oxen', [('move', 1), ('zglmove', 1)], '+1 [ICON_Movement] 移动力；范围内的五虎将再+1 [ICON_Movement] 移动力。', '+1 [ICON_Movement] Movement; Tiger Generals in range receive another +1 [ICON_Movement] Movement.'),
  ('八阵图', 'Eight Formations', [('bagua', 7)], '2格内（含同格）的己方陆地作战单位防守时+7 [ICON_Strength] 战斗力。', 'Friendly land combat units within 2 tiles (including this tile) receive +7 [ICON_Strength] Combat Strength when defending.'),
  ('空城计', 'Empty Fort', [('stealth', 0)], '隐身：只有相邻的单位能看到他。', 'Stealth: only visible to adjacent units.'),
  ('草船借箭', 'Borrowing Arrows', [('arrows', 10)], '范围内的五虎将防守远程攻击时+10 [ICON_Strength] 战斗力。', 'Tiger Generals in range receive +10 [ICON_Strength] Combat Strength when defending against ranged attacks.'),
  ('观星', 'Reading the Stars', [('sight', 2), ('seehidden', 0)], '+2视野，能看到隐身单位。', '+2 Sight and can see stealth units.'),
  ('五虎齐心', 'Five Tigers as One', [('stack', 0)], '五虎将的统率光环互相叠加：每位武将的+5 [ICON_Strength] 战斗力、+1 [ICON_Movement] 移动力分别生效。', 'The Tiger Generals\' Command auras stack: each general\'s +5 [ICON_Strength] Combat Strength and +1 [ICON_Movement] Movement applies separately.'),
 ]),
}
