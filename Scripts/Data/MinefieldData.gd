class_name MinefieldData
extends RefCounted

var minefield_id: int = -1
var ownerid: int = -1
var x: float = 0.0
var y: float = 0.0
var radius: float = 0.0
var units: float = 0.0
var infoturn: int = 0
var ishidden: bool = false
var isweb: bool = false
var friendlycode: String = "???"

func apply_dict(d: Dictionary) -> void:
	minefield_id = int(float(d.get("id", minefield_id)))
	ownerid = int(float(d.get("ownerid", ownerid)))
	x = float(d.get("x", x))
	y = float(d.get("y", y))
	radius = float(d.get("radius", radius))
	units = float(d.get("units", units))
	infoturn = int(float(d.get("infoturn", infoturn)))
	ishidden = bool(d.get("ishidden", ishidden))
	isweb = bool(d.get("isweb", isweb))
	friendlycode = String(d.get("friendlycode", friendlycode))
