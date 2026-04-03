class_name NebulaCircleData
extends RefCounted

var nebula_id: int = -1
var name: String = ""
var x: float = 0.0
var y: float = 0.0
var radius: float = 0.0
var intensity: float = 0.0
var gas: float = 0.0

func apply_dict(d: Dictionary) -> void:
	nebula_id = int(float(d.get("id", nebula_id)))
	name = String(d.get("name", name))
	x = float(d.get("x", x))
	y = float(d.get("y", y))
	radius = float(d.get("radius", radius))
	intensity = float(d.get("intensity", intensity))
	gas = float(d.get("gas", gas))
