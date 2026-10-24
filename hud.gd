extends Control
## HUD + сенсорное управление (альбомная ориентация):
## левая половина — джойстик, правая — обзор, кнопки справа внизу

signal act_pressed
signal candle_pressed
signal fire_pressed

const ACT_R := 70.0
const CAN_R := 56.0
const FIRE_R := 90.0

var move := Vector2.ZERO
var look := Vector2.ZERO
var input_enabled := true

var stick_id := -1
var stick_origin := Vector2.ZERO
var stick_pos := Vector2.ZERO
var look_id := -1

var lbl_time: Label
var lbl_temp: Label
var lbl_cars: Label
var lbl_inv: Label
var lbl_kcal: Label
var bar_kcal: ProgressBar
var bar_hp: ProgressBar
var lbl_prompt: Label
var lbl_msg: Label
var danger: ColorRect
var overlay: ColorRect

var msg_queue: Array = []
var msg_timer := 0.0
var danger_value := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()


func _lbl(text: String, fsize: int, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	l.add_theme_constant_override("outline_size", 7)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _build() -> void:
	danger = ColorRect.new()
	danger.color = Color(0.8, 0.0, 0.0, 0.0)
	danger.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	danger.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(danger)

	var top := VBoxContainer.new()
	top.position = Vector2(24, 16)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)

	lbl_time = _lbl("17:50", 40, Color(1, 0.95, 0.8))
	top.add_child(lbl_time)
	lbl_temp = _lbl("В ГАРАЖЕ +4.0°C", 26)
	top.add_child(lbl_temp)
	lbl_kcal = _lbl("ККАЛ", 20, Color(1, 0.85, 0.3))
	top.add_child(lbl_kcal)
	bar_kcal = ProgressBar.new()
	bar_kcal.custom_minimum_size = Vector2(240, 14)
	bar_kcal.show_percentage = false
	bar_kcal.max_value = 2500.0
	bar_kcal.modulate = Color(1, 0.8, 0.3)
	bar_kcal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(bar_kcal)
	var hp_l := _lbl("ЗДОРОВЬЕ", 20, Color(1, 0.4, 0.4))
	top.add_child(hp_l)
	bar_hp = ProgressBar.new()
	bar_hp.custom_minimum_size = Vector2(240, 14)
	bar_hp.show_percentage = false
	bar_hp.max_value = 100.0
	bar_hp.modulate = Color(1, 0.3, 0.3)
	bar_hp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(bar_hp)
	lbl_inv = _lbl("", 20)
	top.add_child(lbl_inv)

	lbl_cars = _lbl("ФАР: 0", 30, Color(1, 0.35, 0.35))
	add_child(lbl_cars)

	lbl_prompt = _lbl("", 28, Color(1, 0.9, 0.4))
	lbl_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(lbl_prompt)

	lbl_msg = _lbl("", 38)
	lbl_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(lbl_msg)


func queue_msg(t: String, d: float = 3.0) -> void:
	msg_queue.append([t, d])


func show_msg(t: String, d: float = 3.0) -> void:
	msg_queue.insert(0, [t, d])
	msg_timer = 0.0


func set_danger(v: float) -> void:
	danger_value = clampf(v, 0.0, 1.0)


func update_stats(d: Dictionary) -> void:
	lbl_time.text = d["time"]
	var tmp: float = d["temp"]
	var sign_s := "+" if tmp >= 0.0 else ""
	lbl_temp.text = "В ГАРАЖЕ %s%s°C" % [sign_s, String.num(tmp, 1)]
	lbl_temp.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0) if tmp < 0.0 else Color(1.0, 0.7, 0.35))
	var kc: float = d["kcal"]
	lbl_kcal.text = "ККАЛ  %d" % int(kc)
	bar_kcal.value = kc
	bar_hp.value = d["hp"]
	lbl_inv.text = d["inv"]
	lbl_cars.text = "ФАР: %d" % int(d["cars"])
	lbl_prompt.text = d["prompt"]


func show_end(title: String, text: String, good: bool) -> void:
	input_enabled = false
	move = Vector2.ZERO
	stick_id = -1
	look_id = -1
	overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.78)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(cc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 22)
	cc.add_child(vb)
	var l1 := _lbl(title, 56, Color(0.4, 1.0, 0.5) if good else Color(1.0, 0.3, 0.25))
	l1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(l1)
	var l2 := _lbl(text, 30)
	l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l2.custom_minimum_size = Vector2(700, 0)
	vb.add_child(l2)
	var b := Button.new()
	b.text = "ЗАНОВО"
	b.custom_minimum_size = Vector2(320, 90)
	b.add_theme_font_size_override("font_size", 40)
	b.pressed.connect(func(): get_tree().reload_current_scene())
	vb.add_child(b)


func fire_c() -> Vector2:
	return Vector2(size.x - 170.0, size.y - 190.0)


func act_c() -> Vector2:
	return Vector2(size.x - 370.0, size.y - 110.0)


func can_c() -> Vector2:
	return Vector2(size.x - 100.0, size.y - 380.0)


func _process(delta: float) -> void:
	var s := size
	lbl_cars.position = Vector2(s.x - lbl_cars.size.x - 24.0, 20.0)
	lbl_prompt.custom_minimum_size = Vector2(s.x, 0)
	lbl_prompt.size.x = s.x
	lbl_prompt.position = Vector2(0, s.y * 0.56)
	lbl_msg.custom_minimum_size = Vector2(s.x - 300.0, 0)
	lbl_msg.size.x = s.x - 300.0
	lbl_msg.position = Vector2(150, s.y * 0.64)
	danger.color.a = danger_value * 0.38

	msg_timer -= delta
	if msg_timer <= 0.0:
		if msg_queue.size() > 0:
			var m = msg_queue.pop_front()
			lbl_msg.text = m[0]
			msg_timer = m[1]
		else:
			lbl_msg.text = ""
	queue_redraw()


func _draw_button(c: Vector2, r: float, fill: Color, line: Color, text: String, fsize: int) -> void:
	var f: Font = ThemeDB.fallback_font
	draw_circle(c, r, fill)
	draw_arc(c, r, 0.0, TAU, 48, line, 4.0)
	draw_string(f, c + Vector2(-r, 8), text, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, fsize, Color(1, 1, 1, 0.95))


func _draw() -> void:
	var s := size
	draw_circle(s * 0.5, 4.0, Color(1, 1, 1, 0.75))

	var base := stick_origin if stick_id != -1 else Vector2(170, s.y - 170.0)
	var knob := stick_pos if stick_id != -1 else base
	draw_circle(base, 90.0, Color(1, 1, 1, 0.10))
	draw_arc(base, 90.0, 0.0, TAU, 48, Color(1, 1, 1, 0.35), 3.0)
	draw_circle(knob, 42.0, Color(1, 1, 1, 0.30))

	_draw_button(fire_c(), FIRE_R, Color(1.0, 0.2, 0.15, 0.28), Color(1.0, 0.4, 0.3, 0.8), "ВЫСТРЕЛ", 22)
	_draw_button(act_c(), ACT_R, Color(1.0, 0.7, 0.2, 0.28), Color(1.0, 0.8, 0.4, 0.7), "ДЕЙСТВИЕ", 19)
	_draw_button(can_c(), CAN_R, Color(1.0, 0.5, 0.1, 0.25), Color(1.0, 0.7, 0.3, 0.7), "СВЕЧА", 19)


func _input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventScreenTouch:
		var p: Vector2 = event.position
		if event.pressed:
			if p.distance_to(fire_c()) < FIRE_R + 15.0:
				fire_pressed.emit()
			elif p.distance_to(act_c()) < ACT_R + 15.0:
				act_pressed.emit()
			elif p.distance_to(can_c()) < CAN_R + 15.0:
				candle_pressed.emit()
			elif p.x < size.x * 0.5:
				if stick_id == -1:
					stick_id = event.index
					stick_origin = p
					stick_pos = p
			else:
				if look_id == -1:
					look_id = event.index
		else:
			if event.index == stick_id:
				stick_id = -1
				move = Vector2.ZERO
			elif event.index == look_id:
				look_id = -1
	elif event is InputEventScreenDrag:
		if event.index == stick_id:
			var d: Vector2 = (event.position - stick_origin).limit_length(90.0)
			stick_pos = stick_origin + d
			move = Vector2(d.x, -d.y) / 90.0
			if move.length() < 0.12:
				move = Vector2.ZERO
		elif event.index == look_id:
			look += event.relative
