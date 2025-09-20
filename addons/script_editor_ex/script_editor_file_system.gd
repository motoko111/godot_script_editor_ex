@tool
extends VBoxContainer
class_name ScriptEditorFileSystem

## ファイル削除系は危ないので無効化
const ENABLE_DELETE:bool = false 
## Alt+F12でUI再構築
const ENABLE_RELOAD:bool = true
## 表示対象のファイル正規表現
var REGEX_TARGET_FILE:RegEx = RegEx.create_from_string(".*\\.(gd|cfg)$") 

var tree:Tree
var edit:LineEdit
var editor_plugin:EditorPlugin
var right_menu:PopupMenu
var script_create_dialog:ScriptCreateDialog
var folder_create_dialog:DirectoryCreateDialog
var remove_dialog:RemoveDialog
var duplicate_dialog:DirectoryCreateDialog
var shortcut_infos:Array[Dictionary] = []

var _duplicate_src_path = ""

static func create(_editor_plugin:EditorPlugin) -> ScriptEditorFileSystem:
	var instance = ScriptEditorFileSystem.new()
	instance.name = "ScriptEditorFileSystem"
	instance.editor_plugin = _editor_plugin
	return instance

func _ready() -> void:
	setup()

func _enter_tree() -> void:
	var fs = editor_plugin.get_editor_interface().get_resource_filesystem()
	fs.filesystem_changed.connect(_on_filesystem_changed)
	fs.resources_reimported.connect(_on_resources_reimported)
	
func _exit_tree() -> void:
	var fs = editor_plugin.get_editor_interface().get_resource_filesystem()
	fs.filesystem_changed.disconnect(_on_filesystem_changed)
	fs.resources_reimported.disconnect(_on_resources_reimported)
	
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		for info in shortcut_infos:
			var shortcut:Shortcut = info.shortcut
			if info.event != null and shortcut.matches_event(event):
				info.event.call()
				return
		if ENABLE_RELOAD and event.pressed and !event.is_echo() and event.keycode == KEY_F12 and event.alt_pressed:
			setup()
	
func _tree_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			_on_mouse_right_pressed(event)
		
func clear():
	for child in get_children():
		child.queue_free()
	shortcut_infos.clear()
	_duplicate_src_path = ""
			
func setup():
	clear()
	edit = LineEdit.new()
	edit.placeholder_text = "Filter Files"
	edit.right_icon = _get_icon("Search")
	edit.text_changed.connect(_on_edit_text_changed)
	tree = Tree.new()
	tree.select_mode =Tree.SELECT_MULTI
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_build_tree()
	add_child(edit)
	add_child(tree)
	_update_edit()
	
	tree.multi_selected.connect(_on_item_selected)
	tree.gui_input.connect(_tree_gui_input)
	tree.item_edited.connect(_on_item_edited)
			
func _build_right_menu():
	# ref editor/docks/filesystem_dock.cpp
	if right_menu:
		right_menu.queue_free()
	right_menu = PopupMenu.new()
	var new_menu = PopupMenu.new()
	new_menu.add_icon_item(_get_icon("Folder"), "Folder...", 1)
	new_menu.add_icon_item(_get_icon("Script"), "Script...", 2)
	new_menu.id_pressed.connect(_open_menu)
	right_menu.add_submenu_node_item("Create New", new_menu, 0)
	right_menu.set_item_icon(right_menu.get_item_index(0), _get_icon("Add"))
	if ENABLE_DELETE:
		right_menu.add_icon_shortcut(_get_icon("Rename"), _create_shortcut(_rename_file, "Rename", KEY_F2, false), 10)
		right_menu.add_icon_shortcut(_get_icon("Duplicate"), _create_shortcut(_duplicate_file, "Duplicate", KEY_D, true), 12)
		right_menu.add_icon_shortcut(_get_icon("Remove"), _create_shortcut(_remove_file, "Delete", KEY_DELETE, false), 11)
	right_menu.add_icon_shortcut(_get_icon("Filesystem"), _create_shortcut(_open_file_manager, "Open in File Manager", KEY_R, true, false, true), 15)
	right_menu.id_pressed.connect(_open_menu)
	right_menu.hide()
	add_child(right_menu)
	
	script_create_dialog = ScriptCreateDialog.new()
	script_create_dialog.script_created.connect(_on_create_script)
	add_child(script_create_dialog)
	
	folder_create_dialog = DirectoryCreateDialog.new()
	folder_create_dialog.confirmed.connect(_on_create_folder)
	add_child(folder_create_dialog)
	
	if ENABLE_DELETE:
		remove_dialog = RemoveDialog.new()
		remove_dialog.confirmed.connect(_on_remove_file)
		add_child(remove_dialog)
		
		duplicate_dialog = DirectoryCreateDialog.new()
		duplicate_dialog.confirmed.connect(_on_duplicate_file)
		add_child(duplicate_dialog)
	
func _create_shortcut(_event, _name, keycode, ctrl:bool = false, shift:bool = false, alt:bool = false) -> Shortcut:
	var shortcut = Shortcut.new()
	var key_event = InputEventKey.new()
	key_event.keycode = keycode
	key_event.ctrl_pressed = ctrl
	key_event.alt_pressed = alt
	key_event.shift_pressed = shift
	key_event.command_or_control_autoremap = ctrl
	shortcut.resource_name = _name
	shortcut.events = [key_event]
	shortcut_infos.push_back({
		shortcut = shortcut,
		event = _event
	})
	return shortcut
	
func _open_menu(id:int):
	# print("open menu:" + str(id))
	match id:
		0:
			pass
		1:
			_new_folder()
		2:
			_new_file()
		10:
			_rename_file()
		11:
			_remove_file()
		12:
			_duplicate_file()
		15:
			_open_file_manager()
	
func _build_tree():
	tree.clear()
	var root = tree.create_item()
	root.set_icon(0, _get_icon("Folder"))
	root.set_text(0, "res://")
	root.set_icon_modulate(0, Color("#88b6dd"))
	root.set_metadata(0, {
			path = "res://",
			is_dir = true
		})
	root.set_editable(0,false)
	_populate_tree(tree, root, "res://")
	
func _populate_tree(tree:Tree, parent: TreeItem, path: String):
	var dir := DirAccess.open(path)
	if !dir:
		return
	dir.list_dir_begin()
	var file_name = dir.get_next()
	var last_dir_index:int = 0
	while file_name != "":
		var is_dir = dir.current_is_dir()
		
		if file_name.begins_with("."): # 隠しファイル除外
			file_name = dir.get_next()
			continue
			
		if !is_dir and REGEX_TARGET_FILE.search(file_name) == null:
			file_name = dir.get_next()
			continue
		
		var index = -1
		if is_dir:
			index = last_dir_index
		var full_path = path.path_join(file_name)
		var item = tree.create_item(parent,index)
		item.collapsed = true
		item.set_text(0, file_name)
		item.set_metadata(0, {
			path = full_path,
			is_dir = is_dir
		})
		item.set_editable(0,true)

		if is_dir:
			item.set_icon(0, _get_icon("Folder"))
			item.set_icon_modulate(0, Color("#88b6dd"))
			_populate_tree(tree, item, full_path) # 再帰でフォルダを展開
			last_dir_index += 1
		else:
			if file_name.ends_with(".gd"):
				item.set_icon(0, _get_icon("GDScript"))
			elif file_name.ends_with(".cfg"):
				item.set_icon(0, _get_icon("TextFile"))
			else:
				item.set_icon(0, _get_icon("File"))
			item.set_icon_modulate(0, Color("#e0e0e0"))

		file_name = dir.get_next()
	dir.list_dir_end()

func _apply_filter():
	var root = tree.get_root()
	if root:
		_apply_filter_recursive(root)

func _apply_filter_recursive(item: TreeItem):
	var filter_text = edit.text
	var is_empty := filter_text.is_empty()
	while item:
		var _name := item.get_text(0)
		var is_match := is_empty or _name.findn(filter_text) != -1

		# 自分がマッチ or 子がマッチしていれば表示
		var child_visible := _has_visible_child(item)
		item.visible = is_match or child_visible
		if item.visible:
			item.collapsed = false
		
		if item.get_first_child():
			_apply_filter_recursive(item.get_first_child())

		item = item.get_next()

func _has_visible_child(item: TreeItem) -> bool:
	var filter_text = edit.text
	var child := item.get_first_child()
	while child:
		if filter_text == "" or child.get_text(0).findn(filter_text) != -1:
			return true
		if _has_visible_child(child):
			return true
		child = child.get_next()
	return false
		
func _get_icon(_icon:String) -> Texture2D:
	if editor_plugin and editor_plugin.get_editor_interface():
		return editor_plugin.get_editor_interface().get_base_control().get_theme_icon(_icon, "EditorIcons")
	return null
		
func _on_item_selected(_item:TreeItem,_column:int,_seleted:bool):
	if _column != 0:
		return
	var item := tree.get_selected()
	if item:
		var path: String = item.get_metadata(0).path
		if path.ends_with(".gd")or path.ends_with(".cfg") or path.ends_with(".tscn") or path.ends_with(".tres"):
			editor_plugin.get_editor_interface().edit_resource(load(path))
			tree.grab_focus()

func _on_edit_text_changed(txt:String):
	_apply_filter()
	_update_edit()
	
func _on_mouse_right_pressed(ev:InputEventMouse):
	_build_right_menu()
	right_menu.position = ev.position + tree.get_screen_position()
	right_menu.popup()
	tree.grab_focus()
	
func _update_edit():
	if edit.text.length() > 0:
		edit.right_icon = _get_icon("Close")
		edit.clear_button_enabled = true
	else:
		edit.right_icon = _get_icon("Search")
		edit.clear_button_enabled = false
		
func _new_file():
	var item := tree.get_selected()
	print(str(item))
	if item:
		var dir:String = ""
		dir = item.get_metadata(0).path
		if item.get_icon(0) != _get_icon("Folder"):
			dir = dir.get_base_dir()
		var dialog = script_create_dialog
		dialog.config("Node", dir + "/new_script.gd")
		dialog.popup_centered()
	right_menu.hide()
	
func _new_folder():
	var item := tree.get_selected()
	if item:
		var dir:String = ""
		dir = item.get_metadata(0).path
		if item.get_icon(0) != _get_icon("Folder"):
			dir = dir.get_base_dir()
		var dialog = folder_create_dialog
		dialog.config(dir, _on_confirm_new_folder, 1, "Create Folder", "new folder")
		dialog.popup_centered()
	right_menu.hide()
	
func _remove_file():
	var item := tree.get_selected()
	if item:
		var items = _get_seleted_items()
		var remove_files:Array[String] = []
		var remove_dirs:Array[String] = []
		for _item in items:
			var path:String = _item.get_metadata(0).path
			var is_dir:bool = _item.get_metadata(0).is_dir
			if !is_dir:
				remove_files.push_back(path)
			else:
				remove_dirs.push_back(path)
		var dialog = remove_dialog
		dialog.config(remove_files, remove_dirs)
		dialog.popup_centered()
	right_menu.hide()
	
func _rename_file():
	var item := tree.get_selected()
	if item:
		tree.edit_selected()
	right_menu.hide()

func _on_item_edited():
	var item := tree.get_edited()
	if item:
		var file = item.get_text(0)
		var param = item.get_metadata(0)
		var is_error = file.is_empty()
		var path:String = param.path
		var prev_file = path.get_file()
		var dir:String = ""
		var next:String = ""
		if !param.is_dir:
			dir = path.get_base_dir()
			next = dir + "/" + file
		else:
			dir = path
			var index = path.rfind(prev_file)
			var d = path.substr(0,index)
			next = d + file
		if next == path:
			return
		print("%s -> %s" % [path,next])
		is_error = is_error or !_rename(path, next, param.is_dir)
		if is_error:
			print("rename error")
			item.set_text(0,prev_file)
		else:
			print("rename success")
			param.path = next
			item.set_metadata(0, param)
			_on_rename_file()
			
func _rename(src:String,dest:String,is_dir:bool):
	if src == dest:
		return false
	if is_dir:
		if _copy_all_paths(src,dest):
			if _remove_all_paths(src):
				return true
	else:
		var is_error:bool = false
		var success_cnt = 0
		var path = src
		var next = dest
		var result = DirAccess.rename_absolute(path,next)
		if result == OK:
			print("[ScriptEditorFileSystem::_rename] rename:success. path: " + str(path) + " ->" +  str(next))
			success_cnt += 1
		else:
			printerr("[ScriptEditorFileSystem::_rename] rename:error. path: " + str(path) + " ->" +  str(next))
			is_error = true
		return !is_error and success_cnt > 0
	return false
	
func _duplicate_file():
	var item := tree.get_selected()
	if item:
		var dir:String = ""
		var mode:int = 0
		var path:String = item.get_metadata(0).path
		var is_dir:bool = item.get_metadata(0).is_dir
		var file = item.get_text(0)
		if !is_dir:
			dir = path.get_base_dir()
			mode = 0
		else:
			var index = path.rfind(file)
			var d = path.substr(0,index)
			dir = d
			mode = 1
		_duplicate_src_path = path
		var dialog = duplicate_dialog
		if is_dir:
			dialog.config(dir, _on_confirm_duplicate, mode, tr("Duplicating folder:") + " " + file, file)
		else:
			dialog.config(dir, _on_confirm_duplicate, mode, tr("Duplicating file:") + " " + file, file)
		dialog.popup_centered()
	right_menu.hide()
	
func _open_file_manager():
	var item := tree.get_selected()
	if item:
		var path = item.get_metadata(0).path
		var project_path = ProjectSettings.globalize_path(path)
		print("open " + str(project_path))
		OS.shell_show_in_file_manager(project_path)
	
func _on_create_script(script):
	EditorInterface.get_resource_filesystem().scan()
	
func _on_create_folder():
	EditorInterface.get_resource_filesystem().scan()
	
func _on_remove_file():
	EditorInterface.get_resource_filesystem().scan()
	
func _on_rename_file():
	EditorInterface.get_resource_filesystem().scan()
	
func _on_duplicate_file():
	EditorInterface.get_resource_filesystem().scan()
	
func _on_confirm_new_folder(path):
	var result = DirAccess.make_dir_recursive_absolute(path)
	if result == OK:
		print("[ScriptEditorFileSystem::_on_confirm_new_folder] create folder:success. path: " + str(path))
	else:
		printerr("[ScriptEditorFileSystem::_on_confirm_new_folder] create folder:error. path: " + str(path) + " error:" + str(result))
	
func _on_confirm_duplicate(path):
	var src = _duplicate_src_path
	var dest = path
	if _copy_all_paths(src, dest):
		print("[ScriptEditorFileSystem::_on_confirm_duplicate] duplicate:success. path: " + str(src) + " ->" +  str(dest))
	else:
		printerr("[ScriptEditorFileSystem::_on_confirm_duplicate] duplicate:error. path: " + str(src) + " ->" +  str(dest))
	
func _on_filesystem_changed():
	_build_tree()
	_apply_filter()
	
func _on_resources_reimported(resources):
	_build_tree()
	_apply_filter()
	
## 再帰的に選択アイテム取得
func _get_seleted_items() -> Array[TreeItem]:
	var result: Array[TreeItem] = []
	var root: TreeItem = tree.get_root()
	if root:
		_collect_selected_recursive(root, result)
	return result

## 再帰的に選択アイテム取得
func _collect_selected_recursive(item: TreeItem, result: Array):
	while item:
		if item.is_selected(0): # 0列目が選択されているか
			result.append(item)
		if item.get_first_child():
			_collect_selected_recursive(item.get_first_child(), result)
		item = item.get_next()
		
# 再帰的に削除
func _remove_all_paths(path:String) -> bool:
	var dirs:Array[String] = []
	var files:Array[String] = []
	var is_dir = DirAccess.dir_exists_absolute(path)
	if is_dir:
		dirs.push_back(path)
	else:
		files.push_back(path)
	_get_all_paths(path,dirs,files)
	
	var results = []
	var is_error:bool = false
	
	# ファイルを先に削除
	for file in files:
		var result = DirAccess.remove_absolute(file)
		if result == Error.OK:
			results.push_back(file)
			print("[ScriptEditorFileSystem::_remove_all_paths] delete:success. path: " + str(file))
		else:
			is_error = true
			printerr("[ScriptEditorFileSystem::_remove_all_paths] delete:error. path: " + str(file) + " result:" + str(result))
		
	# 最下層から削除する
	dirs.sort()
	dirs.reverse()
	for dir in dirs:
		var result = DirAccess.remove_absolute(dir)
		if result == Error.OK:
			results.push_back(dir)
			print("[ScriptEditorFileSystem::_remove_all_paths] delete:success. path: " + str(dir))
		else:
			is_error = true
			printerr("[ScriptEditorFileSystem::_remove_all_paths] delete:error. path: " + str(dir) + " result:" + str(result))
	
	return !is_error and results.size() > 0
			
# 再帰的にコピー
func _copy_all_paths(src:String,dest:String) -> bool:
	var dirs:Array[String] = []
	var files:Array[String] = []
	var is_dir = DirAccess.dir_exists_absolute(src)
	if is_dir:
		dirs.push_back(src)
	else:
		files.push_back(src)
	_get_all_paths(src,dirs,files)
	
	var results = []
	var is_error:bool = false
	
	dirs.sort()
	for dir in dirs:
		var next = dir.replace(src,dest)
		if DirAccess.dir_exists_absolute(next):
			continue
		var result = DirAccess.make_dir_recursive_absolute(next)
		if result == OK:
			print("[ScriptEditorFileSystem::_copy_all_paths] copy:success. path: " + str(dir) + " ->" +  str(next))
			results.push_back(next)
		else:
			printerr("[ScriptEditorFileSystem::_copy_all_paths] copy:error. path: " + str(dir) + " ->" +  str(next) + " error:" + str(result))
			is_error = true
			
	for file in files:
		if file.ends_with(".uid"):
			continue
		var next = file.replace(src,dest)
		if DirAccess.dir_exists_absolute(next):
			continue
		var result = DirAccess.copy_absolute(file,next)
		if result == OK:
			print("[ScriptEditorFileSystem::_copy_all_paths] copy:success. path: " + str(file) + " ->" +  str(next))
			results.push_back(next)
		else:
			printerr("[ScriptEditorFileSystem::_copy_all_paths] copy:error. path: " + str(file) + " ->" +  str(next) + " error:" + str(result))
			is_error = true
		
			
	return !is_error and results.size() > 0

## 再帰的にファイル/ディレクトリ取得
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
