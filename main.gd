extends Node3D
## Гараж 112 — 3D выживание от первого лица (Godot 4.x, мобильный портрет).
## Всё строится кодом, внешних ассетов нет.

const GAME_MIN_SEC := 0.5      # сколько реальных секунд = 1 игровая минута
const START_MIN := 1070.0      # 17:50
const END_MIN := 1800.0        # 06:00 следующего дня
const G_W := 4.4               # ширина гаража

var player
var hud

var env: Environment
var time_min: float = START_MIN
var temp_in: float = 4.0
var temp_out: float = -4.0
var kcal: float = 900.0
var health: float = 100.0
var has_lock := false
var lock_installed := false
var has_pipe := false
var pipe_installed := false
var wood := 0
var stove_fire := 0.0
var smoke_vis := 0.0
var candle_on := true
var cars_passed := 0
var game_over := false
var door_open := false
var exposure := 0.0
var t := 0.0
var smoke_msg_cd := 0.0

var door_hp := 120.0
var door_broken := false
var door_shaking := false
var door_msg_cd := 0.0
var has_bolt := false
var has_trigger := false
var rifle_ready := false
var salt_ammo := 0
var kills := 0
var fire_cd := 0.0
var hurt_flash := 0.0
var last_zombie_hurt := -100.0
var evt_timer := 12.0
var evt_step := 0
var wave_n := 0
var rifle_wall: Node3D
var rifle_view: Node3D
var muzzle: OmniLight3D

var door_l: Node3D
var door_r: Node3D
var candle_light: OmniLight3D
var flame: MeshInstance3D
var stove_light: OmniLight3D
var stove_glow: MeshInstance3D
var pipe_node: Node3D
var smoke: CPUParticles3D
var door_tween: Tween
var win_tex: ImageTexture

var car: Node3D
var car_dir := 1.0
var car_active := false
var car_prev_x := 0.0
var car_timer := 40.0
var car_warned := false


func _ready() -> void:
	randomize()
	win_tex = _make_window_tex()
	_build_env()
	_build_ground()
	_build_city()
	_build_garages()
	_build_interior()
	_build_lamps()
	_build_car()
	_build_player()
	_build_hud()
	_intro()


# ───────────────────────── helpers ─────────────────────────

func mat(c: Color, emit: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	return m


func add_box(parent: Node, pos: Vector3, size: Vector3, c: Color, solid: bool = true, emit: float = 0.0) -> Node3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat(c, emit)
	if solid:
		var body := StaticBody3D.new()
		body.position = pos
		body.add_child(mi)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		body.add_child(cs)
		parent.add_child(body)
		return body
	mi.position = pos
	parent.add_child(mi)
	return mi


func add_cyl(parent: Node, pos: Vector3, radius: float, height: float, c: Color, solid: bool = true, emit: float = 0.0) -> Node3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	mi.mesh = cm
	mi.material_override = mat(c, emit)
	if solid:
		var body := StaticBody3D.new()
		body.position = pos
		body.add_child(mi)
		var cs := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.radius = radius
		sh.height = height
		cs.shape = sh
		body.add_child(cs)
		parent.add_child(body)
		return body
	mi.position = pos
	parent.add_child(mi)
	return mi


func add_wall(pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	add_child(body)


func add_label(parent: Node, pos: Vector3, text: String, fsize: int, col: Color) -> void:
	var lb := Label3D.new()
	lb.text = text
	lb.font_size = fsize
	lb.pixel_size = 0.006
	lb.modulate = col
	lb.outline_size = 4
	lb.position = pos
	parent.add_child(lb)


func _make_window_tex() -> ImageTexture:
	var img := Image.create(16, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 1))
	for y in range(1, 31, 2):
		for x in range(1, 15, 2):
			if randf() < 0.35:
				img.set_pixel(x, y, Color(1.0, 0.85, 0.5, 1.0))
	return ImageTexture.create_from_image(img)


# ───────────────────────── мир ─────────────────────────

func _build_env() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.30, 0.22, 0.30)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.40, 0.60)
	env.ambient_light_energy = 0.8
	env.fog_enabled = true
	env.fog_light_color = Color(0.25, 0.22, 0.32)
	env.fog_density = 0.012
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = env
	add_child(we)


func _build_ground() -> void:
	add_box(self, Vector3(0, -0.1, 10), Vector3(70, 0.2, 40), Color(0.12, 0.12, 0.14))
	add_box(self, Vector3(0, 0.005, 7.5), Vector3(70, 0.01, 4.5), Color(0.07, 0.07, 0.09), false)
	for i in range(-8, 9):
		add_box(self, Vector3(i * 4.0, 0.012, 7.5), Vector3(1.6, 0.01, 0.12), Color(0.6, 0.6, 0.5), false)
	add_wall(Vector3(-25.5, 2, 5), Vector3(1, 4, 40))
	add_wall(Vector3(25.5, 2, 5), Vector3(1, 4, 40))
	add_wall(Vector3(0, 2, 17), Vector3(60, 4, 1))


func _build_city() -> void:
	for side in [1.0, -1.0]:
		for i in range(0, 14):
			var h: float = randf_range(18.0, 48.0)
			var w: float = randf_range(7.0, 12.0)
			var x: float = -60.0 + i * 9.5 + randf_range(-2.0, 2.0)
			var z: float = side * randf_range(48.0, 75.0)
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(w, h, w)
			mi.mesh = bm
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(0.05, 0.06, 0.10)
			m.emission_enabled = true
			m.emission = Color(1.0, 0.85, 0.55)
			m.emission_texture = win_tex
			m.emission_energy_multiplier = 1.6
			m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			m.uv1_scale = Vector3(1.0, h / 20.0, 1.0)
			mi.material_override = m
			mi.position = Vector3(x, h / 2.0, z)
			add_child(mi)


func _build_garages() -> void:
	var root := Node3D.new()
	root.name = "Garages"
	add_child(root)
	var concrete := Color(0.42, 0.42, 0.40)

	# соседние гаражи — только фасады
	for i in range(-5, 6):
		if i == 0:
			continue
		var cx: float = i * G_W
		add_box(root, Vector3(cx, 1.35, 0.0), Vector3(G_W, 2.7, 0.2), concrete)
		add_box(root, Vector3(cx, 1.15, 0.14), Vector3(3.2, 2.3, 0.06), Color(0.16, 0.28, 0.20), false)
		add_label(root, Vector3(cx, 1.75, 0.19), str(112 + i), 96, Color(0.85, 0.9, 0.85))

	# наш гараж 112
	var open_w := 2.8
	var pier_w: float = (G_W - open_w) / 2.0
	var pier_x: float = open_w / 2.0 + pier_w / 2.0
	add_box(root, Vector3(-pier_x, 1.35, 0), Vector3(pier_w, 2.7, 0.2), concrete)
	add_box(root, Vector3(pier_x, 1.35, 0), Vector3(pier_w, 2.7, 0.2), concrete)
	add_box(root, Vector3(0, 2.5, 0), Vector3(open_w, 0.4, 0.2), concrete)

	var wall_col := Color(0.34, 0.28, 0.22)
	add_box(root, Vector3(-G_W / 2.0, 1.35, -3.1), Vector3(0.2, 2.7, 6.2), wall_col)
	add_box(root, Vector3(G_W / 2.0, 1.35, -3.1), Vector3(0.2, 2.7, 6.2), wall_col)
	add_box(root, Vector3(0, 1.35, -6.1), Vector3(G_W + 0.2, 2.7, 0.2), wall_col)
	add_box(root, Vector3(0, 2.8, -3.1), Vector3(G_W + 0.2, 0.2, 6.4), Color(0.2, 0.19, 0.18))
	add_box(root, Vector3(0, 0.01, -3.0), Vector3(4.2, 0.02, 6.0), Color(0.28, 0.25, 0.22), false)

	# две створки
	door_l = Node3D.new()
	door_l.position = Vector3(-1.4, 0, 0.12)
	root.add_child(door_l)
	door_r = Node3D.new()
	door_r.position = Vector3(1.4, 0, 0.12)
	root.add_child(door_r)
	var leaf_col := Color(0.17, 0.30, 0.20)
	var leaf_l := add_box(door_l, Vector3(0.7, 1.15, 0), Vector3(1.4, 2.3, 0.08), leaf_col)
	var leaf_r := add_box(door_r, Vector3(-0.7, 1.15, 0), Vector3(1.4, 2.3, 0.08), leaf_col)
	leaf_l.set_meta("act", "door")
	leaf_r.set_meta("act", "door")
	add_label(leaf_l, Vector3(0, 0.55, 0.05), "112", 110, Color(0.85, 0.9, 0.85))
	add_label(leaf_r, Vector3(0, 0.55, 0.05), "112", 110, Color(0.85, 0.9, 0.85))
	add_box(leaf_l, Vector3(0.6, -0.1, 0.06), Vector3(0.05, 0.18, 0.05), Color(0.6, 0.6, 0.6), false)
	add_box(leaf_r, Vector3(-0.6, -0.1, 0.06), Vector3(0.05, 0.18, 0.05), Color(0.6, 0.6, 0.6), false)


func _build_interior() -> void:
	var root := Node3D.new()
	root.name = "Interior"
	add_child(root)

	# верстак справа
	add_box(root, Vector3(1.65, 0.45, -3.0), Vector3(0.9, 0.9, 2.2), Color(0.38, 0.27, 0.15))

	# свеча
	add_cyl(root, Vector3(1.65, 0.99, -2.6), 0.04, 0.18, Color(0.95, 0.9, 0.75), false, 0.5)
	flame = add_cyl(root, Vector3(1.65, 1.13, -2.6), 0.02, 0.06, Color(1.0, 0.6, 0.2), false, 3.0) as MeshInstance3D
	candle_light = OmniLight3D.new()
	candle_light.position = Vector3(1.65, 1.25, -2.6)
	candle_light.light_color = Color(1.0, 0.65, 0.3)
	candle_light.light_energy = 1.5
	candle_light.omni_range = 7.5
	root.add_child(candle_light)

	# врезной замок на верстаке
	var lock_item := add_box(root, Vector3(1.65, 0.94, -3.6), Vector3(0.2, 0.08, 0.12), Color(0.7, 0.7, 0.75), true, 0.2)
	lock_item.set_meta("act", "pickup_lock")

	# труба, прислонена к стене
	var pipe_item := add_cyl(root, Vector3(-1.95, 0.7, -1.0), 0.05, 1.4, Color(0.4, 0.4, 0.45), true, 0.2)
	pipe_item.set_meta("act", "pickup_pipe")

	# старые ящики (на дрова)
	var crates := add_box(root, Vector3(-1.4, 0.35, -1.7), Vector3(0.8, 0.7, 0.8), Color(0.45, 0.32, 0.18), true, 0.1)
	crates.set_meta("act", "boards")
	crates.set_meta("uses", 4)

	# бочка
	add_cyl(root, Vector3(-1.0, 0.45, -5.5), 0.3, 0.9, Color(0.55, 0.1, 0.08))

	# стеллаж с банками слева
	var shelf_col := Color(0.30, 0.22, 0.13)
	for y in [0.55, 1.05, 1.55]:
		add_box(root, Vector3(-1.8, y, -3.9), Vector3(0.55, 0.05, 2.8), shelf_col)
	add_box(root, Vector3(-1.8, 0.85, -2.5), Vector3(0.55, 1.7, 0.06), shelf_col, false)
	add_box(root, Vector3(-1.8, 0.85, -5.3), Vector3(0.55, 1.7, 0.06), shelf_col, false)
	var jam_slots: Array = []
	while jam_slots.size() < 7:
		var s: int = randi() % 15
		if not jam_slots.has(s):
			jam_slots.append(s)
	var slot := 0
	for y in [0.55, 1.05, 1.55]:
		for k in range(5):
			var kind := "cuc"
			var idx: int = jam_slots.find(slot)
			if idx >= 0:
				kind = "jam" if idx < 4 else "salt"
			_add_jar(root, Vector3(-1.8, y + 0.025 + 0.11, -2.8 - 0.55 * k), kind)
			slot += 1

	# сломанная винтовка на правой стене
	rifle_wall = add_box(root, Vector3(2.0, 1.5, -4.8), Vector3(0.1, 0.12, 1.1), Color(0.30, 0.20, 0.10), true, 0.1)
	rifle_wall.set_meta("act", "rifle")
	add_box(rifle_wall, Vector3(0, 0.02, -0.75), Vector3(0.05, 0.05, 0.7), Color(0.35, 0.35, 0.40), false, 0.2)

	# затвор лежит на верхней полке
	var bolt_item := add_box(root, Vector3(-1.8, 1.60, -5.22), Vector3(0.14, 0.05, 0.05), Color(0.6, 0.6, 0.65), true, 0.4)
	bolt_item.set_meta("act", "pickup_bolt")

	# печка-буржуйка у задней стены
	var stove := add_box(root, Vector3(0, 0.4, -5.5), Vector3(0.6, 0.8, 0.6), Color(0.12, 0.12, 0.13))
	stove.set_meta("act", "stove")
	stove_glow = add_box(root, Vector3(0, 0.4, -5.19), Vector3(0.28, 0.25, 0.02), Color(1.0, 0.5, 0.1), false, 3.0) as MeshInstance3D
	stove_glow.visible = false
	stove_light = OmniLight3D.new()
	stove_light.position = Vector3(0, 0.6, -4.9)
	stove_light.light_color = Color(1.0, 0.5, 0.2)
	stove_light.omni_range = 6.5
	stove_light.light_energy = 2.0
	stove_light.visible = false
	root.add_child(stove_light)

	# труба через крышу (появляется после установки)
	pipe_node = Node3D.new()
	pipe_node.position = Vector3(0, 0, -5.5)
	root.add_child(pipe_node)
	add_cyl(pipe_node, Vector3(0, 2.15, 0), 0.06, 2.7, Color(0.15, 0.15, 0.17), false)
	pipe_node.visible = false

	smoke = CPUParticles3D.new()
	smoke.position = Vector3(0, 3.55, -5.5)
	smoke.amount = 20
	smoke.lifetime = 4.0
	smoke.direction = Vector3(0, 1, 0)
	smoke.spread = 8.0
	smoke.initial_velocity_min = 0.6
	smoke.initial_velocity_max = 1.0
	smoke.gravity = Vector3(0.3, 0.2, 0.0)
	smoke.scale_amount_min = 0.6
	smoke.scale_amount_max = 1.5
	var sm := SphereMesh.new()
	sm.radius = 0.2
	sm.height = 0.4
	var smm := StandardMaterial3D.new()
	smm.albedo_color = Color(0.6, 0.6, 0.65, 0.45)
	smm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.material = smm
	smoke.mesh = sm
	smoke.emitting = false
	root.add_child(smoke)


func _add_jar(parent: Node, pos: Vector3, kind: String) -> void:
	var col := Color(0.25, 0.55, 0.18)
	if kind == "jam":
		col = Color(0.6, 0.07, 0.12)
	elif kind == "salt":
		col = Color(0.88, 0.88, 0.92)
	var body := add_cyl(parent, pos, 0.09, 0.22, col, true, 0.25)
	body.set_meta("act", "jar")
	body.set_meta("kind", kind)
	var lid := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.095
	cm.bottom_radius = 0.095
	cm.height = 0.04
	lid.mesh = cm
	lid.material_override = mat(Color(0.75, 0.6, 0.2))
	lid.position = Vector3(0, 0.13, 0)
	body.add_child(lid)


func _build_lamps() -> void:
	for x in [-12.0, 6.0, 18.0]:
		add_cyl(self, Vector3(x, 3.0, 9.8), 0.08, 6.0, Color(0.1, 0.1, 0.12), false)
		add_box(self, Vector3(x, 6.0, 9.4), Vector3(0.7, 0.15, 0.4), Color(1.0, 0.85, 0.6), false, 3.0)
		var l := OmniLight3D.new()
		l.position = Vector3(x, 5.8, 9.2)
		l.light_color = Color(1.0, 0.85, 0.6)
		l.light_energy = 1.4
		l.omni_range = 16.0
		add_child(l)


func _build_car() -> void:
	car = Node3D.new()
	add_child(car)
	add_box(car, Vector3(0, 0.7, 0), Vector3(1.9, 1.0, 4.2), Color(0.08, 0.08, 0.10), false)
	add_box(car, Vector3(0, 1.4, 0.3), Vector3(1.7, 0.7, 2.2), Color(0.10, 0.10, 0.13), false)
	for sx in [-0.65, 0.65]:
		add_box(car, Vector3(sx, 0.75, -2.12), Vector3(0.4, 0.2, 0.05), Color(1.0, 0.95, 0.8), false, 4.0)
	var sp := SpotLight3D.new()
	sp.position = Vector3(0, 0.8, -2.2)
	sp.spot_range = 28.0
	sp.spot_angle = 32.0
	sp.light_energy = 5.0
	sp.light_color = Color(1.0, 0.95, 0.82)
	car.add_child(sp)
	car.visible = false


func _build_player() -> void:
	player = CharacterBody3D.new()
	player.set_script(load("res://player.gd"))
	player.position = Vector3(0, 0.05, 5.0)
	add_child(player)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Control.new()
	hud.set_script(load("res://hud.gd"))
	layer.add_child(hud)
	hud.act_pressed.connect(_interact)
	hud.candle_pressed.connect(_toggle_candle)
	hud.fire_pressed.connect(_fire)


func _intro() -> void:
	hud.queue_msg("БЕГИ. Гараж 112.", 2.5)
	hud.queue_msg("Правило 1: запри дверь — врезной замок.", 3.5)
	hud.queue_msg("Правило 2: считай калории, а не банки.", 3.5)
	hud.queue_msg("Правило 3: огонь — только с трубой.", 3.5)
	hud.queue_msg("В гараже — сломанная винтовка. Найди затвор и курок.", 3.5)
	hud.queue_msg("Зарядить её можно солью из банки. Дотяни до 06:00.", 3.5)


# ───────────────────────── действия ─────────────────────────

func msg(text: String, d: float = 3.0) -> void:
	hud.show_msg(text, d)


func _aimed():
	var r: RayCast3D = player.ray
	if r == null:
		return null
	r.force_raycast_update()
	if not r.is_colliding():
		return null
	var c = r.get_collider()
	if c != null and c.has_meta("act"):
		return c
	return null


func _prompt_for(c) -> String:
	var act: String = c.get_meta("act", "")
	match act:
		"door":
			if door_broken:
				return "Дверь выбита"
			if has_lock and not lock_installed:
				return "Врезать замок"
			return "Закрыть дверь" if door_open else "Открыть дверь"
		"jar":
			var kind: String = c.get_meta("kind")
			if kind == "cuc":
				return "Огурцы (≈ 0 ккал)"
			if kind == "jam":
				return "Варенье (1700 ккал)"
			return "Соль — зарядить винтовку"
		"pickup_lock":
			return "Взять врезной замок"
		"pickup_pipe":
			return "Взять трубу"
		"pickup_bolt":
			return "Взять затвор"
		"rifle":
			if has_bolt and has_trigger:
				return "Собрать винтовку"
			return "Сломанная винтовка (нужны затвор и курок)"
		"boards":
			return "Разобрать старые ящики на дрова"
		"stove":
			if has_pipe and not pipe_installed:
				return "Поставить трубу через крышу"
			if stove_fire > 0.0:
				return "Потушить печь"
			return "Растопить печь (дрова: %d)" % wood
	return ""


func _interact() -> void:
	if game_over:
		return
	var c = _aimed()
	if c == null:
		return
	var act: String = c.get_meta("act", "")
	match act:
		"door":
			if door_broken:
				return
			if has_lock and not lock_installed:
				lock_installed = true
				door_hp += 80.0
				add_box(door_r, Vector3(-1.25, 1.0, 0.07), Vector3(0.16, 0.2, 0.06), Color(0.75, 0.75, 0.8), false, 0.3)
				msg("+ ЗАМОК. Врезной.", 2.5)
			else:
				_set_door(not door_open)
		"jar":
			var kind: String = c.get_meta("kind")
			if kind == "salt":
				if not rifle_ready:
					msg("Соль. Сначала собери винтовку.", 2.5)
					return
				salt_ammo += 4
				msg("Винтовка заряжена солью: %d" % salt_ammo, 2.5)
			elif kind == "jam":
				kcal = minf(kcal + 1700.0, 2500.0)
				msg("Варенье: +1700 ккал. Это день жизни.", 3.5)
			else:
				kcal = minf(kcal + 5.0, 2500.0)
				msg("Огурцы: ≈ 0 ккал. Банка — не калории.", 3.5)
			c.queue_free()
		"pickup_lock":
			has_lock = true
			c.queue_free()
			msg("Врезной замок. Врежь его в дверь.", 3.0)
		"pickup_pipe":
			has_pipe = true
			c.queue_free()
			msg("Труба. Выведи её через крышу.", 3.0)
		"pickup_bolt":
			has_bolt = true
			c.queue_free()
			msg("Затвор от винтовки.", 2.5)
		"rifle":
			_assemble_rifle()
		"boards":
			var uses: int = c.get_meta("uses")
			wood += 1
			uses -= 1
			c.set_meta("uses", uses)
			if uses == 2 and not has_trigger:
				has_trigger = true
				msg("В ящике — курок от винтовки! Дрова: %d" % wood, 3.0)
			else:
				msg("Старые ящики → дрова: %d" % wood, 2.0)
			if uses <= 0:
				c.queue_free()
		"stove":
			_stove_action()


func _stove_action() -> void:
	if has_pipe and not pipe_installed:
		pipe_installed = true
		pipe_node.visible = true
		msg("Труба — через крышу.", 3.0)
	elif stove_fire > 0.0:
		stove_fire = 0.0
		msg("Огонь потушен.", 2.0)
	elif wood > 0:
		wood -= 1
		stove_fire = 90.0
		if pipe_installed:
			msg("Печь горит. Дым виден с улицы.", 3.0)
		else:
			msg("Нет трубы! Дым в гараже!", 3.0)
	else:
		msg("Нужны дрова. И труба.", 2.5)


func _set_door(open: bool) -> void:
	if door_broken:
		return
	door_open = open
	if door_tween:
		door_tween.kill()
	door_tween = create_tween().set_parallel(true)
	door_tween.tween_property(door_l, "rotation_degrees:y", -100.0 if open else 0.0, 0.7)
	door_tween.tween_property(door_r, "rotation_degrees:y", 100.0 if open else 0.0, 0.7)


func _toggle_candle() -> void:
	if game_over:
		return
	candle_on = not candle_on
	msg("Свеча горит." if candle_on else "Свеча погашена.", 1.5)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E:
			_interact()
		elif event.keycode == KEY_C:
			_toggle_candle()
		elif event.keycode == KEY_F or event.keycode == KEY_SPACE:
			_fire()


# ───────────────────────── игровой цикл ─────────────────────────

func _clock() -> String:
	var m: int = int(time_min) % 1440
	var hh: int = int(floor(m / 60.0))
	var mm: int = m - hh * 60
	return "%02d:%02d" % [hh, mm]


func _inv_text() -> String:
	var lk := "врезан" if lock_installed else ("в руках" if has_lock else "нет")
	var pp := "на печи" if pipe_installed else ("в руках" if has_pipe else "нет")
	var rf := "готова"
	if not rifle_ready:
		rf = "затвор %s, курок %s" % ["да" if has_bolt else "нет", "да" if has_trigger else "нет"]
	return "Замок: %s\nТруба: %s\nДрова: %d\nВинтовка: %s\nСоль: %d\nУбито: %d" % [lk, pp, wood, rf, salt_ammo, kills]


func _update_candle() -> void:
	candle_light.visible = candle_on
	flame.visible = candle_on
	if candle_on:
		candle_light.light_energy = 1.5 + 0.25 * sin(t * 13.0) + 0.15 * sin(t * 7.3 + 1.0) + randf() * 0.08
	if stove_light.visible:
		stove_light.light_energy = 2.0 + 0.5 * sin(t * 9.0) + randf() * 0.2


func _process(delta: float) -> void:
	t += delta
	_update_candle()
	if game_over:
		return

	# управление: сенсор + клавиатура для теста на ПК
	var kb := Vector2.ZERO
	if Input.is_key_pressed(KEY_W): kb.y += 1.0
	if Input.is_key_pressed(KEY_S): kb.y -= 1.0
	if Input.is_key_pressed(KEY_D): kb.x += 1.0
	if Input.is_key_pressed(KEY_A): kb.x -= 1.0
	player.move_input = (hud.move + kb).limit_length(1.0)
	player.look_delta += hud.look
	hud.look = Vector2.ZERO

	var gdt: float = delta / GAME_MIN_SEC
	time_min += gdt

	# закат
	var f: float = clampf((time_min - START_MIN) / 70.0, 0.0, 1.0)
	env.background_color = Color(0.30, 0.22, 0.30).lerp(Color(0.02, 0.03, 0.08), f)
	env.fog_light_color = Color(0.25, 0.22, 0.32).lerp(Color(0.04, 0.05, 0.10), f)
	env.ambient_light_energy = lerpf(0.8, 0.28, f)

	# температура
	temp_out = lerpf(-4.0, -14.0, clampf((time_min - START_MIN) / 600.0, 0.0, 1.0))
	var target: float
	var k: float
	if door_open:
		target = temp_out + 0.5
		k = 0.10
	else:
		target = temp_out + 8.0
		k = 0.02
		if candle_on:
			target += 1.5
	if stove_fire > 0.0:
		target += 16.0
		k = maxf(k, 0.05)
	temp_in += (target - temp_in) * k * delta

	# печь
	if stove_fire > 0.0:
		stove_fire -= gdt
		if stove_fire <= 0.0:
			stove_fire = 0.0
			msg("Печь прогорела.", 2.0)
	var burning: bool = stove_fire > 0.0
	stove_light.visible = burning
	stove_glow.visible = burning
	smoke.emitting = burning and pipe_installed
	if burning and pipe_installed:
		smoke_vis = 1.0
	else:
		smoke_vis = maxf(0.0, smoke_vis - delta / 12.0)
	smoke_msg_cd -= delta
	if burning and not pipe_installed:
		health -= 4.0 * delta
		if smoke_msg_cd <= 0.0:
			msg("ДЫМ! Огонь — только с трубой!", 2.0)
			smoke_msg_cd = 4.0

	# калории и здоровье
	kcal -= gdt * (1.2 + maxf(0.0, 8.0 - temp_in) * 0.08)
	if kcal <= 0.0:
		kcal = 0.0
		health -= 2.0 * delta
	if temp_in < -4.0:
		health -= (-4.0 - temp_in) * 0.15 * delta
	elif temp_in > 2.0 and kcal > 200.0:
		health = minf(100.0, health + 1.0 * delta)

	# события: люди, зомби, дверь
	fire_cd = maxf(0.0, fire_cd - delta)
	hurt_flash = maxf(0.0, hurt_flash - delta * 2.0)
	_update_events(delta)
	_update_door_shake(delta)

	# фары
	_update_car(delta)

	# подсказка
	var prompt := ""
	var c = _aimed()
	if c != null:
		prompt = _prompt_for(c)

	var danger_v: float = maxf(maxf((40.0 - health) / 40.0, exposure), hurt_flash * 0.8)
	hud.set_danger(danger_v)
	hud.update_stats({
		"time": _clock(), "temp": temp_in, "kcal": kcal, "hp": health,
		"inv": _inv_text(), "cars": cars_passed, "prompt": prompt
	})

	if health <= 0.0:
		if t - last_zombie_hurt < 3.0:
			_end("ТЕБЯ СЪЕЛИ", "Зомби добрались до тебя.", false)
		elif kcal <= 0.0:
			_end("ТЫ УМЕР", "Ты считал банки, а не калории.", false)
		elif temp_in < -4.0:
			_end("ТЫ ЗАМЁРЗ", "Без огня ночью не выжить. Нужны дрова и труба.", false)
		else:
			_end("ТЫ ЗАДОХНУЛСЯ", "Огонь — только с трубой.", false)
	elif time_min >= END_MIN:
		_end("06:00", "Ты пережил ночь. Фар было: %d." % cars_passed, true)


func _update_car(delta: float) -> void:
	if not car_active:
		car_timer -= delta
		if car_timer < 5.0 and not car_warned:
			car_warned = true
			msg("Слышен мотор… ФАРЫ.", 3.0)
		if car_timer <= 0.0:
			car_active = true
			car_warned = false
			cars_passed += 1
			car_dir = [1.0, -1.0].pick_random()
			car.position = Vector3(-car_dir * 40.0, 0.0, 7.5)
			car.rotation_degrees.y = -90.0 * car_dir
			car.visible = true
			car_prev_x = car.position.x
		return

	car.position.x += car_dir * 9.0 * delta
	var cx: float = car.position.x
	if (car_prev_x < 0.0 and cx >= 0.0) or (car_prev_x > 0.0 and cx <= 0.0):
		_car_check()
	car_prev_x = cx

	var px: float = player.global_position.x
	var outside: bool = player.global_position.z > 0.4
	if outside and absf(cx - px) < 16.0:
		exposure += delta
		if exposure > 0.3:
			msg("ФАРЫ! В гараж!", 1.0)
		if exposure >= 1.0:
			_end("ТЕБЯ НАШЛИ", "Тебя поймали фары на улице.", false)
	else:
		exposure = maxf(0.0, exposure - delta)

	if absf(cx) > 42.0:
		car_active = false
		car.visible = false
		car_timer = randf_range(40.0, 70.0)


func _car_check() -> void:
	if player.global_position.z > 0.4:
		return
	var reason := ""
	if door_open and (candle_on or stove_fire > 0.0):
		reason = "Свет из открытой двери выдал гараж."
	elif door_open and randf() < 0.35:
		reason = "Открытую дверь заметили."
	elif not door_open and not lock_installed and randf() < 0.3:
		reason = "Дверь без замка — её просто открыли."
	elif pipe_installed and smoke_vis > 0.3 and randf() < 0.35:
		reason = "Струйка дыма из трубы выдала гараж."
	if reason != "":
		_end("ТЕБЯ НАШЛИ", reason, false)


func _end(title: String, text: String, good: bool) -> void:
	if game_over:
		return
	game_over = true
	player.frozen = true
	player.move_input = Vector2.ZERO
	hud.show_end(title, text, good)


# ───────────────────────── зомби, люди, оружие ─────────────────────────

func spawn_zombie(pos: Vector3, mode: String, spd: float = 2.0, pdir: float = 0.0) -> void:
	if get_tree().get_nodes_in_group("zombies").size() >= 12:
		return
	var z = StaticBody3D.new()
	z.set_script(load("res://zombie.gd"))
	z.position = pos
	add_child(z)
	z.setup(self, mode, spd, pdir)


func spawn_runners(n: int, dir: float) -> void:
	var cols := [Color(0.6, 0.2, 0.2), Color(0.2, 0.4, 0.6), Color(0.7, 0.6, 0.2), Color(0.3, 0.5, 0.3)]
	for i in range(n):
		var p = Node3D.new()
		p.set_script(load("res://person.gd"))
		p.position = Vector3(-dir * (44.0 + i * 3.0), 0.0, randf_range(5.8, 8.8))
		add_child(p)
		p.setup(dir, randf_range(4.8, 6.0), cols[i % cols.size()])


func _update_events(delta: float) -> void:
	evt_timer -= delta
	if evt_timer > 0.0:
		return
	var dir: float = [1.0, -1.0].pick_random()
	match evt_step:
		0:
			spawn_runners(4, dir)
			msg("Люди бегут по улице!", 3.0)
			evt_timer = 7.0
		1:
			for i in range(3):
				spawn_zombie(Vector3(-dir * (46.0 + i * 3.0), 0.0, randf_range(6.0, 8.5)), "pass", 2.6, dir)
			msg("За ними — зомби.", 3.0)
			evt_timer = 10.0
		2:
			spawn_zombie(Vector3(-dir * 38.0, 0.0, 7.0), "door", 2.0)
			msg("Один зомби свернул к твоему гаражу.", 3.5)
			evt_timer = randf_range(50.0, 70.0)
		_:
			wave_n += 1
			if randf() < 0.5:
				spawn_runners(3, dir)
			var n: int = mini(2 + int(wave_n / 2.0), 5)
			for i in range(n):
				spawn_zombie(Vector3(-dir * (36.0 + i * 3.0), 0.0, randf_range(6.0, 8.5)), "door", 2.0)
			msg("Зомби идут к гаражу: %d" % n, 3.0)
			evt_timer = randf_range(55.0, 80.0)
	evt_step += 1


func _update_door_shake(delta: float) -> void:
	var bashing := 0
	for z in get_tree().get_nodes_in_group("zombies"):
		if z.bashing:
			bashing += 1
	door_msg_cd -= delta
	var shaking: bool = bashing > 0 and not door_open and not door_broken
	if shaking:
		var sh: float = absf(sin(t * 38.0)) * 2.0
		door_l.rotation_degrees.y = -sh
		door_r.rotation_degrees.y = sh
		if door_msg_cd <= 0.0:
			msg("В дверь колотятся!", 2.5)
			door_msg_cd = 8.0
	elif door_shaking and not door_open and not door_broken:
		door_l.rotation_degrees.y = 0.0
		door_r.rotation_degrees.y = 0.0
	door_shaking = shaking


func door_hit(dmg: float) -> void:
	if door_broken or door_open:
		return
	door_hp -= dmg
	if door_hp <= 0.0:
		door_broken = true
		door_open = true
		if door_tween:
			door_tween.kill()
		door_tween = create_tween().set_parallel(true)
		door_tween.tween_property(door_l, "rotation_degrees:y", -115.0, 0.25)
		door_tween.tween_property(door_r, "rotation_degrees:y", 70.0, 0.25)
		msg("ДВЕРЬ ВЫБИТА!", 3.0)


func hurt(a: float) -> void:
	health -= a
	hurt_flash = 1.0
	last_zombie_hurt = t


func on_zombie_killed() -> void:
	kills += 1


func _assemble_rifle() -> void:
	if not (has_bolt and has_trigger):
		msg("Сломана. Затвор: %s. Курок: %s." % ["есть" if has_bolt else "нет", "есть" if has_trigger else "нет"], 3.0)
		return
	rifle_ready = true
	rifle_wall.queue_free()
	rifle_view = Node3D.new()
	rifle_view.position = Vector3(0.22, -0.2, -0.45)
	player.cam.add_child(rifle_view)
	add_box(rifle_view, Vector3(0, 0, 0), Vector3(0.05, 0.08, 0.5), Color(0.30, 0.20, 0.10), false, 0.15)
	add_box(rifle_view, Vector3(0, 0.02, -0.4), Vector3(0.03, 0.03, 0.5), Color(0.35, 0.35, 0.40), false, 0.15)
	muzzle = OmniLight3D.new()
	muzzle.position = Vector3(0, 0.02, -0.75)
	muzzle.light_color = Color(1.0, 0.85, 0.5)
	muzzle.light_energy = 4.0
	muzzle.omni_range = 6.0
	muzzle.visible = false
	rifle_view.add_child(muzzle)
	msg("Винтовка собрана. Заряди её солью из банки.", 3.5)


func _fire() -> void:
	if game_over:
		return
	if not rifle_ready:
		msg("Нечем стрелять. Собери винтовку.", 2.0)
		return
	if salt_ammo <= 0:
		msg("Нет заряда. Насыпь соль из банки.", 2.0)
		return
	if fire_cd > 0.0:
		return
	salt_ammo -= 1
	fire_cd = 0.7

	muzzle.visible = true
	var tw := create_tween()
	tw.tween_property(rifle_view, "position:z", -0.38, 0.05)
	tw.tween_property(rifle_view, "position:z", -0.45, 0.2)
	tw.tween_callback(func(): muzzle.visible = false)

	var cam: Camera3D = player.cam
	var from: Vector3 = cam.global_position
	var to: Vector3 = from + (-cam.global_transform.basis.z) * 40.0
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collide_with_areas = false
	q.collide_with_bodies = true
	q.exclude = [player.get_rid()]
	var res: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	if not res.is_empty():
		var col = res.get("collider")
		if col != null and col.has_meta("zombie"):
			col.hit(2.0)
