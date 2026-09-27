extends Node
## Automated checks for the V3 combat core, run in the arena with --demo=arena_selftest.
## Drives the real Ayxan and Foe nodes through parry, block, back hits, stance
## break + execution, stamina exhaustion, the input buffer and lock-on, prints
## PASS/FAIL per check and quits with the failure count as exit code.

var mode      # arena_mode
var player
var _fails := 0


func run() -> void:
	await _wait(1.0)
	player.make_invulnerable(0.0)
	player.invulnerable_until = 0
	await _parry()
	await _block()
	await _back_hit()
	await _break_and_execute()
	await _stamina()
	await _buffer()
	await _lock()
	print("SELFTEST DONE, failures: ", _fails)
	get_tree().quit(_fails)


func _check(name: String, ok: bool, detail := "") -> void:
	print(("PASS  " if ok else "FAIL  ") + name + ("" if detail == "" else "  (" + detail + ")"))
	if not ok:
		_fails += 1


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _foe(id: String, ahead: float):
	var f = mode.spawn_foe(id, player.global_position + player.facing() * ahead, {"roll": false})
	f.set_physics_process(false)  # hold still; the test drives it
	return f


func _hit(from, dmg := 10.0, stance := 10.0):
	return from.Hit.new().setup(from, dmg, "slash", stance, Vector3.ZERO)


func _reset_player() -> void:
	Input.action_release("block")
	player.heal(player.max_health)
	player.stamina = player.max_stamina
	player._exhausted_until_ms = 0
	player.invulnerable_until = 0
	player._enter(player.S.MOVE)
	await _wait(0.3)


func _kill(f) -> void:
	if is_instance_valid(f):
		f.queue_free()
	await _wait(0.1)


func _parry() -> void:
	await _reset_player()
	var f = _foe("bandit_shield", 2.0)
	f.look_at(player.global_position, Vector3.UP)
	Input.action_press("block")
	await _wait(0.05)
	var r: String = player.receive_hit(_hit(f))
	_check("parry inside the window", r == "parried", r)
	_check("parried foe is stunned or broken", f._state in [f.S.STUNNED, f.S.BROKEN], str(f._state))
	Input.action_release("block")
	await _kill(f)


func _block() -> void:
	await _reset_player()
	var f = _foe("ash_shade", 2.0)
	Input.action_press("block")
	await _wait(0.5)
	var before: float = player.stamina
	var hp: float = player.health
	var r: String = player.receive_hit(_hit(f))
	_check("late guard blocks instead of parrying", r == "blocked", r)
	_check("block costs stamina, not health", player.stamina < before and player.health == hp,
		"stamina %.0f→%.0f" % [before, player.stamina])
	Input.action_release("block")
	await _kill(f)


func _back_hit() -> void:
	await _reset_player()
	var f = _foe("ash_shade", -2.0)  # behind Ayxan
	Input.action_press("block")
	await _wait(0.5)
	var r: String = player.receive_hit(_hit(f))
	_check("guard does not cover the back", r == "hit" or r == "broken", r)
	Input.action_release("block")
	await _kill(f)


func _break_and_execute() -> void:
	await _reset_player()
	var f = _foe("ash_shade", 1.6)
	f.set_physics_process(true)
	var r: String = f.receive_hit(_hit(player, 1.0, f.max_stance + 1.0))
	_check("stance damage breaks the foe", r == "broken" and f.is_executable(), r)
	var hp: float = f.health
	player._request("execute")
	await _wait(0.1)
	_check("E starts the execution", player._state == player.S.EXECUTE, str(player._state))
	_check("executor is invulnerable", player.is_invulnerable())
	await _wait(2.0)
	_check("execution deals heavy damage", f.dead or f.health < hp * 0.5, "%.0f→%.0f" % [hp, f.health])
	await _kill(f)


func _stamina() -> void:
	await _reset_player()
	var light: float = DataDB.balance("combat")["stamina"]["light_cost"]
	_check("light attack spends stamina", player._spend(light) and absf(player.stamina - (player.max_stamina - light)) < 0.1)
	player._drain_stamina(999.0)
	_check("empty stamina exhausts", player.is_exhausted())
	_check("no dodge while exhausted", not player._spend(20.0))
	await _wait(DataDB.balance("combat")["stamina"]["exhaust_time"] + 1.0)
	_check("stamina regenerates after exhaustion", player.stamina > 5.0 and not player.is_exhausted(), "%.0f" % player.stamina)


func _buffer() -> void:
	await _reset_player()
	player._enter(player.S.HURT)
	player._request("dodge")
	await _wait(0.1)
	_check("dodge waits in the buffer during hit-stun", player._buffer == "dodge" and player._state == player.S.HURT)
	await _wait(0.2)
	_check("buffered dodge fires once allowed", player._state == player.S.DODGE, str(player._state))
	await _wait(0.6)
	player._enter(player.S.HURT)
	player._request("jump")
	await _wait(DataDB.balance("combat")["stamina"]["input_buffer"] + 0.1)
	_check("stale input expires", player._buffer == "")


func _lock() -> void:
	await _reset_player()
	# Lock-on works in camera space
	var fwd: Vector3 = player.rig.flat_forward()
	var right: Vector3 = player.rig.flat_right()
	var near = mode.spawn_foe("wolf", player.global_position + fwd * 5.0, {"roll": false})
	near.set_physics_process(false)
	var far = mode.spawn_foe("ash_shade", player.global_position + fwd * 10.0 + right * 4.0, {"roll": false})
	far.set_physics_process(false)
	await _wait(0.2)
	player._toggle_lock()
	_check("lock-on takes the nearest foe in view", player.lock_target == near)
	player._switch_lock(1)
	_check("switching moves to the other foe", player.lock_target == far)
	player._toggle_lock()
	_check("second press releases the lock", player.lock_target == null)
	await _kill(near)
	await _kill(far)
