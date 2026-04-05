extends RefCounted
class_name NexusAPI

const BASE_URL = "https://api.nexusmods.com/v1"
const API_VERSION = "1.17.0"
const APP_NAME = "STS2-ModManager"
const APP_VERSION = "1.0.0"

var GAME_DOMAIN = "slaythespire2"
var _game_domain_verified: bool = false  # 标记游戏域名是否已验证
const RATE_LIMIT_PER_SECOND = 30  # 提升到 30 req/s 以加速扫描

var api_key: String = ""
var cache_dir: String = ""
var downloads_dir: String = ""
var _last_request_time: int = 0
var _tree: SceneTree = null

# 客户端分页缓存
var _cached_mods_list: Array = []
var _cached_sort_type: String = ""
# ALL 筛选器专用缓存
var _all_filter_cached_mods: Array = []
var _all_filter_sort_type: String = ""
# ALL 筛选器扫描结果缓存（用于加速重访）
var _all_scanned_mods_cache: Array = []
var _all_max_mod_id_cached: int = 0

signal request_completed(success: bool, data: Variant, error: String)
signal download_progress(bytes_downloaded: int, total_bytes: int)
signal download_completed(success: bool, file_path: String, error: String)
signal binary_search_progress(current_attempt: int, total_attempts: int, current_range: String)

# 获取应用基础路径（编辑器中为res://，导出后为exe所在目录）
func get_base_path() -> String:
	if OS.has_feature("editor"):
		return "res://"
	else:
		return OS.get_executable_path().get_base_dir() + "/"

func _init() -> void:
	# 使用基础路径作为缓存目录
	cache_dir = get_base_path() + "nexus_images_cache"
	if not DirAccess.dir_exists_absolute(cache_dir):
		DirAccess.make_dir_recursive_absolute(cache_dir)
	# 创建下载目录
	downloads_dir = get_base_path() + "downloads"
	if not DirAccess.dir_exists_absolute(downloads_dir):
		DirAccess.make_dir_recursive_absolute(downloads_dir)
	_tree = Engine.get_main_loop() as SceneTree


func _debug_log(msg: String) -> void:
	print(msg)


func get_cached_mods_count() -> int:
	return _cached_mods_list.size()


func set_api_key(key: String) -> void:
	print("[NexusAPI] set_api_key called with key: " + key.substr(0, 10) + "...")
	api_key = key


func validate_api_key() -> Dictionary:
	var test_result = await _request("GET", "/games")
	if test_result.success:
		# 直接使用已获取的游戏列表来查找域名，避免重复请求
		await _find_correct_game_domain_with_games(test_result.data)

	var result = await _request("GET", "/users/validate")
	if result.success and typeof(result.data) == TYPE_DICTIONARY:
		return {
			"success": true,
			"user_id": result.data.get("user_id", 0),
			"username": result.data.get("name", ""),
			"is_premium": result.data.get("is_premium?", false),
			"is_supporter": result.data.get("is_supporter?", false)
		}
	else:
		return {"success": false, "error": result.error}


func _find_correct_game_domain() -> void:
	# 如果已经验证过，直接返回
	if _game_domain_verified:
		return

	print("[NexusAPI] _find_correct_game_domain() called")
	var games_result = await get_games()
	_find_correct_game_domain_with_games(games_result.get("games", []) if games_result.success else [])


func _find_correct_game_domain_with_games(games: Array) -> void:
	# 如果已经验证过，直接返回
	if _game_domain_verified:
		return

	if games.is_empty():
		print("[NexusAPI] No games data provided")
		return

	print("[NexusAPI] Processing ", games.size(), " games for domain match")

	# 精确匹配 Slay the Spire 2
	for game in games:
		var name = game.get("name", "").to_lower()
		var domain = game.get("domain_name", "")
		if name == "slay the spire ii":
			print("[NexusAPI] Found exact match: " + game.get("name", "") + " => domain: " + domain)
			GAME_DOMAIN = domain
			_game_domain_verified = true
			return

	# 如果没找到 Slay the Spire 2，尝试使用 slaythespire (第一版)
	print("[NexusAPI] Slay the Spire 2 not found, trying original Slay the Spire")
	for game in games:
		var name = game.get("name", "").to_lower()
		var domain = game.get("domain_name", "")
		if name == "slay the spire":
			print("[NexusAPI] Using original Slay the Spire: " + game.get("name", "") + " => domain: " + domain)
			GAME_DOMAIN = domain
			_game_domain_verified = true
			return


func get_games() -> Dictionary:
	var result = await _request("GET", "/games")
	if result.success:
		return {"success": true, "games": result.data}
	else:
		return {"success": false, "error": result.error}


func find_game_by_name(game_name: String) -> Dictionary:
	var result = await get_games()
	if result.success:
		var games = result.get("games", [])
		for game in games:
			var name = game.get("name", "").to_lower()
			var domain = game.get("domain_name", "").to_lower()
			var search_name = game_name.to_lower()
			if name == search_name or domain == search_name or search_name in name:
				return {
					"success": true,
					"domain_name": game.get("domain_name", ""),
					"name": game.get("name", ""),
					"id": game.get("id", 0)
				}
		return {"success": false, "error": "Game not found: " + game_name}
	else:
		return result


func search_mods(query: String, page: int = 1, page_size: int = 20, sort_by: String = "downloads") -> Dictionary:
	# 尝试不同的搜索策略
	_debug_log("[NexusAPI search_mods] query='%s', page=%d, page_size=%d" % [query, page, page_size])

	if query.is_empty():
		# 空搜索: 使用 latest_added 端点
		return await get_latest_added(page_size, page)
	else:
		# 有搜索词：尝试多种端点格式

		# 格式1: /games/{domain}/mods?search={query}
		var endpoint1 = "/games/%s/mods?search=%s" % [GAME_DOMAIN, query.uri_encode()]
		_debug_log("[NexusAPI] Trying endpoint1: " + endpoint1)
		var result1 = await _request("GET", endpoint1)
		if result1.success:
			var response_data = result1.data
			var mods: Array = []
			if typeof(response_data) == TYPE_DICTIONARY:
				mods = response_data.get("mods", response_data.get("mod", []))
				if mods.is_empty():
					mods = response_data.get("items", [])
			elif typeof(response_data) == TYPE_ARRAY:
				mods = response_data
			_debug_log("[NexusAPI] Search endpoint1 returned " + str(mods.size()) + " mods, data type=" + str(typeof(response_data)))
			return {"success": true, "mods": mods, "page": page, "page_size": page_size, "has_more": mods.size() >= page_size, "total": -1}

		# 格式2: /games/{domain}/mods/browse?search={query}
		var endpoint2 = "/games/%s/mods/browse?search=%s" % [GAME_DOMAIN, query.uri_encode()]
		_debug_log("[NexusAPI] Trying endpoint2: " + endpoint2)
		var result2 = await _request("GET", endpoint2)
		if result2.success:
			var response_data = result2.data
			var mods: Array = []
			if typeof(response_data) == TYPE_DICTIONARY:
				mods = response_data.get("mods", response_data.get("mod", []))
			elif typeof(response_data) == TYPE_ARRAY:
				mods = response_data
			_debug_log("[NexusAPI] Search endpoint2 returned " + str(mods.size()) + " mods")
			return {"success": true, "mods": mods, "page": page, "page_size": page_size, "has_more": mods.size() >= page_size, "total": -1}

		# 格式3: /games/{domain}/mods/search?q={query}
		var endpoint3 = "/games/%s/mods/search?q=%s" % [GAME_DOMAIN, query.uri_encode()]
		_debug_log("[NexusAPI] Trying endpoint3: " + endpoint3)
		var result3 = await _request("GET", endpoint3)
		if result3.success:
			var response_data = result3.data
			var mods: Array = []
			if typeof(response_data) == TYPE_DICTIONARY:
				mods = response_data.get("mods", response_data.get("mod", []))
			elif typeof(response_data) == TYPE_ARRAY:
				mods = response_data
			_debug_log("[NexusAPI] Search endpoint3 returned " + str(mods.size()) + " mods")
			return {"success": true, "mods": mods, "page": page, "page_size": page_size, "has_more": mods.size() >= page_size, "total": -1}

		# 格式4: /games/{domain}/mod_search?search={query}
		var endpoint4 = "/games/%s/mod_search?search=%s" % [GAME_DOMAIN, query.uri_encode()]
		_debug_log("[NexusAPI] Trying endpoint4: " + endpoint4)
		var result4 = await _request("GET", endpoint4)
		if result4.success:
			var response_data = result4.data
			var mods: Array = []
			if typeof(response_data) == TYPE_DICTIONARY:
				mods = response_data.get("mods", response_data.get("mod", []))
			elif typeof(response_data) == TYPE_ARRAY:
				mods = response_data
			_debug_log("[NexusAPI] Search endpoint4 returned " + str(mods.size()) + " mods")
			return {"success": true, "mods": mods, "page": page, "page_size": page_size, "has_more": mods.size() >= page_size, "total": -1}

		# 格式5: /games/{domain}/mods?q={query}
		var endpoint5 = "/games/%s/mods?q=%s" % [GAME_DOMAIN, query.uri_encode()]
		_debug_log("[NexusAPI] Trying endpoint5: " + endpoint5)
		var result5 = await _request("GET", endpoint5)
		if result5.success:
			var response_data = result5.data
			var mods: Array = []
			if typeof(response_data) == TYPE_DICTIONARY:
				mods = response_data.get("mods", response_data.get("mod", []))
			elif typeof(response_data) == TYPE_ARRAY:
				mods = response_data
			_debug_log("[NexusAPI] Search endpoint5 returned " + str(mods.size()) + " mods")
			return {"success": true, "mods": mods, "page": page, "page_size": page_size, "has_more": mods.size() >= page_size, "total": -1}

		# 所有端点都失败 - 搜索功能可能不可用
		_debug_log("[NexusAPI] All search endpoints failed for game: " + GAME_DOMAIN)
		_debug_log("[NexusAPI] Note: Slay the Spire 2 may not support API search. Use trending/latest endpoints instead.")
		return {"success": false, "error": "Search not available for this game. Try trending or latest filters."}


# 获取热门模组（直接使用 trending 端点）
func get_trending_mods(limit: int = 20, page: int = 1) -> Dictionary:
	# 直接使用 /trending 端点
	if _cached_mods_list.is_empty() or _cached_sort_type != "trending":
		_debug_log("[get_trending_mods] Fetching from trending endpoint...")

		var endpoint = "/games/%s/mods/trending?limit=25" % [GAME_DOMAIN]
		var result = await _request("GET", endpoint)
		if result.success:
			_cached_mods_list = result.data if typeof(result.data) == TYPE_ARRAY else []
			_cached_sort_type = "trending"
			_debug_log("[get_trending_mods] Got " + str(_cached_mods_list.size()) + " mods")
		else:
			_debug_log("[get_trending_mods] Failed: " + result.error)
			_cached_mods_list = []
			return {"success": false, "error": result.error}

	# 从缓存分页
	var start_idx = (page - 1) * limit
	var end_idx = min(start_idx + limit, _cached_mods_list.size())
	if start_idx >= _cached_mods_list.size():
		return {"success": true, "mods": [], "page": page, "page_size": limit, "has_more": false, "total": _cached_mods_list.size()}
	var paginated_mods = _cached_mods_list.slice(start_idx, end_idx)
	var has_more = end_idx < _cached_mods_list.size()
	_debug_log("[get_trending_mods] page=%d, start=%d, end=%d, total=%d, has_more=%s" % [page, start_idx, end_idx, _cached_mods_list.size(), str(has_more)])
	return {"success": true, "mods": paginated_mods, "page": page, "page_size": limit, "has_more": has_more, "total": _cached_mods_list.size()}


func get_mod_details(mod_id: int) -> Dictionary:
	var endpoint = "/games/%s/mods/%d" % [GAME_DOMAIN, mod_id]
	var result = await _request("GET", endpoint)
	if result.success:
		return {"success": true, "mod": result.data}
	else:
		return {"success": false, "error": result.error}


# 批量获取模组详情（真正的并发请求）
# 信号用于并发完成通知
signal _lane_completed(results: Array)

# 批量获取模组详情（并发实现）
func get_mod_details_batch(mod_ids: Array) -> Array:
	var batch_start = Time.get_ticks_msec()
	print("[NexusAPI get_mod_details_batch] START ", mod_ids.size(), " IDs")

	# 检查缓存 - 如果已经扫描过，直接返回缓存结果
	var cached_results: Array = []
	var all_cached = true
	for mod_id in mod_ids:
		var found = false
		for cached_mod in _all_scanned_mods_cache:
			if int(cached_mod.get("mod_id", 0)) == int(mod_id):
				cached_results.append({"success": true, "mod": cached_mod})
				found = true
				break
		if not found:
			all_cached = false
			break

	if all_cached and cached_results.size() == mod_ids.size():
		print("[NexusAPI get_mod_details_batch] CACHE HIT ", cached_results.size(), " mods in 0ms")
		return cached_results

	# 5 个并发 lane
	var CONCURRENT = 5

	# 每个 lane 分配到的 index
	var lane_indices: Array = []
	for i in range(CONCURRENT):
		lane_indices.append([])

	for i in range(mod_ids.size()):
		lane_indices[i % CONCURRENT].append(i)

	# 启动所有协程（立即返回，不等待）
	for idx in range(CONCURRENT):
		if lane_indices[idx].size() > 0:
			_start_lane(mod_ids, lane_indices[idx], idx)

	# 等待所有 lane 完成
	var all_results: Array = []
	var completed_count = 0
	var target = 0
	for indices in lane_indices:
		if indices.size() > 0:
			target += 1

	while completed_count < target:
		var result = await _lane_completed
		all_results.append_array(result)
		completed_count += 1
		# 让 UI 有机会更新
		if completed_count < target:
			await _tree.process_frame

	print("[NexusAPI get_mod_details_batch] END ", all_results.size(), " mods in ", Time.get_ticks_msec() - batch_start, "ms")

	# 保存到缓存（去重）
	for result in all_results:
		if result.success:
			var mod = result.mod
			var mod_id = int(mod.get("mod_id", 0))
			if mod_id != 0:
				var already_exists = false
				for existing in _all_scanned_mods_cache:
					if int(existing.get("mod_id", 0)) == mod_id:
						already_exists = true
						break
				if not already_exists:
					_all_scanned_mods_cache.append(mod)

	return all_results


# 启动一个 lane（不等待，让它并发执行）
func _start_lane(all_ids: Array, indices: Array, lane_id: int) -> void:
	var lane_results: Array = []
	for idx in indices:
		var mod_id = all_ids[idx]
		var endpoint = "/games/%s/mods/%d" % [GAME_DOMAIN, mod_id]
		var result = await _request("GET", endpoint)
		if result.success and result.data != null:
			lane_results.append({"success": true, "mod": result.data})
		else:
			lane_results.append({"success": false, "mod": {}})
	# 完成后通知
	_lane_completed.emit(lane_results)


func get_mod_files(mod_id: int) -> Dictionary:
	var endpoint = "/games/%s/mods/%d/files" % [GAME_DOMAIN, mod_id]
	var result = await _request("GET", endpoint)
	if result.success:
		print("[NexusAPI get_mod_files] mod_id=", mod_id, ", data type=", typeof(result.data))
		return {"success": true, "files": result.data}
	else:
		return {"success": false, "error": result.error}


func get_download_link(mod_id: int, file_id: int) -> Dictionary:
	var endpoint = "/games/%s/mods/%d/files/%d/download_link" % [GAME_DOMAIN, mod_id, file_id]
	var result = await _request("GET", endpoint)
	if result.success:
		print("[NexusAPI get_download_link] mod_id=", mod_id, ", file_id=", file_id, ", data type=", typeof(result.data))
		if typeof(result.data) == TYPE_ARRAY and result.data.size() > 0:
			var first_item = result.data[0]
			if first_item is Dictionary:
				return {"success": true, "download_link": first_item.get("URI", "")}
			else:
				return {"success": false, "error": "Invalid download link format"}
		elif typeof(result.data) == TYPE_DICTIONARY and result.data.has("URI"):
			return {"success": true, "download_link": result.data.get("URI", "")}
		else:
			return {"success": false, "error": "No download link available"}
	else:
		return {"success": false, "error": result.error}


func get_download_link_with_key(mod_id: int, file_id: int, key: String, expires: int, user_id: int) -> Dictionary:
	"""使用 key/expires/user_id 参数获取下载链接（非Premium用户需要）"""
	print("[NexusAPI get_download_link_with_key] mod_id=", mod_id, ", file_id=", file_id, ", key=", key.substr(0, 10) if key else "", ", expires=", expires, ", user_id=", user_id)

	# API endpoint: /games/{game}/mods/{mod_id}/files/{file_id}/download_link?key={key}&expires={expires}&user_id={user_id}
	var endpoint = "/games/%s/mods/%d/files/%d/download_link" % [GAME_DOMAIN, mod_id, file_id]
	var query_params = "key=%s&expires=%d&user_id=%d" % [key, expires, user_id]

	var result = await _request("GET", endpoint, query_params)
	if result.success:
		print("[NexusAPI get_download_link_with_key] Success, data type=", typeof(result.data))
		if typeof(result.data) == TYPE_ARRAY and result.data.size() > 0:
			var first_item = result.data[0]
			if first_item is Dictionary:
				return {"success": true, "download_link": first_item.get("URI", "")}
			else:
				return {"success": false, "error": "Invalid download link format"}
		elif typeof(result.data) == TYPE_DICTIONARY and result.data.has("URI"):
			return {"success": true, "download_link": result.data.get("URI", "")}
		else:
			return {"success": false, "error": "No download link available"}
	else:
		print("[NexusAPI get_download_link_with_key] Error: ", result.error)
		return {"success": false, "error": result.error}


func download_file(url: String, save_path: String) -> void:
	print("[NexusAPI download_file] Starting download: url=", url, ", save_path=", save_path)
	var parts = _parse_url(url)
	if parts.host.is_empty():
		download_completed.emit(false, "", "Invalid URL")
		return

	var http_client = HTTPClient.new()
	var tls_options = TLSOptions.client()
	var err = http_client.connect_to_host(parts.host, 443, tls_options)

	if err != OK:
		download_completed.emit(false, "", "Failed to connect: " + str(err))
		return

	while http_client.get_status() == HTTPClient.STATUS_CONNECTING:
		http_client.poll()
		await _tree.process_frame

	if http_client.get_status() != HTTPClient.STATUS_CONNECTED:
		download_completed.emit(false, "", "Failed to connect to host")
		return

	var headers = PackedStringArray([
		"User-Agent: NexusApiClient/%s" % API_VERSION,
		"Accept: */*"
	])
	err = http_client.request(HTTPClient.METHOD_GET, parts.path, headers)

	if err != OK:
		download_completed.emit(false, "", "Failed to send request: " + str(err))
		return

	while http_client.get_status() == HTTPClient.STATUS_REQUESTING:
		http_client.poll()
		await _tree.process_frame

	if http_client.get_status() != HTTPClient.STATUS_BODY:
		download_completed.emit(false, "", "Request failed")
		return

	var body = await _read_response_body(http_client)
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		download_completed.emit(false, "", "Failed to open file for writing")
		return
	file.store_buffer(body)
	file.close()
	download_completed.emit(true, save_path, "")


func _read_response_body(http_client: HTTPClient) -> PackedByteArray:
	var body = http_client.read_response_body_chunk()
	while http_client.get_status() == HTTPClient.STATUS_BODY:
		var chunk = http_client.read_response_body_chunk()
		if chunk.size() > 0:
			body.append_array(chunk)
		else:
			await _tree.process_frame
	return body


func download_image_to_cache(image_url: String, mod_id: int) -> String:
	var cached_path = cache_dir + "/%d.jpg" % mod_id
	print("[download_image_to_cache] mod_id=", mod_id, " cached_path=", cached_path)

	if FileAccess.file_exists(cached_path):
		print("[download_image_to_cache] File exists in cache")
		return cached_path

	print("[download_image_to_cache] Downloading image...")
	var parts = _parse_url(image_url)
	print("[download_image_to_cache] host=", parts.host, " path=", parts.path)
	if parts.host.is_empty():
		print("[download_image_to_cache] Empty host")
		return ""

	var http_client = HTTPClient.new()
	var tls_options = TLSOptions.client()
	var err = http_client.connect_to_host(parts.host, 443, tls_options)

	if err != OK:
		return ""

	while http_client.get_status() == HTTPClient.STATUS_CONNECTING:
		http_client.poll()
		await _tree.process_frame

	if http_client.get_status() != HTTPClient.STATUS_CONNECTED:
		return ""

	var headers = PackedStringArray([
		"User-Agent: NexusApiClient/%s" % API_VERSION,
		"Accept: image/*"
	])
	err = http_client.request(HTTPClient.METHOD_GET, parts.path, headers)

	if err != OK:
		return ""

	while http_client.get_status() == HTTPClient.STATUS_REQUESTING:
		http_client.poll()
		await _tree.process_frame

	if http_client.get_status() != HTTPClient.STATUS_BODY:
		return ""

	var body = await _read_response_body(http_client)
	var file = FileAccess.open(cached_path, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_buffer(body)
	file.close()
	return cached_path


func _parse_url(url: String) -> Dictionary:
	var result = {"host": "", "path": "/"}
	var host_start = url.find("://")
	if host_start >= 0:
		var remaining = url.substr(host_start + 3)
		var path_idx = remaining.find("/")
		if path_idx >= 0:
			result.host = remaining.substr(0, path_idx)
			result.path = remaining.substr(path_idx)
		else:
			result.host = remaining
	else:
		result.host = url
	return result


func _rate_limit_wait() -> void:
	var now = Time.get_ticks_msec()
	var elapsed = now - _last_request_time
	var min_interval = 1000 / RATE_LIMIT_PER_SECOND
	if elapsed < min_interval:
		await _tree.create_timer((min_interval - elapsed) / 1000.0).timeout
	_last_request_time = Time.get_ticks_msec()


func _request(http_method: String, endpoint: String, query_params: String = "") -> Dictionary:
	var _request_start_time = Time.get_ticks_msec()
	await _rate_limit_wait()

	print("[NexusAPI _request] START " + http_method + " " + endpoint)
	if api_key.is_empty():
		return {"success": false, "data": null, "error": "API Key is not set"}

	var method_enum = HTTPClient.METHOD_GET
	if http_method == "POST":
		method_enum = HTTPClient.METHOD_POST
	elif http_method == "PUT":
		method_enum = HTTPClient.METHOD_PUT
	elif http_method == "DELETE":
		method_enum = HTTPClient.METHOD_DELETE

	var http_client = HTTPClient.new()
	# 添加查询参数到 URL
	var url_str = BASE_URL + endpoint
	if not query_params.is_empty():
		url_str += "?" + query_params
	var parts = _parse_url(url_str)

	var tls_options = TLSOptions.client()
	var err = http_client.connect_to_host(parts.host, 443, tls_options)

	if err != OK:
		return {"success": false, "data": null, "error": "Failed to connect: " + str(err)}

	var connect_timeout = 10000
	var connect_start = Time.get_ticks_msec()
	while true:
		var status = http_client.get_status()
		if status == HTTPClient.STATUS_CONNECTED:
			break
		elif status == HTTPClient.STATUS_CONNECTING or status == HTTPClient.STATUS_RESOLVING:
			http_client.poll()
			await _tree.process_frame
			if Time.get_ticks_msec() - connect_start > connect_timeout:
				return {"success": false, "data": null, "error": "Connection timeout"}
		elif status == HTTPClient.STATUS_CANT_RESOLVE or status == HTTPClient.STATUS_CANT_CONNECT:
			return {"success": false, "data": null, "error": "Cannot resolve or connect to host"}
		else:
			break

	if http_client.get_status() != HTTPClient.STATUS_CONNECTED:
		return {"success": false, "data": null, "error": "Failed to connect to host"}

	var headers = PackedStringArray([
		"APIKEY: %s" % api_key,
		"Protocol-Version: %s" % API_VERSION,
		"Application-Name: %s" % APP_NAME,
		"Application-Version: %s" % APP_VERSION,
		"User-Agent: NexusApiClient/%s" % API_VERSION,
		"Accept: application/json"
	])

	# 构造完整的请求路径（包含查询参数）
	var request_path = parts.path + ("?" + query_params if not query_params.is_empty() else "")
	print("[NexusAPI _request] Request path: ", request_path)
	err = http_client.request(method_enum, request_path, headers)
	if err != OK:
		return {"success": false, "data": null, "error": "Failed to send request: " + str(err)}

	while http_client.get_status() == HTTPClient.STATUS_REQUESTING:
		http_client.poll()
		await _tree.process_frame

	if http_client.get_status() != HTTPClient.STATUS_BODY:
		return {"success": false, "data": null, "error": "Request failed"}

	var response_code = http_client.get_response_code()
	print("[NexusAPI _request] response_code = ", response_code)

	if response_code >= 400:
		var error_msg = "HTTP Error: %d" % response_code
		var body = http_client.read_response_body_chunk()
		if body.size() > 0:
			var body_str = body.get_string_from_utf8()
			_debug_log("[NexusAPI _request] Error response body: " + body_str)
			var json = JSON.new()
			if json.parse(body_str) == OK:
				var data = json.get_data()
				if typeof(data) == TYPE_DICTIONARY:
					error_msg = data.get("error", error_msg)
		return {"success": false, "data": null, "error": error_msg}

	var body = await _read_response_body(http_client)
	print("[NexusAPI] Body size: ", body.size())

	var body_str = body.get_string_from_utf8()
	print("[NexusAPI] Body length: ", body_str.length())

	# 打印响应的前500字符用于调试
	if body_str.length() > 0:
		print("[NexusAPI] Response preview: ", body_str.substr(0, min(500, body_str.length())))

	var cleaned_str = body_str.strip_edges()
	var json = JSON.new()
	var parse_result = json.parse(cleaned_str)

	print("[NexusAPI] parse_result = ", parse_result)
	if parse_result != OK:
		print("[NexusAPI] JSON error: ", json.get_error_message())
		return {"success": false, "data": null, "error": "JSON parse error: " + json.get_error_message()}

	var data = json.get_data()
	print("[NexusAPI _request] END " + endpoint + " took " + str(Time.get_ticks_msec() - _request_start_time) + "ms")
	return {"success": true, "data": data}


func _post_request(endpoint: String, body_data: Dictionary) -> Dictionary:
	"""发送 POST 请求"""
	var _request_start_time = Time.get_ticks_msec()
	await _rate_limit_wait()

	print("[NexusAPI _post_request] START " + endpoint)
	if api_key.is_empty():
		return {"success": false, "data": null, "error": "API Key is not set"}

	var http_client = HTTPClient.new()
	var url_str = BASE_URL + endpoint
	var parts = _parse_url(url_str)

	var tls_options = TLSOptions.client()
	var err = http_client.connect_to_host(parts.host, 443, tls_options)

	if err != OK:
		return {"success": false, "data": null, "error": "Failed to connect: " + str(err)}

	var connect_timeout = 10000
	var connect_start = Time.get_ticks_msec()
	while true:
		var status = http_client.get_status()
		if status == HTTPClient.STATUS_CONNECTED:
			break
		elif status == HTTPClient.STATUS_CONNECTING or status == HTTPClient.STATUS_RESOLVING:
			http_client.poll()
			await _tree.process_frame
			if Time.get_ticks_msec() - connect_start > connect_timeout:
				return {"success": false, "data": null, "error": "Connection timeout"}
		else:
			break

	if http_client.get_status() != HTTPClient.STATUS_CONNECTED:
		return {"success": false, "data": null, "error": "Failed to connect to host"}

	# JSON 序列化 body
	var json_body = JSON.stringify(body_data)

	var headers = PackedStringArray([
		"APIKEY: %s" % api_key,
		"Protocol-Version: %s" % API_VERSION,
		"Application-Name: %s" % APP_NAME,
		"Application-Version: %s" % APP_VERSION,
		"User-Agent: NexusApiClient/%s" % API_VERSION,
		"Accept: application/json",
		"Content-Type: application/json"
	])

	err = http_client.request(HTTPClient.METHOD_POST, parts.path, headers, json_body)
	if err != OK:
		return {"success": false, "data": null, "error": "Failed to send request: " + str(err)}

	while http_client.get_status() == HTTPClient.STATUS_REQUESTING:
		http_client.poll()
		await _tree.process_frame

	if http_client.get_status() != HTTPClient.STATUS_BODY:
		return {"success": false, "data": null, "error": "Request failed"}

	var response_code = http_client.get_response_code()
	print("[NexusAPI _post_request] response_code = ", response_code)

	if response_code >= 400:
		var error_msg = "HTTP Error: %d" % response_code
		var body = http_client.read_response_body_chunk()
		if body.size() > 0:
			var body_str = body.get_string_from_utf8()
			_debug_log("[NexusAPI _post_request] Error response body: " + body_str)
			var json = JSON.new()
			if json.parse(body_str) == OK:
				var data = json.get_data()
				if typeof(data) == TYPE_DICTIONARY:
					error_msg = data.get("error", data.get("message", error_msg))
		return {"success": false, "data": null, "error": error_msg}

	var body = await _read_response_body(http_client)
	var body_str = body.get_string_from_utf8()
	_debug_log("[NexusAPI _post_request] Body length: " + str(body_str.length()))

	if body_str.length() > 0:
		print("[NexusAPI] POST Response preview: ", body_str.substr(0, min(500, body_str.length())))

	var json = JSON.new()
	var parse_result = json.parse(body_str.strip_edges())

	if parse_result != OK:
		return {"success": false, "data": null, "error": "JSON parse error: " + json.get_error_message()}

	var data = json.get_data()
	print("[NexusAPI _post_request] END took " + str(Time.get_ticks_msec() - _request_start_time) + "ms")
	return {"success": true, "data": data}


func parse_mod_info(mod_data: Dictionary) -> Dictionary:
	return {
		"id": mod_data.get("mod_id", 0),
		"name": mod_data.get("name", ""),
		"author": mod_data.get("user", {}).get("name", ""),
		"description": mod_data.get("summary", ""),
		"version": mod_data.get("version", ""),
		"downloads": mod_data.get("downloads", 0),
		"updated": mod_data.get("updated", ""),
		"created": mod_data.get("created", ""),
		"picture_url": mod_data.get("picture_url", ""),
		"mod_page_url": mod_data.get("mod_page_url", ""),
		"category": mod_data.get("category", {}).get("name", "")
	}


# 获取最新添加的模组（客户端分页）
func get_latest_added(limit: int = 20, page: int = 1) -> Dictionary:
	# 直接使用 /latest_added 端点
	var endpoint = "/games/%s/mods/latest_added?limit=%d" % [GAME_DOMAIN, limit]
	var result = await _request("GET", endpoint)
	if result.success:
		var mods = result.data if typeof(result.data) == TYPE_ARRAY else []
		_debug_log("[get_latest_added] Got " + str(mods.size()) + " mods")
		return {"success": true, "mods": mods, "page": page, "page_size": limit, "has_more": false, "total": mods.size()}
	else:
		return {"success": false, "error": result.error}


# 获取最多下载的模组
func get_most_downloaded(limit: int = 20, page: int = 1) -> Dictionary:
	# 直接使用 /most_downloaded 端点
	var endpoint = "/games/%s/mods/most_downloaded?limit=%d" % [GAME_DOMAIN, limit]
	var result = await _request("GET", endpoint)
	if result.success:
		var mods = result.data if typeof(result.data) == TYPE_ARRAY else []
		_debug_log("[get_most_downloaded] Got " + str(mods.size()) + " mods")
		return {"success": true, "mods": mods, "page": page, "page_size": limit, "has_more": false, "total": mods.size()}
	else:
		return {"success": false, "error": result.error}


# 获取最近更新的模组
func get_latest_updated(limit: int = 20, page: int = 1) -> Dictionary:
	# 直接使用 /latest_updated 端点
	var endpoint = "/games/%s/mods/latest_updated?limit=%d" % [GAME_DOMAIN, limit]
	var result = await _request("GET", endpoint)
	if result.success:
		var mods = result.data if typeof(result.data) == TYPE_ARRAY else []
		_debug_log("[get_latest_updated] Got " + str(mods.size()) + " mods")
		return {"success": true, "mods": mods, "page": page, "page_size": limit, "has_more": false, "total": mods.size()}
	else:
		return {"success": false, "error": result.error}


# 获取模组 ID 列表（用于 ALL 筛选器渐进式加载）
func get_mod_list_ids(page: int = 1, page_size: int = 20, sort_by: String = "popular") -> Dictionary:
	# 尝试 /games/{domain}/mods 端点（如果支持分页）
	var endpoint = "/games/%s/mods?page=%d&page_size=%d&sort=%s" % [GAME_DOMAIN, page, page_size, sort_by]
	_debug_log("[NexusAPI get_mod_list_ids] Request: " + endpoint)
	var result = await _request("GET", endpoint)
	if result.success:
		var mods = result.data if typeof(result.data) == TYPE_ARRAY else []
		_debug_log("[NexusAPI get_mod_list_ids] Got " + str(mods.size()) + " mods, page=" + str(page))
		return {
			"success": true,
			"mods": mods,
			"page": page,
			"page_size": page_size,
			"has_more": mods.size() >= page_size
		}
	else:
		_debug_log("[NexusAPI get_mod_list_ids] Error: " + result.error)
		# 如果 /mods 端点不支持，尝试使用 latest_added 端点作为后备
		_debug_log("[NexusAPI get_mod_list_ids] Falling back to latest_added")
		return await get_latest_added(page_size, page)


# 使用并行探测找到最大有效 mod_id
signal _probe_completed(max_id: int)

func find_max_mod_id() -> int:
	_debug_log("[find_max_mod_id] Starting parallel search for max mod_id")

	var max_valid = 0
	var attempts = 0
	var max_attempts = 15  # 最多尝试次数

	# 阶段1：探测多个位置快速找到有效范围
	_debug_log("[find_max_mod_id] Phase 1: Probing positions 1,100,200,300,400...")
	var probe_ids = [1, 100, 200, 300, 400]

	# 使用现有的并发 lane 模式
	var lanes = 5
	var lane_indices: Array = []
	for i in range(lanes):
		lane_indices.append([])

	for i in range(probe_ids.size()):
		lane_indices[i % lanes].append(i)

	# 启动所有 lane
	for idx in range(lanes):
		if lane_indices[idx].size() > 0:
			_probe_lane(probe_ids, lane_indices[idx])

	# 等待结果
	var completed = 0
	var target = 0
	for indices in lane_indices:
		if indices.size() > 0:
			target += 1

	while completed < target:
		var result = await _probe_completed
		if result > max_valid:
			max_valid = result
		completed += 1
		binary_search_progress.emit(completed, target, "探测范围中... ID:" + str(max_valid))

	_debug_log("[find_max_mod_id] Phase 1 done: max_valid=" + str(max_valid))

	if max_valid == 0:
		binary_search_progress.emit(1, 1, "未找到有效模组")
		return 0

	# 阶段2：向上探测
	_debug_log("[find_max_mod_id] Phase 2: Upward scan from " + str(max_valid))
	var scan_batch = 10

	while attempts < max_attempts:
		attempts += 1
		binary_search_progress.emit(attempts, max_attempts, "探测范围中... ID:" + str(max_valid))

		# 构建下一批ID
		var test_ids: Array = []
		for i in range(scan_batch):
			test_ids.append(max_valid + i + 1)

		# 分配到 lanes
		lane_indices.clear()
		for i in range(lanes):
			lane_indices.append([])

		for i in range(test_ids.size()):
			lane_indices[i % lanes].append(i)

		# 启动
		for idx in range(lanes):
			if lane_indices[idx].size() > 0:
				_probe_lane(test_ids, lane_indices[idx])

		# 等待
		completed = 0
		target = 0
		for indices in lane_indices:
			if indices.size() > 0:
				target += 1

		var found_any = false
		while completed < target:
			var result = await _probe_completed
			if result > max_valid:
				max_valid = result
				found_any = true
			completed += 1

		if not found_any:
			break

		_debug_log("[find_max_mod_id] Upward scan at " + str(max_valid) + ", attempts=" + str(attempts))

	binary_search_progress.emit(max_attempts, max_attempts, "范围探测完成! 最大ID: " + str(max_valid))
	_debug_log("[find_max_mod_id] Found max mod_id: " + str(max_valid))
	return max_valid


# 探测 lane（使用 _request 直接调用）
func _probe_lane(id_list: Array, indices: Array) -> void:
	var lane_max = 0
	for idx in indices:
		var mod_id = id_list[idx]
		var endpoint = "/games/%s/mods/%d" % [GAME_DOMAIN, mod_id]
		var result = await _request("GET", endpoint)
		if result.success and result.data != null:
			var mid = result.data.get("mod_id", 0)
			if mid > lane_max:
				lane_max = mid
	# 完成后通知最大ID
	_probe_completed.emit(lane_max)


# 获取所有模组（用于 ALL 筛选器 - 组合多个端点的数据）
func get_all_mods_for_all_filter(page: int = 1, page_size: int = 50) -> Dictionary:
	"""ALL 筛选器专用：组合多个端点的数据来获取更多模组"""
	_debug_log("[get_all_mods_for_all_filter] page=" + str(page) + ", cached=" + str(_all_filter_cached_mods.size()))

	# 首次加载时从多个端点获取数据
	if _all_filter_cached_mods.is_empty() or _all_filter_sort_type != "all":
		_debug_log("[get_all_mods_for_all_filter] Building cache from multiple endpoints...")

		var existing_ids = {}
		var all_mods = []

		# 从多个端点获取数据，每次获取更多
		var endpoints = [
			"/games/%s/mods/latest_added?limit=50" % GAME_DOMAIN,
			"/games/%s/mods/latest_updated?limit=50" % GAME_DOMAIN,
			"/games/%s/mods/trending?limit=50" % GAME_DOMAIN,
			"/games/%s/mods/most_downloaded?limit=50" % GAME_DOMAIN,
		]

		for endpoint in endpoints:
			var result = await _request("GET", endpoint)
			if result.success:
				var mods = result.data if typeof(result.data) == TYPE_ARRAY else []
				for mod in mods:
					var mod_id = mod.get("mod_id", 0)
					if mod_id > 0 and not existing_ids.has(mod_id):
						all_mods.append(mod)
						existing_ids[mod_id] = true

		# 按下载量排序
		all_mods.sort_custom(func(a, b):
			var a_dl = a.get("mod_downloads", a.get("downloads", 0))
			var b_dl = b.get("mod_downloads", b.get("downloads", 0))
			return a_dl > b_dl
		)

		_all_filter_cached_mods = all_mods
		_all_filter_sort_type = "all"
		_debug_log("[get_all_mods_for_all_filter] Cache built with " + str(all_mods.size()) + " unique mods")

	# 从缓存分页
	var start_idx = (page - 1) * page_size
	var end_idx = min(start_idx + page_size, _all_filter_cached_mods.size())

	_debug_log("[get_all_mods_for_all_filter] start_idx=" + str(start_idx) + ", end_idx=" + str(end_idx) + ", total=" + str(_all_filter_cached_mods.size()))

	if start_idx >= _all_filter_cached_mods.size():
		return {"success": true, "mods": [], "page": page, "page_size": page_size, "has_more": false, "total": _all_filter_cached_mods.size()}

	var paginated_mods = _all_filter_cached_mods.slice(start_idx, end_idx)
	var has_more = end_idx < _all_filter_cached_mods.size()
	_debug_log("[get_all_mods_for_all_filter] returning " + str(paginated_mods.size()) + " mods, has_more=" + str(has_more))
	return {"success": true, "mods": paginated_mods, "page": page, "page_size": page_size, "has_more": has_more, "total": _all_filter_cached_mods.size()}
