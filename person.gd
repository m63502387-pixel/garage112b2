extends Node3D
## Человек, который убегает по улице

const Fig = preload("res://figure.gd")

var dir := 1.0
var speed := 5.0
var ph := 0.0
var legs: Array = []
var arms: Array = []


func setup(d: float, spd: float, shirt: Color) -> void:
	dir = d
	speed = spd
	var f: Dictionary = Fig.build(false, shirt, Color(0.85, 0.70, 0.55))
	add_child(f["root"])
	legs = f["legs"]
	arms = f["arms"]
	rotation.y = atan2(-dir, 0.0)
	var lb := Label3D.new()
	lb.text = ["А-А-А!", "БЕЖИМ!", "ОНИ ТУТ!", "ПОМОГИТЕ!"].pick_random()
	lb.font_size = 48
	lb.pixel_size = 0.008
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lb.modulate = Color(1.0, 0.9, 0.4)
	lb.outline_size = 8
	lb.position = Vector3(0, 2.2, 0)
	add_child(lb)


func _process(delta: float) -> void:
	position.x += dir * speed * delta
	ph += delta * speed * 2.2
	var sw: float = sin(ph) * 0.9
	legs[0].rotation.x = sw
	legs[1].rotation.x = -sw
	arms[0].rotation.x = -sw
	arms[1].rotation.x = sw
	if absf(position.x) > 48.0:
		queue_free()
