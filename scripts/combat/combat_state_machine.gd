class_name CombatStateMachine
extends Node

## 《无锋》（Unedged）核心战斗状态机
## 负责管理三向攻防判定、弹反时间窗、握持姿态切换及逻辑帧驱动

signal state_changed(old_state: int, new_state: int)
signal parry_triggered(direction: int)
signal hit_received(damage: int, hit_type: int)

# 状态变量
var current_state: int = CombatConstants.CombatState.IDLE
var current_direction: int = CombatConstants.CombatDirection.TOP
var current_stance: int = CombatConstants.GripStance.ONE_HAND_R

# 判定计数器（以 60Hz 逻辑帧为单位）
var frame_counter: int = 0
var state_duration_frames: int = 0

# 战斗数值属性（从 weapons.json 加载并缓存）
var max_hp: int = 1000
var current_hp: int = 1000
var max_stamina: int = 100
var current_stamina: int = 100
var parry_window_frames: int = 11

# 姿态加成配置
var current_damage_mult: float = 1.0
var current_speed_mult: float = 1.0
var has_hyper_armor: bool = false

func _ready() -> void:
	load_weapon_configuration("td_standard_01")

## 加载武器基础属性与姿态参数
func load_weapon_configuration(weapon_id: String) -> void:
	var config_path: String = "res://assets/configs/weapons.json"
	if not FileAccess.file_exists(config_path):
		push_warning("未找到武器配置文件: %s，采用内置保底数值" % config_path)
		return
	
	var file = FileAccess.open(config_path, FileAccess.READ)
	var json_str = file.get_as_text()
	var json = JSON.new()
	if json.parse(json_str) == OK:
		var data = json.get_data()
		if data.has("archetypes") and data["archetypes"].has("TANGDAO"):
			var tangdao = data["archetypes"]["TANGDAO"]
			var base_stats = tangdao.get("base_stats", {})
			max_hp = base_stats.get("max_hp", 1000)
			current_hp = max_hp
			max_stamina = base_stats.get("max_stamina", 100)
			current_stamina = max_stamina
			parry_window_frames = base_stats.get("parry_window_frames", 11)
			_apply_stance_modifiers()

## 切换握持姿态（单持 / 换手 / 双手）
func switch_stance(target_stance: int) -> void:
	if current_stance == target_stance:
		return
	current_stance = target_stance
	_apply_stance_modifiers()

func _apply_stance_modifiers() -> void:
	match current_stance:
		CombatConstants.GripStance.ONE_HAND_R:
			current_speed_mult = 1.05
			current_damage_mult = 1.0
			has_hyper_armor = false
		CombatConstants.GripStance.ONE_HAND_L:
			current_speed_mult = 1.05
			current_damage_mult = 1.0
			has_hyper_armor = false
		CombatConstants.GripStance.TWO_HAND:
			current_speed_mult = 0.92
			current_damage_mult = 1.2
			has_hyper_armor = true

## 每逻辑帧驱动（60Hz Fixed Process）
func process_combat_frame(input_mask: int, aim_dir: int) -> void:
	frame_counter += 1
	if aim_dir != CombatConstants.CombatDirection.NONE:
		current_direction = aim_dir

	# 姿态切换输入处理
	if input_mask & CombatConstants.ACTION_SWITCH_GRIP:
		var next_stance = (current_stance + 1) % 3
		switch_stance(next_stance)

	# 状态机生命周期演进
	match current_state:
		CombatConstants.CombatState.IDLE, CombatConstants.CombatState.MOVING:
			if input_mask & CombatConstants.ACTION_GUARD:
				_transition_to(CombatConstants.CombatState.GUARDING, 0)
			elif input_mask & CombatConstants.ACTION_ATTACK_LIGHT:
				_transition_to(CombatConstants.CombatState.ATTACK_STARTUP, 8)
		
		CombatConstants.CombatState.GUARDING:
			if not (input_mask & CombatConstants.ACTION_GUARD):
				_transition_to(CombatConstants.CombatState.IDLE, 0)

		CombatConstants.CombatState.ATTACK_STARTUP:
			if frame_counter >= state_duration_frames:
				_transition_to(CombatConstants.CombatState.ATTACK_ACTIVE, 4)

		CombatConstants.CombatState.ATTACK_ACTIVE:
			if frame_counter >= state_duration_frames:
				_transition_to(CombatConstants.CombatState.ATTACK_RECOVERY, 12)

		CombatConstants.CombatState.ATTACK_RECOVERY:
			if frame_counter >= state_duration_frames:
				_transition_to(CombatConstants.CombatState.IDLE, 0)

		CombatConstants.CombatState.HITSTUN:
			if frame_counter >= state_duration_frames:
				_transition_to(CombatConstants.CombatState.IDLE, 0)

## 核心受击裁决（三向攻防同向克制与弹反检测）
func resolve_incoming_attack(attacker_dir: int, raw_damage: int, is_unblockable: bool) -> int:
	# 不可格挡重招判定
	if is_unblockable:
		current_hp -= int(raw_damage * current_damage_mult)
		_transition_to(CombatConstants.CombatState.HITSTUN, 20)
		hit_received.emit(raw_damage, CombatConstants.HitResolution.GUARD_BROKEN)
		return CombatConstants.HitResolution.GUARD_BROKEN

	# 防御状态判定
	if current_state == CombatConstants.CombatState.GUARDING:
		# 同向格挡判定
		if current_direction == attacker_dir:
			# 0.18 秒（约 11 帧）内触发精准弹反
			if frame_counter <= parry_window_frames:
				parry_triggered.emit(current_direction)
				return CombatConstants.HitResolution.PERFECT_PARRY
			else:
				# 常规格挡成功，消耗耐力
				current_stamina = max(0, current_stamina - 20)
				return CombatConstants.HitResolution.GUARD_BLOCKED

	# 未防御或异向格挡，直接受击
	current_hp -= raw_damage
	_transition_to(CombatConstants.CombatState.HITSTUN, 15)
	hit_received.emit(raw_damage, CombatConstants.HitResolution.CLEAN_HIT)
	return CombatConstants.HitResolution.CLEAN_HIT

func _transition_to(new_state: int, duration_frames: int) -> void:
	var old_state = current_state
	current_state = new_state
	frame_counter = 0
	state_duration_frames = duration_frames
	state_changed.emit(old_state, new_state)

