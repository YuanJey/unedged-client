class_name Hitbox3D
extends Area3D

## 《无锋》（Unedged）武器攻击判定盒组件
## 挂载于刀身刃部，仅在状态机进入有效判定帧（ATTACK_ACTIVE）时激活

@export var attacker_id: int = 1
@export var debug_mesh: MeshInstance3D

var attack_direction: int = CombatConstants.CombatDirection.TOP
var raw_damage: int = 100
var is_unblockable: bool = false
var is_active: bool = false

# 调试可视化高亮材质
var active_material: StandardMaterial3D
var inactive_material: StandardMaterial3D

func _ready() -> void:
	collision_layer = 2  # Layer 2: Hitboxes
	collision_mask = 0   # 自身不主动检测碰撞，由 Hurtbox 监听
	monitoring = false
	monitorable = false

	_setup_debug_materials()
	deactivate()

func _setup_debug_materials() -> void:
	active_material = StandardMaterial3D.new()
	active_material.albedo_color = Color(1.0, 0.1, 0.1, 0.7) # 鲜红半透明（攻击判定中）
	active_material.emission_enabled = true
	active_material.emission = Color(1.0, 0.2, 0.2)
	active_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	inactive_material = StandardMaterial3D.new()
	inactive_material.albedo_color = Color(0.5, 0.5, 0.5, 0.1) # 灰色隐蔽（休眠态）
	inactive_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

## 激活攻击判定盒
func activate(dir: int, damage: int, unblockable: bool = false) -> void:
	attack_direction = dir
	raw_damage = damage
	is_unblockable = unblockable
	is_active = true
	
	monitorable = true
	if debug_mesh:
		debug_mesh.material_override = active_material
		debug_mesh.visible = true

## 停用攻击判定盒（收招或中断时调用）
func deactivate() -> void:
	is_active = false
	monitorable = false
	if debug_mesh:
		debug_mesh.material_override = inactive_material
		debug_mesh.visible = false
