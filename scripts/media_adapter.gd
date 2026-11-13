class_name ExpeditionMediaAdapter
extends Node
## 任意の音声・画像モジュールが購読する窓口。接続なしでも進行する。

signal cue_requested(event_id: String)

func on_event_started(event_id: String) -> void:
	cue_requested.emit(event_id)
