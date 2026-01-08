class_name ClockUI
extends CanvasLayer

## Visual clock display and speed controls

var game_clock: GameClock
var time_label: Label
var day_label: Label
var speed_label: Label

const SPEEDS := [0.5, 1.0, 2.0, 5.0, 10.0]
var current_speed_index: int = 1  # Start at 1.0x

func _ready() -> void:
	# Create UI container
	var panel := PanelContainer.new()
	panel.position = Vector2(10, 10)
	add_child(panel)

	var vbox := VBoxContainer.new()
	panel.add_child(vbox)

	# Day label
	day_label = Label.new()
	day_label.text = "Day 1"
	day_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(day_label)

	# Time label
	time_label = Label.new()
	time_label.text = "08:00"
	time_label.add_theme_font_size_override("font_size", 28)
	vbox.add_child(time_label)

	# Speed label
	speed_label = Label.new()
	speed_label.text = "Speed: 1.0x"
	speed_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(speed_label)

	# Instructions
	var help_label := Label.new()
	help_label.text = "[+/-] Speed  [P] Pause"
	help_label.add_theme_font_size_override("font_size", 12)
	help_label.modulate = Color(0.7, 0.7, 0.7)
	vbox.add_child(help_label)

func _process(_delta: float) -> void:
	if game_clock == null:
		return

	time_label.text = game_clock.get_time_string()
	day_label.text = "Day " + str(game_clock.day)

	var speed_text := "Speed: " + str(game_clock.speed_multiplier) + "x"
	if game_clock.is_paused:
		speed_text += " [PAUSED]"
	speed_label.text = speed_text

func _unhandled_input(event: InputEvent) -> void:
	if game_clock == null:
		return

	if event.is_action_pressed("ui_pause") or (event is InputEventKey and event.pressed and event.keycode == KEY_P):
		game_clock.set_paused(not game_clock.is_paused)

	# Speed up with + or =
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_EQUAL or event.keycode == KEY_KP_ADD:
			current_speed_index = mini(current_speed_index + 1, SPEEDS.size() - 1)
			game_clock.set_speed(SPEEDS[current_speed_index])
		elif event.keycode == KEY_MINUS or event.keycode == KEY_KP_SUBTRACT:
			current_speed_index = maxi(current_speed_index - 1, 0)
			game_clock.set_speed(SPEEDS[current_speed_index])

func set_game_clock(clock: GameClock) -> void:
	game_clock = clock
