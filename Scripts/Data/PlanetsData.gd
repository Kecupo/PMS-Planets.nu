class_name PlanetData
extends RefCounted
# Godot 4.5.1
# Data model for a planets.nu "planet" entry from the turn JSON.

# Identity / position
var planet_id: int = -1
var name: String = ""
var x: float = 0.0
var y: float = 0.0

# Ownership / general
var ownerid: int = -1
var friendlycode: String = "???"          # FC (important for UI + later editing)
var temperature: float = 0.0             # "temp"

# Economy / population
var megacredits: float = -1.0
var supplies: float = -1.0
var clans: float = -1.0                  # colonist clans on planet

# Colonists (tax / happiness)
var colonisttaxrate: float = -1.0
var colonisthappypoints: float = -1.0
# If you later want deltas (colhappychange etc.), add them here too.

# Natives
var nativeclans: float = -1.0
var nativeracename: String = "none"
var nativegovernment: float = -1.0
var nativegovernmentname: String = ""
var nativetaxrate: float = -1.0
var nativehappypoints: float = -1.0
var nativetype: float = -1.0
var nativetaxvalue: float = -1.0         # present in your JSON sample

# Industry
var factories: float = -1.0
var mines: float = -1.0
var defense: float = -1.0
var burrowsize: float = -1.0

# Minerals (surface)
var neutronium: float = -1.0
var tritanium: float = -1.0
var duranium: float = -1.0
var molybdenum: float = -1.0

# Minerals (ground)
var groundneutronium: float = -1.0
var groundtritanium: float = -1.0
var groundduranium: float = -1.0
var groundmolybdenum: float = -1.0

# Minerals (density)
var densityneutronium: float = -1.0
var densitytritanium: float = -1.0
var densityduranium: float = -1.0
var densitymolybdenum: float = -1.0

# Optional / useful later
var img: String = ""
var infoturn: float = -1.0
var readystatus: float = -1.0

# Keep original dict (helps debugging / adding more fields later)
var raw: Dictionary = {}

func _init(d: Dictionary = {}) -> void:
	apply_dict(d)

func apply_dict(d: Dictionary) -> void:
	raw = d

	# Identity / position
	planet_id = int(d.get("id", planet_id))
	name = str(d.get("name", name))
	x = float(d.get("x", x))
	y = float(d.get("y", y))

	# Ownership / general
	ownerid = int(d.get("ownerid", ownerid))
	friendlycode = str(d.get("friendlycode", friendlycode))
	temperature = float(d.get("temp", temperature))

	# Economy / population
	megacredits = float(d.get("megacredits", megacredits))
	supplies = float(d.get("supplies", supplies))
	clans = float(d.get("clans", clans))

	# Colonists
	colonisttaxrate = float(d.get("colonisttaxrate", colonisttaxrate))
	colonisthappypoints = float(d.get("colonisthappypoints", colonisthappypoints))

	# Natives
	nativeclans = float(d.get("nativeclans", nativeclans))
	nativeracename = str(d.get("nativeracename", nativeracename))
	nativegovernment = float(d.get("nativegovernment", nativegovernment))
	nativegovernmentname = str(d.get("nativegovernmentname", nativegovernmentname))
	nativetaxrate = float(d.get("nativetaxrate", nativetaxrate))
	nativehappypoints = float(d.get("nativehappypoints", nativehappypoints))
	nativetype = float(d.get("nativetype", nativetype))
	nativetaxvalue = float(d.get("nativetaxvalue", nativetaxvalue))

	# Industry
	factories = float(d.get("factories", factories))
	mines = float(d.get("mines", mines))
	defense = float(d.get("defense", defense))
	burrowsize = float(d.get("burrowsize", burrowsize))

	# Minerals (surface)
	neutronium = float(d.get("neutronium", neutronium))
	tritanium = float(d.get("tritanium", tritanium))
	duranium = float(d.get("duranium", duranium))
	molybdenum = float(d.get("molybdenum", molybdenum))

	# Minerals (ground)
	groundneutronium = float(d.get("groundneutronium", groundneutronium))
	groundtritanium = float(d.get("groundtritanium", groundtritanium))
	groundduranium = float(d.get("groundduranium", groundduranium))
	groundmolybdenum = float(d.get("groundmolybdenum", groundmolybdenum))

	# Minerals (density)
	densityneutronium = float(d.get("densityneutronium", densityneutronium))
	densitytritanium = float(d.get("densitytritanium", densitytritanium))
	densityduranium = float(d.get("densityduranium", densityduranium))
	densitymolybdenum = float(d.get("densitymolybdenum", densitymolybdenum))

	# Optional / useful later
	img = str(d.get("img", img))
	infoturn = float(d.get("infoturn", infoturn))
	readystatus = float(d.get("readystatus", readystatus))

func merge_prefer_known(from_dict: Dictionary) -> void:
	# Merge a second planet dict for the same planet_id, preferring "known" values.
	var tmp := PlanetData.new(from_dict)

	# Do not change planet_id once set
	if name == "" and tmp.name != "":
		name = tmp.name

	if (x == 0.0 and y == 0.0) and not (tmp.x == 0.0 and tmp.y == 0.0):
		x = tmp.x
		y = tmp.y

	# Prefer non-default FC
	if friendlycode == "???" and tmp.friendlycode != "???":
		friendlycode = tmp.friendlycode

	# Owner: prefer non-zero if ours is 0
	if ownerid == 0 and tmp.ownerid != 0:
		ownerid = tmp.ownerid

	# Generic helper: prefer >=0 over -1.0
	if megacredits < 0.0 and tmp.megacredits >= 0.0:
		megacredits = tmp.megacredits
	if supplies < 0.0 and tmp.supplies >= 0.0:
		supplies = tmp.supplies
	if clans < 0.0 and tmp.clans >= 0.0:
		clans = tmp.clans

	# Colonists
	if colonisttaxrate < 0.0 and tmp.colonisttaxrate >= 0.0:
		colonisttaxrate = tmp.colonisttaxrate
	if colonisthappypoints < 0.0 and tmp.colonisthappypoints >= 0.0:
		colonisthappypoints = tmp.colonisthappypoints

	# Natives
	if nativeracename == "none" and tmp.nativeracename != "none":
		nativeracename = tmp.nativeracename
	if nativeclans < 0.0 and tmp.nativeclans >= 0.0:
		nativeclans = tmp.nativeclans
	if nativegovernmentname == "" and tmp.nativegovernmentname != "":
		nativegovernmentname = tmp.nativegovernmentname
	if nativegovernment < 0.0 and tmp.nativegovernment >= 0.0:
		nativegovernment = tmp.nativegovernment
	if nativetaxrate < 0.0 and tmp.nativetaxrate >= 0.0:
		nativetaxrate = tmp.nativetaxrate
	if nativehappypoints < 0.0 and tmp.nativehappypoints >= 0.0:
		nativehappypoints = tmp.nativehappypoints
	if nativetype < 0.0 and tmp.nativetype >= 0.0:
		nativetype = tmp.nativetype
	if nativetaxvalue < 0.0 and tmp.nativetaxvalue >= 0.0:
		nativetaxvalue = tmp.nativetaxvalue

	# Industry
	if factories < 0.0 and tmp.factories >= 0.0:
		factories = tmp.factories
	if mines < 0.0 and tmp.mines >= 0.0:
		mines = tmp.mines
	if defense < 0.0 and tmp.defense >= 0.0:
		defense = tmp.defense

	# Minerals surface
	if neutronium < 0.0 and tmp.neutronium >= 0.0:
		neutronium = tmp.neutronium
	if tritanium < 0.0 and tmp.tritanium >= 0.0:
		tritanium = tmp.tritanium
	if duranium < 0.0 and tmp.duranium >= 0.0:
		duranium = tmp.duranium
	if molybdenum < 0.0 and tmp.molybdenum >= 0.0:
		molybdenum = tmp.molybdenum

	# Minerals ground
	if groundneutronium < 0.0 and tmp.groundneutronium >= 0.0:
		groundneutronium = tmp.groundneutronium
	if groundtritanium < 0.0 and tmp.groundtritanium >= 0.0:
		groundtritanium = tmp.groundtritanium
	if groundduranium < 0.0 and tmp.groundduranium >= 0.0:
		groundduranium = tmp.groundduranium
	if groundmolybdenum < 0.0 and tmp.groundmolybdenum >= 0.0:
		groundmolybdenum = tmp.groundmolybdenum

	# Minerals density
	if densityneutronium < 0.0 and tmp.densityneutronium >= 0.0:
		densityneutronium = tmp.densityneutronium
	if densitytritanium < 0.0 and tmp.densitytritanium >= 0.0:
		densitytritanium = tmp.densitytritanium
	if densityduranium < 0.0 and tmp.densityduranium >= 0.0:
		densityduranium = tmp.densityduranium
	if densitymolybdenum < 0.0 and tmp.densitymolybdenum >= 0.0:
		densitymolybdenum = tmp.densitymolybdenum

	# Optional
	if img == "" and tmp.img != "":
		img = tmp.img
	if infoturn < 0.0 and tmp.infoturn >= 0.0:
		infoturn = tmp.infoturn
	if readystatus < 0.0 and tmp.readystatus >= 0.0:
		readystatus = tmp.readystatus
