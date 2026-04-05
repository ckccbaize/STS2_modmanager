extends RefCounted
class_name SaveUtils

# 存档管理工具类

# 获取所有Steam账号目录
static func get_all_steam_accounts(base_path: String) -> Array:
	var accounts = []

	if base_path.is_empty():
		print("[get_all_steam_accounts] base_path is empty!")
		return accounts

	print("[get_all_steam_accounts] Scanning: ", base_path)

	var dir = DirAccess.open(base_path)
	if dir == null:
		print("[get_all_steam_accounts] Failed to open dir: ", base_path)
		return accounts

	dir.list_dir_begin()
	var folder_name = dir.get_next()
	while folder_name != "":
		if dir.current_is_dir() and folder_name != "." and folder_name != "..":
			# 检查是否是steamid目录（通常是一串纯数字）
			print("[get_all_steam_accounts] Found folder: ", folder_name, " is_valid_int: ", folder_name.is_valid_int())
			if folder_name.is_valid_int():
				accounts.append({
					"steam_id": folder_name,
					"path": base_path.path_join(folder_name)
				})
		folder_name = dir.get_next()

	dir.list_dir_end()
	print("[get_all_steam_accounts] Found ", accounts.size(), " accounts: ", accounts)
	return accounts


# 获取存档目录
static func get_save_directory(base_path: String, steam_id: String = "") -> String:
	if base_path.is_empty():
		return ""

	# 如果提供了steam_id，使用具体目录
	if not steam_id.is_empty():
		return base_path.path_join(steam_id)

	# 否则尝试自动检测
	var dir = DirAccess.open(base_path)
	if dir == null:
		return ""

	dir.list_dir_begin()
	var folder_name = dir.get_next()
	var first_folder = ""
	while folder_name != "":
		if dir.current_is_dir() and folder_name != "." and folder_name != "..":
			# 检查是否是steamid目录（通常是一串数字）
			if folder_name.is_valid_int():
				return base_path.path_join(folder_name)
			elif first_folder.is_empty():
				first_folder = folder_name
		folder_name = dir.get_next()

	dir.list_dir_end()

	# 如果没有找到steamid目录，返回第一个文件夹
	if not first_folder.is_empty():
		return base_path.path_join(first_folder)

	return ""


# 扫描所有存档（包括所有Steam账号和所有profile）
static func scan_all_saves(save_base_path: String) -> Array:
	var all_saves = []
	print("[scan_all_saves] 输入路径: ", save_base_path)

	if save_base_path.is_empty():
		print("[scan_all_saves] 路径为空，返回空数组")
		return all_saves

	# 检查目录是否存在
	if not DirAccess.dir_exists_absolute(save_base_path):
		print("[scan_all_saves] 目录不存在: ", save_base_path)
		return all_saves

	# 检查是否是特定账号目录还是父目录
	var dir_name = save_base_path.get_file()
	print("[scan_all_saves] 目录名: ", dir_name, " 是否为数字: ", dir_name.is_valid_int())

	# 如果目录名是纯数字(SteamID)，则扫描该特定账号
	if dir_name.is_valid_int():
		var steam_id = dir_name
		var account_path = save_base_path
		print("[scan_all_saves] 扫描特定Steam账号: ", steam_id)

		# 扫描普通存档 (profile1-3)
		for i in range(1, 4):
			var profile_path = account_path.path_join("profile" + str(i))
			print("[scan_all_saves] 检查 profile", i, ": ", profile_path, " 存在: ", DirAccess.dir_exists_absolute(profile_path))
			if DirAccess.dir_exists_absolute(profile_path):
				var save_info = get_profile_save_info(profile_path, steam_id, i, false)
				if not save_info.is_empty():
					all_saves.append(save_info)
					print("[scan_all_saves] 添加普通存档: ", save_info.get("full_name", ""))

		# 扫描模组版存档 (modded/profile1-3)
		var modded_path = account_path.path_join("modded")
		print("[scan_all_saves] 检查 modded: ", modded_path, " 存在: ", DirAccess.dir_exists_absolute(modded_path))
		if DirAccess.dir_exists_absolute(modded_path):
			for i in range(1, 4):
				var profile_path = modded_path.path_join("profile" + str(i))
				if DirAccess.dir_exists_absolute(profile_path):
					var save_info = get_profile_save_info(profile_path, steam_id, i, true)
					if not save_info.is_empty():
						all_saves.append(save_info)
						print("[scan_all_saves] 添加模组存档: ", save_info.get("full_name", ""))

		print("[scan_all_saves] 最终结果: ", all_saves.size(), " 个存档")
		return all_saves

	# 否则，扫描所有Steam账号
	var accounts = get_all_steam_accounts(save_base_path)
	print("[scan_all_saves] 找到账号: ", accounts)

	for account in accounts:
		var steam_id = account["steam_id"]
		var account_path = account["path"]
		print("[scan_all_saves] 扫描账号: ", steam_id)

		# 扫描普通存档 (profile1-3)
		for i in range(1, 4):
			var profile_path = account_path.path_join("profile" + str(i))
			if DirAccess.dir_exists_absolute(profile_path):
				var save_info = get_profile_save_info(profile_path, steam_id, i, false)
				if not save_info.is_empty():
					all_saves.append(save_info)

		# 扫描模组版存档 (modded/profile1-3)
		var modded_path = account_path.path_join("modded")
		if DirAccess.dir_exists_absolute(modded_path):
			for i in range(1, 4):
				var profile_path = modded_path.path_join("profile" + str(i))
				if DirAccess.dir_exists_absolute(profile_path):
					var save_info = get_profile_save_info(profile_path, steam_id, i, true)
					if not save_info.is_empty():
						all_saves.append(save_info)

	print("[scan_all_saves] 总共找到: ", all_saves.size(), " 个存档")
	return all_saves


# 获取单个profile的存档信息
static func get_profile_save_info(profile_path: String, steam_id: String, profile_num: int, is_modded: bool) -> Dictionary:
	var saves_path = profile_path.path_join("saves")

	if not DirAccess.dir_exists_absolute(saves_path):
		return {}

	var info = {
		"steam_id": steam_id,
		"profile": profile_num,
		"is_modded": is_modded,
		"name": "账号%s - 存档%d" % [steam_id.substr(steam_id.length() - 4), profile_num],
		"full_name": "%s - Profile %d%s" % [steam_id, profile_num, " (模组版)" if is_modded else ""],
		"path": profile_path,
		"saves_path": saves_path,
		"type": "modded" if is_modded else "steam",
		"date": get_file_modification_date(saves_path),
		"size": get_directory_size(saves_path),
		"has_current_save": false,
		"characters": [],
		"total_wins": 0,
		"total_losses": 0,
		"play_time": 0,
		"floors_climbed": 0
	}

	# 解析progress.save获取游戏信息
	var progress_path = saves_path.path_join("progress.save")
	if FileAccess.file_exists(progress_path):
		var progress_info = parse_progress_save(progress_path)
		info.merge(progress_info)

	# 检查是否有当前游戏
	info["has_current_save"] = FileAccess.file_exists(saves_path.path_join("current_run.save")) or \
							   FileAccess.file_exists(saves_path.path_join("current_run_mp.save"))

	return info


# 解析progress.save文件获取游戏信息
static func parse_progress_save(progress_path: String) -> Dictionary:
	var info = {
		"characters": [],
		"total_wins": 0,
		"total_losses": 0,
		"play_time": 0,
		"floors_climbed": 0,
		"discovered_cards": 0,
		"discovered_relics": 0
	}

	var file = FileAccess.open(progress_path, FileAccess.READ)
	if file == null:
		return info

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		return info

	var data = json.get_data()
	if typeof(data) != TYPE_DICTIONARY:
		return info

	# 获取总游戏时间
	if data.has("total_playtime"):
		info["play_time"] = data["total_playtime"]

	# 获取爬楼数
	if data.has("floors_climbed"):
		info["floors_climbed"] = data["floors_climbed"]

	# 获取已发现卡牌数量
	if data.has("discovered_cards") and data["discovered_cards"] is Array:
		info["discovered_cards"] = data["discovered_cards"].size()

	# 获取已发现遗物数量
	if data.has("discovered_relics") and data["discovered_relics"] is Array:
		info["discovered_relics"] = data["discovered_relics"].size()

	# 获取各角色统计
	if data.has("ancient_stats") and data["ancient_stats"] is Array:
		var char_stats = {}

		for ancient in data["ancient_stats"]:
			if ancient.has("character_stats"):
				for char_stat in ancient["character_stats"]:
					var char_name = char_stat.get("character", "UNKNOWN")
					var wins = char_stat.get("wins", 0)
					var losses = char_stat.get("losses", 0)

					if not char_stats.has(char_name):
						char_stats[char_name] = {"wins": 0, "losses": 0}

					char_stats[char_name]["wins"] += wins
					char_stats[char_name]["losses"] += losses

		# 转换为数组并计算总胜败
		for char_name in char_stats:
			info["characters"].append({
				"name": char_name,
				"wins": char_stats[char_name]["wins"],
				"losses": char_stats[char_name]["losses"]
			})
			info["total_wins"] += char_stats[char_name]["wins"]
			info["total_losses"] += char_stats[char_name]["losses"]

	return info


# 获取模组版存档目录
static func get_modded_save_directory(save_dir: String) -> String:
	return save_dir.path_join("modded")


# 扫描存档
static func scan_saves(save_dir: String) -> Array:
	var saves = []
	print("[scan_saves] Scanning directory: ", save_dir)

	if save_dir.is_empty():
		print("[scan_saves] save_dir is empty!")
		return saves

	var dir = DirAccess.open(save_dir)
	if dir == null:
		print("[scan_saves] Cannot open directory!")
		return saves

	# 扫描所有子目录（SteamID目录）
	dir.list_dir_begin()
	var folder_name = dir.get_next()
	while folder_name != "":
		if dir.current_is_dir():
			var subdir_path = save_dir.path_join(folder_name)
			print("[scan_saves] Found folder: ", folder_name)

			# 检查是否是有效的存档目录（包含profile1-3）
			var profiles = []
			var modded_profiles = []
			var latest_date = ""
			var latest_modded_date = ""
			var latest_time = 0
			var latest_modded_time = 0
			var total_size = 0

			var subdir = DirAccess.open(subdir_path)
			if subdir != null:
				subdir.list_dir_begin()
				var subfolder = subdir.get_next()
				while subfolder != "":
					if subdir.current_is_dir() and subfolder.begins_with("profile"):
						# 提取profile后的数字
						var profile_num_str = subfolder.replace("profile", "")
						var profile_num = profile_num_str.to_int()
						if profile_num > 0:
							profiles.append(profile_num)
							print("[scan_saves] Found profile: ", profile_num)
						var saves_path = subdir_path.path_join(subfolder).path_join("saves")
						if DirAccess.dir_exists_absolute(saves_path):
							var mod_time = get_latest_file_time(saves_path)
							if mod_time > latest_time:
								latest_time = mod_time
								latest_date = get_file_modification_date(saves_path)
							total_size += get_directory_size_bytes(saves_path)
					subfolder = subdir.get_next()
				subdir.list_dir_end()

			# 检查modded文件夹
			var modded_path = subdir_path.path_join("modded")
			if DirAccess.dir_exists_absolute(modded_path):
				var modded_dir = DirAccess.open(modded_path)
				if modded_dir != null:
					modded_dir.list_dir_begin()
					var modfolder = modded_dir.get_next()
					while modfolder != "":
						if modded_dir.current_is_dir() and modfolder.begins_with("profile"):
							var profile_num_str = modfolder.replace("profile", "")
							var profile_num = profile_num_str.to_int()
							if profile_num > 0:
								modded_profiles.append(profile_num)
								print("[scan_saves] Found modded profile: ", profile_num)
							var saves_path = modded_path.path_join(modfolder).path_join("saves")
							if DirAccess.dir_exists_absolute(saves_path):
								var mod_time = get_latest_file_time(saves_path)
								if mod_time > latest_modded_time:
									latest_modded_time = mod_time
									latest_modded_date = get_file_modification_date(saves_path)
						modfolder = modded_dir.get_next()
					modded_dir.list_dir_end()

			print("[scan_saves] Profiles for ", folder_name, ": ", profiles, " modded: ", modded_profiles)
			if profiles.size() > 0 or modded_profiles.size() > 0:
				var save_info = {
					"name": folder_name,
					"path": subdir_path,
					"type": "imported",
					"date": latest_date,
					"size": str(total_size / 1024) + " KB",
					"size_kb": total_size / 1024,
					"profiles": profiles,
					"modded_profiles": modded_profiles,
					"latest_date": latest_date,
					"latest_modded_date": latest_modded_date,
					"has_modded": modded_profiles.size() > 0
				}
				save_info["is_imported"] = true  # 标记为导入存档
				saves.append(save_info)
				print("[scan_saves] Added save: ", folder_name)
		folder_name = dir.get_next()

	dir.list_dir_end()
	print("[scan_saves] Total saves found: ", saves.size())
	return saves


# 获取存档信息
static func get_save_info(save_path: String, name: String, save_type: String) -> Dictionary:
	var info = {
		"name": name,
		"path": save_path,
		"type": save_type,
		"date": get_file_modification_date(save_path),
		"size": get_directory_size(save_path)
	}
	# 如果是导入的存档，标记 is_imported
	if save_type == "imported":
		info["is_imported"] = true
	return info


# 获取文件修改日期
static func get_file_modification_date(path: String) -> String:
	var file = FileAccess.open(path, FileAccess.READ)
	if file != null:
		var modified_time = file.get_modified_time(path)
		file.close()
		var datetime = Time.get_datetime_dict_from_unix_time(modified_time)
		return "%d-%02d-%02d %02d:%02d" % [
			datetime["year"], datetime["month"], datetime["day"],
			datetime["hour"], datetime["minute"]
		]
	
	# 如果是目录，尝试获取目录内最新文件的日期
	var dir = DirAccess.open(path)
	if dir != null:
		var latest_time = 0
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			var file_path = path.path_join(file_name)
			var file_check = FileAccess.open(file_path, FileAccess.READ)
			if file_check != null:
				var file_time = file_check.get_modified_time(file_path)
				if file_time > latest_time:
					latest_time = file_time
				file_check.close()
			file_name = dir.get_next()
		
		dir.list_dir_end()
		
		if latest_time > 0:
			var datetime = Time.get_datetime_dict_from_unix_time(latest_time)
			return "%d-%02d-%02d %02d:%02d" % [
				datetime["year"], datetime["month"], datetime["day"],
				datetime["hour"], datetime["minute"]
			]
	
	return "Unknown Date"


# 获取目录大小（字节）
static func get_directory_size_bytes(path: String) -> int:
	var total_size = 0

	var dir = DirAccess.open(path)
	if dir == null:
		return 0

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		var file_path = path.path_join(file_name)
		if dir.current_is_dir():
			total_size += get_directory_size_bytes(file_path)
		else:
			var file = FileAccess.open(file_path, FileAccess.READ)
			if file != null:
				total_size += file.get_length()
				file.close()
		file_name = dir.get_next()

	dir.list_dir_end()
	return total_size


# 获取目录大小
static func get_directory_size(path: String) -> String:
	var total_size = 0
	
	var dir = DirAccess.open(path)
	if dir == null:
		return "0 KB"
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		var file_path = path.path_join(file_name)
		if dir.current_is_dir():
			# 递归计算子目录大小
			var subdir_size_str = get_directory_size(file_path)
			# 简单处理，这里可以改进
			pass
		else:
			var file = FileAccess.open(file_path, FileAccess.READ)
			if file != null:
				total_size += file.get_length()
				file.close()
		file_name = dir.get_next()
	
	dir.list_dir_end()
	
	# 格式化大小
	if total_size < 1024:
		return "%d B" % total_size
	elif total_size < 1024 * 1024:
		return "%.1f KB" % (total_size / 1024.0)
	else:
		return "%.1f MB" % (total_size / (1024.0 * 1024.0))


# 复制存档
static func copy_save(source_path: String, dest_path: String, create_backup: bool = true) -> Dictionary:
	var result = {"success": false, "message": "", "backup_path": ""}
	
	if not DirAccess.dir_exists_absolute(source_path):
		result["message"] = "Source save does not exist"
		return result
	
	# 创建备份
	if create_backup and DirAccess.dir_exists_absolute(dest_path):
		var backup_dir = dest_path.get_base_dir().path_join("backups")
		var backup_result = create_backup(dest_path, backup_dir)
		if not backup_result.is_empty():
			result["backup_path"] = backup_result
	
	# 复制存档
	if copy_directory(source_path, dest_path):
		result["success"] = true
		result["message"] = "Save copied successfully"
	else:
		result["message"] = "Failed to copy save"
	
	return result


# 辅助函数：转换Godot路径为Windows路径
static func to_windows_path(godot_path: String) -> String:
	# 将 forward slash 转换为 backslash
	return godot_path.replace("/", "\\")


# 导入存档
# 使用 PowerShell 进行解压
static func import_save(zip_path: String, save_dir: String, save_name: String) -> Dictionary:
	var result = {"success": false, "message": "", "save_info": {}}

	# 检查ZIP文件是否存在
	if not FileAccess.file_exists(zip_path):
		result["message"] = "ZIP文件不存在"
		return result

	# 确保目标目录存在
	var dir = DirAccess.open(save_dir)
	if dir == null:
		var create_result = DirAccess.make_dir_recursive_absolute(save_dir)
		if create_result != OK:
			result["message"] = "无法创建存档目录"
			return result

	# 先解压到一个临时目录来验证内容
	var temp_extract_path = save_dir.path_join("_temp_" + save_name)
	if DirAccess.dir_exists_absolute(temp_extract_path):
		delete_directory(temp_extract_path)

	# 创建临时解压目录
	DirAccess.make_dir_recursive_absolute(temp_extract_path)

	# 使用PowerShell解压ZIP文件 - 转换为Windows路径
	var zip_path_win = to_windows_path(ProjectSettings.globalize_path(zip_path))
	var temp_extract_win = to_windows_path(ProjectSettings.globalize_path(temp_extract_path))
	var ps_command = 'Expand-Archive -Path "%s" -DestinationPath "%s" -Force' % [zip_path_win, temp_extract_win]
	print("[import_save] Command: ", ps_command)
	var output = []
	var exit_code = OS.execute("powershell", ["-Command", ps_command], output)

	print("[import_save] Exit code: ", exit_code)
	print("[import_save] Output: ", output)

	if exit_code != 0:
		result["message"] = "无法解压ZIP文件: " + str(output)
		delete_directory(temp_extract_path)
		return result

	# 检查解压后的目录结构
	var first_level_items = []
	var temp_dir = DirAccess.open(temp_extract_path)
	if temp_dir != null:
		temp_dir.list_dir_begin()
		var item = temp_dir.get_next()
		while item != "":
			if item.begins_with("_") == false:  # 跳过临时文件夹
				first_level_items.append(item)
			item = temp_dir.get_next()
		temp_dir.list_dir_end()

	print("[import_save] First level items: ", first_level_items)

	# 使用ZIP文件名作为目标存档名
	var target_folder_name = save_name

	# 目标路径
	var target_path = save_dir.path_join(target_folder_name)

	# 如果目标目录已存在，先删除
	if DirAccess.dir_exists_absolute(target_path):
		delete_directory(target_path)

	# 创建目标目录
	DirAccess.make_dir_recursive_absolute(target_path)

	# 如果只有一个文件夹且里面有profile1，说明是Steam存档的双层结构
	# 需要把内层的内容提取出来
	if first_level_items.size() == 1:
		var first_folder = first_level_items[0]
		var first_folder_path = temp_extract_path.path_join(first_folder)

		# 检查内层是否有profile1
		if DirAccess.dir_exists_absolute(first_folder_path.path_join("profile1")):
			# 双层结构！把内层内容复制到目标位置
			var inner_dir = DirAccess.open(first_folder_path)
			if inner_dir != null:
				inner_dir.list_dir_begin()
				var item = inner_dir.get_next()
				while item != "":
					var src = first_folder_path.path_join(item)
					var dst = target_path.path_join(item)

					if inner_dir.current_is_dir():
						copy_directory(src, dst)
					else:
						copy_file(src, dst)

					item = inner_dir.get_next()
				inner_dir.list_dir_end()
				print("[import_save] Using inner folder content for double-layer structure")
		else:
			# 不是双层，直接复制
			for item in first_level_items:
				var src = temp_extract_path.path_join(item)
				var dst = target_path.path_join(item)
				if DirAccess.dir_exists_absolute(src):
					copy_directory(src, dst)
				else:
					copy_file(src, dst)
	else:
		# 多个文件夹或文件，直接复制
		for item in first_level_items:
			var src = temp_extract_path.path_join(item)
			var dst = target_path.path_join(item)
			if DirAccess.dir_exists_absolute(src):
				copy_directory(src, dst)
			else:
				copy_file(src, dst)

	print("[import_save] Imported to: ", target_path)

	# 删除临时解压目录
	delete_directory(temp_extract_path)

	result["success"] = true
	result["message"] = "存档导入成功"
	result["save_info"] = get_save_info(target_path, target_folder_name, "imported")

	return result


# 获取有效的存档文件夹
static func _get_valid_save_folder(extract_path: String) -> String:
	var temp_dir = DirAccess.open(extract_path)
	if temp_dir == null:
		return ""

	var first_level_folders = []
	temp_dir.list_dir_begin()
	var folder = temp_dir.get_next()
	while folder != "":
		if temp_dir.current_is_dir():
			first_level_folders.append(folder)
		folder = temp_dir.get_next()
	temp_dir.list_dir_end()

	print("[_get_valid_save_folder] first_level_folders: ", first_level_folders)

	# 如果只有一个文件夹，检查是否需要再深入一层
	if first_level_folders.size() == 1:
		var single_folder = first_level_folders[0]
		var inner_path = extract_path.path_join(single_folder)

		# 检查内层是否有 SteamID 同名文件夹（重复嵌套）
		var inner_dir = DirAccess.open(inner_path)
		if inner_dir != null:
			var has_inner_same_name = false
			inner_dir.list_dir_begin()
			var inner_folder = inner_dir.get_next()
			while inner_folder != "":
				if inner_dir.current_is_dir() and inner_folder == single_folder:
					has_inner_same_name = true
					break
				inner_folder = inner_dir.get_next()
			inner_dir.list_dir_end()

			if has_inner_same_name:
				var deeper_path = inner_path.path_join(single_folder)
				if DirAccess.dir_exists_absolute(deeper_path.path_join("profile1")):
					return deeper_path

		# 如果内层有profile1，返回当前层
		if DirAccess.dir_exists_absolute(inner_path.path_join("profile1")):
			return inner_path
		if FileAccess.file_exists(inner_path.path_join("profile.save")):
			return inner_path

	# 查找包含profile1的文件夹（优先返回非modded的）
	for f in first_level_folders:
		# 跳过modded，让原版优先
		if f == "modded":
			continue
		var test_path = extract_path.path_join(f)
		if DirAccess.dir_exists_absolute(test_path.path_join("profile1")):
			return test_path
		if FileAccess.file_exists(test_path.path_join("profile.save")):
			return test_path

	# 如果没找到原版，查找modded
	for f in first_level_folders:
		if f == "modded":
			var test_path = extract_path.path_join(f)
			if DirAccess.dir_exists_absolute(test_path.path_join("profile1")):
				return test_path
			if FileAccess.file_exists(test_path.path_join("profile.save")):
				return test_path

	# 如果还没找到，返回第一个文件夹
	if first_level_folders.size() > 0:
		return extract_path.path_join(first_level_folders[0])

	return ""



# 导出存档
# 使用 PowerShell 进行压缩（Windows平台）
static func export_save(save_path: String, export_path: String) -> Dictionary:
	var result = {"success": false, "message": ""}

	# 检查存档目录是否存在
	if not DirAccess.dir_exists_absolute(save_path):
		result["message"] = "存档目录不存在"
		return result

	# 确保导出路径以 .zip 结尾
	if not export_path.to_lower().ends_with(".zip"):
		export_path += ".zip"

	# 使用PowerShell压缩为ZIP文件
	# 先删除已存在的文件
	if FileAccess.file_exists(export_path):
		DirAccess.remove_absolute(export_path)

	var ps_command = 'Compress-Archive -Path "%s\\*" -DestinationPath "%s" -Force' % [save_path, export_path]
	var output = []
	var exit_code = OS.execute("powershell", ["-Command", ps_command], output)

	if exit_code != 0:
		result["message"] = "无法创建ZIP文件"
		return result

	result["success"] = true
	result["message"] = "存档导出成功"
	return result


# 创建存档ZIP备份
static func create_save_zip(save_path: String, zip_path: String) -> bool:
	# 检查存档目录是否存在
	if not DirAccess.dir_exists_absolute(save_path):
		print("[create_save_zip] Save path does not exist: ", save_path)
		return false

	# 确保ZIP路径以.zip结尾
	if not zip_path.to_lower().ends_with(".zip"):
		zip_path += ".zip"

	# 删除已存在的文件
	if FileAccess.file_exists(zip_path):
		DirAccess.remove_absolute(zip_path)

	# 使用PowerShell压缩为ZIP文件
	var ps_command = 'Compress-Archive -Path "%s\\*" -DestinationPath "%s" -Force' % [save_path, zip_path]
	var output = []
	var exit_code = OS.execute("powershell", ["-Command", ps_command], output)

	if exit_code != 0:
		print("[create_save_zip] Failed to create ZIP: ", output)
		return false

	print("[create_save_zip] Created backup: ", zip_path)
	return true


# 创建备份
# is_auto: true = 自动备份, false = 手动备份
static func create_backup(source_path: String, backup_dir: String, steam_id: String = "", is_auto: bool = true) -> String:
	print("[create_backup] source_path: ", source_path)
	print("[create_backup] backup_dir: ", backup_dir)
	print("[create_backup] steam_id: ", steam_id)
	print("[create_backup] is_auto: ", is_auto)

	var timestamp = Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	# 如果提供了steam_id，使用包含steam_id的命名格式
	# 区分自动备份(auto)和手动备份(manual)
	var backup_type = "auto" if is_auto else "manual"
	var backup_name = "backup_" + timestamp
	if not steam_id.is_empty():
		backup_name = "steam_" + steam_id + "_" + backup_type + "_" + timestamp
	else:
		backup_name = backup_type + "_" + timestamp
	var backup_path = backup_dir.path_join(backup_name)

	print("[create_backup] backup_path: ", backup_path)

	# 创建备份目录
	var dir = DirAccess.open(backup_dir)
	if dir == null:
		var result = DirAccess.make_dir_recursive_absolute(backup_dir)
		print("[create_backup] mkdir result: ", result)
		if result != OK:
			return ""

	print("[create_backup] source exists: ", DirAccess.dir_exists_absolute(source_path))
	print("[create_backup] About to copy_directory...")

	# 使用本地copy_directory
	if copy_directory(source_path, backup_path):
		print("[create_backup] SUCCESS!")
		return backup_path

	print("[create_backup] FAILED!")
	return ""


# 恢复备份
static func restore_backup(backup_path: String, target_path: String) -> bool:
	if not DirAccess.dir_exists_absolute(backup_path):
		return false

	return copy_directory(backup_path, target_path)


# 覆盖存档（将源存档复制到目标目录）
static func overwrite_save(source_path: String, target_dir: String) -> Dictionary:
	var result = {"success": false, "message": ""}

	# 检查源存档是否存在
	if not DirAccess.dir_exists_absolute(source_path):
		result["message"] = "源存档不存在"
		return result

	# 确保目标目录存在
	if not DirAccess.dir_exists_absolute(target_dir):
		result["message"] = "目标存档目录不存在"
		return result

	# 获取目标目录下的所有profile文件夹
	var target_profiles = []
	var dir = DirAccess.open(target_dir)
	if dir != null:
		dir.list_dir_begin()
		var folder_name = dir.get_next()
		while folder_name != "":
			if dir.current_is_dir() and folder_name.begins_with("profile"):
				target_profiles.append(folder_name)
			folder_name = dir.get_next()
		dir.list_dir_end()

	# 删除目标目录下的所有profile文件夹
	for profile in target_profiles:
		var profile_path = target_dir.path_join(profile)
		if not delete_directory(profile_path):
			result["message"] = "无法清理目标存档"
			return result

	# 复制源存档到目标目录
	if copy_directory(source_path, target_dir):
		result["success"] = true
		result["message"] = "存档覆盖成功"
	else:
		result["message"] = "存档复制失败"

	return result


# 定向覆盖profile目录（不覆盖profile.save等全局文件）
# direction: "modded_to_vanilla" = modded profile → vanilla profile
#            "vanilla_to_modded" = vanilla profile → modded profile
#            "imported_to_vanilla" = imported vanilla → target vanilla
#            "imported_to_modded" = imported vanilla → target modded
#            "imported_modded_to_vanilla" = imported modded → target vanilla
static func overwrite_profiles(source_base: String, target_base: String, direction: String) -> Dictionary:
	var result = {"success": false, "message": ""}

	var source_subpath = ""
	var target_subpath = ""

	match direction:
		"modded_to_vanilla":
			source_subpath = "modded"
			target_subpath = ""
		"vanilla_to_modded":
			source_subpath = ""
			target_subpath = "modded"
		"imported_to_vanilla":
			source_subpath = ""
			target_subpath = ""
		"imported_to_modded":
			source_subpath = ""
			target_subpath = "modded"
		"imported_modded_to_vanilla":
			source_subpath = "modded"
			target_subpath = ""
		"imported_modded_to_modded":
			source_subpath = "modded"
			target_subpath = "modded"
		_:
			result["message"] = "未知的覆盖方向"
			return result

	var source_root = source_base.path_join(source_subpath) if not source_subpath.is_empty() else source_base
	var target_root = target_base.path_join(target_subpath) if not target_subpath.is_empty() else target_base

	if not DirAccess.dir_exists_absolute(source_root):
		result["message"] = "源存档不存在: " + source_root
		return result

	if not DirAccess.dir_exists_absolute(target_root):
		result["message"] = "目标存档目录不存在: " + target_root
		return result

	# 覆盖 profile1, profile2, profile3
	for profile_num in range(1, 4):
		var source_profile = source_root.path_join("profile" + str(profile_num))
		var target_profile = target_root.path_join("profile" + str(profile_num))

		if not DirAccess.dir_exists_absolute(source_profile):
			continue

		if DirAccess.dir_exists_absolute(target_profile):
			if not delete_directory(target_profile):
				result["message"] = "无法清理目标profile" + str(profile_num)
				return result

		if not copy_directory(source_profile, target_profile):
			result["message"] = "复制profile" + str(profile_num) + "失败"
			return result

	result["success"] = true
	result["message"] = "覆盖成功"
	return result


# 复制单个文件
static func copy_file(source: String, destination: String) -> bool:
	# 确保目标目录存在
	var dest_dir = DirAccess.open(destination.get_base_dir())
	if dest_dir == null:
		var result = DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
		if result != OK:
			return false

	# 复制文件
	if DirAccess.copy_absolute(source, destination) != OK:
		return false

	return true


# 复制目录（从file_utils复制）
static func copy_directory(source: String, destination: String) -> bool:
	var dir = DirAccess.open(source)
	if dir == null:
		return false

	# 创建目标目录
	var dest_parent = destination.get_base_dir()
	if not DirAccess.dir_exists_absolute(dest_parent):
		if DirAccess.make_dir_recursive_absolute(dest_parent) != OK:
			return false

	if DirAccess.dir_exists_absolute(destination):
		if not delete_directory(destination):
			return false

	if not DirAccess.dir_exists_absolute(destination):
		if DirAccess.make_dir_recursive_absolute(destination) != OK:
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


# 删除目录（递归删除内容，最后删除目录本身）
static func delete_directory(path: String) -> bool:
	if not DirAccess.dir_exists_absolute(path):
		return true
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


# 扫描所有存档，按账号分组
static func scan_all_saves_grouped(save_base_path: String) -> Dictionary:
	# 返回结构: {
	#   "steam": { steam_id: { "name": "xxx", "path": "xxx", "profiles": [1,2,3], "latest_date": "xxx", "has_modded": true/false } },
	#   "modded": { steam_id: { ... } }
	# }
	var grouped = {
		"steam": {},   # 原版存档
		"modded": {}   # 模组版存档
	}

	if save_base_path.is_empty() or not DirAccess.dir_exists_absolute(save_base_path):
		return grouped

	var accounts = get_all_steam_accounts(save_base_path)

	for account in accounts:
		var steam_id = account["steam_id"]
		var account_path = account["path"]

		# 扫描原版存档 profile1-3
		var steam_profiles = []
		var steam_latest_date = ""
		var steam_latest_time = 0

		for i in range(1, 4):
			var profile_path = account_path.path_join("profile" + str(i))
			if DirAccess.dir_exists_absolute(profile_path):
				steam_profiles.append(i)
				var saves_path = profile_path.path_join("saves")
				if DirAccess.dir_exists_absolute(saves_path):
					var mod_time = get_latest_file_time(saves_path)
					if mod_time > steam_latest_time:
						steam_latest_time = mod_time
						steam_latest_date = get_file_modification_date(saves_path)

		if steam_profiles.size() > 0:
			grouped["steam"][steam_id] = {
				"steam_id": steam_id,
				"name": "账号%s" % steam_id.substr(steam_id.length() - 4),
				"path": account_path,
				"profiles": steam_profiles,
				"latest_date": steam_latest_date,
				"has_modded": false
			}

		# 扫描模组版存档 modded/profile1-3
		var modded_path = account_path.path_join("modded")
		if DirAccess.dir_exists_absolute(modded_path):
			var modded_profiles = []
			var modded_latest_date = ""
			var modded_latest_time = 0

			for i in range(1, 4):
				var profile_path = modded_path.path_join("profile" + str(i))
				if DirAccess.dir_exists_absolute(profile_path):
					modded_profiles.append(i)
					var saves_path = profile_path.path_join("saves")
					if DirAccess.dir_exists_absolute(saves_path):
						var mod_time = get_latest_file_time(saves_path)
						if mod_time > modded_latest_time:
							modded_latest_time = mod_time
							modded_latest_date = get_file_modification_date(saves_path)

			if modded_profiles.size() > 0:
				# 标记原版有模组版
				if grouped["steam"].has(steam_id):
					grouped["steam"][steam_id]["has_modded"] = true

				grouped["modded"][steam_id] = {
					"steam_id": steam_id,
					"name": "账号%s (模组版)" % steam_id.substr(steam_id.length() - 4),
					"path": modded_path,
					"profiles": modded_profiles,
					"latest_date": modded_latest_date
				}

	return grouped


# 获取目录中最新文件的时间戳
static func get_latest_file_time(dir_path: String) -> int:
	var latest_time = 0
	var dir = DirAccess.open(dir_path)
	if dir == null:
		return latest_time

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			var file_path = dir_path.path_join(file_name)
			var file = FileAccess.open(file_path, FileAccess.READ)
			if file != null:
				var mod_time = file.get_modified_time(file_path)
				if mod_time > latest_time:
					latest_time = mod_time
				file.close()
		file_name = dir.get_next()

	dir.list_dir_end()
	return latest_time
