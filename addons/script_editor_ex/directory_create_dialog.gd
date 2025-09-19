extends ConfirmationDialog
class_name DirectoryCreateDialog

var validation_panel:Control
var dir_path:LineEdit
var base_path_label:Label
var name_label:Label
var _base_path:String = ""
var _mode:int = 0

func _ready() -> void:
	min_size = Vector2i(480, 0)
	
	var vb = VBoxContainer.new()
	add_child(vb)
	
	base_path_label = Label.new()
	vb.add_child(base_path_label)
	
	name_label = Label.new()
	name_label.text = "Name:"
	name_label.theme_type_variation = "HeaderSmall"
	vb.add_child(name_label)
	
	dir_path = LineEdit.new()
	dir_path.accessibility_name = "Name:"
	vb.add_child(dir_path)
	
	var spacing = Control.new()
	spacing.custom_minimum_size = Vector2(0, 10)
	spacing.update_minimum_size()
	vb.add_child(spacing)
	
	validation_panel = Control.new()
	vb.add_child(validation_panel)
	
	dir_path.text_changed.connect(_on_text_changed)
	
	_update_buttons()
	
	self.visibility_changed.connect(_post_popup)
	self.confirmed.connect(_on_confirmed)
	
func config(p_base_dir:String, p_accept_callback:Callable, p_mode:int, p_title:String, p_default_name:String):
	_mode = p_mode
	_base_path = p_base_dir
	base_path_label.text = tr("Base path: %s") % [_base_path]
	dir_path.text = p_default_name
	title = p_title
	_update_buttons()
	
func _post_popup():
	if visible:
		dir_path.grab_focus()
		dir_path.select_all()
	
func _on_text_changed(txt:String):
	_update_buttons()
	
func _update_buttons():
	var exists = DirAccess.dir_exists_absolute(_base_path + "/" + dir_path.text)
	self.get_ok_button().disabled = dir_path.text.length() < 1 or exists
	
func _on_confirmed():
	if _mode == 0:
		# FILE
		var path = _base_path + "/" + dir_path.text
		DirAccess.make_dir_recursive_absolute(path)
	else:
		# DIR
		var path = _base_path + "/" + dir_path.text
		DirAccess.make_dir_recursive_absolute(path)
