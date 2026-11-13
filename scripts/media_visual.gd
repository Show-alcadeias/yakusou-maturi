extends TextureRect
## AudioやGameFlowを知らない背景表示。

signal issue_reported(message: String)
var current_asset_id: String = ""
var current_path: String = ""

func show_background(asset_id: String, resource_path: String) -> void:
	if asset_id.is_empty():
		_clear()
		return
	if asset_id == current_asset_id and resource_path == current_path and texture != null:
		return
	if not ResourceLoader.exists(resource_path):
		issue_reported.emit("背景がありません: " + resource_path)
		_clear()
		return
	var image := ResourceLoader.load(resource_path) as Texture2D
	if image == null:
		issue_reported.emit("背景の型が不正です: " + resource_path)
		_clear()
		return
	texture = image
	current_asset_id = asset_id
	current_path = resource_path
	show()

func _clear() -> void:
	texture = null
	current_asset_id = ""
	current_path = ""
	hide()
