class_name CombatConstants
extends RefCounted

## 《无锋》（Unedged）核心战斗常量与枚举定义

# 三向攻防架势方向
enum CombatDirection {
	NONE = 0,
	TOP = 1,   # 上段
	LEFT = 2,  # 左侧
	RIGHT = 3  # 右侧
}

# 武器握持姿态
enum GripStance {
	ONE_HAND_R = 0, # 右手单持（默认，移速增益）
	ONE_HAND_L = 1, # 左手换手（镜像动作，变奏突袭）
	TWO_HAND = 2    # 双手持握（双手沉劲，高伤重势，耐力减免）
}

# 动作按键位掩码（用于 60Hz 输入打包与网络帧同步）
const ACTION_NONE: int = 0
const ACTION_ATTACK_LIGHT: int = 1 << 0   # 1: 轻击
const ACTION_ATTACK_HEAVY: int = 1 << 1   # 2: 重击
const ACTION_GUARD: int = 1 << 2          # 4: 防御/格挡
const ACTION_DODGE: int = 1 << 3          # 8: 闪避
const ACTION_SWITCH_GRIP: int = 1 << 4    # 16: 切换持握姿态
const ACTION_SKILL_1: int = 1 << 5        # 32: 名器绝学 1
const ACTION_SKILL_2: int = 1 << 6        # 64: 名器绝学 2
const ACTION_FEINT_CANCEL: int = 1 << 7   # 128: 变招/虚晃打断

# 战斗判定状态
enum CombatState {
	IDLE,             # 待机立回
	MOVING,           # 八向移动
	ATTACK_STARTUP,   # 攻击起手前摇
	ATTACK_ACTIVE,    # 攻击判定有效帧
	ATTACK_RECOVERY,  # 攻击后摇收招
	GUARDING,         # 架势防御中
	PARRYING,         # 弹反成功窗口
	HITSTUN,          # 受击硬直
	KNOCKDOWN         # 倒地状态
}

# 判定结果类型
enum HitResolution {
	CLEAN_HIT,       # 实打实命中（造成满额伤害与硬直）
	GUARD_BLOCKED,   # 同向防御格挡（扣减体力/定力）
	PERFECT_PARRY,   # 完美弹反（弹开对手并反噬大硬直）
	GUARD_BROKEN,    # 破防命中（直接打破防御态）
	DODGED           # 闪避无敌帧规避
}

