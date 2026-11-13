extends Control
## 表示・入力専用。物語の条件はFlowから受け取った応答だけを使う。

const FONT = preload("res://assets/fonts/NotoSansJP.ttf")
const FlowScript = preload("res://scripts/game_flow.gd")
@export_file("*.tscn") var media_scene_path: String = "res://scenes/media_layer.tscn"
const INK := Color("e8eadc")
const MUTED := Color("a6b7a5")
const ACCENT := Color("d1dca2")

var flow: ExpeditionFlow
var title_view: VBoxContainer
var game_view: VBoxContainer
var options: VBoxContainer
var option_scroll: ScrollContainer
var transcript: RichTextLabel
var status: Label
var chapter: Label
var notice: Label
var continue_button: Button
var title_note: Label
var return_button: Button
var media_layer: Node

func _ready() -> void:
	_build_theme()
	_build_ui()
	flow = FlowScript.new()
	flow.name = "GameFlow"
	add_child(flow)
	flow.line_changed.connect(_on_line)
	flow.event_started.connect(_on_event)
	flow.state_changed.connect(_update_status)
	flow.run_finished.connect(_on_finished)
	flow.problem.connect(func(message: String): notice.text = message)
	_attach_media()
	_show_title()

func _attach_media() -> void:
	if media_scene_path.is_empty() or not ResourceLoader.exists(media_scene_path):
		return
	var scene := load(media_scene_path) as PackedScene
	if scene == null:
		return
	media_layer = scene.instantiate()
	add_child(media_layer)
	move_child(media_layer, 0)
	if media_layer.has_method("bind_flow"):
		media_layer.bind_flow(flow)

func _build_theme() -> void:
	var skin := Theme.new()
	var readable_font := FontVariation.new()
	readable_font.base_font = FONT
	readable_font.variation_opentype = {"weight": 400.0}
	skin.default_font = readable_font
	skin.default_font_size = 22
	skin.set_color("font_color", "Label", INK)
	skin.set_color("default_color", "RichTextLabel", INK)
	skin.set_constant("separation", "VBoxContainer", 12)
	for kind in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color("1c2b24") if kind == "normal" else Color("304736")
		if kind == "disabled":
			box.bg_color = Color("17201c")
		box.border_color = ACCENT if kind == "focus" else Color("53654d")
		box.set_border_width_all(3 if kind == "focus" else 1)
		box.set_corner_radius_all(6)
		box.content_margin_left = 20
		box.content_margin_right = 20
		box.content_margin_top = 10
		box.content_margin_bottom = 10
		skin.set_stylebox(kind, "Button", box)
	skin.set_color("font_color", "Button", INK)
	skin.set_color("font_hover_color", "Button", Color.WHITE)
	skin.set_color("font_focus_color", "Button", Color.WHITE)
	skin.set_color("font_disabled_color", "Button", Color("69766a"))
	theme = skin

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	add_child(margin)
	var shell := VBoxContainer.new()
	margin.add_child(shell)
	var eyebrow := _label("山の小さな捜索記録   /   薬草祭り", 18, MUTED)
	shell.add_child(eyebrow)
	shell.add_child(HSeparator.new())
	title_view = VBoxContainer.new()
	title_view.name = "TitleView"
	title_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	title_view.alignment = BoxContainer.ALIGNMENT_CENTER
	shell.add_child(title_view)
	title_view.add_child(_label("薬草祭りの遭難者", 52, ACCENT))
	title_view.add_child(_label("人を一人。余裕があれば、薬草も。", 26, INK))
	var intro := _label("山で消息を絶った錬金術師レオ。\n何となく依頼を受けた冒険者ムハンマド。\n何を調べ、何を持ち帰るかで、帰還の物語が少し変わる。", 22, MUTED)
	intro.custom_minimum_size.y = 140
	title_view.add_child(intro)
	var start := _button("はじめから", _start_new)
	start.name = "NewGame"
	title_view.add_child(start)
	continue_button = _button("つづきから", _continue_game)
	continue_button.name = "ContinueGame"
	title_view.add_child(continue_button)
	title_note = _label("", 18, MUTED)
	title_view.add_child(title_note)
	title_view.add_child(_label("操作：クリック / ↑↓・Tabで移動 / Enter・Spaceで決定\nシナリオ初稿 · 1周 約5〜10分", 18, MUTED))
	game_view = VBoxContainer.new()
	game_view.name = "GameView"
	game_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.add_child(game_view)
	var heading := HBoxContainer.new()
	game_view.add_child(heading)
	chapter = _label("", 28, ACCENT)
	chapter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(chapter)
	return_button = _button("タイトルへ", _show_title)
	return_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	return_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return_button.custom_minimum_size = Vector2(160, 50)
	return_button.add_theme_font_size_override("font_size", 18)
	heading.add_child(return_button)
	status = _label("", 18, MUTED)
	game_view.add_child(status)
	transcript = RichTextLabel.new()
	transcript.name = "Transcript"
	transcript.bbcode_enabled = false
	transcript.selection_enabled = true
	transcript.scroll_following = true
	transcript.size_flags_vertical = Control.SIZE_EXPAND_FILL
	transcript.custom_minimum_size.y = 160
	transcript.add_theme_font_size_override("normal_font_size", 24)
	transcript.add_theme_constant_override("line_separation", 10)
	game_view.add_child(transcript)
	game_view.add_child(HSeparator.new())
	option_scroll = ScrollContainer.new()
	option_scroll.name = "ChoiceScroll"
	option_scroll.custom_minimum_size.y = 230
	option_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	option_scroll.follow_focus = true
	game_view.add_child(option_scroll)
	options = VBoxContainer.new()
	options.name = "Choices"
	options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option_scroll.add_child(options)
	notice = _label("", 16, MUTED)
	shell.add_child(notice)

func _label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _button(value: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = value
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size.y = 50
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(action)
	return button

func _show_title() -> void:
	if flow.busy:
		return
	if is_instance_valid(media_layer) and media_layer.has_method("show_title"):
		media_layer.show_title()
	title_view.show()
	game_view.hide()
	notice.text = ""
	continue_button.disabled = not flow.can_continue()
	title_note.text = "イベント開始時に自動保存。新しい周回を始めると、前のセーブを上書きします。"
	if FileAccess.file_exists(flow.save_path) and continue_button.disabled:
		title_note.text += "\n保存データを読み込めません。「はじめから」で開始できます。"
	var focus_target: Control = continue_button if not continue_button.disabled else title_view.get_node("NewGame")
	_focus.call_deferred(focus_target)

func _prepare_game() -> void:
	title_view.hide()
	game_view.show()
	transcript.text = ""
	notice.text = "イベント開始時に自動保存 / 本文・選択肢はスクロールできます"

func _start_new() -> void:
	if flow.busy:
		return
	_prepare_game()
	await flow.start_new()

func _continue_game() -> void:
	if flow.busy:
		return
	_prepare_game()
	if not await flow.load_game():
		_show_title()

func _on_event(event_id: String) -> void:
	chapter.text = ExpeditionFlow.EVENT_NAMES.get(event_id, event_id)
	transcript.text = ""

func _update_status() -> void:
	var state := flow.state
	status.text = "薬草 %d束   /   品質 %d   /   調査 %dか所   /   %s" % [state.herbs, state.quality, state.visited.size(), "レオと帰還中" if state.rescued else "レオを捜索中"]

func _clear_options() -> void:
	for child in options.get_children():
		options.remove_child(child)
		child.queue_free()

func _on_line(line: DialogueLine) -> void:
	var paragraph := "" if transcript.text.is_empty() else "\n\n"
	if not line.character.is_empty() and line.character != "語り":
		paragraph += line.character + "\n"
	transcript.text += paragraph + line.text
	_clear_options()
	var responses := flow.allowed_responses()
	if responses.is_empty():
		options.add_child(_button("次へ  →", _choose.bind(-1)))
	else:
		for index in responses.size():
			options.add_child(_button(responses[index].text, _choose.bind(index)))
	option_scroll.scroll_vertical = 0
	_focus.call_deferred(options.get_child(0))

func _choose(index: int) -> void:
	if flow.busy or flow.finished:
		return
	# await中の連打による二重適用を防ぐ。
	for child in options.get_children():
		child.disabled = true
	return_button.disabled = true
	await flow.choose(index)
	return_button.disabled = false

func _on_finished() -> void:
	_clear_options()
	options.add_child(_button("タイトルへ戻る", _show_title))
	_focus.call_deferred(options.get_child(0))
	notice.text = "最後までプレイしていただき、ありがとうございました。別の選択でもう一度遊べます。"

func _focus(control: Control) -> void:
	if is_instance_valid(control) and control.is_inside_tree() and control.is_visible_in_tree():
		control.grab_focus()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down"):
		var list: Array[Control] = []
		var container: VBoxContainer = title_view if title_view.visible else options
		for child in container.get_children():
			if child is Button and not child.disabled:
				list.append(child)
		if list.is_empty():
			return
		var current := list.find(get_viewport().gui_get_focus_owner())
		var step := -1 if event.is_action_pressed("ui_up") else 1
		list[posmod(current + step, list.size())].grab_focus()
		get_viewport().set_input_as_handled()
