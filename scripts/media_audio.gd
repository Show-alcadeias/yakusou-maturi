extends AudioStreamPlayer
## VisualやGameFlowを知らない、1曲だけのループプレイヤー。

signal issue_reported(message: String)
signal playback_started(asset_id: String)
var current_asset_id: String = ""
var current_path: String = ""

func request_bgm(asset_id: String, resource_path: String) -> void:
	if asset_id.is_empty():
		_clear()
		return
	if asset_id == current_asset_id and resource_path == current_path and playing:
		return
	if not ResourceLoader.exists(resource_path):
		issue_reported.emit("音源がありません: " + resource_path)
		_clear()
		return
	var source := ResourceLoader.load(resource_path) as AudioStream
	if source == null:
		issue_reported.emit("音源の型が不正です: " + resource_path)
		_clear()
		return
	_clear()
	stream = source.duplicate()
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
	elif stream is AudioStreamOggVorbis or stream is AudioStreamMP3:
		stream.loop = true
	current_asset_id = asset_id
	current_path = resource_path
	play()
	playback_started.emit(asset_id)

func _clear() -> void:
	stop()
	stream = null
	current_asset_id = ""
	current_path = ""
