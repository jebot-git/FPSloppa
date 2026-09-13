extends RefCounted
## Preserve bounds used by doors/lifts/fall limits without retaining render resources.
const BOUNDS:="server_geometry_bounds"
static func strip(root: Node3D) -> void:
	var stack: Array=[root]
	while not stack.is_empty():
		var node: Node=stack.pop_back()
		if node is MeshInstance3D:
			var bounds: AABB=node.get_aabb()
			var replacement:=Node3D.new();replacement.name=node.name;replacement.transform=node.transform
			replacement.set_meta(BOUNDS,bounds)
			var parent:=node.get_parent();parent.remove_child(node);parent.add_child(replacement);replacement.owner=root
			for child in node.get_children():child.reparent(replacement,false)
			node.free();node=replacement
		elif node is VisualInstance3D or node is Camera3D or node is WorldEnvironment or node is AudioStreamPlayer3D:
			node.free();continue
		stack.append_array(node.get_children())
