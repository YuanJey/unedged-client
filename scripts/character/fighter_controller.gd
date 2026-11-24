class_name FighterController
extends CharacterBody3D

## 《无锋》（Unedged）3D 角色运动、输入打包与战斗实体控制器
## 驱动 60Hz 逻辑帧输入、三向攻防变换与武器判定盒生命周期

@export var fighter_id: int = 1
@export var is_bot: bool = false
@export var move_speed: float = 4.5

@onready var state_machine: CombatStateMachine = $CombatStateMachine
@onready var hitbox: Hitbox3D = $WeaponPivot/Hitbox3D
@onready var hurtbox: Hurtbox3D = $Hurtbox3D
@onready var weapon_pivot: Node3D = $WeaponPivot
@onready var debug_label: Label3D = $DebugLabel
@onready var stance_indicator: Node3D = $StanceIndicator

# 重力加速度
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

# 挥刀表现插值变量
var base_weapon_rot: Vector3 = Vector3.ZERO
var swing_progress: float = 0.0

# 假人自动测试定时器
var bot_action_timer: float = 0.0

func _ready() -> void:
	if hitbox:
		hitbox.attacker_id = fighter_id
	if hurtbox:
		hurtbox.owner_id = fighter_id
		hurtbox.state_machine = state_machine

	state_machine.state_changed.connect(_on_state_changed)
	state_machine.parry_triggered.connect(_on_parry_triggered)
	base_weapon_rot = weapon_pivot.rotation

func _physics_process(delta: float) -> void:
	# 1. 物理重力计算
	if not is_on_floor():
		velocity.y -= gravity * delta

	# 2. 采集单帧输入并喂给状态机
	var input_mask: int = 0
	var aim_dir: int = CombatConstants.CombatDirection.NONE

	if not is_bot:
		# 玩家输入读取
		var move_input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		var move_dir = (transform.basis * Vector3(move_input.x, 0, move_input.y)).normalized()
		
		# 状态机硬直阻断移动
		if state_machine.current_state in [CombatConstants.CombatState.IDLE, CombatConstants.CombatState.MOVING]:
			velocity.x = move_dir.x * move_speed * state_machine.current_speed_mult
			velocity.z = move_dir.z * move_speed * state_machine.current_speed_mult
		else:
			velocity.x = move_toward(velocity.x, 0, move_speed * delta * 8.0)
			velocity.z = move_toward(velocity.z, 0, move_speed * delta * 8.0)

		# 方向键切换三向架势
		if Input.is_action_pressed("dir_top"):
			aim_dir = CombatConstants.CombatDirection.TOP
		elif Input.is_action_pressed("dir_left"):
			aim_dir = CombatConstants.CombatDirection.LEFT
		elif Input.is_action_pressed("dir_right"):
			aim_dir = CombatConstants.CombatDirection.RIGHT

		# 动作位掩码拼接
		if Input.is_action_just_pressed("attack_light"):
			input_mask |= CombatConstants.ACTION_ATTACK_LIGHT
		if Input.is_action_just_pressed("attack_heavy"):
			input_mask |= CombatConstants.ACTION_ATTACK_HEAVY
		if Input.is_action_pressed("guard"):
			input_mask |= CombatConstants.ACTION_GUARD
		if Input.is_action_just_pressed("dodge"):
			input_mask |= CombatConstants.ACTION_DODGE
		if Input.is_action_just_pressed("stance_switch"):
			input_mask |= CombatConstants.ACTION_SWITCH_GRIP
		if Input.is_action_just_pressed("skill_1"):
			input_mask |= CombatConstants.ACTION_SKILL_1
		if Input.is_action_just_pressed("skill_2"):
			input_mask |= CombatConstants.ACTION_SKILL_2
	else:
		# 假人行为模式：周期性摆出架势并自动挥刀，供弹反测试
		velocity.x = 0
		velocity.z = 0
		bot_action_timer += delta
		aim_dir = CombatConstants.CombatDirection.TOP
		if bot_action_timer > 3.0:
			bot_action_timer = 0.0
			input_mask |= CombatConstants.ACTION_ATTACK_LIGHT
		else:
			input_mask |= CombatConstants.ACTION_GUARD

	# 驱动状态机逻辑帧推进
	state_machine.process_combat_frame(input_mask, aim_dir)
	move_and_slide()

	# 3. 挥刀表现插值更新
	_update_weapon_visual(delta)
	_update_stance_indicator()
	_update_debug_ui()

func _update_weapon_visual(delta: float) -> void:
	if not weapon_pivot:
		return

	# 根据握持姿态微调武器基准坐标（单持 vs 左手换手 vs 双持）
	match state_machine.current_stance:
		CombatConstants.GripStance.ONE_HAND_R:
			weapon_pivot.position = Vector3(0.45, 0.9, -0.2)
		CombatConstants.GripStance.ONE_HAND_L:
			weapon_pivot.position = Vector3(-0.45, 0.9, -0.2) # 换手镜像位置
		CombatConstants.GripStance.TWO_HAND:
			weapon_pivot.position = Vector3(0.0, 1.0, -0.3)  # 中置双手持握

	# 攻击判定有效帧中执行物理前挥横扫
	if state_machine.current_state == CombatConstants.CombatState.ATTACK_ACTIVE:
		swing_progress = min(1.0, swing_progress + delta * 12.0)
		var swing_offset = Vector3(-deg_to_rad(65.0) * swing_progress, deg_to_rad(45.0) * swing_progress, 0)
		weapon_pivot.rotation = base_weapon_rot + swing_offset
	elif state_machine.current_state == CombatConstants.CombatState.ATTACK_RECOVERY:
		swing_progress = max(0.0, swing_progress - delta * 6.0)
		var swing_offset = Vector3(-deg_to_rad(65.0) * swing_progress, deg_to_rad(45.0) * swing_progress, 0)
		weapon_pivot.rotation = base_weapon_rot + swing_offset
	else:
		swing_progress = 0.0
		weapon_pivot.rotation = base_weapon_rot

func _update_stance_indicator() -> void:
	if not stance_indicator:
		return
	# 改变指示光环朝向（上 / 左 / 右）
	match state_machine.current_direction:
		CombatConstants.CombatDirection.TOP:
			stance_indicator.rotation_degrees = Vector3(0, 0, 0)
		CombatConstants.CombatDirection.LEFT:
			stance_indicator.rotation_degrees = Vector3(0, 0, 45)
		CombatConstants.CombatDirection.RIGHT:
			stance_indicator.rotation_degrees = Vector3(0, 0, -45)

func _on_state_changed(old_state: int, new_state: int) -> void:
	# 判定有效帧严格控制 Hitbox 唤醒与休眠
	if new_state == CombatConstants.CombatState.ATTACK_ACTIVE:
		var dmg = int(120 * state_machine.current_damage_mult)
		hitbox.activate(state_machine.current_direction, dmg, false)
	elif old_state == CombatConstants.CombatState.ATTACK_ACTIVE:
		hitbox.deactivate()

func _on_parry_triggered(direction: int) -> void:
	print("[角色 %d] 成功在方向 %d 触发 11 帧精准弹反！" % [fighter_id, direction])

func _update_debug_ui() -> void:
	if not debug_label:
		return

	var dir_name = "上"
	match state_machine.current_direction:
		CombatConstants.CombatDirection.LEFT: dir_name = "左"
		CombatConstants.CombatDirection.RIGHT: dir_name = "右"

	var stance_name = "右手单持"
	match state_machine.current_stance:
		CombatConstants.GripStance.ONE_HAND_L: stance_name = "左手换手"
		CombatConstants.GripStance.TWO_HAND: stance_name = "双手持握(霸体)"

	var state_name = "待机"
	match state_machine.current_state:
		CombatConstants.CombatState.ATTACK_STARTUP: state_name = "起手前摇"
		CombatConstants.CombatState.ATTACK_ACTIVE: state_name = "★ 判定生效中 ★"
		CombatConstants.CombatState.ATTACK_RECOVERY: state_name = "收招后摇"
		CombatConstants.CombatState.GUARDING: state_name = "架势防御中"
		CombatConstants.CombatState.HITSTUN: state_name = "受击硬直"

	debug_label.text = "[角色 %d - %s]\n状态: %s | 架势: %s\n姿态: %s\nHP: %d/%d | 体力: %d/%d" % [
		fighter_id,
		"玩家" if not is_bot else "训练木桩",
		state_name,
		dir_name,
		stance_name,
		state_machine.current_hp,
		state_machine.max_hp,
		state_machine.current_stamina,
		state_machine.max_stamina
	]
