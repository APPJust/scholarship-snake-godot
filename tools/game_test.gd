extends SceneTree
var game
var checks = []
func check(ok, title):
	checks.append({"name":title,"passed":ok})
	if not ok: push_error(title)
func _initialize():
	call_deferred("run")
func run():
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.muted = true
	game.start_game()
	check(game.snake.size() == 3 and game.documents.size() == 3, "initial state")
	game.turn(Vector2i.LEFT)
	check(game.turns.is_empty(), "reject reverse direction")
	game.turn(Vector2i.UP)
	game.turn(Vector2i.LEFT)
	game.step()
	check(game.snake[0] == Vector2i(4,5), "queued turn one")
	game.step()
	check(game.snake[0] == Vector2i(3,5), "queued turn two")
	game.start_game()
	game.documents.assign([{ "pos":Vector2i(5,6),"kind":0}])
	game.step()
	check(game.score == 100 and game.snake.size() == 4 and game.counts[0] == 1, "collect score growth count")
	game.snake.assign([Vector2i(15,6),Vector2i(14,6),Vector2i(13,6)])
	game.step()
	check(game.mode == "result" and "邊界" in game.reason, "wall collision")
	game.start_game()
	game.snake.assign([Vector2i(4,6),Vector2i(4,5),Vector2i(5,5),Vector2i(5,6),Vector2i(6,6)])
	game.documents.clear()
	game.step()
	check(game.mode == "result" and "打結" in game.reason, "self collision")
	game.start_game()
	game.snake.assign([Vector2i(4,6),Vector2i(4,5),Vector2i(5,5),Vector2i(5,6)])
	game.documents.clear()
	game.step()
	check(game.mode == "play", "vacated tail cell legal")
	game.level = 2
	game.setup_stage()
	game.snake.assign([Vector2i(6,3),Vector2i(5,3),Vector2i(4,3)])
	game.step()
	check(game.mode == "result" and "路障" in game.reason, "obstacle collision")
	game.start_game()
	game.grace = 0
	game.remaining = 0.01
	game._process(0.02)
	check(game.mode == "result" and "截止" in game.reason, "timeout")
	game.start_game()
	game.toggle_pause()
	var before = game.remaining
	game._process(5)
	check(game.remaining == before and game.mode == "paused", "pause stops deadline")
	game.start_game()
	for stage in range(1,4):
		game.remaining = 30
		for kind in range(3):
			for repeat in range(2):
				game.snake.assign([Vector2i(4,6),Vector2i(3,6),Vector2i(2,6)])
				game.direction = Vector2i.RIGHT
				game.documents.assign([{ "pos":Vector2i(5,6),"kind":kind}])
				game.step()
		check(game.score == stage * 900, "stage %d scoring incl time bonus" % stage)
		check(game.mode == ("result" if stage == 3 else "stage"), "stage %d transition" % stage)
		if stage < 3: game.next_stage()
	check("成功" in game.reason, "three stage victory")
	for stage in range(1,4):
		game.level = stage
		for trial in range(100):
			game.setup_stage()
			var cells = []
			for doc in game.documents:
				if doc.pos in game.snake or doc.pos in game.blocks or doc.pos in cells:
					check(false, "spawn placement")
				cells.append(doc.pos)
	check(true, "300 randomized spawn layouts")
	var f = FileAccess.open("res://qa/game-tests.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(checks,"  "))
	print(JSON.stringify(checks))
	var failures = checks.filter(func(c): return not c.passed).size()
	game.queue_free()
	quit(failures)

