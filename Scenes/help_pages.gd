extends Control
class_name HelpPanel

const HELP_JSON_PATH: String = "res://help_pages.json"

@onready var search_edit: LineEdit = %SearchEdit
@onready var toc_tree: Tree = %TocTree
@onready var content_text: RichTextLabel = %ContentText
@onready var close_btn: Button = %CloseBtn

var _help_data: Dictionary = {}
var _pages_by_id: Dictionary = {}
var _first_page_id: String = ""


func _ready() -> void:
	if close_btn != null:
		close_btn.pressed.connect(_on_close_pressed)

	search_edit.text_changed.connect(_on_search_text_changed)
	toc_tree.item_selected.connect(_on_toc_item_selected)

	content_text.bbcode_enabled = true
	content_text.clear()

	_load_help_json()
	_rebuild_tree("")

	if not _first_page_id.is_empty():
		_show_page(_first_page_id)


func open_panel() -> void:
	show()
	grab_focus()


func _on_close_pressed() -> void:
	hide()


# -----------------------------------------------------------------------------
# Load / index help data
# -----------------------------------------------------------------------------

func _load_help_json() -> void:
	_help_data.clear()
	_pages_by_id.clear()
	_first_page_id = ""

	if not FileAccess.file_exists(HELP_JSON_PATH):
		push_error("Help JSON not found: " + HELP_JSON_PATH)
		return

	var f: FileAccess = FileAccess.open(HELP_JSON_PATH, FileAccess.READ)
	if f == null:
		push_error("Cannot open help JSON: " + HELP_JSON_PATH)
		return

	var text: String = f.get_as_text()
	f.close()

	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_error("Invalid help JSON in " + HELP_JSON_PATH)
		return

	_help_data = parsed as Dictionary

	var pages_v: Variant = _help_data.get("pages", [])
	if pages_v is Array:
		var pages: Array = pages_v as Array
		_index_pages_recursive(pages)


func _index_pages_recursive(pages: Array) -> void:
	for entry in pages:
		if not (entry is Dictionary):
			continue

		var d: Dictionary = entry as Dictionary
		var id_s: String = String(d.get("id", ""))

		if not id_s.is_empty():
			_pages_by_id[id_s] = d
			if _first_page_id.is_empty():
				_first_page_id = id_s

		var children_v: Variant = d.get("children", [])
		if children_v is Array:
			_index_pages_recursive(children_v as Array)


# -----------------------------------------------------------------------------
# Tree building / filtering
# -----------------------------------------------------------------------------

func _rebuild_tree(filter_text: String) -> void:
	toc_tree.clear()

	var root: TreeItem = toc_tree.create_item()
	var pages_v: Variant = _help_data.get("pages", [])
	if not (pages_v is Array):
		return

	var filter_lc: String = filter_text.strip_edges().to_lower()
	_add_pages_to_tree(root, pages_v as Array, filter_lc)

	_select_first_visible_page()


func _add_pages_to_tree(parent: TreeItem, pages: Array, filter_text: String) -> void:
	for entry in pages:
		if not (entry is Dictionary):
			continue

		var d: Dictionary = entry as Dictionary
		var title: String = String(d.get("title", ""))
		var id_s: String = String(d.get("id", ""))
		var content: String = String(d.get("content", ""))

		var children: Array = []
		var children_v: Variant = d.get("children", [])
		if children_v is Array:
			children = children_v as Array

		var matches_self: bool = filter_text.is_empty() \
			or title.to_lower().contains(filter_text) \
			or content.to_lower().contains(filter_text)

		var child_matches: bool = _has_matching_child(children, filter_text)

		if not matches_self and not child_matches:
			continue

		var item: TreeItem = toc_tree.create_item(parent)
		item.set_text(0, title)
		item.set_metadata(0, id_s)

		if not children.is_empty():
			_add_pages_to_tree(item, children, filter_text)
			item.collapsed = false


func _has_matching_child(children: Array, filter_text: String) -> bool:
	if children.is_empty():
		return false

	if filter_text.is_empty():
		return true

	for entry in children:
		if not (entry is Dictionary):
			continue

		var d: Dictionary = entry as Dictionary
		var title: String = String(d.get("title", ""))
		var content: String = String(d.get("content", ""))

		if title.to_lower().contains(filter_text):
			return true
		if content.to_lower().contains(filter_text):
			return true

		var sub_v: Variant = d.get("children", [])
		if sub_v is Array:
			if _has_matching_child(sub_v as Array, filter_text):
				return true

	return false


func _select_first_visible_page() -> void:
	var root: TreeItem = toc_tree.get_root()
	if root == null:
		return

	var first: TreeItem = _find_first_item_with_page(root)
	if first == null:
		content_text.clear()
		return

	toc_tree.set_selected(first, 0)
	var meta: Variant = first.get_metadata(0)
	if typeof(meta) == TYPE_STRING:
		_show_page(String(meta))


func _find_first_item_with_page(item: TreeItem) -> TreeItem:
	var child: TreeItem = item.get_first_child()
	while child != null:
		var meta: Variant = child.get_metadata(0)
		if typeof(meta) == TYPE_STRING and not String(meta).is_empty():
			return child

		var nested: TreeItem = _find_first_item_with_page(child)
		if nested != null:
			return nested

		child = child.get_next()

	return null


# -----------------------------------------------------------------------------
# Selection / display
# -----------------------------------------------------------------------------

func _on_search_text_changed(new_text: String) -> void:
	_rebuild_tree(new_text)


func _on_toc_item_selected() -> void:
	var item: TreeItem = toc_tree.get_selected()
	if item == null:
		return

	var meta: Variant = item.get_metadata(0)
	if typeof(meta) != TYPE_STRING:
		return

	var page_id: String = String(meta)
	if page_id.is_empty():
		return

	_show_page(page_id)


func _show_page(page_id: String) -> void:
	if not _pages_by_id.has(page_id):
		content_text.clear()
		return

	var d: Dictionary = _pages_by_id[page_id] as Dictionary
	var title: String = String(d.get("title", ""))
	var content: String = String(d.get("content", ""))

	content_text.clear()
	content_text.text = "[center][b]" + _escape_bbcode(title) + "[/b][/center]\n\n" + content


# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------

func _escape_bbcode(s: String) -> String:
	var out: String = s
	out = out.replace("[", "[lb]")
	out = out.replace("]", "[rb]")
	return out
