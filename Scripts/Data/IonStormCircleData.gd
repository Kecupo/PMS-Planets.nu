class_name IonStormCircleData
extends RefCounted

var storm_id: int = -1
var parent_id: int = 0
var x: float = 0.0
var y: float = 0.0
var radius: float = 0.0
var heading: float = 0.0
var warp: float = 0.0
var voltage: float = 0.0
var is_growing: bool = false

func apply_dict(d: Dictionary) -> void:
	storm_id = int(float(d.get("id", storm_id)))
	parent_id = int(float(d.get("parentid", parent_id)))
	x = float(d.get("x", x))
	y = float(d.get("y", y))
	radius = float(d.get("radius", radius))
	heading = float(d.get("heading", heading))
	warp = float(d.get("warp", warp))
	voltage = float(d.get("voltage", voltage))
	is_growing = bool(d.get("isgrowing", is_growing))
