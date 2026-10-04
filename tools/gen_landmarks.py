"""
生成 CivConquestMode/ArtDefs/Landmarks.artdef

问题：很多特色改良/建筑的地标模型只登记了原文明的文化标签
（如 LM_PYRAMID 只有 Tag_Culture = Civilization:CIVILIZATION_NUBIA），
其他文明通过征服模式建造时找不到匹配的模型，显示为红色感叹号。

做法：扫描本体与 DLC 的 Landmarks.artdef，找出“所有变体都只针对特定文明”的地标，
为每个变体复制一份 Tag_Culture = Culture:DEFAULT 的版本（模型完全相同），
作为任意文明的兜底。原文明的显示不受影响。

用法：python tools/gen_landmarks.py [游戏安装目录]
"""
import copy
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

DEFAULT_GAME_DIR = r"D:\Steam\steamapps\common\Sid Meier's Civilization VI"
OUT = Path(__file__).resolve().parent.parent / "CivConquestMode" / "ArtDefs" / "Landmarks.artdef"


def find_artdefs(game_dir: Path):
    files = [game_dir / "Base" / "ArtDefs" / "Landmarks.artdef"]
    for dlc in sorted((game_dir / "DLC").iterdir()):
        # 剧本 DLC 只在对应剧本中加载，不参与
        if "Scenario" in dlc.name:
            continue
        f = dlc / "ArtDefs" / "Landmarks.artdef"
        if f.exists():
            files.append(f)
    return files


def param(values, name):
    for v in values:
        p = v.find("m_ParamName")
        if p is not None and p.get("text") == name:
            return v
    return None


def entry_key(era_elem):
    """用 (时代, 魅力, 模型) 去重。"""
    values = era_elem.find("m_Fields/m_Values")
    def text(name, child):
        v = param(values, name)
        c = v.find(child) if v is not None else None
        return c.get("text") if c is not None else ""
    return (text("Tag_Era", "m_ElementName"), text("Tag_Appeal", "m_ElementName"),
            text("Asset", "m_EntryName"), text("Asset", "m_BLPPackage"))


def main():
    game_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(DEFAULT_GAME_DIR)

    # 地标名 -> {"fields": 首次出现的 m_Fields, "entries": [Eras 元素], "generic": bool}
    landmarks = {}
    for f in find_artdefs(game_dir):
        root = ET.parse(f).getroot()
        for coll in root.find("m_RootCollections"):
            name_el = coll.find("m_CollectionName")
            if name_el is None or name_el.get("text") != "Landmarks":
                continue
            for lm in coll.findall("Element"):
                lm_name = lm.find("m_Name").get("text")
                info = landmarks.setdefault(lm_name, {"fields": lm.find("m_Fields"), "entries": [], "generic": False})
                for child in lm.find("m_ChildCollections"):
                    if child.find("m_CollectionName").get("text") != "Eras":
                        continue
                    for era in child.findall("Element"):
                        values = era.find("m_Fields/m_Values")
                        culture = param(values, "Tag_Culture")
                        root_name = culture.find("m_RootCollectionName").get("text") if culture is not None else ""
                        if root_name == "Civilization":
                            info["entries"].append(era)
                        else:
                            info["generic"] = True

    targets = {k: v for k, v in landmarks.items() if not v["generic"] and v["entries"]}

    out_root = ET.Element("AssetObjects..ArtDefSet")
    ver = ET.SubElement(out_root, "m_Version")
    for tag, val in (("major", "4"), ("minor", "0"), ("build", "291"), ("revision", "558")):
        ET.SubElement(ver, tag).text = val
    ET.SubElement(out_root, "m_TemplateName", text="Landmarks")
    roots = ET.SubElement(out_root, "m_RootCollections")
    coll = ET.SubElement(roots, "Element")
    ET.SubElement(coll, "m_CollectionName", text="Landmarks")
    ET.SubElement(coll, "m_ReplaceMergedCollectionElements").text = "false"

    for lm_name in sorted(targets):
        info = targets[lm_name]
        lm = ET.SubElement(coll, "Element")
        lm.append(copy.deepcopy(info["fields"]) if info["fields"] is not None else ET.Element("m_Fields"))
        children = ET.SubElement(lm, "m_ChildCollections")
        eras = ET.SubElement(children, "Element")
        ET.SubElement(eras, "m_CollectionName", text="Eras")
        ET.SubElement(eras, "m_ReplaceMergedCollectionElements").text = "false"

        seen = set()
        for i, era in enumerate(info["entries"]):
            key = entry_key(era)
            if key in seen:
                continue
            seen.add(key)
            new = copy.deepcopy(era)
            culture = param(new.find("m_Fields/m_Values"), "Tag_Culture")
            culture.find("m_ElementName").set("text", "DEFAULT")
            culture.find("m_RootCollectionName").set("text", "Culture")
            culture.find("m_ArtDefPath").set("text", "Cultures.artdef")
            culture.find("m_TemplateName").set("text", "")
            new.find("m_Name").set("text", f"CQ_DefaultCulture{len(seen):03d}")
            eras.append(new)

        ET.SubElement(lm, "m_Name", text=lm_name)
        ET.SubElement(lm, "m_AppendMergedParameterCollections").text = "false"

    ET.indent(out_root, space="\t")
    OUT.parent.mkdir(parents=True, exist_ok=True)
    with open(OUT, "wb") as fp:
        fp.write(b'<?xml version="1.0" encoding="UTF-8" ?>\n')
        # 与官方 artdef 格式保持一致（<x/> 而不是 <x />）
        fp.write(ET.tostring(out_root, encoding="utf-8").replace(b" />", b"/>"))
        fp.write(b"\n")

    print(f"{len(targets)} landmarks -> {OUT}")
    for name in sorted(targets):
        cultures = sorted({param(e.find('m_Fields/m_Values'), 'Tag_Culture').find('m_ElementName').get('text')
                           for e in targets[name]["entries"]})
        print(f"  {name}: {', '.join(cultures)}")


if __name__ == "__main__":
    main()
