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
		if !dir_paths.has(path):
			dir_paths.push_back(path)
		_get_all_paths(path,dir_paths,file_paths)
	for path in _files:
		if !file_paths.has(path):
			file_paths.push_back(path)
		var uid = path + ".uid"
		if !file_paths.has(uid):
			if FileAccess.file_exists(uid):
				file_paths.push_back(uid)
	for path in dir_paths:
		items.add_item(path)
	for path in file_paths:
		items.add_item(path)
	#if paths.size() <= 0:
	#	text.text = "Remove the selected files from the project? (Cannot be undone.)\nDepending on your filesystem configuration, the files will either be moved to the system trash or deleted permanently."
	#else:
	#	text.text = "The files being removed are required by other resources in order for them to work.\nRemove them anyway? (Cannot be undone.)\nDepending on your filesystem configuration, the files will either be moved to the system trash or deleted permanently."
	title = _title
	_update_buttons()
	
func _get_all_paths(path:String,dirs:Array[String],files:Array[String]):
	var dir := DirAccess.open(path)
	if not dir:
		return
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		var full_path = path.path_join(file_name)
		if dir.current_is_dir():
			if !dirs.has(full_path):
				dirs.push_back(full_path)
			_get_all_paths(full_path,dirs,files)
		else:
			if !files.has(full_path):
				files.push_back(full_path)
		file_name = dir.get_next()
	
func _on_text_changed(txt:String):
	_update_buttons()
	
func _update_buttons():
	self.get_ok_button().disabled = dir_paths.size() < 1 and file_paths.size() < 1
	
func _on_confirmed():
	# ファイルを先に削除
	for path in file_paths:
		var result = DirAccess.remove_absolute(path)
		if result == Error.OK:
			print("[RemoveDialog] delete:success. path: " + str(path))
		else:
			printerr("[RemoveDialog] delete:error. path: " + str(path) + " result:" + str(result))
		
	# 最下層から削除する
	dir_paths.sort()
	dir_paths.reverse()
	for path in dir_paths:
		var result = DirAccess.remove_absolute(path)
		if result == Error.OK:
			print("[RemoveDialog] delete:success. path: " + str(path))
		else:
			printerr("[RemoveDialog] delete:error. path: " + str(path) + " result:" + str(result))
			
