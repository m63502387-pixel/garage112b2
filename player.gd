extends CharacterBody3D
## Игрок от первого лица: джойстик + свайп-обзор (значения приходят из hud.gd)

const SPEED := 3.4
const GRAV := 20.0
const LOOK_SENS := 0.0042

var move_input := Vector2.ZERO   # x вправо, y вперёд, -1..1
var look_delta := Vector2.ZERO   # пиксели свайпа за кадр
var pitch := 0.0
var frozen := false
var bob := 0.0

var head: Node3D
var cam: Camera3D
var ray: RayCast3D


func _ready() -> void:
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.7
	cs.shape = cap
	cs.position = Vector3(0, 0.85, 0)
	add_child(cs)

	head = Node3D.new()
	head.position = Vector3(0, 1.6, 0)
	add_child(head)

	cam = Camera3D.new()
	cam.fov = 68.0
	cam.near = 0.05
	cam.far = 140.0
	head.add_child(cam)
	cam.current = true

	ray = RayCast3D.new()
	ray.target_position = Vector3(0, 0, -2.6)
	ray.collide_with_areas = false
	ray.collide_with_bodies = true
	ray.add_exception(self)
	cam.add_child(ray)


func _physics_process(delta: float) -> void:
	if frozen:
		velocity = Vector3.ZERO
		return

	rotate_y(-look_delta.x * LOOK_SENS)
	pitch = clampf(pitch - look_delta.y * LOOK_SENS, -1.45, 1.45)
	head.rotation.x = pitch
	look_delta = Vector2.ZERO

	var dir: Vector3 = global_transform.basis * Vector3(move_input.x, 0.0, -move_input.y)
	dir.y = 0.0
	if dir.length() > 1.0:
		dir = dir.normalized()
	velocity.x = dir.x * SPEED
	velocity.z = dir.z * SPEED
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GRAV * delta
	move_and_slide()

	if dir.length() > 0.1 and is_on_floor():
		bob += delta * 9.0
		head.position.y = 1.6 + sin(bob) * 0.03
	else:
		head.position.y = lerpf(head.position.y, 1.6, 0.2)
