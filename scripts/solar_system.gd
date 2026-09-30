extends Node3D

const SUN_SCENE: PackedScene = preload("res://assets/models/sun.glb")
const EARTH_SCENE: PackedScene = preload("res://assets/models/earth.glb")
const MARS_SCENE: PackedScene = preload("res://assets/models/mars.glb")
const JUPITER_SCENE: PackedScene = preload("res://assets/models/jupiter.glb")

const STAR_COUNT := 180
const MOUSE_SENSITIVITY := 0.0025

var camera: Camera3D
var orbiters: Array[Dictionary] = []
var yaw := 0.0
var pitch := 0.0


func _ready() -> void:
	_build_environment()
	_build_sun()
	_add_planet("Earth", EARTH_SCENE, 8.0, 0.78, 0.16, 0.7, 0.3)
	_add_planet("Mars", MARS_SCENE, 12.0, 0.58, 0.11, 0.55, 1.8)
	_add_planet("Jupiter", JUPITER_SCENE, 17.0, 1.45, 0.055, 0.9, 3.9)
	_build_stars()
	_build_camera()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	for item in orbiters:
		var pivot: Node3D = item["pivot"]
		var model: Node3D = item["model"]
		pivot.rotation.y += float(item["orbit_speed"]) * delta
		model.rotation.y += float(item["spin_speed"]) * delta
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	var direction := Vector3.ZERO
	if Input.is_key_pressed(KEY_W): direction.z -= 1.0
	if Input.is_key_pressed(KEY_S): direction.z += 1.0
	if Input.is_key_pressed(KEY_A): direction.x -= 1.0
	if Input.is_key_pressed(KEY_D): direction.x += 1.0
	if Input.is_key_pressed(KEY_E) or Input.is_key_pressed(KEY_SPACE): direction.y += 1.0
	if Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_CTRL): direction.y -= 1.0
	var speed := 18.0 if Input.is_key_pressed(KEY_SHIFT) else 7.0
	if direction != Vector3.ZERO:
		var movement := camera.basis * Vector3(direction.x, 0.0, direction.z) + Vector3.UP * direction.y
		camera.position += movement.normalized() * speed * delta


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.position -= camera.basis.z * 1.2
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.position += camera.basis.z * 1.2
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * MOUSE_SENSITIVITY
		pitch = clampf(pitch - event.relative.y * MOUSE_SENSITIVITY, -1.5, 1.5)
		camera.rotation = Vector3(pitch, yaw, 0.0)


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.006, 0.009, 0.025)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.17, 0.21, 0.32)
	env.ambient_light_energy = 0.75
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)


func _build_sun() -> void:
	var sun := SUN_SCENE.instantiate() as Node3D
	sun.name = "Sun"
	sun.scale = Vector3.ONE * 2.0
	add_child(sun)
	var light := OmniLight3D.new()
	light.name = "SunLight"
	light.light_color = Color(1.0, 0.83, 0.57)
	light.light_energy = 5.0
	light.omni_range = 45.0
	light.shadow_enabled = false
	add_child(light)
	var halo_mesh := SphereMesh.new()
	halo_mesh.radius = 2.45
	halo_mesh.height = 4.9
	halo_mesh.radial_segments = 24
	halo_mesh.rings = 12
	var halo_material := StandardMaterial3D.new()
	halo_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	halo_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo_material.albedo_color = Color(1.0, 0.47, 0.08, 0.09)
	halo_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	var halo := MeshInstance3D.new()
	halo.name = "SunGlow"
	halo.mesh = halo_mesh
	halo.material_override = halo_material
	add_child(halo)


func _add_planet(label: String, scene: PackedScene, radius: float, size: float, orbit_speed: float, spin_speed: float, start_angle: float) -> void:
	var pivot := Node3D.new()
	pivot.name = label + "Orbit"
	pivot.rotation.y = start_angle
	add_child(pivot)
	var model := scene.instantiate() as Node3D
	model.name = label
	model.position.x = radius
	model.scale = Vector3.ONE * size
	pivot.add_child(model)
	orbiters.append({"pivot": pivot, "model": model, "orbit_speed": orbit_speed, "spin_speed": spin_speed})
	var ring := MeshInstance3D.new()
	ring.name = label + "OrbitLine"
	var torus := TorusMesh.new()
	torus.inner_radius = radius - 0.018
	torus.outer_radius = radius + 0.018
	torus.rings = 128
	torus.ring_segments = 4
	ring.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.17, 0.28, 0.42)
	ring.material_override = mat
	add_child(ring)


func _build_stars() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.035
	mesh.height = 0.07
	mesh.radial_segments = 4
	mesh.rings = 2
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.72, 0.82, 1.0)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = STAR_COUNT
	var rng := RandomNumberGenerator.new()
	rng.seed = 45117
	for i in STAR_COUNT:
		var angle := rng.randf_range(0.0, TAU)
		var height := rng.randf_range(-0.85, 0.85)
		var radius := rng.randf_range(70.0, 95.0)
		var flat := sqrt(1.0 - height * height)
		var position := Vector3(cos(angle) * flat, height, sin(angle) * flat) * radius
		var transform := Transform3D(Basis.IDENTITY, position)
		multi.set_instance_transform(i, transform)
	var stars := MultiMeshInstance3D.new()
	stars.name = "Stars"
	stars.multimesh = multi
	stars.material_override = material
	add_child(stars)


func _build_camera() -> void:
	camera = Camera3D.new()
	camera.name = "FreeCamera"
	camera.current = true
	camera.fov = 75.0
	camera.near = 0.04
	camera.far = 150.0
	camera.position = Vector3(0.0, 10.0, 25.0)
	add_child(camera)
	camera.look_at(Vector3.ZERO)
	yaw = camera.rotation.y
	pitch = camera.rotation.x
