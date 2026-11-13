class_name ExpeditionState
extends RefCounted
## 会話向けの状態。保存時も履歴から再構築して整合性を検証する。

var priority: String = ""
var visited: Array[String] = []
var history: Array[String] = []
var herbs: int = 0
var quality: int = 0
var delay: int = 0
var search_effort: int = 0
var trail_known: bool = false
var rope_found: bool = false
var shortcut_used: bool = false
var rescued: bool = false
var aid_method: String = ""

func has_visited(place: String) -> bool:
	return place in visited

func act(action: String) -> bool:
	if action in history:
		return false
	if action.begins_with("priority_"):
		if not priority.is_empty():
			return false
		match action:
			"priority_search":
				priority = "search"
				search_effort += 1
			"priority_herbs":
				priority = "herbs"
				delay += 1
			_:
				return false
	elif action in ["meadow_gather", "meadow_search", "stream_gather", "stream_search", "ridge_gather", "ridge_search"]:
		var place: String = action.get_slice("_", 0)
		if priority.is_empty() or rescued or has_visited(place):
			return false
		visited.append(place)
		match action:
			"meadow_gather":
				herbs += 3
				quality += 1
				delay += 2
			"stream_gather":
				herbs += 2
				delay += 1
			"ridge_gather":
				herbs += 2
				quality += 2
				delay += 1
			"meadow_search":
				search_effort += 1
			"stream_search":
				trail_known = true
				search_effort += 1
			"ridge_search":
				rope_found = true
				search_effort += 1
	elif action == "shortcut":
		if not trail_known or rescued:
			return false
		shortcut_used = true
	elif action in ["aid_rope", "aid_alchemy", "aid_support"]:
		if priority.is_empty() or rescued or (action == "aid_rope" and not rope_found):
			return false
		rescued = true
		aid_method = action.trim_prefix("aid_")
	elif action in ["sort", "return"]:
		if not rescued or "sort" in history or "return" in history or (action == "sort" and herbs == 0):
			return false
		if action == "sort":
			quality += 1
	else:
		return false
	history.append(action)
	return true

func harvest_grade() -> String:
	if herbs == 0:
		return "empty"
	return "excellent" if herbs >= 4 and quality >= 2 else "modest"

func to_dict() -> Dictionary:
	return {
		"priority": priority, "visited": visited.duplicate(), "history": history.duplicate(),
		"herbs": herbs, "quality": quality, "delay": delay, "search_effort": search_effort,
		"trail_known": trail_known, "rope_found": rope_found, "shortcut_used": shortcut_used,
		"rescued": rescued, "aid_method": aid_method,
	}

static func from_dict(data: Dictionary) -> ExpeditionState:
	# 数値型のJSON変換差は == で許容するが、真偽・配列・キーは厳密に検証。
	if not data.get("history") is Array or data.history.size() > 10:
		return null
	var restored := ExpeditionState.new()
	for action in data.history:
		if not action is String or not restored.act(action):
			return null
	var expected := restored.to_dict()
	if data.size() != expected.size():
		return null
	for key in expected:
		if not data.has(key) or data[key] != expected[key]:
			return null
		if expected[key] is bool and not data[key] is bool:
			return null
	return restored
