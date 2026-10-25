extends Control

const FONT = preload("res://assets/fonts/ui_font.tres")
const INK = Color("173e36")
const MINT = Color("dcead8")
const GOLD = Color("e8b44b")
const CORAL = Color("d76c53")
const PAPER = Color("fcfaf3")
const CELL = 40
const ORIGIN = Vector2(40, 230)
const GRID = Vector2i(16, 12)
const NAMES = ["成績單", "推薦信", "自傳"]
const COLORS = [Color("6cae96"), Color("e8b44b"), Color("d8917d")]
var mode = "home"
var level = 1
var score = 0
var best = 0
var remaining = 75.0
var snake: Array[Vector2i] = []
var direction = Vector2i.RIGHT
var turns: Array[Vector2i] = []
var documents: Array[Dictionary] = []
var blocks: Array[Vector2i] = []
var counts = [0, 0, 0]
var clock = 0.0
var grace = 1.5
var flash = 0.0
var message = ""
var reason = ""
var muted = false
var ui: Control
var audio: AudioStreamPlayer
var sounds = {}
var hero: Texture2D
var swipe_start = Vector2.ZERO
var rng = RandomNumberGenerator.new()
var snapshot_clock = 0.0

func _ready():
	rng.randomize()
	if ResourceLoader.exists("res://assets/campus.png"):
		hero = load("res://assets/campus.png")
	audio = AudioStreamPlayer.new()
	add_child(audio)
	for sound in ["collect", "fail", "win", "turn"]:
		sounds[sound] = load("res://assets/audio/" + sound + ".wav")
	var cfg = ConfigFile.new()
	if cfg.load("user://scholarship.cfg") == OK:
		best = int(cfg.get_value("record", "best", 0))
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)
	build_ui()

func box(r: Rect2, color: Color, radius = 16):
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	draw_style_box(style, r)

func label_at(text: String, p: Vector2, size_px = 24, color = INK):
	draw_string(FONT, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)

func centered(text: String, y: float, size_px = 24, color = INK):
	draw_string(FONT, Vector2(0, y), text, HORIZONTAL_ALIGNMENT_CENTER, 720, size_px, color)

func button(text: String, rect: Rect2, action: Callable, primary = false):
	var b = Button.new()
	b.text = text
	b.position = rect.position
	b.size = rect.size
	b.add_theme_font_override("font", FONT)
	b.add_theme_font_size_override("font_size", 25)
	b.add_theme_color_override("font_color", PAPER if primary else INK)
	b.add_theme_color_override("font_hover_color", PAPER if primary else INK)
	for state in ["normal", "hover", "pressed", "focus"]:
		var s = StyleBoxFlat.new()
		s.bg_color = INK.lightened(0.12) if primary else MINT
		if state == "pressed": s.bg_color = GOLD
		s.set_corner_radius_all(16)
		b.add_theme_stylebox_override(state, s)
	b.pressed.connect(action)
	b.focus_mode = Control.FOCUS_NONE
	ui.add_child(b)

func build_ui():
	for child in ui.get_children():
		ui.remove_child(child)
		child.queue_free()
	button("聲音：關" if muted else "聲音：開", Rect2(520, 28, 160, 48), toggle_sound)
	match mode:
		"home":
			button("開始申請  →", Rect2(60, 738, 600, 68), start_game, true)
			button("玩法與素材來源", Rect2(60, 824, 600, 58), func(): change_mode("help"))
		"help":
			button("回到首頁", Rect2(60, 850, 600, 64), func(): change_mode("home"), true)
		"play", "paused":
			button("繼續" if mode == "paused" else "暫停", Rect2(40, 28, 120, 48), toggle_pause)
			button("↑", Rect2(300, 760, 120, 78), func(): turn(Vector2i.UP))
			button("←", Rect2(160, 850, 120, 78), func(): turn(Vector2i.LEFT))
			button("↓", Rect2(300, 850, 120, 78), func(): turn(Vector2i.DOWN))
			button("→", Rect2(440, 850, 120, 78), func(): turn(Vector2i.RIGHT))
		"stage":
			button("前往下一輪  →", Rect2(60, 680, 600, 68), next_stage, true)
			button("回到首頁", Rect2(60, 770, 600, 60), func(): change_mode("home"))
		"result":
			button("再挑戰一次", Rect2(60, 680, 600, 68), start_game, true)
			button("回到首頁", Rect2(60, 770, 600, 60), func(): change_mode("home"))
	queue_redraw()

func change_mode(value: String):
	mode = value
	build_ui()

func toggle_sound():
	muted = not muted
	if muted: audio.stop()
	build_ui()

func tone(sound: String):
	if not muted and sounds.has(sound):
		audio.stream = sounds[sound]
		audio.play()

func start_game():
	level = 1
	score = 0
	setup_stage()

func next_stage():
	level += 1
	setup_stage()

func setup_stage():
	snake.assign([Vector2i(4, 6), Vector2i(3, 6), Vector2i(2, 6)])
	direction = Vector2i.RIGHT
	turns.clear()
	counts = [0, 0, 0]
	remaining = 75.0
	clock = 0.0
	grace = 1.5
	blocks.clear()
	if level >= 2:
		blocks.assign([Vector2i(7, 3), Vector2i(8, 3), Vector2i(7, 9), Vector2i(8, 9)])
	if level >= 3:
		blocks.append_array([Vector2i(3, 3), Vector2i(12, 8)])
	documents.clear()
	for kind in range(3): spawn_document(kind)
	message = "準備出發！收齊三類文件各 2 份"
	flash = 2.0
	change_mode("play")

func spawn_document(kind: int):
	var free: Array[Vector2i] = []
	for y in range(GRID.y):
		for x in range(GRID.x):
			var p = Vector2i(x, y)
			if p in snake or p in blocks: continue
			var occupied = false
			for doc in documents:
				if doc.pos == p: occupied = true
			if not occupied: free.append(p)
	if not free.is_empty():
		documents.append({"pos": free[rng.randi_range(0, free.size() - 1)], "kind": kind})

func turn(value: Vector2i):
	if mode != "play": return
	var last = direction if turns.is_empty() else turns.back()
	if value == -last:
		message = "不能直接回頭，請先向側邊轉彎"
		flash = 1.1
		tone("turn")
		return
	if value != last and turns.size() < 2: turns.append(value)

func toggle_pause():
	if mode == "play": change_mode("paused")
	elif mode == "paused":
		grace = 1.0
		change_mode("play")

func _notification(what):
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and mode == "play":
		change_mode("paused")

func _input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_UP, KEY_W: turn(Vector2i.UP)
			KEY_DOWN, KEY_S: turn(Vector2i.DOWN)
			KEY_LEFT, KEY_A: turn(Vector2i.LEFT)
			KEY_RIGHT, KEY_D: turn(Vector2i.RIGHT)
			KEY_ESCAPE, KEY_P: toggle_pause()
	if event is InputEventScreenTouch:
		if event.pressed: swipe_start = event.position
		elif mode == "play":
			var delta = event.position - swipe_start
			if delta.length() > 28:
				if abs(delta.x) > abs(delta.y): turn(Vector2i.RIGHT if delta.x > 0 else Vector2i.LEFT)
				else: turn(Vector2i.DOWN if delta.y > 0 else Vector2i.UP)

func _process(delta):
	flash = maxf(0, flash - delta)
	if mode == "play":
		if grace > 0: grace -= delta
		else:
			remaining = maxf(0, remaining - delta)
			if remaining <= 0: finish(false, "申請截止了！下次記得提早準備。")
			else:
				clock += delta
				var interval = [0.26, 0.21, 0.17][level - 1]
				if clock >= interval:
					clock -= interval
					step()
	snapshot_clock += delta
	if OS.has_feature("web") and snapshot_clock > 0.2:
		snapshot_clock = 0
		JavaScriptBridge.eval("window.scholarshipState=" + JSON.stringify({"mode": mode, "score": score, "level": level, "remaining": remaining, "counts": counts, "snake": snake.map(func(p): return [p.x,p.y]), "documents": documents.map(func(d): return {"pos":[d.pos.x,d.pos.y],"kind":d.kind}), "blocks": blocks.map(func(p): return [p.x,p.y])}) + ";")
	queue_redraw()

func step():
	if mode != "play": return
	if not turns.is_empty(): direction = turns.pop_front()
	var head = snake[0] + direction
	var found = -1
	for i in range(documents.size()):
		if documents[i].pos == head: found = i
	if head.x < 0 or head.y < 0 or head.x >= GRID.x or head.y >= GRID.y:
		finish(false, "撞到校園邊界了！提早轉彎再試一次。")
		return
	if head in blocks:
		finish(false, "撞到施工路障了！記得規劃申請路線。")
		return
	var occupied = snake.duplicate()
	if found == -1: occupied.pop_back()
	if head in occupied:
		finish(false, "文件隊伍打結了！別撞到自己的尾巴。")
		return
	snake.push_front(head)
	if found == -1: snake.pop_back()
	else:
		var kind = documents[found].kind
		documents.remove_at(found)
		counts[kind] += 1
		score += 100
		message = NAMES[kind] + " +100！"
		flash = 1.2
		tone("collect")
		if counts[kind] < 2: spawn_document(kind)
		if counts[0] == 2 and counts[1] == 2 and counts[2] == 2:
			var bonus = int(ceil(remaining)) * 10
			score += bonus
			message = "準時送件獎勵 +%d" % bonus
			if level == 3: finish(true, "三輪審核完成，獎學金申請成功！")
			else:
				tone("win")
				change_mode("stage")

func finish(won: bool, why: String):
	reason = why
	message = "獎學金申請成功" if won else "這次差一點！"
	tone("win" if won else "fail")
	best = maxi(best, score)
	var cfg = ConfigFile.new()
	cfg.set_value("record", "best", best)
	cfg.save("user://scholarship.cfg")
	change_mode("result")

func _draw():
	draw_rect(Rect2(0, 0, 720, 1000), PAPER)
	label_at("CAMPUS QUEST  /  24", Vector2(40, 108), 20)
	centered("資通系 李振偉老師", 976, 20)
	match mode:
		"home": draw_home()
		"help": draw_help()
		"play", "paused": draw_game()
		"stage", "result": draw_result()

func draw_home():
	label_at("獎學金衝刺", Vector2(40, 178), 56)
	label_at("文件貪食蛇", Vector2(42, 222), 30, Color("59816b"))
	if hero:
		draw_texture_rect(hero, Rect2(40, 250, 640, 320), false)
	else:
		box(Rect2(40, 250, 640, 320), MINT)
		centered("把努力，連成通往夢想的路。", 420, 30)
	box(Rect2(40, 594, 640, 120), MINT)
	label_at("你是資通系學生「小青」", Vector2(60, 632), 26)
	label_at("收齊文件，趕在截止前完成三輪申請。", Vector2(60, 667), 24)
	label_at("方向鍵 / WASD ・ 手機方向鈕 / 滑動", Vector2(60, 699), 21)
	centered("3 輪挑戰  ·  每輪 75 秒  ·  最高分 %d" % best, 925, 23)

func draw_help():
	label_at("申請攻略", Vector2(40, 180), 46)
	var lines = [
		"01   主角：小青與他的申請文件隊伍。",
		"02   方向鍵 / WASD，手機按方向鈕或滑動。",
		"03   每輪收成績單、推薦信、自傳各 2 份。",
		"04   每份 +100 分，吃到文件隊伍就會變長。",
		"05   每輪限時 75 秒；過關加剩餘秒數 ×10。",
		"06   三輪全過即獲勝；後兩輪加速、增路障。",
		"07   撞牆、撞自己、撞路障、超時即失敗。",
		"08   不能直接反向；P / Esc 暫停，切頁自動暫停。"
	]
	for i in range(lines.size()): label_at(lines[i], Vector2(40, 242 + i * 49), 23)
	box(Rect2(40, 650, 640, 172), MINT)
	label_at("素材與製作", Vector2(60, 685), 26)
	label_at("首頁插畫：OpenAI ImageGen 生成。", Vector2(60, 721), 21)
	label_at("遊戲圖形與音效：程式原創繪製、合成。", Vector2(60, 755), 21)
	label_at("字型：Noto Sans TC（SIL OFL 1.1）。", Vector2(60, 789), 21)

func draw_game():
	label_at("第 %d / 3 輪" % level, Vector2(40, 150), 31)
	label_at("%04d 分" % score, Vector2(270, 150), 31)
	label_at("%02d 秒" % int(ceil(remaining)), Vector2(548, 150), 31, CORAL if remaining < 15 else INK)
	for i in range(3):
		box(Rect2(40 + i * 216, 170, 208, 44), COLORS[i].lightened(0.45), 10)
		label_at("%s %d/2" % [NAMES[i], counts[i]], Vector2(52 + i * 216, 201), 24)
	box(Rect2(34, 224, 652, 492), INK, 12)
	for y in range(GRID.y):
		for x in range(GRID.x):
			var col = Color("ecf0df") if (x + y) % 2 == 0 else Color("e3ead7")
			draw_rect(Rect2(ORIGIN + Vector2(x, y) * CELL, Vector2.ONE * CELL), col)
	for p in blocks:
		var xy = ORIGIN + Vector2(p) * CELL
		box(Rect2(xy + Vector2(3,3), Vector2(34,34)), CORAL, 6)
		draw_line(xy + Vector2(10,10), xy + Vector2(30,30), PAPER, 4)
		draw_line(xy + Vector2(30,10), xy + Vector2(10,30), PAPER, 4)
	for doc in documents:
		var xy = ORIGIN + Vector2(doc.pos) * CELL
		box(Rect2(xy + Vector2(5,3), Vector2(30,34)), COLORS[doc.kind], 5)
		label_at(["成","薦","傳"][doc.kind], xy + Vector2(9,28), 22, INK)
	for i in range(snake.size() - 1, -1, -1):
		var xy = ORIGIN + Vector2(snake[i]) * CELL
		if i == 0:
			box(Rect2(xy + Vector2(1,1), Vector2(38,38)), INK, 13)
			draw_circle(xy + Vector2(20,21), 12, Color("f4c69b"))
			draw_arc(xy + Vector2(20,18), 12, PI, TAU, 16, INK, 7)
			draw_circle(xy + Vector2(16,22), 2, INK)
			draw_circle(xy + Vector2(25,22), 2, INK)
		else:
			box(Rect2(xy + Vector2(4,4), Vector2(32,32)), Color("5d977d"), 8)
			draw_line(xy + Vector2(11,16), xy + Vector2(29,16), MINT, 3)
			draw_line(xy + Vector2(11,24), xy + Vector2(24,24), MINT, 3)
	centered(message if flash > 0 else "別撞牆、路障或自己  ·  各收 2 份即可送件", 745, 22, CORAL if flash > 0 else INK)
	if mode == "paused" or grace > 0:
		draw_rect(Rect2(40,230,640,480), Color(0.08,0.22,0.17,0.80))
		centered("已暫停" if mode == "paused" else "準備出發", 452, 48, PAPER)
		centered("按上方繼續，保留你的申請進度" if mode == "paused" else "先看文件位置，規劃你的路線", 507, 24, PAPER)

func draw_result():
	var stage_clear = mode == "stage"
	centered("ROUND %d COMPLETE" % level if stage_clear else "APPLICATION RESULT", 220, 23, Color("59816b"))
	centered("文件收齊，送件成功！" if stage_clear else message, 295, 42)
	box(Rect2(60, 340, 600, 265), MINT, 24)
	centered("累積分數", 395, 26)
	centered(str(score), 482, 76)
	centered(message if stage_clear else "本裝置最高分  %d" % best, 554, 25)
	centered("下一輪速度更快，注意施工路障。" if stage_clear else reason, 645, 23)
	centered("每一份準備，都離夢想更近一點。", 895, 25, Color("59816b"))
