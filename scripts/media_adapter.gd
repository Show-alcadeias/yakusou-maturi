class_name ExpeditionMediaAdapter
extends Node
## イベントとアセットIDの対応だけを扱う。再生・表示・ゲーム状態は所有しない。

signal cue_requested(event_id: String)
signal bgm_requested(asset_id: String, resource_path: String)
signal background_requested(asset_id: String, resource_path: String)
signal issue_reported(message: String)

@export_file("*.json") var catalog_path: String = "res://media/catalog.json"
var catalog: Dictionary = {}

func _ready() -> void:
	cue_requested.connect(_apply_event)
	_load_catalog()

func _load_catalog() -> void:
	if not FileAccess.file_exists(catalog_path):
		issue_reported.emit("対応表がありません: " + catalog_path)
		return
	var file := FileAccess.open(catalog_path, FileAccess.READ)
	if file == null or file.get_length() > 65536:
		issue_reported.emit("対応表を読み込めません: " + catalog_path)
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or not json.data is Dictionary:
		issue_reported.emit("対応表のJSONが不正です: " + catalog_path)
		return
	if not json.data.get("assets") is Dictionary or not json.data.get("events") is Dictionary:
		issue_reported.emit("対応表にはassetsとeventsが必要です")
		return
	catalog = json.data

func on_event_started(event_id: String) -> void:
	cue_requested.emit(event_id)

func _apply_event(event_id: String) -> void:
	var cue = catalog.get("events", {}).get(event_id)
	if not cue is Dictionary:
		issue_reported.emit("メディア未定義のイベント: " + event_id)
		cue = {}
	var bgm_id = cue.get("bgm", "")
	var background_id = cue.get("background", "")
	var bgm_path := _resolve("bgm", bgm_id)
	var background_path := _resolve("background", background_id)
	bgm_requested.emit(bgm_id if not bgm_path.is_empty() else "", bgm_path)
	background_requested.emit(background_id if not background_path.is_empty() else "", background_path)

func _resolve(category: String, asset_id: Variant) -> String:
	if asset_id is String and asset_id.is_empty():
		return ""
	if not asset_id is String or not asset_id.begins_with(category + "."):
		issue_reported.emit("アセットIDの種別が不正です: " + str(asset_id))
		return ""
	var path = catalog.get("assets", {}).get(asset_id)
	if not path is String or not path.begins_with("res://"):
		issue_reported.emit("アセットIDが未定義、またはパスが不正です: " + asset_id)
		return ""
	return path
