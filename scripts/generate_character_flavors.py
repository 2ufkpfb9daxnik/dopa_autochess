#!/usr/bin/env python3
"""全キャラクターのフレーバーを生成し character.md・characters3.md を更新する。"""

import hashlib
import re
from pathlib import Path

from flavor_pools import build_distinctive_marks

ROOT = Path(__file__).resolve().parent.parent
CHAR_DIR = ROOT / "src" / "characters"
CHARACTERS3 = ROOT / "dump" / "characters3.md"

# シナジー名 → さりげないフレーバー片（字面の意味に縛られない）
SYNERGY_FLAVOR_HINTS: dict[str, str] = {
    "炎": "夏場は妙に元気になる",
    "水": "雨の日は妙に集中できる",
    "雷": "雷鳴の日にひらめきが多い",
    "土": "土いじりや盆栽が趣味",
    "氷": "冷たい飲み物にこだわる",
    "風": "風通しの良い場所を好む",
    "吸収": "人の話をよく聞いて覚える",
    "ナギナタスタイル": "古い武具カタログを読みふける",
    "伊豆は飛鳥": "温泉旅館の雑誌をよく読む",
    "月2-263": "カレンダーに謎の記号を書く癖がある",
    "新しい下駄を履く": "履物の履き替えに妙にこだわる",
    "計算された富士": "遠くの山の写真を集めている",
    "イェットアナザー": "同じ失敗を繰り返すと笑い出す",
    "バナナスライド": "滑り台のある公園を散歩コースにしている",
    "と乗り越える": "壁の落書きを見ると立ち止まる",
    "隠遁ドライブ": "夜道を一人で走るのが好き",
    "睡蓮": "池のある公園でよく昼寝する",
    "フローチャート": "手帳に矢印だらけのメモを書く",
    "に敬意を表して": "古い建物の前で深く礼をする癖",
    "街": "雑踏の中で落ち着く不思議な人",
    "後転する蚤・鯖・烏": "変な動物の映像に惹かれる",
    "三途の川を反復横飛": "川沿いの道を何度も往復する",
    "空耳": "聞き間違いから新しい言葉を生む",
    "新しい血圧": "健康診断の数値に妙に詳しい",
    "アバンタイトル": "映画の予告だけ見て満足するタイプ",
    "懐かしい味": "子どもの頃の食べ物を探し続けている",
    "事後諸葛亮": "後から「やっぱりな」と言う",
    "ネコという名前の犬": "名前と中身がズレたものが好き",
    "エフェクトハンドラ": "小さな仕掛けを仕込むのが趣味",
    "麺棒の作者": "麺類の茹で時間にうるさい",
    "潮風とともに": "海の匂いがすると故郷を思う",
    "無人販売所": "夜の自動販売機で考え事をする",
    "竹拾い食い": "路傍の草の名前を知っている",
    "かげろう": "夕方の光を写真に撮りまくる",
    "音か絵か": "音楽と絵のどちらで覚えたか迷う",
    "赤黒木": "赤と黒の配色に惹かれる",
    "ガラムマサラ": "香辛料の匂いで場所を思い出す",
    "晩から朝まで": "夜型で朝は弱い",
    "ブルー・ノートと調性": "ジャズ喫茶に通っていた時期がある",
    "レトリック感覚": "言葉の響きに敏感",
    "骸骨を構成する": "骨格標本や模型に興味がある",
    "矢印撲滅委員会": "看板の矢印の向きにうるさい",
    "タグが痒い": "分類ラベルを貼りたがる",
    "核心的拙速": "大事なことは急いで片付ける",
    "接着剤と潤滑油": "壊れたものを直すのが得意",
    "最も身近な実験": "台所で小さな実験をよくする",
    "二本道": "行き止まりの道を探す趣味",
    "中華丼の道化師": "中華料理屋の看板が好き",
    "誰かが5を付けた": "点数や評価に妙にこだわる",
    "笠地蔵": "石像や置物をよく撮る",
    "より大きなサムネイル": "小さな写真を拡大して眺める",
    "バグパイプ": "笛のような音が好き",
    "すばる鳴く": "鳥のさえずりで時間を知る",
    "シチリア": "地中海の雑誌を読む",
    "層は誤っていない": "地層や年表の話が好き",
    "視察旅行": "学校の遠足より個人の散策派",
    "寅申線": "方角や方位に敏感",
    "O.S.C.A.": "略語を勝手に作る",
    "アカデミー": "学園ものの映画が好き",
}

GENRES = [
    # ファンタジー（中程度）
    "ファンタジー・旅商の街道",
    "ファンタジー・浮遊する書庫",
    "ファンタジー・古い塔の町",
    "ファンタジー・森の外れの宿",
    "ファンタジー・魔法学院の寮",
    "ファンタジー・妖精の市場",
    "ファンタジー・鍛冶の火炉が絶えない港",
    "ファンタジー・地下迷宮の入口町",
    "ファンタジー・賢者の隠れ里",
    "ファンタジー・雲上の城塞",
    # 現代（増量）
    "現代・地方の高校",
    "現代・大都市の高校",
    "現代・大学の研究室",
    "現代・専門学校",
    "現代・海辺の小さな町",
    "現代・山あいの温泉街",
    "現代・深夜のコンビニ社会",
    "現代・町工場の街",
    "現代・古本屋街",
    "現代・音楽スタジオ街",
    "現代・鉄道模型の商店街",
    "現代・看護実習の病棟",
    "現代・高校の天体観測部",
    "現代・古民家カフェの路地",
    "現代・地方球場のスタンド",
    # SF・近未来
    "近未来・港町",
    "近未来・水上都市",
    "近未来・廃墟と新ビルの混在都市",
    "近未来・学園都市",
    "ソフトSF・コロニー船",
    "ソフトSF・軌道ステーション",
    "ソフトSF・月面基地",
    "ソフトSF・深海都市",
    "ソフトSF・惑星移民船の世代交代期",
    "ネオSF・AIと共存する大都会",
    # レトロ（少数）
    "レトロ・蒸気都市",
    # 郷土・異界・その他
    "郷土・祭りのある村",
    "郷土・漁港の町",
    "郷土・農村の集落",
    "異界・夢と現実の境界",
    "異界・時が止まった酒店",
    "東洋幻想・山上の寺院",
    "北欧風・雪深い峠の旅館",
    "蛮族・草原の遊牧民",
    "海賊・嵐の航路",
    "中世風・修道院の書庫",
    "ノワール・雨の埠頭",
    "怪奇・廃旅館の管理人",
    "ポストアポカ・緑が戻った廃都",
    "トロピカル・珊瑚のリゾート島",
    "西部・砂塵の一本道",
    "スチームパンク・時計塔の工房",
    "現代・消防署の仮眠室",
    "現代・アパレル縫製工房",
    "現代・犬の散歩公園常連",
    "現代・同人イベントの裏側",
    "現代・カフェ巡りの学生",
    "現代・バンド活動の世界",
    "現代・夜の繁華街",
    "現代・地方の図書館",
]

ROLE_LINES: dict[str, list[str]] = {
    "物理攻撃": [
        "体を動かす仕事や部活に縁がある。",
        "力仕事より「間合い」を語るタイプ。",
        "格闘より先に礼儀を学んだ。",
        "背中で語る主義で、口数は少ない。",
    ],
    "防御": [
        "人の前に立つ役回りが多い。",
        "黙って場を守る癖がある。",
        "堅実で、約束を破らない。",
        "盾になることに慣れすぎている。",
    ],
    "回復": [
        "誰かの世話を焼くと落ち着く。",
        "怪我人や病人に自然と寄り添う。",
        "薬や飲み物の知識が雑多に広い。",
        "休ませるより休まされる方が苦手。",
    ],
    "バフ": [
        "場の空気を整えるのが得意。",
        "励ます台詞をストックしている。",
        "まとめ役を断れない性格。",
        "人の良いところを早く見つける。",
    ],
    "デバフ": [
        "皮肉と真相を同時に言う癖がある。",
        "噂と情報の流通を知っている。",
        "相手の弱点を見抜くが、悪意は薄い。",
        "言葉の刃で距離を取るタイプ。",
    ],
    "炎": [
        "情熱はあるが、燃えすぎを戒めている。",
        "熱いもの・赤い色に惹かれる一方、冷静な一面もある。",
        "勢いで突っ走った後に反省する。",
    ],
    "水": [
        "流れに身を任せる方がうまくいく。",
        "水辺で考えを整理する。",
        "潤いのある言葉を選ぶ。",
    ],
    "雷": [
        "直感が鋭く、ひらめきが早い。",
        "静かな場でも頭の中は忙しい。",
        "電気的なテンポで話が進む。",
    ],
    "土": [
        "足元の安定を何より大事にする。",
        "古いものや重いものに愛着がある。",
        "地道な積み重ねを信じている。",
    ],
    "氷": [
        "冷静な評価を下すが、内心は繊細。",
        "冷たく見えるが、距離が近い人には優しい。",
        "冬の空気のような静けさを好む。",
    ],
    "風": [
        "束縛が苦手で、風の通る場所を選ぶ。",
        "軽やかな足取りと軽い冗談が取り柄。",
        "どこか遠くを見ている顔をする。",
    ],
    "吸収": [
        "人の話や技を吸収して自分のものにする。",
        "観察眼が鋭く、真似が早い。",
        "空気を読んで立ち位置を変える。",
    ],
}

ELEMENT_ACCENTS: dict[str, list[str]] = {
    "炎": ["赤いストラップやマフラーがトレードマーク。", "夏のイベントには妙に張り切る。"],
    "水": ["青い小物を身につけている。", "泳ぎは得意だが、それをあまり語らない。"],
    "雷": ["稲妻模様の小物をひそかに好む。", "雷雨の日にアイデアが湧く。"],
    "土": ["茶色の革製品を長く使い続ける。", "石や土の感触を信頼する。"],
    "氷": ["透明感のある飾りが好き。", "冷たい飲み物で気分を整える。"],
    "風": ["黄緑の服をよく着る。", "風が強い日は機嫌がいい。"],
    "吸収": ["紫や闇色のアクセントを好む。", "人混みの中で輪に入るのが上手い。"],
    "物理": ["実用的な服装で、飾りは少ない。", "手のひらの硬さが物語っている。"],
    "": ["特に色のこだわりはないが、雰囲気で覚えられる。", "見た目より経歴の方が語られやすい。"],
}

SPECIAL_FLAVORS: dict[str, str] = {
    "nksy": (
        "【現代・高専】劣悪な環境に疲弊した教員気質。"
        "雑務に追われているが、本気で授業をしたいタイプ。"
        "夜の無人販売機で缶コーヒーを買うのが日課で、"
        "評価の数字に妙に敏感。変な映像サイトもよく見ている。"
    ),
}


def stable_index(key: str, n: int) -> int:
    digest = hashlib.sha256(key.encode()).hexdigest()
    return int(digest[:8], 16) % n


def parse_character(sheet: Path) -> dict:
    text = sheet.read_text(encoding="utf-8")
    char_id = sheet.parent.name
    name = ""
    role = ""
    attack = ""
    synergies: list[str] = []

    m_name = re.search(r"^名前:\s*(.+)$", text, re.M)
    m_role = re.search(r"^役割:\s*(.+)$", text, re.M)
    m_attack = re.search(r"^## 攻撃属性\s*\n+([^\n#]+)", text, re.M)
    if m_name:
        name = m_name.group(1).strip()
    if m_role:
        role = m_role.group(1).strip()
    if m_attack:
        attack = m_attack.group(1).strip()

    in_synergy = False
    for line in text.splitlines():
        if line.strip() == "## シナジー":
            in_synergy = True
            continue
        if in_synergy and line.startswith("## "):
            break
        if in_synergy and line.strip().startswith("- "):
            synergies.append(line.strip()[2:].strip())

    if not attack and role:
        m_elem = re.search(r"魔法攻撃\(([^)]+)\)", role)
        if m_elem:
            attack = m_elem.group(1).strip()

    role_key = role
    for elem in ("炎", "水", "雷", "土", "氷", "風", "吸収"):
        if f"魔法攻撃({elem})" in role:
            role_key = elem
            break
    if role == "物理攻撃":
        role_key = "物理攻撃"
    elif role in ("防御", "回復", "バフ", "デバフ"):
        role_key = role

    return {
        "id": char_id,
        "name": name,
        "role": role,
        "role_key": role_key,
        "attack": attack,
        "synergies": synergies,
        "sheet": sheet,
        "text": text,
    }


def build_flavor(meta: dict, distinctive: str) -> str:
    if meta["name"] in SPECIAL_FLAVORS:
        return SPECIAL_FLAVORS[meta["name"]]

    key = f"{meta['id']}:{meta['name']}"
    genre = GENRES[stable_index(key + "g", len(GENRES))]
    role_pool = ROLE_LINES.get(meta["role_key"], ROLE_LINES["バフ"])
    role_line = role_pool[stable_index(key + "r", len(role_pool))]
    accent_pool = ELEMENT_ACCENTS.get(meta["attack"], ELEMENT_ACCENTS[""])
    accent = accent_pool[stable_index(key + "a", len(accent_pool))]

    syn_line = ""
    if meta["synergies"]:
        syn = meta["synergies"][stable_index(key + "s", len(meta["synergies"]))]
        hint = SYNERGY_FLAVOR_HINTS.get(syn, "")
        if hint:
            syn_line = hint

    parts = [f"【{genre}】", distinctive, role_line, accent]
    if syn_line:
        parts.append(syn_line)
    return "".join(parts)


def upsert_flavor_section(text: str, flavor: str) -> str:
    flavor_block = f"## フレーバー\n\n{flavor}\n"
    if re.search(r"^## フレーバー\s*$", text, re.M):
        return re.sub(
            r"^## フレーバー\s*\n.*?(?=^## |\Z)",
            flavor_block + "\n",
            text,
            count=1,
            flags=re.M | re.S,
        )
    # 詳細な説明文の直後に挿入
    if re.search(r"^## 詳細な説明文\s*$", text, re.M):
        return re.sub(
            r"(^## 詳細な説明文\s*\n)",
            r"\1\n" + flavor_block + "\n",
            text,
            count=1,
            flags=re.M,
        )
    return text.rstrip() + "\n\n" + flavor_block


def write_characters3(entries: list[dict]) -> None:
    lines = [
        "# キャラクター フレーバー",
        "",
        "（`scripts/generate_character_flavors.py` で生成）",
        "",
        "| ID | 名前 | フレーバー |",
        "| --- | --- | --- |",
    ]
    for e in sorted(entries, key=lambda x: x["id"]):
        flavor = e["flavor"].replace("|", "\\|")
        lines.append(f"| {e['id']} | {e['name']} | {flavor} |")
    lines.append("")
    CHARACTERS3.write_text("\n".join(lines), encoding="utf-8")


def main() -> None:
    metas: list[dict] = []
    for char_dir in sorted(CHAR_DIR.iterdir()):
        if not char_dir.is_dir() or not re.fullmatch(r"\d{4}", char_dir.name):
            continue
        sheet = char_dir / "character.md"
        if not sheet.is_file():
            continue
        metas.append(parse_character(sheet))

    distinctive_marks = build_distinctive_marks(len(metas))
    entries: list[dict] = []
    for i, meta in enumerate(metas):
        distinctive = distinctive_marks[i]
        flavor = build_flavor(meta, distinctive)
        meta["flavor"] = flavor
        new_text = upsert_flavor_section(meta["text"], flavor)
        meta["sheet"].write_text(new_text, encoding="utf-8")
        entries.append(meta)

    write_characters3(entries)
    print(f"Updated {len(entries)} character sheets")
    print(f"Wrote {CHARACTERS3}")
    print(f"Distinctive marks: {len(set(distinctive_marks))} unique")


if __name__ == "__main__":
    main()
