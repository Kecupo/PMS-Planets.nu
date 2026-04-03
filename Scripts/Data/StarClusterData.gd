class_name StarClusterData
extends RefCounted

var star_id: int = -1
var name: String = ""
var mass: float = 0.0
var temp: float = 0.0
var radius: float = 0.0
var x: float = 0.0
var y: float = 0.0

func apply_dict(d: Dictionary) -> void:
	star_id = int(float(d.get("id", star_id)))
	name = String(d.get("name", name))
	mass = float(d.get("mass", mass))
	temp = float(d.get("temp", temp))
	radius = float(d.get("radius", radius))
	x = float(d.get("x", x))
	y = float(d.get("y", y))
