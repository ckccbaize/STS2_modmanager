extends RefCounted
class_name FileUtils

# 文件操作工具类

# 复制目录及其所有内容
static func copy_directory(source: String, destination: String) -> bool:
	var dir = DirAccess.open(source)
	if dir == null:
		return false
	
	# 创建目标目录
	var dest_dir = DirAccess.open(destination.get_base_dir())
	if dest_dir == null:
		var result = DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
		if result != OK:
			return false
	
	if DirAccess.dir_exists_absolute(destination):
		var remove_result = DirAccess.remove_absolute(destination)
		if remove_result != OK:
			return false
	
	var make_result = DirAccess.make_dir_recursive_absolute(destination)
	if make_result != OK:
		return false
	
	# 复制文件
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name == "." or file_name == "..":
			file_name = dir.get_next()
			continue
		
		var source_path = source.path_join(file_name)
		var dest_path = destination.path_join(file_name)
		
		if dir.current_is_dir():
			if not copy_directory(source_path, dest_path):
				return false
		else:
			if DirAccess.copy_absolute(source_path, dest_path) != OK:
				return false
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	return true


# 删除目录及其所有内容
static func delete_directory(path: String) -> bool:
	var dir = DirAccess.open(path)
	if dir == null:
		return false
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name == "." or file_name == "..":
			file_name = dir.get_next()
			continue
		
		var file_path = path.path_join(file_name)
		
		if dir.current_is_dir():
			if not delete_directory(file_path):
				return false
		else:
			if DirAccess.remove_absolute(file_path) != OK:
				return false
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	
	if DirAccess.remove_absolute(path) != OK:
		return false
	
	return true


# 移动目录
static func move_directory(source: String, destination: String) -> bool:
	if copy_directory(source, destination):
		return delete_directory(source)
	return false


# 创建带时间戳的备份
static func create_backup(source_path: String, backup_dir: String) -> String:
	var timestamp = Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	var backup_name = "backup_" + timestamp
	var backup_path = backup_dir.path_join(backup_name)
	
	if copy_directory(source_path, backup_path):
		return backup_path
	
	return ""


# 检查文件是否存在
static func file_exists(path: String) -> bool:
	if FileAccess.file_exists(path):
		return true
	else:
		return DirAccess.dir_exists_absolute(path)


# 读取JSON文件
static func read_json_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	
	var content = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(content)
	if error != OK:
		return {}
	
	return json.get_data()
