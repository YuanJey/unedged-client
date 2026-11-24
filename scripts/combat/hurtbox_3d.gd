class_name Hurtbox3D
extends Area3D

const CombatConstants = preload("res://scripts/combat/combat_constants.gd")

## 《无锋》（Unedged）躯干受击盒组件
## 监听进入的 Hitbox3D，联动 CombatStateMachine 进行受击、格挡与精准弹反裁决

signal hit_processed(hitbox: Hitbox3D, resolution: int)

@export var owner_id: int = 1
@export var state_machine: CombatStateMachine
@export var debug_mesh: MeshInstance3D

var default_material: StandardMaterial3D
var block_material: StandardMaterial3D
var parry_material: StandardMaterial3D
var hit_material: StandardMaterial3D

var feedback_timer: float = 0.0

func _ready() -> void:
	collision_layer = 0   # 自身不作为攻击盒
	collision_mask = 2    # 监听 Layer 2 (Hitboxes)
	monitoring = true
	monitorable = true

	_setup_feedback_materials()
	area_entered.connect(_on_area_entered)

func _setup_feedback_materials() -> void:
	default_material = StandardMaterial3D.new()
	default_material.albedo_color = Color(0.2, 0.8, 0.3, 0.35) # 基础翡翠绿（受击待机态）
	default_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	block_material = StandardMaterial3D.new()
	block_material.albedo_color = Color(0.1, 0.4, 1.0, 0.7)   # 宝石蓝（同向格挡成功）
	block_material.emission_enabled = true
	block_material.emission = Color(0.2, 0.5, 1.0)
	block_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	parry_material = StandardMaterial3D.new()
	parry_material.albedo_color = Color(1.0, 0.85, 0.1, 0.9)  # 璀璨金（11帧精准弹反）
	parry_material.emission_enabled = true
	parry_material.emission = Color(1.0, 0.9, 0.3)
	parry_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	hit_material = StandardMaterial3D.new()
	hit_material.albedo_color = Color(1.0, 0.0, 0.0, 0.8)     # 血红（实打实受击破绽）
	hit_material.emission_enabled = true
	hit_material.emission = Color(1.0, 0.1, 0.1)
	hit_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	if debug_mesh:
		debug_mesh.material_override = default_material

func _process(delta: float) -> void:
	if feedback_timer > 0.0:
		feedback_timer -= delta
		if feedback_timer <= 0.0 and debug_mesh:
			debug_mesh.material_override = default_material

func _on_area_entered(area: Area3D) -> void:
	if not (area is Hitbox3D):
		return
	
	var hitbox = area as Hitbox3D
	# 过滤自身武器判定
	if hitbox.attacker_id == owner_id or not hitbox.is_active:
		return

	if not state_machine:
		push_warning("Hurtbox3D 未绑定状态机，忽略碰撞处理")
		return

	# 将攻击者方向与伤害送入核心状态机进行三向对决裁决
	var resolution = state_machine.resolve_incoming_attack(
		hitbox.attack_direction,
		hitbox.raw_damage,
		hitbox.is_unblockable
	)

	_trigger_visual_feedback(resolution)
	hit_processed.emit(hitbox, resolution)

## 根据裁决结果呈现即时碰撞高亮反馈
func _trigger_visual_feedback(resolution: int) -> void:
	if not debug_mesh:
		return

	feedback_timer = 0.22 # 高亮持续时间约 13 帧
	match resolution:
		CombatConstants.HitResolution.PERFECT_PARRY:
			debug_mesh.material_override = parry_material
			print("[对决裁决] >>> ⚡ 触发完美弹反（PERFECT_PARRY）！金光自发光高亮")
		CombatConstants.HitResolution.GUARD_BLOCKED:
			debug_mesh.material_override = block_material
			print("[对决裁决] >>> 🛡️ 触发同向格挡（GUARD_BLOCKED）！消耗耐力")
		CombatConstants.HitResolution.CLEAN_HIT, CombatConstants.HitResolution.GUARD_BROKEN:
			debug_mesh.material_override = hit_material
			print("[对决裁决] >>> 💥 实质命中受击（CLEAN_HIT / GUARD_BROKEN）！扣除血量")
