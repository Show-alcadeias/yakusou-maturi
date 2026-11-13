extends SceneTree
## 実際の画像描画とGodotミキサーのPCM出力を確認。スピーカー聴取とは分ける。

var checks := 0
var failures := 0

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

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("This test needs a display. Use media_tests.gd for headless logic.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute("res://work/media-gui")
	var capture := AudioEffectCapture.new()
	capture.buffer_length = 1.0
	var effect_index := AudioServer.get_bus_effect_count(0)
	AudioServer.add_bus_effect(0, capture)
	var ui = load("res://scenes/main.tscn").instantiate()
	root.add_child(ui)
	ui.flow.save_path = "user://media_gui_test.json"
	await settle()
	root.get_texture().get_image().save_png("res://work/media-gui/title.png")
	check(ui.media_layer.get_node("Background").texture != null, "タイトルに街画像")
	await ui._start_new()
	var guard := 0
	while ui.flow.current_event != "approach" and guard < 20:
		guard += 1
		await ui._choose(-1)
	await create_timer(0.4).timeout
	await settle()
	var audio = ui.media_layer.get_node("Audio")
	var visual = ui.media_layer.get_node("Background")
	check(audio.playing and audio.current_asset_id == "bgm.mountain", "実AudioStreamPlayerが山BGMを再生中")
	var frames := capture.get_frames_available()
	var buffer := capture.get_buffer(frames)
	var energy := 0.0
	var peak := 0.0
	for sample in buffer:
		energy += sample.length_squared() / 2.0
		peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
	var rms := sqrt(energy / maxf(buffer.size(), 1))
	check(frames > 0 and rms > 0.0001, "Godotミキサーから非ゼロのPCMを取得")
	var mountain_image := root.get_texture().get_image()
	mountain_image.save_png("res://work/media-gui/mountain.png")
	var corner := mountain_image.get_pixel(mountain_image.get_width() - 5, mountain_image.get_height() - 5)
	while (ui.flow.current_event != "explore" or ui.flow.allowed_responses().is_empty()) and guard < 40:
		guard += 1
		await ui._choose(-1 if ui.flow.allowed_responses().is_empty() else 0)
	# 探索の2番目は沢。実際の選択から背景を切り替える。
	await ui._choose(1)
	await settle()
	var stream_image := root.get_texture().get_image()
	stream_image.save_png("res://work/media-gui/stream.png")
	check(visual.current_asset_id == "background.stream", "沢の選択で背景変更")
	check(stream_image.get_pixel(stream_image.get_width() - 5, stream_image.get_height() - 5) != corner, "描画ピクセルも背景変更を反映")
	check(ui.transcript.get_theme_color("default_color").get_luminance() > 0.7, "本文の明るい文字色を維持")
	check(ui.media_layer.get_node("Shade").color.a >= 0.8, "背景の前に十分な暗幕")
	check(visual.mouse_filter == Control.MOUSE_FILTER_IGNORE, "背景が入力を遮らない")
	DisplayServer.window_set_size(Vector2i(640, 480))
	await create_timer(0.2).timeout
	await settle()
	root.get_texture().get_image().save_png("res://work/media-gui/small-window.png")
	check(DisplayServer.window_get_size() == Vector2i(640, 480), "小窓で描画")
	ui._show_title()
	check(not audio.playing, "タイトルへ戻ると実プレイヤーも停止")
	print("MEDIA GUI RESULT checks=%d failures=%d captured_frames=%d rms=%.6f peak=%.6f renderer=%s audio_driver=%s" % [checks, failures, frames, rms, peak, RenderingServer.get_video_adapter_name(), AudioServer.get_driver_name()])
	AudioServer.remove_bus_effect(0, effect_index)
	# ミキサースレッドがテスト用エフェクトの参照を解放するのを待つ。
	await create_timer(0.1).timeout
	DirAccess.remove_absolute(ui.flow.save_path)
	ui.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
