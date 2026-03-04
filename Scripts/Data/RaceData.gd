class_name RaceData
extends RefCounted

var id: int = -1
var name: String = ""
var shortname: String = ""     # "The Feds"
var adjective: String = ""     # "Fed" (sehr gut als Owner-Kürzel geeignet)

var advantages: Array[int] = []
var baseadvantages: Array[int] = []
var hulls: Array[int] = []
var basehulls: Array[int] = []

var raw: Dictionary = {}

func _init(d: Dictionary = {}) -> void:
	raw = d
	id = int(d.get("id", -1))
	name = str(d.get("name", ""))
	shortname = str(d.get("shortname", ""))
	adjective = str(d.get("adjective", ""))

	advantages = _parse_csv_ints(str(d.get("advantages", "")))
	baseadvantages = _parse_csv_ints(str(d.get("baseadvantages", "")))
	hulls = _parse_csv_ints(str(d.get("hulls", "")))
	basehulls = _parse_csv_ints(str(d.get("basehulls", "")))

func owner_abbrev() -> String:
	# Für die Anzeige (Owner im Overlay) ist "adjective" meist ideal:
	# "Fed", "Lizard", "Privateer" usw.
	if adjective != "" and adjective != "Unknown":
		return adjective
	# Fallbacks
	if shortname != "" and shortname != "Unknown":
		return shortname
	if name != "" and name != "Unknown":
		return name
	return "—"

func has_advantage(adv_id: int) -> bool:
	return advantages.has(adv_id)

static func _parse_csv_ints(csv: String) -> Array[int]:
	var result: Array[int] = []
	var s := csv.strip_edges()
	if s == "":
		return result

	for part in s.split(",", false):
		var t := part.strip_edges()
		if t == "":
			continue
		# defensive: manche Inhalte könnten whitespace enthalten
		if t.is_valid_int():
			result.append(int(t))
		else:
			# wenn doch mal "1.0" kommt
			var f := float(t)
			result.append(int(f))

	return result
