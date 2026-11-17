extends StaticBody3D
## Test object: changes colour each time it is used.

const COLOURS := [
	Color(0.85, 0.15, 0.15),
	Color(0.15, 0.6, 0.2),
	Color(0.2, 0.4, 0.9),
	Color(0.95, 0.8, 0.1),
]

@onready var mesh: MeshInstance3D = $Mesh

var _index := 0
var _material := StandardMaterial3D.new()


func _ready() -> void:
	_material.albedo_color = COLOURS[0]
	mesh.material_override = _material


func interact() -> void:
	_index = (_index + 1) % COLOURS.size()
	_material.albedo_color = COLOURS[_index]
