@tool
extends EditorPlugin

var _panel:Control

func _enter_tree():
	get_editor_interface().get_script_editor().editor_script_changed.connect(_on_editor_script_changed)
	_add_ui()
	
func _exit_tree():
	_remove_ui()
	get_editor_interface().get_script_editor().editor_script_changed.disconnect(_on_editor_script_changed)
	
func _on_editor_script_changed(script):
	_add_ui()
			
func _add_ui():
	if _panel or !_is_open_script_editor():
		return
		
	var split = VSplitContainer.new()
	split.split_offset = 400
	
	var filesystem = ScriptEditorFileSystem.create(self)
	split.add_child(filesystem)
	
	_panel = split
	
	_insert_ui(_panel)
	
	#_print_all_control(_get_editor_root().get_parent())
	#var dock = _find_ui_by_all_control(_get_editor_root().get_parent().get_parent().get_parent().get_parent().get_parent().get_parent().get_parent(), "FileSystemDock")[0]
	#print(str(dock))
	#var dock_duplicate = dock.duplicate(true)
	#print(str(dock_duplicate))
	#var dock = _copy_ui(get_editor_interface().get_file_system_dock().get_children()[0])
	#_print_all_control(dock)
	#save_control_as_scene(dock, "res://addons/script_editor_ex/file_system_dock.tscn")
	
func _remove_ui():
	if _panel:
		var script_editor = get_editor_interface().get_script_editor()
		if script_editor and script_editor.get_current_editor():
			_reverse_ui(_panel)
			

func _is_open_script_editor() -> bool:
	if !get_editor_interface():
		return false
	if !get_editor_interface().get_script_editor():
		return false
	if !get_editor_interface().get_script_editor().get_current_editor():
		return false
	if !get_editor_interface().get_script_editor().get_current_editor().get_parent():
		return false
	return true

func _get_editor_root():
	if _is_open_script_editor():
		return (get_editor_interface()
		.get_script_editor()
		.get_current_editor()
		.get_parent()
		.get_parent()
		.get_parent()
		.get_children()[0]
		)
	return null

func _insert_ui(ui:Control):
	var target = _get_editor_root().get_children()[1]
	_get_editor_root().remove_child(target)
	ui.add_child(target)
	_get_editor_root().add_child(ui)
	
func _reverse_ui(ui:Control):
	var target = ui.get_children()[1]
	ui.remove_child(target)
	_get_editor_root().remove_child(ui)
	_get_editor_root().add_child(target)
	
func _copy_ui(base:Control):
	var copy = base.duplicate(true)
	_apply_copy_all_control(base,copy)
	return copy
	
func _apply_copy_all_control(target:Node,copy:Node):
	if target:
		for child in target.get_children():
			var child_copy = child.duplicate(true)
			copy.add_child(child_copy)
			_apply_copy_all_control(child, child_copy)
	
func _find_ui_by_all_control(base:Control,find:String):
	var ret = []
	var f = func(_node:Node,h:int):
		if _node.name == find:
			ret.push_back(_node)
	_apply_all_children(base,f,0)
	return ret

func _print_all_control(base:Control):
	var _log = [""]
	print(str(base.get_path()))
	var f = func(_node:Node,h:int):
		var head = ""
		for i in range(h):
			head += "- "
		_log[0] += head + str(_node.name) + "\n"
	_apply_all_children(base,f,0)
	print(_log[0])

func _apply_all_children(target:Node,f,h = 0):
	if target:
		f.call(target,h)
		for child in target.get_children():
			_apply_all_children(child, f, h+1)

func save_control_as_scene(control: Control, path: String):
	# PackedScene に変換
	var packed_scene := PackedScene.new()
	var result = packed_scene.pack(control)
	if result != OK:
		push_error("シーンのパックに失敗しました: %s" % result)
		return

	# 保存
	var err = ResourceSaver.save(packed_scene, path)
	if err != OK:
		push_error("保存に失敗しました: %s" % err)
	else:
		print("保存成功: %s" % path)
