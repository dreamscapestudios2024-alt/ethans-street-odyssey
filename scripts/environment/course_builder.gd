class_name CourseBuilder
extends RefCounted
## Places StreetModules end-to-end on a shared 2D world coordinate system.
## `layout` is an Array of Dictionaries: {type: StreetModule.Type, ...props}.
## Hybrid fixed/random assembly can later feed this same API with generated
## layouts (see docs/architecture.md).

var cursor := Vector2.ZERO
var modules: Array[StreetModule] = []

func _init(start: Vector2 = Vector2.ZERO) -> void:
	cursor = start

func place(parent: Node, spec: Dictionary) -> StreetModule:
	var m := StreetModule.new()
	m.type = spec["type"]
	for key: String in spec:
		if key != "type":
			m.set(key, spec[key])
	m.position = cursor
	parent.add_child(m)
	cursor += m.end_offset()
	modules.append(m)
	return m

func build(parent: Node, layout: Array) -> void:
	for spec: Dictionary in layout:
		place(parent, spec)
