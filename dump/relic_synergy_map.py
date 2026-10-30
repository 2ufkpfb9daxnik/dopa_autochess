# -*- coding: utf-8 -*-
import re
from pathlib import Path

for i in range(201, 253):
    p = Path(f"src/data/relics/{i:03d}.md")
    if not p.exists():
        print("missing", i)
        continue
    t = p.read_text(encoding="utf-8")
    syn = re.search(r"- 追加シナジー: (.+)", t)
    eff = re.findall(r"\| ([^|]+) \| ([0-9.]+) \|", t)
    label = syn.group(1).strip() if syn else "?"
    print(f"{i}: {label} | {eff}")
