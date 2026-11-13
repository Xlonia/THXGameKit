# 内核接入指南（引用接口）——GameKit "要么没用要么主导"问题的答案

> 读者：想把 THXGameKit 嵌进自己游戏的开发者。
> 核心承诺：**GameKit 既可整体成为一款游戏（如 THX75），也可以只作为
> 一个被调用的弹幕系统**——两种接入形态，随你的游戏形态选择。

## 两种接入形态

### 形态 A：场景引用（"我只想在 RPG 里来一场弹幕 Boss 战"）

把 GameKit 的对战场面（或你基于它定制的 Boss 战场景）**作为子场景**
在你自己的游戏流程里实例化。GameKit 平时不加载——遭遇战/剧情节点调用。

```gdscript
# 你的 RPG 剧情脚本里（遭遇触发时）
const ARENA := preload("res://addons/thx_gamekit/你的对战场景.tscn")
# 或基于 THX75 式 battle_arena 定制版

func start_boss_fight(boss_data: Dictionary) -> void:
    var arena := ARENA.instantiate()
    arena.set("boss_config", boss_data)   # 你的配置入口（见下"配置注入"）
    add_child(arena)
    await arena.finished                  # 对战结束信号（你的场景里定义）
    arena.queue_free()
    # 回到你的 RPG 流程——战利品/剧情由你的游戏接手
```

要点：
- GameKit 的类与事件表**只在战斗期间存在**，退出场景即释放——不驻留内存。
- 你的 RPG 的数值/背包/剧情系统**完全不受影响**——弹幕战通过
  `finished` 信号+结算回调与你交接（战利品在④期接口预留）。

### 形态 B：常驻系统（"弹幕是我的子弹表达方式"——东方弹幕 × 拳皇）

把弹幕运行时**注册为常驻节点**（autoload 或根节点子节点），
你的格斗/Roguelike 任意时刻调用发射接口——弹幕=武器表现层。

```gdscript
# 1. project.godot 加 autoload（GameKit 已有 THXKit 可直接用），
#    或在你游戏的根节点挂一个 DanmakuHost（示例）：
var host := Node.new()
host.name = "DanmakuHost"
add_child(host)

# 2. 任意角色/招式脚本里发射弹幕（事件名来自编辑器做的弹幕表）：
func fire_player_shot(origin: Vector2) -> void:
    var ev: DanmakuEventData = THXKit.get_event("your_shot_event")
    if ev == null:
        return
    var b := Bullet.new()
    b.setup(ev, origin, 0, null, self)   # side=0 自机侧；world=宿主（碰撞查询接口）
    _live_bullets.append(b)

func _physics_process(delta: float) -> void:
    for i in range(_live_bullets.size() - 1, -1, -1):
        if not _live_bullets[i].update(delta * 60.0):
            _live_bullets[i] = null
            _live_bullets.remove_at(i)
    # 渲染：MultiMesh 批量提交（参考 trial_ground._draw 的分组提交）
```

要点：
- Bullet.update 返回 false=弹已死（出界/到期/被消），你决定回收。
- `world` 宿主对象需要实现少量查询接口（`bullet_hit_query`/
  `bullet_nearest_enemy_pos` 等——参考 `trial_ground.gd` 尾部的极简桩）。
- 消弹/判定/偏心中心/特殊判定盒全部由内核处理——你只管"何时何地
  发射哪个事件"。

## 配置注入（两种形态通用）

- **事件表**：编辑器产出 `.thxp`（开发）/`.thxe`（发布）——运行时
  `THXKit.load_thx(path)` 装载（签名强校验）。
- **角色/数值**：`characters.csv`（Determine/Defend/部位 HP/AP——
  见 `docs/SCHEMA-CHARACTERS.md`）。
- **场景级参数**：`THXKit.scenario_cfg`（画布大小/特殊判定盒开关等）。

## 保存与发布（ModBox 流）

| 阶段 | 格式 | 说明 |
|---|---|---|
| 开发期 | **.thxp 引用态** | JSON 清单→本地文件（热改即时生效；projectdata/ 目录） |
| 交付/备份 | **.thxp 打包态** | zip 全资源（转引用/转打包按钮互转） |
| 发布 | **.thxe** | 签名强校验发布包——玩家直接游玩（GameKit 标题"打开 .thxe 游玩"）或随 Godot 导出 pck |

- 编辑器"打开/保存 .thxp"自动记录最近工程→标题**"继续（上次工程）"**一键回。
- **引用态转打包态**：编辑器设置页/主屏内核引用页按钮（资源收拢进单文件）。
- Godot 导出流程不变（pck），数据层=thxe 内嵌或随包。

## 版本与许可

GameKit 独立版本线（当前 0.0.9）——宿主游戏（如 THX75）按自己的
版本节奏引用。MIT License。
