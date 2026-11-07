extends Node3D

# Muundo wa character ni ule ule wa awali (Head, Hoodie, Arms, Legs, Eyes, Shoes).
# Nimeongeza: Hood (kofia ya nyuma) na pivot za mikono/miguu ili ziweze kukimbia.

var left_arm: Node3D
var right_arm: Node3D
var left_leg: Node3D
var right_leg: Node3D
var run_time := 0.0
var base_y := 0.0

func _ready():
    create_character()
    base_y = position.y

func create_part(part_name, mesh, pos, color, parent = null):
    var part = MeshInstance3D.new()
    part.name = part_name
    part.mesh = mesh
    part.position = pos

    var material = StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.85

    part.material_override = material
    if parent == null:
        parent = self
    parent.add_child(part)
    return part

func make_pivot(pivot_name, pos):
    var pivot = Node3D.new()
    pivot.name = pivot_name
    pivot.position = pos
    add_child(pivot)
    return pivot

func create_character():

    # Head
    var head = SphereMesh.new()
    head.radius = 0.38
    head.height = 0.76
    create_part("Head", head, Vector3(0, 1.65, 0), Color("#d99b70"))

    # Hood (inaonekana mgongoni)
    var hood = SphereMesh.new()
    hood.radius = 0.3
    hood.height = 0.6
    create_part("Hood", hood, Vector3(0, 1.5, -0.22), Color("#1c5db0"))

    # Body / Hoodie
    var body = CapsuleMesh.new()
    body.radius = 0.35
    body.height = 1.0
    create_part("Hoodie", body, Vector3(0, 0.85, 0), Color("#2475d5"))

    # Left and right arms (kwenye pivot ya bega)
    for side in [-1, 1]:
        var pivot = make_pivot("ArmPivot", Vector3(side * 0.46, 1.25, 0))
        var arm = CapsuleMesh.new()
        arm.radius = 0.13
        arm.height = 0.75
        create_part("Arm", arm, Vector3(0, -0.35, 0), Color("#d99b70"), pivot)
        pivot.rotation.z = -side * 0.25
        if side < 0:
            left_arm = pivot
        else:
            right_arm = pivot

    # Legs + Shoes (kwenye pivot ya nyonga)
    for side in [-1, 1]:
        var pivot = make_pivot("LegPivot", Vector3(side * 0.19, 0.55, 0))
        var leg = CapsuleMesh.new()
        leg.radius = 0.15
        leg.height = 0.8
        create_part("Leg", leg, Vector3(0, -0.4, 0), Color("#252b38"), pivot)

        var shoe = BoxMesh.new()
        shoe.size = Vector3(0.3, 0.15, 0.4)
        create_part("Shoe", shoe, Vector3(0, -0.82, 0.08), Color("#eeeeee"), pivot)

        if side < 0:
            left_leg = pivot
        else:
            right_leg = pivot

    # Eyes
    for side in [-1, 1]:
        var eye = SphereMesh.new()
        eye.radius = 0.055
        eye.height = 0.11
        create_part("Eye", eye, Vector3(side * 0.13, 1.72, 0.34), Color.WHITE)

# state: "idle", "run", "jump", "slide", "dead"
func update_pose(delta: float, state: String, speed: float):
    var tilt := 0.0
    match state:
        "run":
            run_time += delta * (9.0 + speed * 0.25)
            var s := sin(run_time)
            left_leg.rotation.x = s * 0.9
            right_leg.rotation.x = -s * 0.9
            left_arm.rotation.x = -s * 0.8
            right_arm.rotation.x = s * 0.8
            position.y = base_y + abs(cos(run_time)) * 0.06
        "jump":
            left_leg.rotation.x = 0.7
            right_leg.rotation.x = -0.5
            left_arm.rotation.x = -2.6
            right_arm.rotation.x = -2.6
            position.y = base_y
        "slide":
            tilt = -1.2
            left_leg.rotation.x = 0.0
            right_leg.rotation.x = 0.0
            left_arm.rotation.x = 0.6
            right_arm.rotation.x = 0.6
            position.y = base_y
        "dead":
            tilt = -1.4
            left_leg.rotation.x = 0.4
            right_leg.rotation.x = -0.3
            left_arm.rotation.x = -1.8
            right_arm.rotation.x = -1.2
            position.y = base_y
        _:
            run_time += delta * 2.0
            var w := sin(run_time) * 0.1
            left_arm.rotation.x = w
            right_arm.rotation.x = -w
            left_leg.rotation.x = 0.0
            right_leg.rotation.x = 0.0
            position.y = base_y
    rotation.x = lerpf(rotation.x, tilt, clampf(delta * 14.0, 0.0, 1.0))
