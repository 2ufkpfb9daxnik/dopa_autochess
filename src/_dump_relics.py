import os
import re
import sys

start = int(sys.argv[1])
end = int(sys.argv[2])
root = r"D:\dopa_autochess\src\data\relics"
for i in range(start, end + 1):
    path = os.path.join(root, "%03d.md" % i)
    text = open(path, encoding="utf-8").read()
    name = re.search(r"- 名前: (.+)", text).group(1)
    equip = re.search(r"- 装備可能: (.+)", text).group(1)
    detail = text.split("## 詳細な説明文")[1].split("##")[0].strip().replace("\n", " ")
    rows = []
    if "## 効果値" in text:
        effects = text.split("## 効果値")[1]
        for line in effects.splitlines():
            if line.startswith("|") and "---" not in line and "効果値" not in line:
                cells = [c.strip() for c in line.strip("|").split("|")]
                if len(cells) >= 2 and cells[0] and cells[1] and cells[0] != "効果値":
                    rows.append("%s=%s" % (cells[0], cells[1]))
    print("=== %03d %s equip=%s | %s" % (i, name, equip, ", ".join(rows)))
    print(detail)
    print()
