extends RefCounted
class_name LocalServer

# 本地HTTP服务器 - 监听浏览器扩展的下载请求

const DEFAULT_PORT: int = 8765

var _server_port: int = DEFAULT_PORT
var _server: TCPServer = null
var _is_running: bool = false
var _thread: Thread = null
var _mutex: Mutex = null
var _active_downloads: int = 0
var _installed_mods_count: int = 0

# Nexus API 引用
var _nexus_api: NexusAPI = null

signal download_request_received(data: Dictionary)
signal server_status_changed(running: bool)
signal server_error(error: String)


func _init() -> void:
	_mutex = Mutex.new()


func set_port(port: int) -> void:
	_server_port = port


func get_port() -> int:
	return _server_port


func set_nexus_api(api: NexusAPI) -> void:
	_nexus_api = api


func start() -> bool:
	if _is_running:
		return true

	print("[LocalServer] Starting server on port ", _server_port)

	_server = TCPServer.new()
	var err = _server.listen(_server_port, "127.0.0.1")

	if err != OK:
		print("[LocalServer] Failed to start server: ", err)
		server_error.emit("Failed to start server: " + str(err))
		return false

	_is_running = true
	server_status_changed.emit(true)

	# 启动处理线程
	_thread = Thread.new()
	_thread.start(_thread_loop.bind(self), Thread.PRIORITY_NORMAL)

	print("[LocalServer] Server started successfully")
	return true


func stop() -> void:
	if not _is_running:
		return

	print("[LocalServer] Stopping server...")
	_is_running = false

	# 等待线程结束
	if _thread != null:
		_thread.wait_to_finish()
		_thread = null

	# 关闭服务器
	if _server != null:
		_server.stop()
		_server = null

	server_status_changed.emit(false)
	print("[LocalServer] Server stopped")


func is_running() -> bool:
	return _is_running


func get_status() -> Dictionary:
	_mutex.lock()
	var count = _active_downloads
	var installed = _installed_mods_count
	_mutex.unlock()

	return {
		"running": _is_running,
		"active_downloads": count,
		"installed_mods": installed,
		"version": "1.0.0"
	}


func _thread_loop(server_ref: LocalServer) -> void:
	while server_ref._is_running:
		if server_ref._server == null:
			break

		# 等待客户端连接
		var client = server_ref._server.take_connection()
		if client == null:
			# 没有连接，睡眠一小段时间
			OS.delay_msec(50)
			continue

		# 处理请求
		server_ref._handle_client(client)

	# 清理
	if server_ref._server != null:
		server_ref._server.stop()
		server_ref._server = null


func _handle_client(client: StreamPeerTCP) -> void:
	print("[LocalServer] Client connected")

	var request_data = ""

	# 读取请求
	var buffer = PackedByteArray()
	var max_read = 65536  # 64KB max

	# 第一阶段：读取headers（知道Content-Length）
	var content_length = -1
	var headers_complete = false

	while buffer.size() < max_read:
		# 等待数据到达
		var start_time = Time.get_ticks_msec()
		while client.get_available_bytes() == 0:
			if Time.get_ticks_msec() - start_time > 200:  # 200ms超时
				break
			OS.delay_usec(500)

		var available = client.get_available_bytes()
		if available == 0:
			if buffer.size() > 0 and headers_complete:
				break  # 如果已经有headers了，且body也读得差不多了
			break

		var result = client.get_data(available)
		if result[0] != OK:
			break
		var chunk: PackedByteArray = result[1]
		if chunk.size() == 0:
			break

		buffer.append_array(chunk)

		# 检查headers是否完整
		if not headers_complete:
			var check_str = buffer.get_string_from_utf8()
			var header_end = check_str.find("\r\n\r\n")
			if header_end >= 0:
				var headers_section = check_str.substr(0, header_end)
				content_length = _get_content_length(headers_section)
				headers_complete = true
				print("[LocalServer] Headers complete, Content-Length: ", content_length)

		# 检查是否读完
		if headers_complete and content_length >= 0:
			var header_end_pos = buffer.get_string_from_utf8().find("\r\n\r\n")
			if header_end_pos >= 0:
				var body_start = header_end_pos + 4
				var body_received = buffer.size() - body_start
				if body_received >= content_length:
					break

	if buffer.size() > 0:
		request_data = buffer.get_string_from_utf8()
		print("[LocalServer] Request received, size: ", buffer.size())

	# 解析请求
	var parsed = _parse_http_request(request_data)
	if parsed.size() == 0:
		print("[LocalServer] Failed to parse request")
		_send_response(client, 400, {"error": "Bad request"})
		client.disconnect_from_host()
		return

	var method = parsed.get("method", "GET")
	var path = parsed.get("path", "/")
	var headers_dict = parsed.get("headers", {})
	var body_content = parsed.get("body", "")

	print("[LocalServer] ", method, " ", path)

	# 处理请求
	var response = _handle_request(method, path, headers_dict, body_content)

	# 发送响应
	_send_response(client, response.get("code", 200), response.get("data", {}))

	client.disconnect_from_host()
	print("[LocalServer] Client disconnected")



func _get_content_length(headers: String) -> int:
	var lines = headers.split("\r\n")
	for line in lines:
		if line.to_lower().strip_edges().begins_with("content-length:"):
			var value = line.substr(14).strip_edges()
			return value.to_int()
	return -1


func _parse_http_request(data: String) -> Dictionary:
	var result = {
		"method": "GET",
		"path": "/",
		"headers": {},
		"body": ""
	}

	if data.is_empty():
		return {}

	var lines = data.split("\r\n")
	if lines.is_empty():
		return {}

	# 解析请求行
	var request_line = lines[0].split(" ")
	if request_line.size() >= 2:
		result["method"] = request_line[0].strip_edges()
		result["path"] = request_line[1].strip_edges()

	# 解析headers
	var body_start = -1
	for i in range(1, lines.size()):
		var line = lines[i]
		if line.is_empty():
			body_start = i + 1
			break

		var colon_idx = line.find(":")
		if colon_idx > 0:
			var key = line.substr(0, colon_idx).strip_edges()
			var value = line.substr(colon_idx + 1).strip_edges()
			result["headers"][key.to_lower()] = value

	# 解析body - 收集从 body_start 到末尾的所有行
	if body_start >= 0 and body_start < lines.size():
		var body_lines = lines.slice(body_start)
		# 过滤空行并清理
		var cleaned_body = ""
		for i in range(body_lines.size()):
			var line = body_lines[i]
			# 跳过纯空行（但保留实际内容）
			if line.is_empty() and cleaned_body.is_empty():
				continue
			if not cleaned_body.is_empty():
				cleaned_body += "\r\n"
			cleaned_body += line

		# 去除首尾空白
		result["body"] = cleaned_body.strip_edges()
		print("[LocalServer] Parsed body length: ", result["body"].length())

	return result


func _handle_request(method: String, path: String, headers: Dictionary, body: String) -> Dictionary:
	# 处理 CORS 预检请求
	if method == "OPTIONS":
		return {"code": 200, "data": {}, "is_options": true}

	# API 路由
	if path == "/api/status":
		return _handle_status(method, headers, body)
	elif path == "/api/download":
		return _handle_download(method, headers, body)
	elif path == "/api/shutdown":
		return _handle_shutdown(method, headers, body)
	elif path == "/api/health":
		return {"code": 200, "data": {"status": "ok"}}
	else:
		return {"code": 404, "data": {"error": "Not found"}}


func _handle_status(method: String, headers: Dictionary, body: String) -> Dictionary:
	if method != "GET":
		return {"code": 405, "data": {"error": "Method not allowed"}}

	var status = get_status()
	return {"code": 200, "data": status}


func _handle_download(method: String, headers: Dictionary, body: String) -> Dictionary:
	if method != "POST":
		return {"code": 405, "data": {"error": "Method not allowed"}}

	print("[LocalServer] Download request body: '", body, "'")

	# 解析请求体
	var json = JSON.new()
	var parse_result = json.parse(body)
	if parse_result != OK:
		print("[LocalServer] JSON parse error: ", parse_result, ", body: '", body, "'")
		return {"code": 400, "data": {"error": "Invalid JSON"}}

	var request_data = json.get_data()
	if typeof(request_data) != TYPE_DICTIONARY:
		print("[LocalServer] Request data is not a dictionary: ", typeof(request_data))
		return {"code": 400, "data": {"error": "Invalid request body"}}

	var mod_id = request_data.get("mod_id", 0)
	if typeof(mod_id) == TYPE_STRING:
		mod_id = int(mod_id) if mod_id.is_valid_int() else 0

	var mod_name = request_data.get("mod_name", "Unknown")
	var mod_page_url = request_data.get("mod_page_url", "")
	var version = request_data.get("version", "")
	var download_url = request_data.get("download_url", "")
	var key = request_data.get("key", "")
	var expires = request_data.get("expires", 0)
	var user_id = request_data.get("user_id", 0)
	var file_id = request_data.get("file_id", 0)

	print("[LocalServer] Download request: mod_id=", mod_id, ", name=", mod_name, ", download_url=", download_url)
	print("[LocalServer] Extra params: key=", key.substr(0, 10) if key else "", ", expires=", expires, ", user_id=", user_id, ", file_id=", file_id)

	if mod_id == 0:
		return {"code": 400, "data": {"error": "mod_id is required"}}

	# 增加活跃下载计数
	_mutex.lock()
	_active_downloads += 1
	_mutex.unlock()

	# 异步处理下载（使用信号通知主线程）
	download_request_received.emit({
		"mod_id": mod_id,
		"mod_name": mod_name,
		"mod_page_url": mod_page_url,
		"version": version,
		"download_url": download_url,
		"key": key,
		"expires": expires,
		"user_id": user_id,
		"file_id": file_id
	})

	# 立即返回accepted状态
	return {
		"code": 202,
		"data": {
			"status": "accepted",
			"message": "Download request received",
			"mod_id": mod_id,
			"mod_name": mod_name
		}
	}


func _handle_shutdown(method: String, headers: Dictionary, body: String) -> Dictionary:
	if method != "POST":
		return {"code": 405, "data": {"error": "Method not allowed"}}

	print("[LocalServer] Shutdown request received")

	# 延迟关闭服务器（通过call_deferred避免阻塞）
	call_deferred("_deferred_stop")

	return {"code": 200, "data": {"status": "shutdown", "message": "Server stopped"}}


func _deferred_stop() -> void:
	OS.delay_msec(50)
	stop()


func notify_download_complete(success: bool, mod_name: String, error: String = "") -> void:
	_mutex.lock()
	_active_downloads = max(0, _active_downloads - 1)
	if success:
		_installed_mods_count += 1
	_mutex.unlock()

	if success:
		print("[LocalServer] Download complete: ", mod_name)
	else:
		print("[LocalServer] Download failed: ", mod_name, " - ", error)


func _send_download_started(mod_id: int, mod_name: String) -> void:
	print("[LocalServer] Download started: ", mod_name)


func _send_response(client: StreamPeerTCP, code: int, data: Dictionary, is_options: bool = false) -> void:
	var status_text = ""
	match code:
		200: status_text = "OK"
		202: status_text = "Accepted"
		400: status_text = "Bad Request"
		404: status_text = "Not Found"
		405: status_text = "Method Not Allowed"
		500: status_text = "Internal Server Error"
		_: status_text = "Unknown"

	# 构建响应
	var response = "HTTP/1.1 %d %s\r\n" % [code, status_text]
	response += "Content-Type: application/json\r\n"
	response += "Access-Control-Allow-Origin: *\r\n"
	response += "Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n"
	response += "Access-Control-Allow-Headers: Content-Type\r\n"

	# CORS 预检请求不需要 body
	if not is_options:
		# 序列化响应数据
		var body_data = JSON.stringify(data)
		var body_bytes = body_data.to_utf8_buffer()
		response += "Content-Length: %d\r\n" % body_bytes.size()
		response += "Connection: close\r\n"
		response += "\r\n"

		# 发送完整响应
		var header_bytes = response.to_utf8_buffer()
		var all_bytes = PackedByteArray(header_bytes) + body_bytes
		var result = client.put_data(all_bytes)
		if result != OK:
			print("[LocalServer] Failed to send response")
	else:
		response += "Content-Length: 0\r\n"
		response += "Connection: close\r\n"
		response += "\r\n"

		var header_bytes = response.to_utf8_buffer()
		var result = client.put_data(header_bytes)
		if result != OK:
			print("[LocalServer] Failed to send OPTIONS response")


func get_active_downloads() -> int:
	_mutex.lock()
	var count = _active_downloads
	_mutex.unlock()
	return count


func get_installed_mods_count() -> int:
	_mutex.lock()
	var count = _installed_mods_count
	_mutex.unlock()
	return count


func set_installed_mods_count(count: int) -> void:
	_mutex.lock()
	_installed_mods_count = count
	_mutex.unlock()
