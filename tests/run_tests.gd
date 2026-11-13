extends SceneTree
## 外部フレームワークなし。実際のDMとGameFlowで全応答経路を走査する。

const Flow = preload("res://scripts/game_flow.gd")
var checks := 0
var failures := 0
var endings := 0
var transitions := 0
var grades: Dictionary = {}
var speeds: Dictionary = {}
var methods: Dictionary = {}
var events: Dictionary = {}
var flags := {"shortcut_true": false, "shortcut_false": false, "rope_true": false, "rope_false": false, "sort_true": false, "sort_false": false, "revisit_hidden": false}
var test_flow: ExpeditionFlow

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", description)

func _run() -> void:
	var result := DMCompiler.compile_string(FileAccess.get_file_as_string("res://story/story.dialogue"), "res://story/story.dialogue")
	check(result.errors.is_empty(), "公式DMコンパイラで構文エラーなし")
	check(load(Flow.STORY_PATH).cues.size() == 11, "11個のイベントcue")
	test_flow = Flow.new()
	test_flow.save_path = "user://test_expedition_save.json"
	root.add_child(test_flow)
	test_flow.problem.connect(func(message: String): check(false, message))
	await test_flow.start_new()
	await _walk(0, [])
	check(endings > 100, "複数の探索順序・応答経路を完走")
	check(events.size() == 11, "全11イベント到達")
	check(grades.size() == 3, "薬草評価3種類")
	check(speeds.size() == 2, "救出速度2種類")
	check(methods.size() == 3, "救助手順3種類")
	for key in flags:
		check(flags[key], "条件真偽の実行証拠: " + key)
	await _test_checkpoints()
	await _test_ui()
	print("RESULT checks=%d failures=%d completed_routes=%d transitions=%d events=%d harvest_grades=%d rescue_speeds=%d aid_methods=%d" % [checks, failures, endings, transitions, events.size(), grades.size(), speeds.size(), methods.size()])
	print("CONDITIONS ", JSON.stringify(flags))
	_remove_test_save()
	test_flow.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

func _walk(depth: int, passages: Array) -> void:
	if depth > 130:
		check(false, "進行ループを検出")
		return
	transitions += 1
	var flow := test_flow
	if flow.finished:
		endings += 1
		var state := flow.state
		check(state.rescued, "必ずレオ救出後に結末へ")
		check("sort" in state.history or "return" in state.history, "帰路を経由")
		check(state.herbs >= 0 and state.herbs <= 7 and state.quality <= 4, "採取数・品質の上限")
		check(ExpeditionState.from_dict(state.to_dict()) != null, "状態履歴の整合性")
		grades[state.harvest_grade()] = true
		speeds[state.delay >= 3] = true
		methods[state.aid_method] = true
		var text := "\n".join(passages)
		var expected: String = {"empty": "【手ぶらの救助者】", "modest": "【小さな収穫】", "excellent": "【救助と収穫】"}[state.harvest_grade()]
		check(expected in text, "薬草評価が結末の本文へ反映")
		check(("救出は日暮れ間際" in text) == (state.delay >= 3), "救出経過が結末の本文へ反映")
		check(("袋のふくらみ" in text) == (state.priority == "herbs"), "最初の方針が発見時の会話へ反映")
		check(("目印は、ちゃんと役に立った" in text) == state.shortcut_used, "近道履歴が発見時の本文へ反映")
		check(("岩場で回収したロープが救助を支えた" in text) == (state.aid_method == "rope"), "救助手順が本文へ反映")
		return
	check(flow.current_line != null, "終了以外で表示行が存在")
	if flow.current_line == null:
		return
	events[flow.current_event] = true
	var next_passages := passages.duplicate()
	next_passages.append(flow.current_line.text)
	var responses := flow.allowed_responses()
	if not responses.is_empty():
		_check_responses(flow, responses)
	# 各分岐直前をメモリ内で復元。製品のセーブ形式とは独立した走査用スナップショット。
	var snapshot := flow.state.to_dict()
	var event_id := flow.current_event
	var line := flow.current_line
	var pending := flow.pending_event
	var choices: Array = [-1] if responses.is_empty() else range(responses.size())
	for index in choices:
		flow.state = ExpeditionState.from_dict(snapshot)
		flow.current_event = event_id
		flow.current_line = line
		flow.pending_event = pending
		flow.finished = false
		await flow.choose(index)
		await _walk(depth + 1, next_passages)

func _check_responses(flow: ExpeditionFlow, responses: Array[DialogueResponse]) -> void:
	var text: String = "\n".join(responses.map(func(r: DialogueResponse): return r.text))
	match flow.current_event:
		"explore":
			check(("近道" in text) == flow.state.trail_known, "v4条件付き近道の出現・消失")
			flags["shortcut_true" if flow.state.trail_known else "shortcut_false"] = true
			check(responses.size() == 4 - flow.state.visited.size() + int(flow.state.trail_known), "探索応答数・常時の捜索手段")
			for place in ["meadow", "stream", "ridge"]:
				var label: String = {"meadow": "薬草の草地", "stream": "沢の周囲", "ridge": "岩場の落とし物"}[place]
				check((label in text) == not flow.state.has_visited(place), "探索済みの場所は選べない: " + place)
				if flow.state.has_visited(place):
					flags.revisit_hidden = true
		"aid":
			check(("ロープ" in text) == flow.state.rope_found, "v4条件付きロープ救助の出現・消失")
			check(responses.size() == 2 + int(flow.state.rope_found), "道具がなくても救助手段が残る")
			flags["rope_true" if flow.state.rope_found else "rope_false"] = true
		"descent":
			check(("選別" in text) == (flow.state.herbs > 0), "v4条件付き鑑別の出現・消失")
			flags["sort_true" if flow.state.herbs > 0 else "sort_false"] = true
	for response in responses:
		check("[if" not in response.text, "条件タグを画面へ漏らさない")

func _test_checkpoints() -> void:
	print("CHECKPOINT tests")
	await test_flow.start_new()
	var checked: Dictionary = {}
	var guard := 0
	while not test_flow.finished and guard < 130:
		guard += 1
		var event_id := test_flow.current_event
		if not checked.has(event_id):
			checked[event_id] = true
			var restored := Flow.new()
			restored.save_path = test_flow.save_path
			root.add_child(restored)
			check(restored.can_continue(), "保存済みのイベントを認識: " + event_id)
			check(await restored.load_game(), "実ファイルからロード: " + event_id)
			check(restored.current_event == event_id, "イベント開始地点に再開")
			check(restored.state.to_dict() == test_flow.state.to_dict(), "開始時状態が等しい")
			check(restored.current_line.id == test_flow.current_line.id, "同じ冒頭行から再開")
			restored.queue_free()
		var responses := test_flow.allowed_responses()
		var index := -1 if responses.is_empty() else 0
		# 草地採取→沢調査→岩場調査→ロープ救助→選別。
		if test_flow.current_event == "stream" and not responses.is_empty():
			index = 0
		if test_flow.current_event == "ridge" and not responses.is_empty():
			index = 0
		await test_flow.choose(index)
	check(test_flow.finished, "ロード検証ルートも最後まで進む")
	check(checked.size() == 11, "全イベント境界の保存と再開")
	# 途中の状態変更後もディスクはイベント開始時のまま。
	test_flow.finished = false
	await test_flow.start_new()
	while test_flow.current_event != "approach" or test_flow.allowed_responses().is_empty():
		await test_flow.choose()
	await test_flow.choose(1)
	check(test_flow.state.priority == "herbs", "選択結果を状態に記録")
	var before := test_flow.state.to_dict()
	check(await test_flow.load_game(), "会話途中からイベント開始へ戻れる")
	check(test_flow.state.priority.is_empty(), "未保存の選択を巻き戻し二重適用を防ぐ")
	# 破損、異版、存在しないイベント、改ざん状態、誤った段階を拒否。
	var invalid := ["{broken", "null", "[]", JSON.stringify({"version": 999, "event": "prologue", "state": before}), JSON.stringify({"version": 1, "event": "missing", "state": before}), JSON.stringify({"version": 1, "event": "ending", "state": before})]
	var tampered := before.duplicate(true)
	tampered.herbs = 999
	invalid.append(JSON.stringify({"version": 1, "event": "explore", "state": tampered}))
	for content in invalid:
		var file := FileAccess.open(test_flow.save_path, FileAccess.WRITE)
		file.store_string(content)
		file.close()
		var unchanged := test_flow.state.to_dict()
		check(not test_flow.can_continue(), "不正セーブの拒否")
		check(test_flow.state.to_dict() == unchanged, "読込検証で現在状態を破壊しない")
	var state := ExpeditionState.new()
	check(state.act("priority_search"), "初回行動")
	check(not state.act("priority_search"), "重複行動を拒否")
	check(not state.act("aid_rope"), "未取得ロープの使用を拒否")
	check(not state.act("unknown"), "未知行動を拒否")
	# メディアノードを一切付けずに全経路を完走済み。
	check(test_flow.get_child_count() == 0, "外部メディアなしの進行")

func _test_ui() -> void:
	var ui = load("res://scenes/main.tscn").instantiate()
	root.add_child(ui)
	ui.flow.save_path = "user://test_ui_save.json"
	await process_frame
	check(ui.title_view.visible and not ui.game_view.visible, "タイトル画面で起動")
	await ui._start_new()
	check(ui.game_view.visible and not ui.title_view.visible, "ゲーム画面へ遷移")
	check(not ui.transcript.text.is_empty(), "本文UIにDMの文章を表示")
	check(ui.options.get_child_count() == 1, "次へボタン")
	await ui._choose(-1)
	check(not ui.flow.busy, "UI操作後に入力が復帰")
	while ui.flow.current_event == "prologue":
		await ui._choose(-1)
	check("消息を絶ち" not in ui.transcript.text, "イベント変更時に前イベントの本文を消去")
	ui._show_title()
	check(not ui.continue_button.disabled, "タイトルから再開可能")
	ui.queue_free()
	await process_frame
	DirAccess.remove_absolute("user://test_ui_save.json")

func _remove_test_save() -> void:
	DirAccess.remove_absolute(test_flow.save_path)
	DirAccess.remove_absolute(test_flow.save_path + ".tmp")
