extends SceneTree
## 実際のウィンドウ・描画・入力を使う。ヘッドレスでの実行は不可。

var ui
var failures := 0
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", description)

func settle() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventKey.new()
	event.keycode = code
	event.pressed = false
	Input.parse_input_event(event)
	await settle()

func click(button: Button) -> void:
	button.grab_focus()
	await settle()
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = button.get_global_rect().get_center()
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = button.get_global_rect().get_center()
	event.pressed = false
	Input.parse_input_event(event)
	await settle()

func capture(filename: String) -> void:
	await settle()
	root.get_texture().get_image().save_png("res://work/gui/" + filename)

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("GUI test requires an actual display server")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute("res://work/gui")
	ui = load("res://scenes/main.tscn").instantiate()
	root.add_child(ui)
	ui.flow.save_path = "user://gui_test_save.json"
	await settle()
	check(ui.title_view.visible, "描画されるタイトル")
	var source := FileAccess.get_file_as_string("res://story/story.dialogue")
	var missing: Dictionary = {}
	for index in source.length():
		var code := source.unicode_at(index)
		if code >= 0x3000 and not ui.FONT.has_char(code):
			missing[code] = true
	check(missing.is_empty(), "シナリオ中の日本語字形を同梱フォントでカバー")
	await capture("title.png")
	ui.title_view.get_node("NewGame").grab_focus()
	await key(KEY_ENTER)
	check(ui.game_view.visible and ui.flow.current_event == "prologue", "Enterで新規開始")
	var previous: String = ui.flow.current_line.id
	await click(ui.options.get_child(0))
	check(ui.flow.current_line.id != previous, "マウスで本文を進める")
	await capture("prologue.png")
	var guard := 0
	var small_captured := false
	while not ui.flow.finished and guard < 130:
		guard += 1
		var responses: Array = ui.flow.allowed_responses()
		if ui.flow.current_event == "explore" and ui.flow.state.trail_known and responses.size() > 1 and not small_captured:
			await capture("exploration.png")
			DisplayServer.window_set_size(Vector2i(640, 480))
			await create_timer(0.2).timeout
			await settle()
			check(DisplayServer.window_get_size() == Vector2i(640, 480), "実際のウィンドウを640×480へ縮小")
			var last: Button = ui.options.get_child(ui.options.get_child_count() - 1)
			last.grab_focus()
			await settle()
			check(ui.option_scroll.get_global_rect().intersects(last.get_global_rect()), "小窓でフォーカス先の選択肢までスクロール")
			await capture("small-window.png")
			DisplayServer.window_set_size(Vector2i(1100, 780))
			await create_timer(0.2).timeout
			await settle()
			small_captured = true
		if responses.size() >= 2:
			ui.options.get_child(0).grab_focus()
			await key(KEY_DOWN)
			check(root.gui_get_focus_owner() == ui.options.get_child(1), "↓で応答移動")
			await key(KEY_UP)
			check(root.gui_get_focus_owner() == ui.options.get_child(0), "↑で応答移動")
		# 初回探索は沢へ。条件付き近道を含む4応答を小窓で確認する。
		var chosen := 1 if ui.flow.current_event == "explore" and ui.flow.state.visited.is_empty() and responses.size() > 1 else 0
		ui.options.get_child(chosen).grab_focus()
		await key(KEY_ENTER)
	check(ui.flow.finished and ui.flow.state.rescued, "GUI操作だけで帰還・結末まで完走")
	check(small_captured, "小窓表示検証に到達")
	await capture("ending.png")
	await click(ui.options.get_child(0))
	check(ui.title_view.visible, "結末からタイトルへ戻れる")
	await click(ui.continue_button)
	check(ui.game_view.visible and ui.flow.current_event == "ending", "マウスで保存した結末を再開")
	print("GUI RESULT checks=%d failures=%d renderer=%s display=%s" % [checks, failures, RenderingServer.get_video_adapter_name(), DisplayServer.get_name()])
	DirAccess.remove_absolute(ui.flow.save_path)
	ui.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
