"""
生成 CivConquestMode/ArtDefs/Landmarks.artdef

问题：很多特色改良/区域/建筑的地标模型只登记了原文明的文化标签
（如 LM_PYRAMID 只有 Tag_Culture = Civilization:CIVILIZATION_NUBIA，
工业区里的电子厂只有 Civilization:CIVILIZATION_JAPAN），
其他文明通过征服模式建造时找不到匹配的模型，显示为红色感叹号。

做法：扫描本体与 DLC 的 Landmarks.artdef 中所有根集合（Landmarks、Districts 等）
及其子集合（Eras、BuildingVariants、BaseVariants 等），按“地标 + 子集合 + 主角建筑”分组，
找出所有变体都只针对特定文明的组，为每个变体复制一份 Tag_Culture = Culture:DEFAULT 的版本
（模型完全相同），作为任意文明的兜底。原文明的显示不受影响。

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


def ref_name(values, name):
    v = param(values, name)
    c = v.find("m_ElementName") if v is not None else None
    return c.get("text") if c is not None else ""


def entry_key(values):
    """除 Tag_Culture 外的所有参数，用于去重。"""
    parts = []
    for v in values:
        if v.find("m_ParamName").get("text") == "Tag_Culture":
            continue
        parts.append(ET.tostring(v))
    return tuple(parts)


def main():
    game_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(DEFAULT_GAME_DIR)

    # 根集合名 -> 地标名 -> m_Fields（以本体/最早定义的为准，部分小 DLC 的取值与本体不一致）
    fields = {}
    # (根集合, 地标, 子集合, 主角建筑) -> {"entries": [变体], "generic": bool}
    groups = {}
    for f in find_artdefs(game_dir):
        root = ET.parse(f).getroot()
        for coll in root.find("m_RootCollections"):
            root_name = coll.find("m_CollectionName").get("text")
            for lm in coll.findall("Element"):
                lm_name = lm.find("m_Name").get("text")
                children = lm.find("m_ChildCollections")
                if children is None:
                    continue
                if lm.find("m_Fields") is not None:
                    fields.setdefault(root_name, {}).setdefault(lm_name, lm.find("m_Fields"))
                for child in children:
                    child_name = child.find("m_CollectionName").get("text")
                    for entry in child.findall("Element"):
                        values = entry.find("m_Fields/m_Values")
                        if values is None:
                            continue
                        culture = param(values, "Tag_Culture")
                        if culture is None:
                            continue
                        key = (root_name, lm_name, child_name, ref_name(values, "Tag_HeroBuilding"))
                        g = groups.setdefault(key, {"entries": [], "generic": False})
                        if culture.find("m_RootCollectionName").get("text") == "Civilization":
                            g["entries"].append(entry)
                        else:
                            g["generic"] = True

    targets = {k: v["entries"] for k, v in groups.items() if not v["generic"] and v["entries"]}

    # 根集合 -> 地标 -> 子集合 -> [变体]
    tree = {}
    for (root_name, lm_name, child_name, _), entries in sorted(targets.items()):
        tree.setdefault(root_name, {}).setdefault(lm_name, {}).setdefault(child_name, []).extend(entries)

    out_root = ET.Element("AssetObjects..ArtDefSet")
    ver = ET.SubElement(out_root, "m_Version")
    for tag, val in (("major", "4"), ("minor", "0"), ("build", "291"), ("revision", "558")):
        ET.SubElement(ver, tag).text = val
    ET.SubElement(out_root, "m_TemplateName", text="Landmarks")
    roots = ET.SubElement(out_root, "m_RootCollections")

    for root_name in sorted(tree):
        coll = ET.SubElement(roots, "Element")
        ET.SubElement(coll, "m_CollectionName", text=root_name)
        ET.SubElement(coll, "m_ReplaceMergedCollectionElements").text = "false"
        for lm_name in sorted(tree[root_name]):
            lm = ET.SubElement(coll, "Element")
            lm_fields = fields.get(root_name, {}).get(lm_name)
            lm.append(copy.deepcopy(lm_fields) if lm_fields is not None else ET.Element("m_Fields"))
            children = ET.SubElement(lm, "m_ChildCollections")
            for child_name in sorted(tree[root_name][lm_name]):
                child = ET.SubElement(children, "Element")
                ET.SubElement(child, "m_CollectionName", text=child_name)
                ET.SubElement(child, "m_ReplaceMergedCollectionElements").text = "false"

                seen = set()
                for entry in tree[root_name][lm_name][child_name]:
                    key = entry_key(entry.find("m_Fields/m_Values"))
                    if key in seen:
                        continue
                    seen.add(key)
                    new = copy.deepcopy(entry)
                    culture = param(new.find("m_Fields/m_Values"), "Tag_Culture")
                    culture.find("m_ElementName").set("text", "DEFAULT")
                    culture.find("m_RootCollectionName").set("text", "Culture")
                    culture.find("m_ArtDefPath").set("text", "Cultures.artdef")
                    culture.find("m_TemplateName").set("text", "")
                    new.find("m_Name").set("text", f"CQ_DefaultCulture{len(seen):03d}")
                    child.append(new)

            ET.SubElement(lm, "m_Name", text=lm_name)
            ET.SubElement(lm, "m_AppendMergedParameterCollections").text = "false"

    ET.indent(out_root, space="\t")
    OUT.parent.mkdir(parents=True, exist_ok=True)
    with open(OUT, "wb") as fp:
        fp.write(b'<?xml version="1.0" encoding="UTF-8" ?>\n')
        # 与官方 artdef 格式保持一致（<x/> 而不是 <x />）
        fp.write(ET.tostring(out_root, encoding="utf-8").replace(b" />", b"/>"))
        fp.write(b"\n")

    print(f"{len(targets)} groups -> {OUT}")
    for (root_name, lm_name, child_name, hero), entries in sorted(targets.items()):
        cultures = sorted({param(e.find("m_Fields/m_Values"), "Tag_Culture").find("m_ElementName").get("text")
                           for e in entries})
        label = f"{root_name}/{lm_name}/{child_name}" + (f" [{hero}]" if hero else "")
        print(f"  {label}: {', '.join(cultures)}")


if __name__ == "__main__":
    main()
