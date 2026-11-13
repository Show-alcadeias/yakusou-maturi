class_name ExpeditionFlow
extends Node
## イベント境界とDMの呼び出しだけを管理。本文・条件評価はDMに委譲。

signal line_changed(line: DialogueLine)
signal event_started(event_id: String)
signal state_changed
signal run_finished
signal problem(message: String)

const STORY_PATH := "res://story/story.dialogue"
const SAVE_VERSION := 1
const EVENTS := ["prologue", "approach", "explore", "meadow", "stream", "ridge", "discovery", "aid", "descent", "appraisal", "ending"]
const NEXT := {"prologue": "approach", "approach": "explore", "meadow": "explore", "stream": "explore", "ridge": "explore", "discovery": "aid", "aid": "descent", "descent": "appraisal", "appraisal": "ending"}
const EVENT_NAMES := {"prologue": "依頼書", "approach": "山への道", "explore": "山腹の分かれ道", "meadow": "薬草の草地", "stream": "沢の目印", "ridge": "岩場の落とし物", "discovery": "錬金術師、発見", "aid": "救助の段取り", "descent": "ふたりの帰路", "appraisal": "祭りの受付", "ending": "どうでもいい冒険の結末"}

var state := ExpeditionState.new()
@onready var story: DialogueResource = load(STORY_PATH)
var current_event: String = ""
var current_line: DialogueLine
var pending_event: String = ""
var busy: bool = false
var finished: bool = false
var save_path: String = "user://expedition_save.json"

func start_new() -> void:
	if busy:
		return
	state = ExpeditionState.new()
	finished = false
	await _enter("prologue")

func allowed_responses() -> Array[DialogueResponse]:
	var result: Array[DialogueResponse] = []
	if current_line != null:
		for response in current_line.responses:
			if response.is_allowed:
				result.append(response)
	return result

func choose(index: int = -1) -> void:
	if busy or finished or current_line == null:
		return
	var responses := allowed_responses()
	var next_id := current_line.next_id
	if not responses.is_empty():
		if index < 0 or index >= responses.size():
			return
		next_id = responses[index].next_id
	elif index != -1:
		return
	await _read(next_id)

func go(event_id: String) -> void:
	# DMが指定できる自由遷移は探索拠点からの4種類だけ。
	if current_event != "explore" or event_id not in ["meadow", "stream", "ridge", "discovery"]:
		return
	if event_id != "discovery" and state.has_visited(event_id):
		return
	pending_event = event_id

func _enter(event_id: String) -> void:
	if event_id == "explore" and state.visited.size() >= 3:
		event_id = "discovery"
	current_event = event_id
	pending_event = ""
	current_line = null
	if not save_checkpoint():
		problem.emit("自動保存できませんでした。ゲームは続行できます。")
	event_started.emit(current_event)
	await _read(current_event)

func _read(key: String) -> void:
	busy = true
	current_line = await get_node("/root/DialogueManager").get_next_dialogue_line(story, key, [{"state": state, "flow": self}])
	busy = false
	state_changed.emit()
	if current_line != null:
		line_changed.emit(current_line)
	elif current_event == "ending":
		finished = true
		run_finished.emit()
	else:
		var target: String = pending_event if not pending_event.is_empty() else NEXT.get(current_event, "")
		if target.is_empty():
			problem.emit("進行先が見つかりません。タイトルから再開してください。")
			return
		await _enter(target)

func save_checkpoint() -> bool:
	var temporary := save_path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({"version": SAVE_VERSION, "event": current_event, "state": state.to_dict()}))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		return false
	return DirAccess.rename_absolute(temporary, save_path) == OK

func _read_save() -> Dictionary:
	if not FileAccess.file_exists(save_path):
		return {}
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null or file.get_length() > 16384:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return {}
	var data = json.data
	if not data is Dictionary or data.get("version") != SAVE_VERSION or data.get("event") not in EVENTS or not data.get("state") is Dictionary:
		return {}
	var restored := ExpeditionState.from_dict(data.state)
	if restored == null or not _valid_checkpoint(data.event, restored):
		return {}
	return {"event": data.event, "state": restored}

func _valid_checkpoint(event_id: String, snapshot: ExpeditionState) -> bool:
	match event_id:
		"prologue", "approach":
			return snapshot.history.is_empty()
		"explore", "meadow", "stream", "ridge", "discovery", "aid":
			if snapshot.priority.is_empty() or snapshot.rescued or "sort" in snapshot.history or "return" in snapshot.history:
				return false
			if event_id in ["meadow", "stream", "ridge"]:
				return not snapshot.has_visited(event_id) and snapshot.visited.size() < 3
			return true
		"descent":
			return snapshot.rescued and "sort" not in snapshot.history and "return" not in snapshot.history
		"appraisal", "ending":
			return snapshot.rescued and ("sort" in snapshot.history or "return" in snapshot.history)
	return false

func can_continue() -> bool:
	return not _read_save().is_empty()

func load_game() -> bool:
	if busy:
		return false
	var data := _read_save()
	if data.is_empty():
		problem.emit("有効なセーブがありません。「はじめから」で開始できます。")
		return false
	state = data.state
	finished = false
	await _enter(data.event)
	return true
