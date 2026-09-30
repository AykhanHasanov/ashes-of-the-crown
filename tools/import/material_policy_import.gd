@tool
extends EditorScenePostImport
## glTF import script (the .import files' import_script/path): applies the material rule
## (scripts/core/material_policy.gd) to every imported model, so no non-metal comes in
## metallic or glossy.

const MaterialPolicy := preload("res://scripts/core/material_policy.gd")


func _post_import(scene: Node) -> Object:
	MaterialPolicy.apply(scene)
	return scene
