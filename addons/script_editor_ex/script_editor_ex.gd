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
