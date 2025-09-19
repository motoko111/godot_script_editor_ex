extends ConfirmationDialog
class_name RemoveDialog

#var text:Label = null
#var tree:Tree = null
var items:ItemList = null
var dir_paths:Array[String] = []
var file_paths:Array[String] = []

func _ready() -> void:
	dir_paths.clear()
	file_paths.clear()
	
	min_size = Vector2i(480, 0)
	
	var vb = VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(vb)
	
	#text = Label.new()
	#text.focus_mode = Control.FOCUS_ACCESSIBILITY
	#vb.add_child(text)
	
	var files_to_delete_label = Label.new()
	files_to_delete_label.theme_type_variation = "HeaderSmall"
	files_to_delete_label.text = "Files to be deleted:"
	vb.add_child(files_to_delete_label)
	
	items = ItemList.new()
	items.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	items.size_flags_vertical = Control.SIZE_EXPAND_FILL
	items.custom_minimum_size = Vector2(0, 94)
	items.accessibility_name = "Files to be deleted:"
	vb.add_child(items)
	
	_update_buttons()
	
	self.confirmed.connect(_on_confirmed)
	
func config(_files:Array[String],_dirs:Array[String],_title:String = "Please Confirm..."):
	items.clear()
	dir_paths.clear()
	file_paths.clear()
	for path in _dirs:
		items.add_item(path)
		dir_paths.push_back(path)
	for path in _files:
		items.add_item(path)
		file_paths.push_back(path)
	#if paths.size() <= 0:
	#	text.text = "Remove the selected files from the project? (Cannot be undone.)\nDepending on your filesystem configuration, the files will either be moved to the system trash or deleted permanently."
	#else:
	#	text.text = "The files being removed are required by other resources in order for them to work.\nRemove them anyway? (Cannot be undone.)\nDepending on your filesystem configuration, the files will either be moved to the system trash or deleted permanently."
	title = _title
	_update_buttons()
	
func _get_all_paths(path:String):
	var ret = []
	var dir := DirAccess.open(path)
	if not dir:
		return
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		ret.push_back(file_name)
	return ret
	
func _on_text_changed(txt:String):
	_update_buttons()
	
func _update_buttons():
	self.get_ok_button().disabled = dir_paths.size() < 1 and file_paths.size() < 1
	
func _on_confirmed():
	var regex = RegEx.create_from_string("^res://")
	var project_path = ProjectSettings.globalize_path("res://")
	for path in file_paths:
		var result = DirAccess.remove_absolute(path)
		if result == Error.OK:
			print("[RemoveDialog] delete:success. path: " + str(path))
		else:
			printerr("[RemoveDialog] delete:error. path: " + str(path) + " result:" + str(result))
	for path in dir_paths:
		var taret_path = project_path + regex.sub(path,"/")
		var result = OS.move_to_trash(taret_path)
		if result == Error.OK:
			print("[RemoveDialog] delete:success. path: " + str(taret_path))
		else:
			printerr("[RemoveDialog] delete:error. path: " + str(taret_path) + " result:" + str(result))
			
