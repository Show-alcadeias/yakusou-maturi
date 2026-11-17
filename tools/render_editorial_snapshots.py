"""DMの実行記録を作者が読めるMarkdownとdiffへ変換。ゲームの実行には使わない。"""
import difflib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / "tests/fixtures/editorial_v03"
OUTPUT = ROOT / "docs/editorial/v03"
NAMES = {
    "fast_search": "捜索優先・早期発見・薬草なし",
    "late_herbs": "採取優先・遅い発見・7束",
    "rope_rescue": "調査を重ね、ロープで救助",
    "alchemy_rescue": "レオの錬金術で救助",
    "herb_priority_empty": "採取優先を選んだが採取せず帰還",
    "quality_harvest": "良質な4束を選別して帰還",
    "quantity_low_quality": "5束あるが品質不足で控えめな評価",
    "footprints_only": "落とし物未調査・足跡だけで捜索値2",
}


def render(snapshot, phase):
    lines = [f"# Ver.0.3 代表ルートの表示文（{'修正前' if phase == 'before' else '修正後'}）", "",
             "公式Dialogue Managerを通した実行記録。基準mainは `0ce5f61`。", "",
             "共通段落も省略せず掲載する。各選択時に表示された応答と、選んだ応答を記録。面白さの自動採点ではない。", "",
             f"元本文SHA256：`{snapshot['source_sha256']}`", ""]
    for route in snapshot["routes"]:
        state = route["state"]
        lines += [f"## {route['id']} — {NAMES[route['id']]}", "",
                  f"最終状態：薬草{state['herbs']}束／品質{state['quality']}／遅れ{state['delay']}／評価`{route['grade']}`／救助`{state['aid_method']}`。", "",
                  "行動履歴：" + " → ".join(f"`{action}`" for action in state["history"]) + "。", ""]
        previous = None
        for step in route["steps"]:
            if step["event"] != previous:
                lines += ["### " + step["event"], ""]
                previous = step["event"]
            lines += [f"**{step['speaker'] or '地の文'}**：{step['text']}", ""]
            if step["responses"]:
                lines += ["表示された選択肢：", ""]
                for index, response in enumerate(step["responses"]):
                    lines += [f"- {'**選択** ' if index == step['choice'] else ''}{response}"]
                lines += [""]
        lines += ["---", ""]
    return "\n".join(lines)


if __name__ == "__main__":
    OUTPUT.mkdir(parents=True, exist_ok=True)
    results = {}
    for phase in ["before", "after"]:
        source = FIXTURES / (phase + ".json")
        if source.exists():
            results[phase] = render(json.loads(source.read_text()), phase)
            (OUTPUT / (phase + ".md")).write_text(results[phase])
    if len(results) == 2:
        diff = "".join(difflib.unified_diff(results["before"].splitlines(True), results["after"].splitlines(True), fromfile="before.md", tofile="after.md"))
        (OUTPUT / "changes.diff").write_text(diff)
