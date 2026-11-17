extends SceneTree
## 旧稿も公式DMで実行し、本文以外の命令・応答・状態の不変性を比較する。

const Flow = preload("res://scripts/game_flow.gd")
const Routes = preload("res://tests/editorial_routes.gd")
const BASE := "res://tests/fixtures/editorial_v03/base_story.txt"
const SNAPSHOTS := "res://tests/fixtures/editorial_v03/"
var checks := 0
var failures := 0
var capture_only := false

func _initialize() -> void:
	capture_only = "--capture-before" in OS.get_cmdline_user_args()
	_run.call_deferred()

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", description)

func _run() -> void:
	var before_text := FileAccess.get_file_as_string(BASE)
	var after_text := FileAccess.get_file_as_string(Flow.STORY_PATH)
	check(_structure(before_text) == _structure(after_text), "本文以外の条件・選択肢・命令・話者順は完全一致")
	var manager := root.get_node("DialogueManager")
	var before: DialogueResource = manager.create_resource_from_text(before_text)
	check(before != null, "旧稿も公式DMでコンパイル")
	check(_structure(before_text) == _structure(after_text), "本文以外の条件・選択肢・命令・話者順序が不変")
	var baseline: Array = []
	var revised: Array = []
	for route in Routes.CASES:
		var old := await _play(route, before)
		baseline.append(old)
		if capture_only:
			continue
		var current := await _play(route, load(Flow.STORY_PATH))
		revised.append(current)
		check(old.state == current.state, "同一の最終状態: " + route.id)
		check(old.grade == current.grade, "同一の薬草評価: " + route.id)
		check(old.steps.size() == current.steps.size(), "同一の表示段落数: " + route.id)
		for index in mini(old.steps.size(), current.steps.size()):
			check(old.steps[index].event == current.steps[index].event, "同一のイベント順")
			check(old.steps[index].responses == current.steps[index].responses, "同一の表示選択肢")
			check(old.steps[index].choice == current.steps[index].choice, "同一の選択履歴")
		var text: String = "\n".join(current.steps.map(func(step: Dictionary): return step.text))
		check("袋のふくらみ" not in text, "採取優先だけでは所持を断定しない")
		check("薬草には目もくれず" not in text, "捜索優先後の採取を否定しない")
		check("あの紫の葉" not in text, "未提示の植物を指さない")
		check("優勝には届かなくても" not in text, "順位判定を推測しない")
		if route.id == "footprints_only":
			check(current.state.search_effort == 2 and "ridge" not in current.state.visited, "落とし物未調査でも捜索値2")
			check("落とし物の位置" not in text and "調べた跡をたどった先に" in text, "未調査の落とし物を断定しない")
		if route.id == "quantity_low_quality":
			check(current.state.herbs == 5 and current.grade == "modest", "量十分・品質不足の境界例")
			check("袋は軽め" not in text and "祭りの評価は控えめ" in text, "量と評価を混同しない")
		if route.id == "herb_priority_empty":
			check("道の脇にも、いい株があっただろう" in text and current.state.herbs == 0, "0束でも自然な採取方針の会話")
	var before_snapshot := {"source_sha256": before_text.sha256_text(), "routes": baseline}
	if capture_only:
		_write(SNAPSHOTS + "before.json", before_snapshot)
	else:
		# JSON読込時の数値型へ双方をそろえ、入れ子の辞書も比較する。
		check(JSON.parse_string(FileAccess.get_file_as_string(SNAPSHOTS + "before.json")) == JSON.parse_string(JSON.stringify(before_snapshot)), "修正前記録を再現（上書きせず検証）")
		_write("res://work/editorial_after.json", {"source_sha256": after_text.sha256_text(), "routes": revised})
		var recorded := SNAPSHOTS + "after.json"
		if FileAccess.file_exists(recorded):
			check(JSON.parse_string(FileAccess.get_file_as_string(recorded)) == JSON.parse_string(FileAccess.get_file_as_string("res://work/editorial_after.json")), "修正後記録を再現")
	print("EDITORIAL RESULT checks=%d failures=%d routes=%d mode=%s" % [checks, failures, Routes.CASES.size(), "capture-before" if capture_only else "compare"])
	await process_frame
	quit(0 if failures == 0 else 1)

func _play(route: Dictionary, resource: DialogueResource) -> Dictionary:
	var flow := Flow.new()
	flow.save_path = "user://editorial_test_save.json"
	root.add_child(flow)
	flow.story = resource
	await flow.start_new()
	var steps: Array = []
	var guard := 0
	while not flow.finished and guard < 100:
		guard += 1
		var index := Routes.choose(flow, route)
		check(index != -99, "指定した応答が存在: " + route.id)
		if index == -99:
			break
		steps.append({"event": flow.current_event, "speaker": flow.current_line.character, "text": flow.current_line.text, "responses": flow.allowed_responses().map(func(response: DialogueResponse): return response.text), "choice": index})
		await flow.choose(index)
	check(flow.finished and flow.state.rescued, "救出・帰還・終了: " + route.id)
	for key in ["herbs", "quality", "delay"]:
		check(flow.state.get(key) == route[key], "想定状態: " + route.id + "/" + key)
	check(flow.state.priority == route.priority and flow.state.aid_method == route.aid, "方針・救助手順")
	check(flow.state.harvest_grade() == route.grade, "想定した薬草評価")
	var snapshot := {"id": route.id, "state": flow.state.to_dict(), "grade": flow.state.harvest_grade(), "steps": steps}
	DirAccess.remove_absolute(flow.save_path)
	flow.free()
	return snapshot

func _structure(source: String) -> PackedStringArray:
	var regex := RegEx.new()
	regex.compile("^(\\s*)(語り|レオ|ムハンマド): .*$")
	var result := PackedStringArray()
	for line in source.split("\n"):
		result.append(regex.sub(line, "$1$2: <本文>"))
	return result

func _write(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	check(file != null, "記録ファイル作成")
	if file != null:
		file.store_string(JSON.stringify(data, "\t") + "\n")
