extends SceneTree
## 命令・標準ノード・交換・未接続・セーブ復元を検証。音を聴いた試験ではない。

const Flow = preload("res://scripts/game_flow.gd")
const Adapter = preload("res://scripts/media_adapter.gd")
const Layer = preload("res://scenes/media_layer.tscn")
const UI = preload("res://scenes/main.tscn")
var checks := 0
var failures := 0
var completed_modes := 0
var restored_events := 0
var reference_state: Dictionary = {}

class RecordedAudio extends Node:
	var commands: Array = []
	func request_bgm(asset_id: String, path: String) -> void:
		commands.append([asset_id, path])

class RecordedVisual extends Node:
	var commands: Array = []
	func show_background(asset_id: String, path: String) -> void:
		commands.append([asset_id, path])

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", description)

func _run() -> void:
	_test_players()
	_test_catalog_errors()
	await _test_resume()
	for mode in ["none", "missing_scene", "both", "audio_only", "visual_only", "no_players", "recorders", "invalid_assets"]:
		await _play_ui(mode)
	var default_ui = UI.instantiate()
	root.add_child(default_ui)
	check(default_ui.media_layer != null, "通常のUIが任意シーンを接続")
	check(default_ui.media_layer.get_node("Background").current_asset_id == "background.town", "タイトル背景")
	check(not default_ui.media_layer.get_node("Audio").playing, "タイトルは明示的な無音")
	default_ui.queue_free()
	await process_frame
	check(Flow.SAVE_VERSION == 1, "既存セーブ形式番号を維持")
	print("MEDIA RESULT checks=%d failures=%d completed_ui_modes=%d restored_events=%d" % [checks, failures, completed_modes, restored_events])
	quit(0 if failures == 0 else 1)

func _test_players() -> void:
	var layer := Layer.instantiate()
	root.add_child(layer)
	var adapter = layer.get_node("MediaAdapter")
	var audio = layer.get_node("Audio")
	var visual = layer.get_node("Background")
	var starts: Array = []
	var issues: Array = []
	audio.playback_started.connect(func(id: String): starts.append(id))
	for component in [adapter, audio, visual]:
		component.issue_reported.connect(func(message: String): issues.append(message))
	for event_id in Flow.EVENTS:
		check(adapter.catalog.events.has(event_id), "対応表に既存イベント: " + event_id)
	adapter.on_event_started("approach")
	check(audio.playing and audio.current_asset_id == "bgm.mountain", "標準AudioStreamPlayerで開始")
	check(audio.stream is AudioStreamWAV and audio.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "WAVをループ設定")
	check(visual.texture is Texture2D and visual.current_asset_id == "background.mountain", "標準TextureRectに背景")
	var same_stream: AudioStream = audio.stream
	adapter.on_event_started("stream")
	check(starts.size() == 1 and audio.stream == same_stream, "同じ山BGMを再ロード・再始動しない")
	check(visual.current_asset_id == "background.stream", "BGMを継続したまま背景だけ変更")
	adapter.on_event_started("discovery")
	check(starts == ["bgm.mountain", "bgm.discovery"], "発見時に曲を切替")
	adapter.on_event_started("aid")
	check(starts.size() == 2, "救助イベントで同一曲継続")
	adapter.on_event_started("ending")
	check(not audio.playing and audio.stream == null and audio.current_asset_id.is_empty(), "空IDは明示的に停止・解放")
	adapter.on_event_started("approach")
	check(starts.size() == 3 and audio.playing, "停止後は同じ曲でも再開")
	audio.request_bgm("bgm.mountain", adapter.catalog.assets["bgm.discovery"])
	check(starts.size() == 4, "同じIDでもファイル差し替え時は切替")
	adapter.catalog.events.explore.bgm = "bgm.unknown"
	adapter.on_event_started("explore")
	check(not audio.playing and visual.current_asset_id == "background.mountain", "未知の音源IDは音だけ停止")
	adapter.catalog.events.explore.background = "background.missing"
	adapter.catalog.assets["background.missing"] = "res://assets/media/not_found.svg"
	adapter.on_event_started("explore")
	check(visual.texture == null and not visual.visible, "背景ファイル欠落はクリア")
	audio.request_bgm("bgm.missing", "res://assets/media/not_found.wav")
	check(not audio.playing, "音源ファイル欠落も安全に停止")
	audio.request_bgm("bgm.wrong_type", "res://assets/media/town.svg")
	visual.show_background("background.wrong_type", "res://assets/media/mountain.wav")
	check(audio.stream == null and visual.texture == null, "アセットのリソース型違いを拒否")
	adapter.on_event_started("discovery")
	adapter.on_event_started("unknown_event")
	check(not audio.playing and visual.texture == null, "未知イベントは両方クリア")
	check(issues.size() >= 7, "欠落・未知IDを診断signalで通知")
	layer.free()

func _test_catalog_errors() -> void:
	for content in ["{broken", "[]", "{}", '{"assets":[],"events":{}}']:
		var path := "user://media_test_catalog.json"
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(content)
		file.close()
		var adapter := Adapter.new()
		adapter.catalog_path = path
		var requests: Array = []
		var diagnostics: Array = []
		adapter.issue_reported.connect(func(message: String): diagnostics.append(message))
		adapter.bgm_requested.connect(func(id: String, resource: String): requests.append([id, resource]))
		root.add_child(adapter)
		adapter.on_event_started("prologue")
		check(requests == [["", ""]] and not diagnostics.is_empty(), "壊れた対応表でも停止命令を通知")
		adapter.free()
		DirAccess.remove_absolute(path)
	var missing := Adapter.new()
	missing.catalog_path = "user://no_such_media_catalog.json"
	root.add_child(missing)
	check(missing.catalog.is_empty(), "対応表ファイルがなくても起動")
	missing.free()
	var adapter := Adapter.new()
	root.add_child(adapter)
	var commands: Array = []
	adapter.background_requested.connect(func(id: String, path: String): commands.append([id, path]))
	for invalid in [123, "bgm.mountain", "background.unknown"]:
		adapter.catalog.events.title.background = invalid
		adapter.on_event_started("title")
		check(commands.back() == ["", ""], "不正・別カテゴリ・未知のIDはクリア")
	adapter.catalog.assets["background.unsafe"] = "file:///tmp/not_a_game_asset.svg"
	adapter.catalog.events.title.background = "background.unsafe"
	adapter.on_event_started("title")
	check(commands.back() == ["", ""], "res以外の不正パスを拒否")
	adapter.free()

func _test_resume() -> void:
	var flow := Flow.new()
	flow.save_path = "user://media_resume_test.json"
	root.add_child(flow)
	await flow.start_new()
	var visited: Dictionary = {}
	var guard := 0
	while not flow.finished and guard < 100:
		guard += 1
		var event_id := flow.current_event
		if not visited.has(event_id):
			visited[event_id] = true
			var restored := Flow.new()
			restored.save_path = flow.save_path
			root.add_child(restored)
			var layer := Layer.instantiate()
			root.add_child(layer)
			layer.bind_flow(restored)
			check(await restored.load_game(), "既存形式の実ファイルから再開: " + event_id)
			var cue: Dictionary = layer.get_node("MediaAdapter").catalog.events[event_id]
			check(layer.get_node("Audio").current_asset_id == cue.bgm, "再通知だけでBGM復元: " + event_id)
			check(layer.get_node("Background").current_asset_id == cue.background, "再通知だけで背景復元: " + event_id)
			check(restored.state.to_dict() == flow.state.to_dict(), "メディアの復元で状態を変えない")
			restored_events += 1
			layer.free()
			restored.free()
		await flow.choose(-1 if flow.allowed_responses().is_empty() else 0)
	check(restored_events == 11, "全11イベントの復元")
	reference_state = flow.state.to_dict()
	DirAccess.remove_absolute(flow.save_path)
	flow.free()

func _play_ui(mode: String) -> void:
	var ui = UI.instantiate()
	ui.media_scene_path = "res://scenes/not_present.tscn" if mode == "missing_scene" else ""
	root.add_child(ui)
	ui.flow.save_path = "user://media_ui_test.json"
	var layer: Node
	if mode not in ["none", "missing_scene"]:
		layer = Layer.instantiate()
		if mode in ["visual_only", "no_players", "recorders"]:
			layer.get_node("Audio").free()
		if mode in ["audio_only", "no_players", "recorders"]:
			layer.get_node("Background").free()
		if mode == "recorders":
			var audio := RecordedAudio.new()
			audio.name = "Audio"
			layer.add_child(audio)
			var visual := RecordedVisual.new()
			visual.name = "Background"
			layer.add_child(visual)
		ui.add_child(layer)
		ui.move_child(layer, 0)
		layer.bind_flow(ui.flow)
		ui.media_layer = layer
		if mode == "invalid_assets":
			layer.get_node("MediaAdapter").catalog.events.explore.bgm = "bgm.not_registered"
			layer.get_node("MediaAdapter").catalog.assets["background.mountain"] = "res://assets/media/missing.svg"
		ui._show_title()
	await ui._start_new()
	var guard := 0
	while not ui.flow.finished and guard < 100:
		guard += 1
		await ui._choose(-1 if ui.flow.allowed_responses().is_empty() else 0)
	check(ui.flow.finished and ui.flow.state.rescued, "UIで完走: " + mode)
	check(ui.flow.state.to_dict() == reference_state, "同一履歴なら同一結末状態: " + mode)
	if mode == "recorders":
		var commands: Array = layer.get_node("Audio").commands
		check(commands.any(func(command: Array): return command[0] == "bgm.mountain"), "別実装が音楽命令を受信")
		check(commands.any(func(command: Array): return command[0] == "bgm.discovery"), "別実装が切替命令を受信")
		check(commands.back() == ["", ""], "別実装が停止命令を受信")
		check(layer.get_node("Background").commands.back()[0] == "background.town", "別実装が背景命令を受信")
	ui._show_title()
	if mode in ["both", "audio_only"]:
		check(not layer.get_node("Audio").playing, "タイトルへ戻ると停止")
	if mode in ["none", "missing_scene"]:
		check(ui.media_layer == null, "メディアシーン未接続のまま進行")
	completed_modes += 1
	ui.queue_free()
	await process_frame
	DirAccess.remove_absolute("user://media_ui_test.json")
