extends RefCounted
## 編集比較用の固定プレイ履歴。製品のシナリオ・進行には組み込まない。

const CASES := [
	{"id": "fast_search", "priority": "search", "visits": [], "aid": "support", "sort": false, "herbs": 0, "quality": 0, "delay": 0, "grade": "empty"},
	{"id": "late_herbs", "priority": "herbs", "visits": [["meadow", 0], ["stream", 1], ["ridge", 1]], "aid": "support", "sort": false, "herbs": 7, "quality": 3, "delay": 5, "grade": "excellent"},
	{"id": "rope_rescue", "priority": "search", "visits": [["meadow", 1], ["stream", 0], ["ridge", 0]], "aid": "rope", "sort": false, "herbs": 0, "quality": 0, "delay": 0, "grade": "empty"},
	{"id": "alchemy_rescue", "priority": "search", "visits": [], "aid": "alchemy", "sort": false, "herbs": 0, "quality": 0, "delay": 0, "grade": "empty"},
	{"id": "herb_priority_empty", "priority": "herbs", "visits": [], "aid": "support", "sort": false, "herbs": 0, "quality": 0, "delay": 1, "grade": "empty"},
	{"id": "quality_harvest", "priority": "search", "visits": [["stream", 1], ["ridge", 1]], "aid": "alchemy", "sort": true, "herbs": 4, "quality": 3, "delay": 2, "grade": "excellent"},
	{"id": "quantity_low_quality", "priority": "search", "visits": [["meadow", 0], ["stream", 1]], "aid": "support", "sort": false, "herbs": 5, "quality": 1, "delay": 3, "grade": "modest"},
	{"id": "footprints_only", "priority": "search", "visits": [["meadow", 1]], "aid": "support", "sort": false, "herbs": 0, "quality": 0, "delay": 0, "grade": "empty"},
]

static func choose(flow: ExpeditionFlow, route: Dictionary) -> int:
	var responses := flow.allowed_responses()
	if responses.is_empty():
		return -1
	var target: String = ""
	match flow.current_event:
		"approach":
			return 0 if route.priority == "search" else 1
		"explore":
			for visit in route.visits:
				if not flow.state.has_visited(visit[0]):
					target = {"meadow": "薬草の草地", "stream": "沢の周囲", "ridge": "岩場の落とし物"}[visit[0]]
					break
			if target.is_empty():
				target = "捜索を進める"
		"meadow", "stream", "ridge":
			for visit in route.visits:
				if visit[0] == flow.current_event:
					return visit[1]
		"aid":
			target = {"rope": "拾ったロープ", "alchemy": "レオに応急", "support": "時間をかけ"}[route.aid]
		"descent":
			target = "選別" if route.sort else "そのまま街へ"
	if not target.is_empty():
		for index in responses.size():
			if target in responses[index].text:
				return index
	return -99
