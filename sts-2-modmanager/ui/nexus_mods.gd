extends Control

# N网模组页面脚本 - 简化版无限滚动

# Nexus API 实例
var nexus_api: NexusAPI

# 翻译函数引用（由主控制器设置）
var translate_func: Callable

# 调试日志文件
var _debug_log_file: FileAccess = null

# ============ 常量配置 ============
const MODS_PER_PAGE: int = 50  # 每页50个模组
const CARD_HEIGHT: int = 220
const CARD_WIDTH: int = 180
const COLUMN_COUNT: int = 3
const NON_ALL_INITIAL_COUNT: int = 10  # 非 ALL 筛选器初始显示数量
const SCAN_BATCH_SIZE: int = 5  # 每5个ID等待1帧，减少等待时间

# ============ 筛选类型 ============
enum FilterType {
	TRENDING,
	NEWEST,
	MOST_DOWNLOADS,
	UPDATED,
	ALL  # 所有模组 - 使用搜索 API，支持真正分页
}

# ============ 状态变量 ============
var _current_filter: FilterType = FilterType.TRENDING
var _current_sort_for_all: String = "popular"  # 当前 ALL 筛选器的排序方式
var current_page: int = 1
var total_pages: int = 1
var current_search_query: String = ""
var _is_loading_more: bool = false
var _has_more_pages: bool = true

# ============ 数据存储 ============
var all_mods_data: Array = []

# ============ ALL 筛选器专用状态 ============
var _all_pending_mod_ids: Array = []  # 待获取详情的 mod_id 列表
var _all_loaded_details: Dictionary = {}  # 已加载的详情缓存 {mod_id: full_mod_data}
var _all_next_batch_index: int = 0  # 下一批要加载的索引
var _all_initial_display_count: int = 10  # 初始显示数量

# ALL 筛选器 ID 遍历专用状态
var _all_max_mod_id: int = 0  # 最大 mod_id（检测得到）
var _all_current_scan_id: int = 1  # 当前扫描到的 id
var _all_valid_mods_cache: Array = []  # 有效模组缓存
var _all_initial_load_done: bool = false  # 是否已完成初始加载（检测到 max_id）
var _scan_cancelled: bool = false  # 扫描是否被取消
var _is_scanning: bool = false  # 是否正在扫描中

# ============ 进度窗口节点引用 ============
@onready var _progress_panel: PanelContainer = $ProgressPanel
@onready var _progress_title: Label = $ProgressPanel/VBox/Title
@onready var _progress_status: Label = $ProgressPanel/VBox/Status
@onready var _progress_found: Label = $ProgressPanel/VBox/Found
@onready var _progress_bar: ProgressBar = $ProgressPanel/VBox/ProgressBar
@onready var _progress_cancel_btn: Button = $ProgressPanel/VBox/CancelBtn

# ============ 下拉加载状态 ============
var _is_pulling: bool = false
const PULL_THRESHOLD: float = 60.0

# ============ 节点引用 ============
var _search_edit: LineEdit
var _search_btn: Button
var _search_label: Label
var _refresh_btn: Button
var _filter_dropdown: OptionButton
var _filter_label: Label
var _mods_scroll: ScrollContainer
var _content_vbox: VBoxContainer
var _mods_grid: GridContainer
var _pull_panel: PanelContainer
var _pull_label: Label
var _view_more_panel: PanelContainer
var _view_more_btn: Button
var _loading_more_label: Label  # 加载更多详情时的提示
@onready var _no_result_panel: PanelContainer = $NoResultPanel
@onready var _no_result_bg: Panel = $NoResultBG
var _loading_label: Label
var _tree: SceneTree = null

# ============ 下载列表节点引用 ============
@onready var _downloads_scroll: ScrollContainer = $MainHSplit/LeftPanel/DownloadsSection/DownloadsScroll
@onready var _downloads_vbox: VBoxContainer = $MainHSplit/LeftPanel/DownloadsSection/DownloadsScroll/DownloadsVBox
@onready var _open_folder_btn: Button = $MainHSplit/LeftPanel/DownloadsSection/OpenFolderBtn

# ============ 详情信息窗节点引用 ============
@onready var _details_bg: Panel = $DetailsBG
@onready var _details_panel: PanelContainer = $DetailsPanel
@onready var _details_close_btn: Button = $DetailsPanel/VBox/Header/CloseBtn
@onready var _details_image: TextureRect = $DetailsPanel/VBox/Scroll/Content/Image
@onready var _details_name: Label = $DetailsPanel/VBox/Scroll/Content/Name
@onready var _details_author: Label = $DetailsPanel/VBox/Scroll/Content/Author
@onready var _details_downloads: Label = $DetailsPanel/VBox/Scroll/Content/InfoRow/Downloads
@onready var _details_version: Label = $DetailsPanel/VBox/Scroll/Content/InfoRow/Version
@onready var _details_description: RichTextLabel = $DetailsPanel/VBox/Scroll/Content/Description
@onready var _details_page_btn: Button = $DetailsPanel/VBox/Buttons/PageBtn
@onready var _details_download_btn: Button = $DetailsPanel/VBox/Buttons/DownloadBtn
var _details_mod_data: Dictionary  # 当前显示的模组数据

# ============ 回调 ============
var on_view_details_callback: Callable

# ============ 下载列表状态 ============
var _downloading_items: Array = []  # 正在下载的项目 {name, progress, status}
var _downloaded_items: Array = []   # 已下载的项目 {path, name, time}


# ============ 调试日志 ============
func _debug_log(msg: String) -> void:
	if _debug_log_file == null:
		var log_path = "user://nexus_debug.log"
		_debug_log_file = FileAccess.open(log_path, FileAccess.WRITE)
		if _debug_log_file:
			_debug_log_file.store_string("=== Nexus Debug Log Start ===\n")
	if _debug_log_file:
		_debug_log_file.store_string(msg + "\n")
		_debug_log_file.flush()
	print(msg)


# ============ 翻译函数 ============
func t(key: String) -> String:
	if translate_func and translate_func.is_valid():
		return translate_func.call(key)
	var defaults = {
		"nexus_search_placeholder": "搜索N网模组...",
		"nexus_filter": "筛选",
		"nexus_trending": "热门推荐",
		"nexus_newest": "最新发布",
		"nexus_most_downloads": "最多下载",
		"nexus_recently_updated": "最近更新",
		"nexus_all_mods": "所有模组",
		"nexus_search": "搜索",
		"nexus_refresh": "刷新",
		"nexus_no_results": "未找到相关模组",
		"nexus_loading": "加载中...",
		"nexus_loading_more": "加载中...",
		"nexus_pull_to_load": "继续下拉以浏览更多",
		"nexus_release_to_load": "释放加载更多",
		"nexus_no_more": "没有更多模组了",
		"nexus_view_more": "查看更多",
		"nexus_page": "第 %d / %d 页",
		"nexus_author": "作者: ",
		"nexus_downloads": "下载: ",
		"nexus_view_details": "详情",
		"nexus_download": "下载",
		"nexus_scanning": "正在扫描模组...",
		"nexus_scanned_ids": "已扫描 ID %d / %d",
		"nexus_found_mods": "已找到模组: %d 个",
		"nexus_cancel": "取消",
		"nexus_mod_details": "模组详情",
		"nexus_open_page": "在浏览器中打开",
		"nexus_download_btn": "下载模组",
		"nexus_close": "关闭",
		"nexus_version": "版本: ",
		"nexus_no_description": "暂无描述",
		"nexus_binary_search_progress": "二分查找进度: 第 %d / %d 轮 (范围: %s)",
		"nexus_getting_mods": "正在获取模组...",
		"nexus_searching": "搜索中",
		"nexus_search_failed": "搜索失败",
		"nexus_search_tip": "提示：可尝试使用筛选器（热门/最新）浏览模组",
		"nexus_open_browser_search": "正在打开浏览器搜索...",
		"nexus_getting_mods_info": "正在获取模组信息...",
		"nexus_cancelling_scan": "正在取消扫描...",
		"nexus_error_prefix": "错误: "
	}
	return defaults.get(key, key)


# ============ 初始化 ============
func _ready() -> void:
	_debug_log("[nexus_mods] _ready() called")
	_tree = Engine.get_main_loop() as SceneTree

	# 创建 Nexus API 实例
	nexus_api = NexusAPI.new()

	# 连接二分查找进度信号
	nexus_api.binary_search_progress.connect(_on_binary_search_progress)

	# 获取节点引用
	_search_edit = $MainHSplit/LeftPanel/SearchSection/SearchEdit
	_search_btn = $MainHSplit/LeftPanel/SearchSection/SearchBtn
	_search_label = $MainHSplit/LeftPanel/SearchSection/SearchLabel
	_refresh_btn = $MainHSplit/LeftPanel/RefreshBtn
	_filter_dropdown = $MainHSplit/LeftPanel/FilterSection/FilterDropdown
	_filter_label = $MainHSplit/LeftPanel/FilterSection/FilterLabel
	_mods_scroll = $MainHSplit/RightPanel/ModsScroll
	_content_vbox = $MainHSplit/RightPanel/ModsScroll/ContentVBox
	_mods_grid = $MainHSplit/RightPanel/ModsScroll/ContentVBox/ModsGrid
	_pull_panel = $MainHSplit/RightPanel/ModsScroll/ContentVBox/PullToLoadPanel
	_pull_label = $MainHSplit/RightPanel/ModsScroll/ContentVBox/PullToLoadPanel/PullLabel
	_view_more_panel = $MainHSplit/RightPanel/ModsScroll/ContentVBox/ViewMorePanel
	_view_more_btn = $MainHSplit/RightPanel/ModsScroll/ContentVBox/ViewMorePanel/ViewMoreBtn
	_loading_more_label = $MainHSplit/RightPanel/ModsScroll/ContentVBox/LoadingMoreLabel
	_loading_label = $LoadingLabel

	# 连接下载列表相关按钮
	_open_folder_btn.pressed.connect(_on_open_downloads_folder)

	# 隐藏下载部分和下载按钮（用户要求移除）
	_hide_download_features()

	# 设置按钮文字为翻译
	if _search_btn:
		_search_btn.text = t("search")
	if _search_label:
		_search_label.text = t("search")
	if _refresh_btn:
		_refresh_btn.text = t("refresh")
	if _filter_label:
		_filter_label.text = t("nexus_filter")
	if _filter_dropdown:
		_filter_dropdown.set_item_text(0, t("nexus_trending"))
		_filter_dropdown.set_item_text(1, t("nexus_newest"))
		_filter_dropdown.set_item_text(2, t("nexus_most_downloads"))
		_filter_dropdown.set_item_text(3, t("nexus_recently_updated"))
		_filter_dropdown.set_item_text(4, t("nexus_all_mods"))

	# 连接无结果弹窗的关闭按钮
	$NoResultPanel/VBox/CloseBtn.pressed.connect(_hide_no_result_panel)

	# 连接进度窗口的取消按钮
	$ProgressPanel/VBox/CancelBtn.pressed.connect(_on_progress_cancel_pressed)

	# 连接详情弹窗的关闭按钮
	$DetailsPanel/VBox/Header/CloseBtn.pressed.connect(_hide_details_panel)
	$DetailsBG.gui_input.connect(_on_details_bg_clicked)
	$DetailsPanel/VBox/Buttons/PageBtn.pressed.connect(_on_details_page_pressed)
	$DetailsPanel/VBox/Buttons/PageBtn.text = t("nexus_open_page")
	$DetailsPanel/VBox/Buttons/DownloadBtn.text = t("nexus_download_btn")

	# 初始化筛选下拉框
	_init_filter_dropdown()

	# 连接信号
	_search_btn.pressed.connect(_on_search_btn_pressed)
	_refresh_btn.pressed.connect(_on_refresh_btn_pressed)
	_search_edit.text_submitted.connect(_on_search_text_submitted)
	_filter_dropdown.item_selected.connect(_on_filter_changed)
	_view_more_btn.pressed.connect(_on_view_more_pressed)

	# 滚动检测 - 简化为检测滚动到底部
	_mods_scroll.get_v_scroll_bar().value_changed.connect(_on_scroll_changed)

	# 初始加载
	if not nexus_api.api_key.is_empty():
		_reset_and_load()


# ============ 筛选初始化 ============
func _init_filter_dropdown() -> void:
	_filter_dropdown.clear()
	_filter_dropdown.add_item(t("nexus_trending"), FilterType.TRENDING)
	_filter_dropdown.add_item(t("nexus_newest"), FilterType.NEWEST)
	_filter_dropdown.add_item(t("nexus_most_downloads"), FilterType.MOST_DOWNLOADS)
	_filter_dropdown.add_item(t("nexus_recently_updated"), FilterType.UPDATED)
	_filter_dropdown.add_item(t("nexus_all_mods"), FilterType.ALL)
	_filter_dropdown.select(0)


# ============ 公共接口 ============
func set_api_key(api_key: String) -> void:
	nexus_api.set_api_key(api_key)
	# 验证 API key 并自动检测游戏域名
	var validation_result = await nexus_api.validate_api_key()
	if validation_result.success:
		print("[nexus_mods] API key validated, user: " + validation_result.get("username", "unknown"))
	else:
		print("[nexus_mods] API key validation failed: " + validation_result.get("error", "unknown"))
	_reset_and_load()


func set_view_details_callback(callback: Callable) -> void:
	on_view_details_callback = callback


# 刷新UI文本（语言切换时调用）
func refresh_ui_text() -> void:
	# 刷新搜索和筛选相关文本
	if _search_btn:
		_search_btn.text = t("search")
	if _search_label:
		_search_label.text = t("search")
	if _refresh_btn:
		_refresh_btn.text = t("refresh")
	if _filter_label:
		_filter_label.text = t("nexus_filter")
	if _filter_dropdown:
		_filter_dropdown.set_item_text(0, t("nexus_trending"))
		_filter_dropdown.set_item_text(1, t("nexus_newest"))
		_filter_dropdown.set_item_text(2, t("nexus_most_downloads"))
		_filter_dropdown.set_item_text(3, t("nexus_recently_updated"))
		_filter_dropdown.set_item_text(4, t("nexus_all_mods"))

	# 刷新搜索框placeholder
	if _search_edit:
		_search_edit.placeholder_text = t("nexus_search_placeholder")

	# 刷新详情弹窗按钮
	var details_page_btn = $DetailsPanel/VBox/Buttons/PageBtn
	var details_download_btn = $DetailsPanel/VBox/Buttons/DownloadBtn
	if details_page_btn:
		details_page_btn.text = t("nexus_open_page")
	if details_download_btn:
		details_download_btn.text = t("nexus_download_btn")

	# 刷新"无结果"弹窗
	var no_result_close_btn = $NoResultPanel/VBox/CloseBtn
	if no_result_close_btn:
		no_result_close_btn.text = t("nexus_close")

	# 刷新加载更多按钮
	if _view_more_btn:
		_view_more_btn.text = t("nexus_view_more")

	# 刷新下拉加载提示
	if _pull_label:
		_pull_label.text = t("nexus_pull_to_load")

	# 刷新加载提示
	if _loading_label:
		_loading_label.text = t("nexus_loading")
	if _loading_more_label:
		_loading_more_label.text = t("nexus_loading_more")


# ============ 重置与加载 ============
func _reset_and_load() -> void:
	# 清空数据
	all_mods_data.clear()

	# ALL 筛选器 ID 遍历专用状态
	_all_max_mod_id = 0
	_all_current_scan_id = 1
	_all_valid_mods_cache.clear()
	_all_loaded_details.clear()
	_all_initial_load_done = false
	_all_next_batch_index = 0
	_scan_cancelled = false
	_is_scanning = false
	_set_scan_mode(false)  # 确保退出扫描模式

	# 隐藏进度窗口
	_hide_progress_panel()

	# 清除现有卡片
	for child in _mods_grid.get_children():
		child.queue_free()

	current_page = 1
	_has_more_pages = true
	_pull_panel.visible = false
	# ViewMorePanel 不再显示，改为下拉滚动加载
	_view_more_panel.visible = false
	_loading_more_label.visible = false

	# 根据筛选器类型加载
	match _current_filter:
		FilterType.ALL:
			_load_all_mods_initial()
		_:
			_load_mods_with_current_filter()


func _load_mods_with_current_filter() -> void:
	match _current_filter:
		FilterType.TRENDING:
			_load_trending_mods()
		FilterType.NEWEST:
			_load_page_data("newest", current_page)
		FilterType.MOST_DOWNLOADS:
			_load_page_data("most_downloaded", current_page)
		FilterType.UPDATED:
			_load_page_data("updated", current_page)
		FilterType.ALL:
			# ALL 筛选器使用渐进式加载，由 _reset_and_load 调用
			pass


# ============ 非 ALL 筛选器加载 ============
func _load_trending_mods() -> void:
	"""热门模组 - 非 ALL 筛选器，只加载 10 个不显示查看更多"""
	if _is_loading_more:
		return

	_set_loading(true)
	_is_loading_more = true

	_debug_log("[_load_trending_mods] Loading trending mods (limit 10)")

	var result = await nexus_api.get_trending_mods(NON_ALL_INITIAL_COUNT, 1)

	if result.success:
		var mods = result.get("mods", [])
		_debug_log("[_load_trending_mods] Got " + str(mods.size()) + " mods")

		_has_more_pages = false  # 非 ALL 筛选器不显示查看更多

		_append_mods(mods)
		_view_more_panel.visible = false
	else:
		show_error(result.get("error", "Failed to load"))
		_view_more_panel.visible = false

	_is_loading_more = false
	_set_loading(false)


# ============ ALL 筛选器: 渐进式加载（ID 遍历）==========
func _load_all_mods_initial() -> void:
	"""ALL 筛选器: 使用 ID 遍历方式获取模组"""
	var func_start = Time.get_ticks_msec()
	_debug_log("[_load_all_mods_initial] START at " + str(func_start))

	if _is_loading_more:
		return

	_is_loading_more = true
	_is_scanning = true
	_set_scan_mode(true)  # 进入扫描模式，禁用部分UI
	_set_loading(true)
	_scan_cancelled = false

	# 先快速检测最大 mod_id
	_debug_log("[_load_all_mods_initial] Detecting max mod_id...")
	_show_progress_panel()
	_all_max_mod_id = await nexus_api.find_max_mod_id()

	if _scan_cancelled:
		_is_loading_more = false
		_set_loading(false)
		_set_scan_mode(false)
		_hide_progress_panel()
		return

	_debug_log("[_load_all_mods_initial] Max mod_id = " + str(_all_max_mod_id))

	# 初始加载一小批（比如前 20 个 ID）
	var initial_batch_size = 20
	if _all_max_mod_id > 0:
		# 从 ID 1 开始扫描前 initial_batch_size 个
		_all_current_scan_id = 1
		var start_id = 1
		var end_id = mini(initial_batch_size, _all_max_mod_id)

		_debug_log("[_load_all_mods_initial] Initial scan IDs " + str(start_id) + " to " + str(end_id))

		# 更新进度提示
		_progress_status.text = t("nexus_getting_mods_info")
		_progress_bar.value = 0
		_progress_found.text = ""

		# 批量请求
		var mod_ids: Array = []
		for id in range(start_id, end_id + 1):
			mod_ids.append(id)

		_update_progress_panel(end_id)
		var results = await nexus_api.get_mod_details_batch(mod_ids)

		# 处理结果
		for result in results:
			if _scan_cancelled:
				break

			if result.success:
				var mod = result.get("mod", {})
				if mod.size() > 0 and mod.get("name", "") != "":
					_all_valid_mods_cache.append(mod)
					var mod_id = mod.get("mod_id", 0)
					if mod_id > 0:
						_all_loaded_details[mod_id] = mod

		_all_current_scan_id = end_id + 1

	# 显示
	_all_initial_load_done = true
	_display_first_n_mods(_all_valid_mods_cache.size())

	# 显示下拉提示（确保至少显示"下拉加载更多"）
	if _all_current_scan_id <= _all_max_mod_id:
		_pull_panel.visible = true
		_pull_label.text = t("nexus_pull_to_load") + " (" + str(_all_valid_mods_cache.size()) + ")"
	else:
		_pull_panel.visible = false
		_debug_log("[_load_all_mods_initial] Done, total mods: " + str(_all_valid_mods_cache.size()))

	_hide_progress_panel()
	_is_loading_more = false
	_is_scanning = false
	_set_scan_mode(false)
	_set_loading(false)
	var func_end = Time.get_ticks_msec()
	_debug_log("[_load_all_mods_initial] END took " + str(func_end - func_start) + "ms")


func _scan_remaining_ids(start_id: int) -> void:
	"""在后台扫描剩余的 ID（使用批量请求）"""
	var func_start = Time.get_ticks_msec()
	_debug_log("[_scan_remaining_ids] START at " + str(func_start))

	if start_id > _all_max_mod_id:
		return

	if _scan_cancelled:
		return

	_is_loading_more = true
	_is_scanning = true
	_set_scan_mode(true)  # 进入扫描模式，禁用部分UI

	var scan_end = mini(start_id + 49, _all_max_mod_id)
	_debug_log("[_scan_remaining_ids] Batch scanning IDs " + str(start_id) + " to " + str(scan_end))

	# 用于去重的已存在 mod_id 集合
	var existing_ids = {}
	for existing_mod in _all_valid_mods_cache:
		var mid = existing_mod.get("mod_id", 0)
		if mid > 0:
			existing_ids[mid] = true

	# 批量扫描
	var mod_ids: Array = []
	for id in range(start_id, scan_end + 1):
		mod_ids.append(id)

	_update_progress_panel(scan_end)
	var results = await nexus_api.get_mod_details_batch(mod_ids)

	# 处理结果
	for i in range(results.size()):
		if _scan_cancelled:
			break

		var result = results[i]
		if result.success:
			var mod = result.get("mod", {})
			if mod.size() > 0 and mod.get("name", "") != "":
				var mod_id = mod.get("mod_id", 0)
				if mod_id > 0 and existing_ids.has(mod_id):
					continue
				_all_valid_mods_cache.append(mod)
				_all_loaded_details[mod_id] = mod
				if mod_id > 0:
					existing_ids[mod_id] = true

	_all_current_scan_id = scan_end + 1
	_is_loading_more = false
	_is_scanning = false
	_set_scan_mode(false)  # 退出扫描模式

	# 显示下拉提示（替代"查看更多"按钮）
	if _all_current_scan_id <= _all_max_mod_id:
		_pull_panel.visible = true
		_pull_label.text = t("nexus_pull_to_load") + " (" + str(_all_valid_mods_cache.size()) + ")"
	else:
		_pull_panel.visible = false
		_debug_log("[_scan_remaining_ids] Done scanning all IDs, total mods: " + str(_all_valid_mods_cache.size()))

	var func_end = Time.get_ticks_msec()
	_debug_log("[_scan_remaining_ids] END took " + str(func_end - func_start) + "ms")


func _scan_next_batch_ids() -> void:
	"""扫描下一批 ID（由滚动触发）- 找到20个有效模组后停止"""
	var func_start = Time.get_ticks_msec()
	_debug_log("[_scan_next_batch_ids] START at " + str(func_start))

	if _all_current_scan_id > _all_max_mod_id or _scan_cancelled:
		_pull_panel.visible = false
		return

	_is_loading_more = true
	_is_scanning = true
	_set_scan_mode(true)  # 进入扫描模式，禁用部分UI
	_show_progress_panel()  # 显示进度弹窗

	# 更新进度提示
	_progress_status.text = t("nexus_getting_mods_info")
	_progress_bar.value = 0
	_progress_found.text = ""

	const MAX_NEW_MODS_PER_BATCH: int = 20  # 每次最多显示20个新模组
	const BATCH_SIZE: int = 30  # 每次批量请求30个ID
	_debug_log("[_scan_next_batch_ids] Starting batch scan from ID " + str(_all_current_scan_id))

	# 用于去重的已存在 mod_id 集合
	var existing_ids = {}
	for existing_mod in _all_valid_mods_cache:
		var mid = existing_mod.get("mod_id", 0)
		if mid > 0:
			existing_ids[mid] = true

	# 用于追踪本次找到的新模组数量
	var new_mods_this_batch = 0

	# 批量扫描，直到找到20个新模组或到达最大ID
	while new_mods_this_batch < MAX_NEW_MODS_PER_BATCH and _all_current_scan_id <= _all_max_mod_id:
		if _scan_cancelled:
			break

		# 计算这一批要请求的ID数量
		var remaining_ids = _all_max_mod_id - _all_current_scan_id + 1
		var current_batch_size = mini(BATCH_SIZE, remaining_ids)

		# 构建ID列表
		var mod_ids: Array = []
		for i in range(current_batch_size):
			mod_ids.append(_all_current_scan_id + i)

		# 批量请求（一次网络请求获取多个模组）
		_update_progress_panel(_all_current_scan_id + current_batch_size - 1)
		var results = await nexus_api.get_mod_details_batch(mod_ids)

		# 处理结果
		for i in range(results.size()):
			if _scan_cancelled:
				break
			if new_mods_this_batch >= MAX_NEW_MODS_PER_BATCH:
				break

			var result = results[i]
			if result.success:
				var mod = result.get("mod", {})
				if mod.size() > 0 and mod.get("name", "") != "":
					var mod_id = mod.get("mod_id", 0)
					if mod_id > 0 and existing_ids.has(mod_id):
						_debug_log("[_scan_next_batch_ids] Skipping duplicate mod_id: " + str(mod_id))
					else:
						_all_valid_mods_cache.append(mod)
						if mod_id > 0:
							existing_ids[mod_id] = true
						new_mods_this_batch += 1
						_debug_log("[_scan_next_batch_ids] Found: " + mod.get("name", "") + " (id=" + str(mod_id) + ")")

		# 更新扫描位置
		_all_current_scan_id += current_batch_size

		# UI更新
		await get_tree().process_frame

	_is_loading_more = false
	_is_scanning = false
	_set_scan_mode(false)  # 退出扫描模式

	# 隐藏进度窗口
	_hide_progress_panel()

	# 刷新显示
	_refresh_mods_display()

	# 显示下拉提示
	if _all_current_scan_id <= _all_max_mod_id:
		_pull_panel.visible = true
		_pull_label.text = t("nexus_pull_to_load") + " (" + str(_all_valid_mods_cache.size()) + ")"
	else:
		_pull_panel.visible = false
		_debug_log("[_scan_next_batch_ids] Done, total mods: " + str(_all_valid_mods_cache.size()))

	var func_end = Time.get_ticks_msec()
	_debug_log("[_scan_next_batch_ids] END took " + str(func_end - func_start) + "ms")


func _display_first_n_mods(count: int) -> void:
	"""显示前 N 个模组"""
	_debug_log("[_display_first_n_mods] Displaying first " + str(count) + " mods")

	# 清除现有卡片
	for child in _mods_grid.get_children():
		child.queue_free()
	all_mods_data.clear()

	# 显示前 N 个（从缓存中）
	var display_count = mini(count, _all_valid_mods_cache.size())
	for i in range(display_count):
		var mod_data = _all_valid_mods_cache[i]
		if mod_data.size() > 0:
			var card = _create_mod_card(mod_data)
			_mods_grid.add_child(card)
			all_mods_data.append(mod_data)

	_all_next_batch_index = display_count


func _load_next_batch_details() -> void:
	"""已废弃 - 使用 _scan_next_batch_ids 代替"""
	_scan_next_batch_ids()


func _refresh_mods_display() -> void:
	"""刷新模组显示"""
	for child in _mods_grid.get_children():
		child.queue_free()
	all_mods_data.clear()

	# 显示所有已加载的（从缓存中）
	var count = 0
	for mod_data in _all_valid_mods_cache:
		if mod_data.size() > 0:
			var card = _create_mod_card(mod_data)
			_mods_grid.add_child(card)
			all_mods_data.append(mod_data)
			count += 1

	_debug_log("[_refresh_mods_display] Displayed " + str(count) + " mods")


func _load_more_mod_ids() -> void:
	"""加载更多 mod ID（分页）"""
	if _is_loading_more:
		return

	_is_loading_more = true
	_loading_more_label.visible = true

	# 获取下一页数据
	var page_to_load = (_all_pending_mod_ids.size() / 20) + 1
	_debug_log("[_load_more_mod_ids] Loading page " + str(page_to_load))

	# 使用 ALL 筛选器专用函数获取下一页
	var result = await nexus_api.get_all_mods_for_all_filter(page_to_load, 20)

	if result.success:
		var mods = result.get("mods", [])
		_debug_log("[_load_more_mod_ids] Got " + str(mods.size()) + " new mods")

		for mod in mods:
			var mod_id = mod.get("mod_id", 0)
			if mod_id > 0 and not _all_pending_mod_ids.has(mod_id):
				_all_pending_mod_ids.append(mod_id)
				_all_loaded_details[mod_id] = mod

		_has_more_pages = result.get("has_more", false)
	else:
		_has_more_pages = false

	_is_loading_more = false
	_loading_more_label.visible = false

	# 更新"查看更多"按钮
	_update_view_more_button()


# ============ 非 ALL 筛选器（已禁用"查看更多"，固定10个）==========
func _load_page_data(sort_type: String, page: int) -> void:
	if _is_loading_more:
		return

	_is_loading_more = true
	_set_loading(true)

	_debug_log("[_load_page_data] Loading " + sort_type + " (limit 10)")

	var result
	match sort_type:
		"newest":
			result = await nexus_api.get_latest_added(NON_ALL_INITIAL_COUNT, 1)
		"most_downloaded":
			result = await nexus_api.get_most_downloaded(NON_ALL_INITIAL_COUNT, 1)
		"updated":
			result = await nexus_api.get_latest_updated(NON_ALL_INITIAL_COUNT, 1)
		"trending":
			# 使用支持分页的 trending API
			result = await nexus_api.get_trending_mods(NON_ALL_INITIAL_COUNT, 1)
		"search":
			result = await nexus_api.search_mods(current_search_query, 1, NON_ALL_INITIAL_COUNT)
		_:
			result = await nexus_api.search_mods(current_search_query, 1, NON_ALL_INITIAL_COUNT)

	if result.success:
		var mods = result.get("mods", [])
		_debug_log("[_load_page_data] Got " + str(mods.size()) + " mods")

		# 非 ALL 筛选器不使用分页，固定 10 个
		_has_more_pages = false

		_append_mods(_limit_mods_to_10(mods))
		# 非 ALL 筛选器不显示查看更多按钮
		_view_more_panel.visible = false
	else:
		show_error(result.get("error", "Failed to load"))
		_has_more_pages = false

	_is_loading_more = false
	_set_loading(false)


func _limit_mods_to_10(mods: Array) -> Array:
	"""限制模组列表最多 10 个"""
	if mods.size() <= NON_ALL_INITIAL_COUNT:
		return mods
	return mods.slice(0, NON_ALL_INITIAL_COUNT)


func _append_mods(mods: Array) -> void:
	_debug_log("[_append_mods] mods=" + str(mods.size()))

	if mods.is_empty() and all_mods_data.is_empty():
		_show_no_result_message(t("nexus_no_results"))
		return

	_hide_no_result_panel()

	# 去重：检查是否已存在相同 mod_id 的模组
	var existing_ids = {}
	for existing_mod in all_mods_data:
		var mod_id = existing_mod.get("mod_id", 0)
		if mod_id > 0:
			existing_ids[mod_id] = true

	# 创建卡片（去重）
	var new_mods_count = 0
	for mod_data in mods:
		var mod_id = mod_data.get("mod_id", 0)
		if mod_id > 0 and existing_ids.has(mod_id):
			_debug_log("[_append_mods] Skipping duplicate mod_id: " + str(mod_id))
			continue

		var card = _create_mod_card(mod_data)
		_mods_grid.add_child(card)
		all_mods_data.append(mod_data)
		if mod_id > 0:
			existing_ids[mod_id] = true
		new_mods_count += 1

	_debug_log("[_append_mods] total cards=" + str(all_mods_data.size()) + ", new this page: " + str(new_mods_count))

	# 如果新加载的数据全都被去重（API返回相同数据），停止分页
	if new_mods_count == 0 and mods.size() > 0:
		_debug_log("[_append_mods] No new mods, stopping pagination")
		_has_more_pages = false
		_view_more_panel.visible = false
		return

	# 延迟一帧确保布局更新后再检查是否需要加载更多
	await get_tree().process_frame

	# 不再自动加载更多，显示"查看更多"按钮（如果还有更多）
	_update_view_more_button()


# ============ 创建模组卡片 ============
func _create_mod_card(mod_data: Dictionary) -> Control:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var main_vbox = VBoxContainer.new()
	panel.add_child(main_vbox)

	# 图片区域
	var texture_rect = TextureRect.new()
	texture_rect.custom_minimum_size = Vector2(160, 120)
	texture_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.modulate = Color(0.3, 0.3, 0.3, 1)
	main_vbox.add_child(texture_rect)

	# 信息区域
	var info_margin = MarginContainer.new()
	info_margin.add_theme_constant_override("margin_left", 8)
	info_margin.add_theme_constant_override("margin_right", 8)
	info_margin.add_theme_constant_override("margin_top", 8)
	info_margin.add_theme_constant_override("margin_bottom", 8)
	main_vbox.add_child(info_margin)

	var info_vbox = VBoxContainer.new()
	info_margin.add_child(info_vbox)

	# 名称
	var name_label = Label.new()
	name_label.text = mod_data.get("name", "Unknown")
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_child(name_label)

	# 作者
	var author_label = Label.new()
	var user_data = mod_data.get("user")
	var author_name = "Unknown"
	if user_data is Dictionary:
		author_name = user_data.get("name", "Unknown")
	author_label.text = t("nexus_author") + author_name
	author_label.add_theme_font_size_override("font_size", 12)
	author_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
	info_vbox.add_child(author_label)

	# 下载量
	var downloads_label = Label.new()
	var downloads = int(mod_data.get("mod_downloads", 0))
	if downloads == 0:
		downloads = int(mod_data.get("downloads", 0))
	downloads_label.text = t("nexus_downloads") + _format_number(downloads)
	downloads_label.add_theme_font_size_override("font_size", 12)
	downloads_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
	info_vbox.add_child(downloads_label)

	# 按钮区域
	var btn_hbox = HBoxContainer.new()
	btn_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_child(btn_hbox)

	# 查看详情按钮
	var view_btn = Button.new()
	view_btn.text = t("nexus_view_details")
	view_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view_btn.pressed.connect(_on_view_pressed.bind(mod_data))
	btn_hbox.add_child(view_btn)

	# 点击整个卡片也能查看详情
	panel.gui_input.connect(_on_mod_card_clicked.bind(mod_data))

	# 添加淡入动画（设置初始透明度为0，然后渐显）
	panel.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)

	# 异步加载图片
	var picture_url = mod_data.get("picture_url", "")
	var mod_id = int(mod_data.get("mod_id", 0))
	if not picture_url.is_empty() and mod_id != 0:
		_load_mod_image_async(picture_url, mod_id, texture_rect)

	return panel


# ============ 图片加载 ============
func _load_mod_image_async(url: String, mod_id: int, texture_rect: TextureRect) -> void:
	# 使用计时器延迟加载图片，不阻塞 UI 初始化
	var timer = get_tree().create_timer(0.05)
	await timer.timeout
	# 异步加载图片，最多重试2次
	_load_mod_image_with_retry(url, mod_id, texture_rect, 2)


func _load_mod_image_with_retry(url: String, mod_id: int, texture_rect: TextureRect, max_retries: int) -> void:
	"""带重试的图片加载"""
	for attempt in range(max_retries):
		if not is_instance_valid(texture_rect):
			return

		var success = await _load_mod_image_task(url, mod_id, texture_rect)
		if success:
			return

		# 失败后等待一下再重试
		if attempt < max_retries - 1:
			var timer = get_tree().create_timer(0.5)
			await timer.timeout

	_debug_log("[_load_mod_image_with_retry] Failed after " + str(max_retries) + " attempts: " + url)


func _load_mod_image_task(url: String, mod_id: int, texture_rect: TextureRect) -> bool:
	"""加载图片，返回是否成功"""
	# 检查缓存
	var cached_path = await nexus_api.download_image_to_cache(url, mod_id)
	if not cached_path.is_empty() and is_instance_valid(texture_rect):
		var texture = load(cached_path)
		if texture:
			texture_rect.texture = texture
			texture_rect.modulate = Color.WHITE
			return true

	# 简化的HTTP加载
	var url_str = url
	var host_start = url_str.find("://") + 3 if url_str.find("://") >= 0 else 0
	var remaining = url_str.substr(host_start)
	var path_idx = remaining.find("/")
	var host = remaining.substr(0, path_idx) if path_idx >= 0 else remaining
	var img_path = remaining.substr(path_idx) if path_idx >= 0 else "/"

	var http_client = HTTPClient.new()
	var tls_options = TLSOptions.client()
	var err = http_client.connect_to_host(host, 443, tls_options)
	if err != OK:
		return false

	# 超时时间10秒
	var timeout = Time.get_ticks_msec() + 10000
	while http_client.get_status() in [HTTPClient.STATUS_CONNECTING, HTTPClient.STATUS_RESOLVING]:
		http_client.poll()
		await get_tree().process_frame
		if Time.get_ticks_msec() > timeout:
			return false

	if http_client.get_status() != HTTPClient.STATUS_CONNECTED:
		return false

	var headers = PackedStringArray(["User-Agent: NexusApiClient/1.17.0", "Accept: image/*"])
	if http_client.request(HTTPClient.METHOD_GET, img_path, headers) != OK:
		return false

	while http_client.get_status() == HTTPClient.STATUS_REQUESTING:
		http_client.poll()
		await get_tree().process_frame

	if http_client.get_status() != HTTPClient.STATUS_BODY:
		return false

	var body = PackedByteArray()
	while http_client.get_status() == HTTPClient.STATUS_BODY:
		var chunk = http_client.read_response_body_chunk()
		if chunk.size() > 0:
			body.append_array(chunk)
		else:
			await get_tree().process_frame

	if body.is_empty():
		return false

	var image = Image.new()
	var error = image.load_webp_from_buffer(body)
	if error != OK:
		error = image.load_png_from_buffer(body)
	if error != OK:
		error = image.load_jpg_from_buffer(body)

	if error != OK or not is_instance_valid(texture_rect):
		return false

	var texture = ImageTexture.create_from_image(image)
	if texture:
		texture_rect.texture = texture
		texture_rect.modulate = Color.WHITE
		return true

	return false


# ============ 滚动检测 ============
func _on_scroll_changed(value: float) -> void:
	if not is_instance_valid(_mods_scroll):
		return

	var scroll_bar = _mods_scroll.get_v_scroll_bar()
	if not is_instance_valid(scroll_bar):
		return

	var max_value = scroll_bar.max_value
	var page_size = scroll_bar.page
	var max_scroll = max_value - page_size

	if max_scroll <= 0:
		_pull_panel.visible = false
		return

	# 显示下滑提示（距离底部50像素内）
	if value >= max_scroll - 50:
		_pull_panel.visible = true
		if _current_filter == FilterType.ALL:
			# ALL 筛选器 - 使用 ID 遍历
			if _all_current_scan_id <= _all_max_mod_id:
				_pull_label.text = t("nexus_pull_to_load") + " (" + str(_all_valid_mods_cache.size()) + ")"
				# 触发加载更多
				if not _is_loading_more:
					_scan_next_batch_ids()
			else:
				_pull_label.text = t("nexus_no_more")
		else:
			_pull_label.text = t("nexus_no_more")
	else:
		_pull_panel.visible = false


func _trigger_next_batch_scan() -> void:
	"""触发下一批扫描（ALL 筛选器 - 使用 API 分页）"""
	if _current_filter != FilterType.ALL:
		return
	if _is_loading_more:
		return

	# 计算当前页码
	var current_count = _all_valid_mods_cache.size()
	var next_page = (current_count / 50) + 1

	# 显示加载状态
	_pull_label.text = t("nexus_loading_more")
	_pull_panel.visible = true

	# 显示进度窗口
	_show_progress_panel()

	_is_loading_more = true
	_is_scanning = true
	_set_scan_mode(true)

	# 使用 API 获取下一页
	var result = await nexus_api.get_all_mods_for_all_filter(next_page, 50)

	if result.success:
		var mods = result.get("mods", [])
		for mod in mods:
			var mod_id = mod.get("mod_id", 0)
			if mod_id > 0:
				# 检查是否已存在
				var exists = false
				for existing in _all_valid_mods_cache:
					if int(existing.get("mod_id", 0)) == mod_id:
						exists = true
						break
				if not exists:
					_all_valid_mods_cache.append(mod)

	# 刷新显示
	_refresh_mods_display()

	_is_loading_more = false
	_is_scanning = false
	_set_scan_mode(false)
	_hide_progress_panel()

	# 更新提示
	if _all_valid_mods_cache.size() >= 50 * next_page:
		_pull_panel.visible = true
		_pull_label.text = t("nexus_pull_to_load") + " (" + str(_all_valid_mods_cache.size()) + ")"
	else:
		_pull_panel.visible = false


func _load_next_page() -> void:
	_debug_log("[_load_next_page] START: loading=" + str(_is_loading_more) + ", has_more=" + str(_has_more_pages) + ", page=" + str(current_page))

	if _is_loading_more or not _has_more_pages:
		_debug_log("[_load_next_page] Early return: loading=" + str(_is_loading_more) + ", has_more=" + str(_has_more_pages))
		return

	# 非 ALL 筛选器的分页加载
	match _current_filter:
		FilterType.ALL:
			# ALL 筛选器不使用此方法，使用 _load_next_batch_details
			pass
		FilterType.TRENDING:
			current_page += 1
			_load_trending_mods()
		FilterType.NEWEST:
			current_page += 1
			_load_page_data("newest", current_page)
		FilterType.MOST_DOWNLOADS:
			current_page += 1
			_load_page_data("most_downloaded", current_page)
		FilterType.UPDATED:
			current_page += 1
			_load_page_data("updated", current_page)


func _get_sort_type() -> String:
	match _current_filter:
		FilterType.NEWEST:
			return "newest"
		FilterType.MOST_DOWNLOADS:
			return "most_downloaded"
		FilterType.UPDATED:
			return "updated"
		_:
			return "trending"


func _load_search_page(page: int) -> void:
	_debug_log("[_load_search_page] Loading search page " + str(page))
	_load_page_data("search", page)


# ============ 事件处理 ============
func _on_search_btn_pressed() -> void:
	current_search_query = _search_edit.text.strip_edges()

	if current_search_query.is_empty():
		# 如果搜索词为空，切换到默认筛选器
		_current_filter = FilterType.TRENDING
		_filter_dropdown.select(0)
		current_page = 1
		_reset_and_load()
		return

	# 构建 Nexus 搜索 URL（使用浏览器跳转方案）
	var game_domain = nexus_api.GAME_DOMAIN
	var search_url = "https://www.nexusmods.com/games/%s/search?keyword=%s" % [game_domain, current_search_query.uri_encode()]

	# 用默认浏览器打开
	OS.shell_open(search_url)

	# 清空搜索框
	_search_edit.text = ""
	current_search_query = ""


func _perform_client_search(query: String) -> void:
	"""执行客户端搜索：加载模组并过滤"""
	_debug_log("[_perform_client_search] Loading mods for client-side search")

	# 加载热门模组作为搜索数据源
	var result = await nexus_api.get_trending_mods(100, 1)

	if not result.success:
		_debug_log("[_perform_client_search] Failed to load mods: " + result.get("error", "unknown"))
		_set_loading(false)
		_show_no_result_message(t("nexus_search_failed") + ": " + result.get("error", ""))
		return

	var all_mods = result.get("mods", [])
	_debug_log("[_perform_client_search] Loaded " + str(all_mods.size()) + " mods for filtering")

	# 在客户端过滤
	var query_lower = query.to_lower()
	var filtered_mods: Array = []

	for mod in all_mods:
		var name = mod.get("name", "").to_lower()
		var summary = mod.get("summary", "").to_lower()
		var description = mod.get("description", "").to_lower()
		var author_name = ""
		var user_data = mod.get("user", {})
		if user_data is Dictionary:
			author_name = user_data.get("name", "").to_lower()

		# 检查是否匹配搜索词
		if name.find(query_lower) >= 0 or summary.find(query_lower) >= 0 or description.find(query_lower) >= 0 or author_name.find(query_lower) >= 0:
			filtered_mods.append(mod)

	_debug_log("[_perform_client_search] Filtered to " + str(filtered_mods.size()) + " mods matching '" + query + "'")

	_set_loading(false)

	if filtered_mods.is_empty():
		_show_no_result_message(t("nexus_no_results") + "\n\n" + t("nexus_search_tip"))
	else:
		_hide_no_result_panel()
		_append_mods(filtered_mods)


func _on_refresh_btn_pressed() -> void:
	_reset_and_load()


func _on_filter_changed(index: int) -> void:
	if _is_scanning:
		_show_progress_panel()
		_progress_status.text = t("nexus_cancelling_scan")
		_scan_cancelled = true
		await get_tree().process_frame
	_current_filter = _filter_dropdown.get_item_id(index)
	current_search_query = ""
	_search_edit.text = ""
	_reset_and_load()


func _on_search_text_submitted(text: String) -> void:
	_on_search_btn_pressed()


func _check_need_load_more() -> void:
	"""禁用自动加载更多（只通过按钮触发）"""
	return


# ============ "查看更多"按钮功能（已禁用）===========
func _show_view_more_button() -> void:
	"""显示"查看更多"按钮（已禁用，始终隐藏）"""
	_view_more_panel.visible = false


func _update_view_more_button() -> void:
	"""根据筛选器类型更新"查看更多"按钮（已禁用，始终隐藏）"""
	_view_more_panel.visible = false


func _on_view_more_pressed() -> void:
	"""点击"查看更多"按钮"""
	if _current_filter == FilterType.ALL:
		# ALL 筛选器：渐进式加载下一批详情
		_load_next_batch_details()
	else:
		_load_next_page()


func _on_mod_card_clicked(event: InputEvent, mod_data: Dictionary) -> void:
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_on_view_pressed(mod_data)


# ============ 工具函数 ============
static func _format_number(num: int) -> String:
	if num >= 1000000:
		return "%.1fM" % (num / 1000000.0)
	elif num >= 1000:
		return "%.1fK" % (num / 1000.0)
	else:
		return str(num)


func _set_loading(loading: bool) -> void:
	_loading_label.visible = loading
	_mods_scroll.visible = not loading


func _set_scan_mode(scanning: bool) -> void:
	"""设置扫描模式，扫描时禁用部分UI操作以提升性能"""
	if scanning:
		# 禁用搜索和刷新按钮
		_search_btn.disabled = true
		_refresh_btn.disabled = true
		_filter_dropdown.disabled = true
		_search_edit.editable = false
	else:
		# 恢复UI
		_search_btn.disabled = false
		_refresh_btn.disabled = false
		_filter_dropdown.disabled = false
		_search_edit.editable = true


func show_error(message: String) -> void:
	_debug_log("[show_error] " + message)
	_show_no_result_message(t("nexus_error_prefix") + message)
	_hide_progress_panel()
	# 确保扫描模式被禁用
	_is_scanning = false
	_set_scan_mode(false)


func _create_no_result_panel() -> void:
	"""显示无结果弹窗（静态节点已存在）"""
	_show_no_result_message("")


func _show_no_result_message(message: String) -> void:
	"""显示无结果消息"""
	if not is_instance_valid(_no_result_panel):
		return

	# 设置消息文本
	var vbox = _no_result_panel.get_node_or_null("VBox")
	if vbox:
		var msg_label = vbox.get_node_or_null("Msg") as Label
		if msg_label:
			msg_label.text = message if not message.is_empty() else t("nexus_no_results")

	# 显示背景和弹窗
	if is_instance_valid(_no_result_bg):
		_no_result_bg.visible = true
	_no_result_panel.visible = true


func _hide_no_result_panel() -> void:
	"""隐藏无结果弹窗"""
	if is_instance_valid(_no_result_panel):
		_no_result_panel.visible = false
	if is_instance_valid(_no_result_bg):
		_no_result_bg.visible = false


# ============ 进度信息窗口 ============
func _create_progress_panel() -> void:
	"""显示进度窗口（静态节点）"""
	_show_progress_panel()


func _show_progress_panel() -> void:
	"""显示进度窗口"""
	if not is_instance_valid(_progress_panel):
		return
	_progress_title.text = t("nexus_scanning")
	_progress_status.text = ""
	_progress_bar.value = 0
	_progress_found.text = ""
	_progress_panel.visible = true


func _hide_download_features() -> void:
	"""隐藏下载相关功能（用户要求移除）"""
	var downloads_section = get_node_or_null("MainHSplit/LeftPanel/DownloadsSection")
	if downloads_section:
		downloads_section.visible = false

	var details_download_btn = get_node_or_null("DetailsPanel/VBox/Buttons/DownloadBtn")
	if details_download_btn:
		details_download_btn.visible = false


func _hide_progress_panel() -> void:
	"""隐藏进度窗口"""
	if is_instance_valid(_progress_panel):
		_progress_panel.visible = false


func _update_progress_panel(current_id: int) -> void:
	"""更新进度信息"""
	if not is_instance_valid(_progress_panel):
		return

	var progress_percent = 0.0
	if _all_max_mod_id > 0:
		progress_percent = float(current_id) / float(_all_max_mod_id) * 100.0

	_progress_status.text = t("nexus_scanned_ids") % [current_id, _all_max_mod_id]
	_progress_bar.value = progress_percent
	_progress_found.text = t("nexus_found_mods") % _all_valid_mods_cache.size()


func _on_progress_cancel_pressed() -> void:
	"""取消扫描"""
	_scan_cancelled = true
	_hide_progress_panel()
	_is_loading_more = false
	_is_scanning = false
	_set_scan_mode(false)  # 确保退出扫描模式


# ============ 详情信息窗 ============
func _create_details_panel() -> void:
	"""显示详情信息窗（静态节点已存在）"""
	_show_details_panel({})


func _show_details_panel(mod_data: Dictionary) -> void:
	"""显示详情信息窗"""
	if not is_instance_valid(_details_panel):
		return

	_details_mod_data = mod_data

	# 填充数据
	var name = mod_data.get("name", "")
	var user_data = mod_data.get("user", {})
	var author = ""
	if user_data is Dictionary:
		author = user_data.get("name", "Unknown")
	var downloads = mod_data.get("mod_downloads", 0)
	if downloads == 0:
		downloads = mod_data.get("downloads", 0)
	var version = mod_data.get("version", "未知")
	var description = mod_data.get("summary", mod_data.get("description", ""))
	var picture_url = mod_data.get("picture_url", "")
	var mod_id = mod_data.get("mod_id", 0)

	_details_name.text = name
	_details_author.text = t("nexus_author") + author
	_details_downloads.text = t("nexus_downloads") + _format_number(int(downloads))
	_details_version.text = t("nexus_version") + version

	if description.is_empty():
		description = t("nexus_no_description")
	_details_description.text = description

	# 加载图片
	_details_image.modulate = Color(0.5, 0.5, 0.5, 1)
	_details_image.texture = null
	if not picture_url.is_empty() and mod_id != 0:
		_load_details_image_async(picture_url, mod_id)

	# 显示面板
	if is_instance_valid(_details_bg):
		_details_bg.visible = true
	_details_panel.visible = true


func _hide_details_panel() -> void:
	"""隐藏详情信息窗"""
	if is_instance_valid(_details_panel):
		_details_panel.visible = false
	if is_instance_valid(_details_bg):
		_details_bg.visible = false


func _load_details_image_async(url: String, mod_id: int) -> void:
	"""异步加载详情图片"""
	var cached_path = await nexus_api.download_image_to_cache(url, mod_id)
	if not cached_path.is_empty() and is_instance_valid(_details_image):
		var texture = load(cached_path)
		if texture:
			_details_image.texture = texture
			_details_image.modulate = Color.WHITE
			return

	# 如果缓存中没有，尝试直接下载（带重试）
	await _load_mod_image_with_retry(url, mod_id, _details_image, 3)


func _on_details_bg_clicked(event: InputEvent) -> void:
	"""点击背景关闭详情窗"""
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_hide_details_panel()


func _on_details_page_pressed() -> void:
	"""打开模组页面"""
	if _details_mod_data.is_empty():
		return
	var mod_id = int(_details_mod_data.get("mod_id", 0))
	if mod_id > 0:
		# 构建Nexus模组页面URL
		var page_url = "https://www.nexusmods.com/slaythespire2/mods/" + str(mod_id)
		OS.shell_open(page_url)

func _on_view_pressed(mod_data: Dictionary) -> void:
	_show_details_panel(mod_data)


func get_nexus_api() -> NexusAPI:
	return nexus_api


# ============ 二分查找进度信号处理 ============
func _on_binary_search_progress(current_attempt: int, total_attempts: int, current_range: String) -> void:
	"""处理二分查找进度更新"""
	# 更新屏幕中央加载提示
	_loading_label.text = t("nexus_binary_search_progress") % [current_attempt, total_attempts, current_range]

	# 同步更新进度弹窗（如果显示了）
	if is_instance_valid(_progress_panel) and _progress_panel.visible:
		_progress_status.text = t("nexus_binary_search_progress") % [current_attempt, total_attempts, current_range]
		# 更新进度条
		var progress_percent = float(current_attempt) / float(total_attempts) * 100.0
		_progress_bar.value = progress_percent


# ============ 下载列表功能 ============
func _on_open_downloads_folder() -> void:
	"""打开下载文件夹"""
	var downloads_path = nexus_api.downloads_dir if nexus_api else "downloads"
	print("[NexusMods] Opening downloads folder: " + downloads_path)
	OS.shell_open(downloads_path)


func add_downloading_item(mod_name: String) -> void:
	"""添加一个正在下载的项目到列表"""
	_downloading_items.append({
		"name": mod_name,
		"status": t("nexus_downloading"),
		"progress": 0.0
	})
	_refresh_downloads_list()


func add_downloaded_item(file_path: String, mod_name: String) -> void:
	"""添加一个已下载的项目到列表"""
	_downloaded_items.append({
		"path": file_path,
		"name": mod_name,
		"time": Time.get_datetime_string_from_system()
	})
	_refresh_downloads_list()


func _refresh_downloads_list() -> void:
	"""刷新下载列表显示"""
	# 清空现有列表
	for child in _downloads_vbox.get_children():
		child.queue_free()

	# 添加正在下载的项目
	for item in _downloading_items:
		var item_panel = _create_download_item(item.get("name", ""), item.get("status", ""), true)
		_downloads_vbox.add_child(item_panel)

	# 添加已下载的项目
	for item in _downloaded_items:
		var item_panel = _create_download_item(item.get("name", ""), t("nexus_download_complete"), false)
		_downloads_vbox.add_child(item_panel)


func _create_download_item(name: String, status: String, is_downloading: bool) -> Control:
	"""创建下载项控件"""
	var hbox = HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var label = Label.new()
	label.text = name
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hbox.add_child(label)

	var status_label = Label.new()
	status_label.text = status
	status_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
	status_label.add_theme_font_size_override("font_size", 10)
	hbox.add_child(status_label)

	return hbox


func update_download_progress(mod_name: String, progress: float, status: String) -> void:
	"""更新下载进度"""
	for item in _downloading_items:
		if item.get("name", "") == mod_name:
			item["progress"] = progress
			item["status"] = status
			break
	_refresh_downloads_list()
