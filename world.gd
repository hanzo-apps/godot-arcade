extends Node3D
## Orb Runner — the whole game, built in code so the repo has no binary scenes
## to merge-conflict on. Roll the sphere, bank the orbs, don't fall off the arena.

const ARENA := 22.0
const SPEED := 14.0
const JUMP := 9.0
const GRAVITY := 26.0
const ROUND_TIME := 60.0

var player: CharacterBody3D
var cam: Camera3D
var hud: Label
var orbs: Node3D
var score := 0
var best := 0
var clock := ROUND_TIME

func _ready() -> void:
	_build_world()
	_build_player()
	orbs = Node3D.new()
	add_child(orbs)
	for i in 7:
		_spawn_orb()
	hud = Label.new()
	hud.position = Vector2(24, 18)
	hud.add_theme_font_size_override("font_size", 26)
	hud.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	var layer := CanvasLayer.new()
	layer.add_child(hud)
	add_child(layer)

func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var mat := ProceduralSkyMaterial.new()
	mat.sky_top_color = Color(0.03, 0.04, 0.10)
	mat.sky_horizon_color = Color(0.10, 0.06, 0.22)
	mat.ground_bottom_color = Color(0.02, 0.02, 0.05)
	mat.ground_horizon_color = Color(0.08, 0.05, 0.16)
	sky.sky_material = mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_energy = 1.3
	sun.light_color = Color(1.0, 0.93, 0.85)
	add_child(sun)

	var floor_body := StaticBody3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(ARENA * 2, 1, ARENA * 2)
	var mi := MeshInstance3D.new()
	mi.mesh = box
	mi.material_override = _mat(Color(0.09, 0.11, 0.18), Color(0.05, 0.12, 0.25), 0.35)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box.size
	cs.shape = shape
	floor_body.add_child(mi)
	floor_body.add_child(cs)
	floor_body.position.y = -0.5
	add_child(floor_body)

	# Grid of emissive pillars: cheap depth cue + a reason to steer.
	for x in range(-2, 3):
		for z in range(-2, 3):
			if x == 0 and z == 0:
				continue
			var p := StaticBody3D.new()
			var pm := BoxMesh.new()
			pm.size = Vector3(1.2, 3.0, 1.2)
			var pmi := MeshInstance3D.new()
			pmi.mesh = pm
			pmi.material_override = _mat(Color(0.15, 0.08, 0.3), Color(0.35, 0.1, 0.6), 0.8)
			var pcs := CollisionShape3D.new()
			var ps := BoxShape3D.new()
			ps.size = pm.size
			pcs.shape = ps
			p.add_child(pmi)
			p.add_child(pcs)
			p.position = Vector3(x * 8.0, 1.5, z * 8.0)
			add_child(p)

func _build_player() -> void:
	player = CharacterBody3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.7
	sm.height = 1.4
	var mi := MeshInstance3D.new()
	mi.mesh = sm
	mi.material_override = _mat(Color(0.2, 0.9, 0.8), Color(0.1, 0.9, 0.8), 1.4)
	var cs := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.7
	cs.shape = shape
	player.add_child(mi)
	player.add_child(cs)
	player.position = Vector3(0, 2, 0)
	add_child(player)

	cam = Camera3D.new()
	cam.fov = 65.0
	add_child(cam)
	_track_camera(1.0)

func _mat(albedo: Color, emit: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo
	m.metallic = 0.2
	m.roughness = 0.45
	if energy > 0.0:
		m.emission_enabled = true
		m.emission = emit
		m.emission_energy_multiplier = energy
	return m

func _spawn_orb() -> void:
	var a := Area3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.45
	sm.height = 0.9
	var mi := MeshInstance3D.new()
	mi.mesh = sm
	mi.material_override = _mat(Color(1.0, 0.8, 0.2), Color(1.0, 0.7, 0.1), 2.2)
	var cs := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.9
	cs.shape = shape
	a.add_child(mi)
	a.add_child(cs)
	a.position = Vector3(randf_range(-ARENA + 2, ARENA - 2), 1.2, randf_range(-ARENA + 2, ARENA - 2))
	a.body_entered.connect(func(b): _collect(a, b))
	orbs.add_child(a)

func _collect(orb: Area3D, body: Node) -> void:
	if body != player or not is_instance_valid(orb):
		return
	score += 1
	best = maxi(best, score)
	orb.queue_free()
	_spawn_orb()

func _process(delta: float) -> void:
	clock -= delta
	if clock <= 0.0:
		_reset()
	orbs.rotate_y(delta * 0.9)
	_track_camera(delta * 6.0)
	hud.text = "ORBS %d    BEST %d    %0.1fs\nWASD / arrows to roll, SPACE to hop" % [score, best, clock]

func _track_camera(w: float) -> void:
	var want := player.position + Vector3(0, 11, 15)
	cam.position = cam.position.lerp(want, clampf(w, 0.0, 1.0))
	cam.look_at(player.position + Vector3.UP * 1.5, Vector3.UP)

func _physics_process(delta: float) -> void:
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var wish := Vector3(dir.x, 0, dir.y)
	player.velocity.x = move_toward(player.velocity.x, wish.x * SPEED, SPEED * 6.0 * delta)
	player.velocity.z = move_toward(player.velocity.z, wish.z * SPEED, SPEED * 6.0 * delta)
	if player.is_on_floor():
		if Input.is_action_pressed("jump"):
			player.velocity.y = JUMP
	else:
		player.velocity.y -= GRAVITY * delta
	player.move_and_slide()
	if player.position.y < -12.0:
		_reset()

func _reset() -> void:
	score = 0
	clock = ROUND_TIME
	player.position = Vector3(0, 2, 0)
	player.velocity = Vector3.ZERO
