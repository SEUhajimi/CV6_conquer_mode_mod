-- 临时图标：借用原版单位、中国文明和秦始皇的图标。
INSERT INTO IconDefinitions(Name,Atlas,"Index")
SELECT 'ICON_UNIT_HAN_GUAN_YU'||Suffix,Atlas,"Index" FROM (SELECT '' AS Suffix UNION ALL SELECT '_PORTRAIT') s JOIN IconDefinitions ON Name='ICON_UNIT_KNIGHT'||Suffix
UNION ALL SELECT 'ICON_UNIT_HAN_ZHANG_FEI'||Suffix,Atlas,"Index" FROM (SELECT '' AS Suffix UNION ALL SELECT '_PORTRAIT') s JOIN IconDefinitions ON Name='ICON_UNIT_SPEARMAN'||Suffix
UNION ALL SELECT 'ICON_UNIT_HAN_ZHAO_YUN'||Suffix,Atlas,"Index" FROM (SELECT '' AS Suffix UNION ALL SELECT '_PORTRAIT') s JOIN IconDefinitions ON Name='ICON_UNIT_HORSEMAN'||Suffix
UNION ALL SELECT 'ICON_UNIT_HAN_MA_CHAO'||Suffix,Atlas,"Index" FROM (SELECT '' AS Suffix UNION ALL SELECT '_PORTRAIT') s JOIN IconDefinitions ON Name='ICON_UNIT_COURSER'||Suffix
UNION ALL SELECT 'ICON_UNIT_HAN_HUANG_ZHONG'||Suffix,Atlas,"Index" FROM (SELECT '' AS Suffix UNION ALL SELECT '_PORTRAIT') s JOIN IconDefinitions ON Name='ICON_UNIT_ARCHER'||Suffix;
INSERT INTO IconDefinitions(Name,Atlas,"Index") SELECT 'ICON_CIVILIZATION_HAN',Atlas,"Index" FROM IconDefinitions WHERE Name='ICON_CIVILIZATION_CHINA';
INSERT INTO IconDefinitions(Name,Atlas,"Index") SELECT 'ICON_LEADER_LIU_BEI',Atlas,"Index" FROM IconDefinitions WHERE Name='ICON_LEADER_QIN';
