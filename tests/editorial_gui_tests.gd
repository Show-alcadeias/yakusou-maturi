extends SceneTree
## 長い発見会話と結末を上端・下端から読むための描画検証。

const Routes = preload("res://tests/editorial_routes.gd")
var checks := 0
var failures := 0
var phase := "after"

func _initialize() -> void:
	if "--before" in OS.get_cmdline_user_args():
		phase = "before"
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

func capture(ui: Control, label: String) -> void:
	var bar: VScrollBar = ui.transcript.get_v_scroll_bar()
	await settle()
	check(bar.value + bar.page >= bar.max_value - 2, "長文の末尾へ追従: " + label)
	root.get_texture().get_image().save_png("res://work/editorial-gui/" + phase + "-" + label + "-bottom.png")
	bar.value = 0
	await settle()
	check(is_zero_approx(bar.value), "スクロールで冒頭を再読可能: " + label)
	root.get_texture().get_image().save_png("res://work/editorial-gui/" + phase + "-" + label + "-top.png")
	bar.value = bar.max_value
	await settle()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Editorial GUI tests need a display")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute("res://work/editorial-gui")
	for route in Routes.CASES:
		if route.id not in ["fast_search", "late_herbs", "quantity_low_quality"]:
			continue
		var ui = load("res://scenes/main.tscn").instantiate()
		root.add_child(ui)
		ui.flow.save_path = "user://editorial_gui_test.json"
		if phase == "before":
			ui.flow.story = root.get_node("DialogueManager").create_resource_from_text(FileAccess.get_file_as_string("res://tests/fixtures/editorial_v03/base_story.txt"))
		await ui._start_new()
		var guard := 0
		while not ui.flow.finished and guard < 100:
			guard += 1
			if "山道が研究室" in ui.flow.current_line.text:
				await capture(ui, route.id + "-discovery")
				check("レオ\n" in ui.transcript.text and "\n\n" in ui.transcript.text, "話者名と段落を分離")
			var choice := Routes.choose(ui.flow, route)
			check(choice != -99, "代表ルートの応答が存在")
			if choice == -99:
				break
			await ui._choose(choice)
			await process_frame
		check(ui.flow.finished, "GUIでも代表ルートを完走")
		await capture(ui, route.id + "-ending")
		DisplayServer.window_set_size(Vector2i(640, 480))
		await create_timer(0.2).timeout
		await capture(ui, route.id + "-small-ending")
		check(DisplayServer.window_get_size() == Vector2i(640, 480), "小窓の長い結末を検証")
		DisplayServer.window_set_size(Vector2i(1100, 780))
		await create_timer(0.2).timeout
		DirAccess.remove_absolute(ui.flow.save_path)
		ui.queue_free()
		await process_frame
	print("EDITORIAL GUI RESULT checks=%d failures=%d routes=3 phase=%s" % [checks, failures, phase])
	quit(0 if failures == 0 else 1)
