extends Control
## このゲームのメディア部品の配線。Audio/Backgroundは各々省略・交換できる。

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var adapter := get_node_or_null("MediaAdapter")
	if adapter == null:
		return
	var audio := get_node_or_null("Audio")
	var visual := get_node_or_null("Background")
	if audio != null and audio.has_method("request_bgm"):
		adapter.bgm_requested.connect(audio.request_bgm)
	if visual != null and visual.has_method("show_background"):
		adapter.background_requested.connect(visual.show_background)
	for component in [adapter, audio, visual]:
		if component != null and component.has_signal("issue_reported"):
			component.issue_reported.connect(_report)

func bind_flow(flow: Node) -> void:
	var adapter := get_node_or_null("MediaAdapter")
	if adapter != null and flow.has_signal("event_started"):
		flow.event_started.connect(adapter.on_event_started)

func show_title() -> void:
	var adapter := get_node_or_null("MediaAdapter")
	if adapter != null:
		adapter.on_event_started("title")

func _report(message: String) -> void:
	push_warning("Media: " + message)
