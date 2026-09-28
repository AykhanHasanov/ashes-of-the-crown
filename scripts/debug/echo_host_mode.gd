extends "res://scripts/chapter_base.gd"
## A small place to enter echoes from in the echo tests (scenes/tests/echo_host.tscn): the
## test yard with the real protagonist, camera and HUD. Returning here from an echo uses
## the same chapter_base code as the world.

const TestYard := preload("res://scripts/debug/test_yard.gd")
const Protagonist := preload("res://scripts/player_v3/protagonist.gd")
const TPCamera := preload("res://scripts/camera/third_person_camera.gd")


func _make_level() -> Node3D:
	return TestYard.new()


func _make_player() -> Node3D:
	return Protagonist.new()


func _make_camera() -> Node3D:
	return TPCamera.new()


func _begin(_mode: String) -> void:
	player.wake()
