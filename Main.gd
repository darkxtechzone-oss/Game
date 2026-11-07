extends Node3D

const CartoonCharacter = preload("res://CartoonCharacter.gd")

const LANE_W := 1.7
const TILE_LEN := 10.0
const TILE_COUNT := 9
const SPAWN_Z := -72.0
const GRAVITY := 30.0
const JUMP_V := 10.0
const STAND_H := 1.4
const SLIDE_H := 0.75

var rng := RandomNumberGenerator.new()
var mats := {}
var camera: Camera3D
var player: Node3D
var character
var shadow: MeshInstance3D
var tiles: Array = []
var obstacles: Array = []
var coins: Array = []
var tile_counter := 0

var lane := 1
var py := 0.0
var vy := 0.0
var sliding := false
var slide_timer := 0.0
var speed := 12.0
var distance := 0.0
var coin_count := 0
var spawn_acc := 0.0
var next_gap := 18.0
var alive := true
var started := false
var death_time := 0.0
var best := 0

var top_label: Label
var msg_label: Label
var touch_start := Vector2.ZERO
var touch_active := false
var swipe_done := false

# ---------------------------------------------------------------- setup

func _ready():
    rng.randomize()
    load_best()
    build_environment()
    build_tiles()
    build_player()
    build_ui()
    show_start_message()
    if has_node("Boot"):
        $Boot.queue_free()

func mat(c: Color) -> StandardMaterial3D:
    var key := c.to_html()
    if not mats.has(key):
        var m := StandardMaterial3D.new()
        m.albedo_color = c
        m.roughness = 0.9
        mats[key] = m
    return mats[key]

func box(parent: Node, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var bm := BoxMesh.new()
    bm.size = size
    mi.mesh = bm
    mi.position = pos
    mi.material_override = mat(color)
    parent.add_child(mi)
    return mi

func build_environment():
    var sky := Color("#8fd3f4")
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = sky
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.8, 0.85, 0.95)
    env.ambient_light_energy = 0.8
    env.fog_enabled = false
    env.fog_light_color = sky
    env.fog_density = 0.02
    var we := WorldEnvironment.new()
    we.environment = env
    add_child(we)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-55, -30, 0)
    sun.light_energy = 1.0
    add_child(sun)

    camera = Camera3D.new()
    camera.fov = 70
    camera.position = Vector3(0, 3.4, 5.2)
    camera.rotation_degrees = Vector3(-18, 0, 0)
    add_child(camera)

func build_tiles():
    for i in TILE_COUNT:
        var t := Node3D.new()
        t.position.z = TILE_LEN - i * TILE_LEN
        add_child(t)
        fill_tile(t)
        tiles.append(t)

func fill_tile(t: Node3D):
    for c in t.get_children():
        c.queue_free()
    tile_counter += 1
    var L := TILE_LEN + 0.02
    # barabara
    box(t, Vector3(5.6, 0.2, L), Vector3(0, -0.1, 0), Color("#3a3f4b"))
    # mistari ya njia (dashes)
    for x in [-LANE_W / 2.0, LANE_W / 2.0]:
        for z in [-2.5, 2.5]:
            box(t, Vector3(0.1, 0.02, 3.0), Vector3(x, 0.01, z), Color("#e8e8e8"))
    # kingo za njano + kerb + nyasi
    for sx in [-1, 1]:
        box(t, Vector3(0.14, 0.02, L), Vector3(sx * 2.62, 0.01, 0), Color("#ffd23f"))
        box(t, Vector3(0.6, 0.15, L), Vector3(sx * 3.1, -0.025, 0), Color("#b9bcc4"))
        box(t, Vector3(16, 0.2, L), Vector3(sx * 11.4, -0.1, 0), Color("#6cc66a"))
        # majengo
        if rng.randf() < 0.85:
            var w := rng.randf_range(3.0, 5.0)
            var h := rng.randf_range(4.0, 12.0)
            var d := rng.randf_range(4.0, 7.0)
            var cx := 5.0 + w / 2.0 + rng.randf_range(0.0, 2.5)
            var bz := rng.randf_range(-2.0, 2.0)
            var cols := [Color("#f4a6a6"), Color("#f7d794"), Color("#a3d9c9"), Color("#b5a8e6"), Color("#9ec5f0")]
            var col: Color = cols[rng.randi() % cols.size()]
            box(t, Vector3(w, h, d), Vector3(sx * cx, h / 2.0, bz), col)
            var face_x: float = sx * (cx - w / 2.0)
            var wy := 1.6
            var rows := 0
            while wy < h - 0.8 and rows < 4:
                box(t, Vector3(0.06, 0.8, d * 0.6), Vector3(face_x, wy, bz), Color("#fdf6d8"))
                wy += 2.0
                rows += 1

func build_player():
    player = Node3D.new()
    add_child(player)
    character = CartoonCharacter.new()
    character.scale = Vector3.ONE * 0.6
    character.position.y = 0.207
    character.rotation.y = PI
    player.add_child(character)

    shadow = MeshInstance3D.new()
    var cm := CylinderMesh.new()
    cm.top_radius = 0.45
    cm.bottom_radius = 0.45
    cm.height = 0.01
    shadow.mesh = cm
    var sm := StandardMaterial3D.new()
    sm.albedo_color = Color(0, 0, 0, 0.35)
    sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    shadow.material_override = sm
    shadow.position.y = 0.02
    add_child(shadow)

func build_ui():
    var layer := CanvasLayer.new()
    add_child(layer)

    top_label = Label.new()
    style_label(top_label, 34)
    layer.add_child(top_label)
    top_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
    top_label.offset_top = 50

    msg_label = Label.new()
    style_label(msg_label, 40)
    msg_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    layer.add_child(msg_label)
    msg_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func style_label(l: Label, size: int):
    l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    l.mouse_filter = Control.MOUSE_FILTER_IGNORE
    l.add_theme_font_size_override("font_size", size)
    l.add_theme_constant_override("outline_size", 8)
    l.add_theme_color_override("font_outline_color", Color.BLACK)

func show_start_message():
    msg_label.text = "MKIMBIAJI\n\nTelezesha kushoto / kulia = badilisha njia\nJuu = ruka\nChini = telezea\n\nBora: %d\n\nGusa kuanza" % best
    msg_label.visible = true

# ---------------------------------------------------------------- input

func _input(event):
    if event is InputEventScreenTouch:
        if event.pressed:
            touch_start = event.position
            touch_active = true
            swipe_done = false
            tap()
        else:
            touch_active = false
    elif event is InputEventScreenDrag:
        if touch_active and not swipe_done and alive and started:
            var d: Vector2 = event.position - touch_start
            if d.length() > 40.0:
                swipe_done = true
                if absf(d.x) > absf(d.y):
                    if d.x < 0: do_left()
                    else: do_right()
                else:
                    if d.y < 0: do_jump()
                    else: do_slide()
    elif event is InputEventKey and event.pressed and not event.echo:
        match event.keycode:
            KEY_LEFT, KEY_A: do_left()
            KEY_RIGHT, KEY_D: do_right()
            KEY_UP, KEY_W, KEY_SPACE: do_jump()
            KEY_DOWN, KEY_S: do_slide()
        tap()

func tap():
    if not started:
        started = true
        msg_label.visible = false
    elif not alive and Time.get_ticks_msec() / 1000.0 - death_time > 0.6:
        get_tree().reload_current_scene()

func do_left():
    if alive and started and lane > 0:
        lane -= 1

func do_right():
    if alive and started and lane < 2:
        lane += 1

func do_jump():
    if alive and started and py <= 0.01:
        vy = JUMP_V
        sliding = false

func do_slide():
    if alive and started:
        sliding = true
        slide_timer = 0.7
        if py > 0.01:
            vy = -22.0

# ---------------------------------------------------------------- game loop

func _process(delta):
    if not started:
        character.update_pose(delta, "idle", 0.0)
        return
    if not alive:
        character.update_pose(delta, "dead", 0.0)
        return

    speed = minf(12.0 + distance * 0.004, 26.0)
    var move := speed * delta
    distance += move

    for t in tiles:
        t.position.z += move
        if t.position.z > 16.0:
            t.position.z -= TILE_COUNT * TILE_LEN
            fill_tile(t)

    var target_x := (lane - 1) * LANE_W
    player.position.x = lerpf(player.position.x, target_x, clampf(delta * 14.0, 0.0, 1.0))

    if py > 0.0 or vy > 0.0:
        vy -= GRAVITY * delta
        py += vy * delta
        if py <= 0.0:
            py = 0.0
            vy = 0.0
    player.position.y = py

    if sliding:
        slide_timer -= delta
        if slide_timer <= 0.0 and py <= 0.0:
            sliding = false

    shadow.position.x = player.position.x
    var ss := clampf(1.0 - py * 0.3, 0.4, 1.0)
    shadow.scale = Vector3(ss, 1, ss)
    camera.position.x = lerpf(camera.position.x, player.position.x * 0.5, clampf(delta * 5.0, 0.0, 1.0))

    spawn_acc += move
    if spawn_acc >= next_gap:
        spawn_acc = 0.0
        next_gap = speed * 1.2 + rng.randf_range(4.0, 9.0)
        spawn_pattern()

    update_coins(move, delta)
    update_obstacles(move)

    var state := "run"
    if py > 0.02:
        state = "jump"
    elif sliding:
        state = "slide"
    character.update_pose(delta, state, speed)

    top_label.text = "Pointi: %d      Sarafu: %d" % [score(), coin_count]

func score() -> int:
    return int(distance) + coin_count * 10

func update_obstacles(move: float):
    var top := py + (SLIDE_H if sliding else STAND_H)
    for i in range(obstacles.size() - 1, -1, -1):
        var o: Node3D = obstacles[i]
        o.position.z += move
        if o.position.z > 8.0:
            o.queue_free()
            obstacles.remove_at(i)
            continue
        if absf(o.position.z) < float(o.get_meta("hz")) + 0.25:
            if absf(o.position.x - player.position.x) < float(o.get_meta("hx")) + 0.2:
                if top > float(o.get_meta("bottom")) and py < float(o.get_meta("top")):
                    game_over()
                    return

func update_coins(move: float, delta: float):
    var top := py + (SLIDE_H if sliding else STAND_H)
    for i in range(coins.size() - 1, -1, -1):
        var c: Node3D = coins[i]
        c.position.z += move
        c.rotation.y += delta * 4.0
        if c.position.z > 8.0:
            c.queue_free()
            coins.remove_at(i)
            continue
        if absf(c.position.z) < 0.7 and absf(c.position.x - player.position.x) < 0.7:
            if c.position.y > py - 0.1 and c.position.y < top + 0.1:
                coin_count += 1
                c.queue_free()
                coins.remove_at(i)

func game_over():
    alive = false
    death_time = Time.get_ticks_msec() / 1000.0
    var s := score()
    if s > best:
        best = s
        save_best()
    msg_label.text = "UMEANGUKA!\n\nPointi: %d\nBora: %d\n\nGusa kucheza tena" % [s, best]
    msg_label.visible = true

# ---------------------------------------------------------------- spawning

func spawn_pattern():
    var z := SPAWN_Z
    var l := rng.randi_range(0, 2)
    match rng.randi_range(0, 8):
        0, 1:
            # treni kwenye njia mbili, njia ya tatu ina sarafu
            var free_lane := rng.randi_range(0, 2)
            var tlen := rng.randf_range(5.0, 8.0)
            for k in 3:
                if k != free_lane:
                    add_train(k, z, tlen)
            add_coin_row(free_lane, z - tlen / 2.0, 6)
        2:
            add_train(l, z, rng.randf_range(4.0, 7.0))
        3, 4:
            add_barrier(l, z)
            add_coin_row((l + 1) % 3, z, 5)
        5:
            # vizuizi vya kuruka kwenye njia zote + sarafu hewani
            for k in 3:
                add_barrier(k, z)
            for k in 5:
                add_coin(0.0, 0.9 + sin(k / 4.0 * PI) * 0.8, z + 2.4 - k * 1.2)
        6:
            # upau wa juu njia zote: telezea
            for k in 3:
                add_overhead(k, z)
        7:
            add_coin_row(l, z, 8)
        _:
            add_overhead(l, z)
            add_barrier((l + 1) % 3, z)
            add_coin_row((l + 2) % 3, z, 5)

func set_hit(n: Node3D, hx: float, hz: float, bottom: float, top: float):
    n.set_meta("hx", hx)
    n.set_meta("hz", hz)
    n.set_meta("bottom", bottom)
    n.set_meta("top", top)
    add_child(n)
    obstacles.append(n)

func add_train(l: int, z: float, length: float):
    var t := Node3D.new()
    t.position = Vector3((l - 1) * LANE_W, 0, z)
    var cols := [Color("#e6494f"), Color("#f5a623"), Color("#7b4fd6"), Color("#1fa97a")]
    var col: Color = cols[rng.randi() % cols.size()]
    box(t, Vector3(1.4, 2.0, length), Vector3(0, 1.1, 0), col)
    box(t, Vector3(1.5, 0.2, length + 0.1), Vector3(0, 2.2, 0), Color("#dfe6ee"))
    box(t, Vector3(1.42, 0.3, length + 0.02), Vector3(0, 0.45, 0), Color("#2b2f3a"))
    for k in int(length / 2.0):
        box(t, Vector3(1.44, 0.6, 1.0), Vector3(0, 1.5, -length / 2.0 + 1.0 + k * 2.0), Color("#bfe6ff"))
    box(t, Vector3(1.1, 0.9, 0.05), Vector3(0, 1.5, length / 2.0 + 0.03), Color("#bfe6ff"))
    box(t, Vector3(0.25, 0.25, 0.06), Vector3(-0.45, 0.7, length / 2.0 + 0.03), Color("#fff3a8"))
    box(t, Vector3(0.25, 0.25, 0.06), Vector3(0.45, 0.7, length / 2.0 + 0.03), Color("#fff3a8"))
    set_hit(t, 0.7, length / 2.0, 0.0, 2.3)

func add_barrier(l: int, z: float):
    var t := Node3D.new()
    t.position = Vector3((l - 1) * LANE_W, 0, z)
    box(t, Vector3(1.5, 0.3, 0.4), Vector3(0, 0.55, 0), Color("#e6494f"))
    box(t, Vector3(0.4, 0.31, 0.41), Vector3(-0.4, 0.55, 0), Color("#ffffff"))
    box(t, Vector3(0.4, 0.31, 0.41), Vector3(0.4, 0.55, 0), Color("#ffffff"))
    box(t, Vector3(0.12, 0.5, 0.12), Vector3(-0.6, 0.25, 0), Color("#555b66"))
    box(t, Vector3(0.12, 0.5, 0.12), Vector3(0.6, 0.25, 0), Color("#555b66"))
    set_hit(t, 0.75, 0.25, 0.0, 0.7)

func add_overhead(l: int, z: float):
    var t := Node3D.new()
    t.position = Vector3((l - 1) * LANE_W, 0, z)
    box(t, Vector3(1.6, 0.4, 0.4), Vector3(0, 1.2, 0), Color("#f5a623"))
    box(t, Vector3(0.4, 0.41, 0.41), Vector3(-0.4, 1.2, 0), Color("#2b2f3a"))
    box(t, Vector3(0.4, 0.41, 0.41), Vector3(0.4, 1.2, 0), Color("#2b2f3a"))
    box(t, Vector3(0.15, 1.4, 0.15), Vector3(-0.72, 0.7, 0), Color("#555b66"))
    box(t, Vector3(0.15, 1.4, 0.15), Vector3(0.72, 0.7, 0), Color("#555b66"))
    set_hit(t, 0.8, 0.25, 1.0, 1.4)

func add_coin_row(l: int, z_start: float, count: int):
    for k in count:
        add_coin((l - 1) * LANE_W, 0.8, z_start + k * 1.5)

func add_coin(x: float, y: float, z: float):
    var holder := Node3D.new()
    holder.position = Vector3(x, y, z)
    var mi := MeshInstance3D.new()
    var cm := CylinderMesh.new()
    cm.top_radius = 0.28
    cm.bottom_radius = 0.28
    cm.height = 0.07
    cm.radial_segments = 16
    cm.rings = 1
    mi.mesh = cm
    mi.rotation_degrees.x = 90
    mi.material_override = mat(Color("#ffd23f"))
    holder.add_child(mi)
    add_child(holder)
    coins.append(holder)

# ---------------------------------------------------------------- save

func load_best():
    if FileAccess.file_exists("user://best.dat"):
        var f := FileAccess.open("user://best.dat", FileAccess.READ)
        if f:
            best = int(f.get_as_text())

func save_best():
    var f := FileAccess.open("user://best.dat", FileAccess.WRITE)
    if f:
        f.store_string(str(best))
