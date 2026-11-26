# 弹幕运动与伤害解析 API（教程+参考）— THXGameKit 0.1.0

> 面向：想要理解/扩展"编辑器参数如何变成弹幕运动与伤害"的创作者与开发者。
> 本文是**内核现状的完整解析文档**，也是未来"自定义弹幕解析代码作为项目元素"（作者 20261126 提案）的地基——文末列出预留扩展位。
> 数据流总览：
> `danmaku_event*.csv → DanmakuEventData.parse_csv_text() → compile()（表达式预编译）→ eval_spawn_params(ctx)（发射时刻求值）→ Bullet 池个体 → BulletRuntime.update(dt) → match tag → _step_regular/_step_physical/_step_functed/_step_laser/_step_nodes（每帧运动）→ hit_damage()（被弹结算）`

---

## 1. 三层求值模型（理解一切的第一步）

弹幕参数分三层，**编辑器里每个数值都是表达式**：

| 层 | 时机 | 典型变量 | 例子 |
|---|---|---|---|
| **发射求值**（spawn） | 弹幕出现的一帧 | `t`(事件出现至今帧) `t_copy` `wpcs`(火力点序) `main_lr/sub_lr` `getTarget()` 等 | x_offset、dmg、repeat 参数、rotate 参数 |
| **逐帧求值**（每帧） | 个体存活的每帧 | `t`（个体出现至今帧）+ 各类私有 | 点向的 acc/turn_arg、激光 x/y |
| **被弹结算** | 命中一瞬 | hit_damage() 内部 | 伤害=基础×倍乘 |

表达式语法：`+ - * / ^`、比较 `== != < > <= >= >> <<`（`>>`/`<<` 在 CSV 里代替 `>=`/`<=`——CSV 逗号分隔冲突）、布尔 `& | !`；函数 `abs/min/max/log/rand/iterate`、`getTarget()/getChara()/getField()`。**禁止 `#`**。全角括号注释由 W1/W2 引入工具生成（内核表达式引擎忽略全角内容）。

## 2. 六类运动方式（tag 分派表）

`BulletRuntime.update(dt)` 尾部按 `ev.tag` 分派（`bullet_runtime.gd:629`）：

| tag（CSV 的 tag 列） | 运动解析 | 核心参数 | 运动语义 |
|---|---|---|---|
| `IsDanmakuRegular` 一般直线 | `_step_regular` | speed / x / y（任一非空即坐标速度型） / freeze 相关 | 匀速直线；**旋转散布**（rotate_range/div/rate/offset/sequence/pingpong/delay——发射时按序计算方向）；**慢机冻结**（frozen_ok：BC 规避判定内速度比例缩放） |
| `IsDanmakuPhysical` 物理弹 | `_step_physical` | x / y / speed（速度分量式） | vx=Σx 式逐帧积分（x_copy 消偿）；与直线共享旋转散布 |
| `IsDanmakuFuncted` 轨道弹 | `_step_functed` | speed / x / y / func | 参数曲线轨道（func 表达式驱动）；火炮节点（is_cannon）按 repeat_time×freq 间发 |
| 激光 | `_step_laser`（update 内联） | x / y（t 依赖可变）/ alarm / alarm_shader_alpha·scale / laser_render_scale | 预警（alarm_now 前不判定不扣血）→成型（一次采样 401 上限）；**t 依赖型每 6 帧重采样**；R-ETA 预警期规避注册 |
| `Nodes` / `NodesB` 新节点 | `_step_nodes` | 节点参数族 | 节点图驱动的复合运动 |
| 瞬时（alarm+shader） | 直线/激光的 alarm 变体 | alarm / alarm_shader | 预警呈现→延迟生效 |

**横切机制**（对所有类生效）：**旋转重复**（rotate_* 组：发射时按 sequence/rate/delay 展开成旋转副本，rot_pending 队列）、**延时副本**（pend：stxy 绝对位释放时重算）、**亡计/反弹/就近消弹/被弹弹设**（特殊弹设四钩：death_evs/spawn_conv/nearclear/self_hitcool）、**多帧倍乘**（见 §4）、**擦弹标记**（grazed，判定环外 14px 内一次性）。

## 3. 表达式上下文（ctx）变量速查

**发射时刻**（eval_spawn_params / _rot_eval_ctx 提供）：
`t` `t_copy` `x_copy`（旋转重复消偿坐标）`rotate_id`（副本序）`wpcs`（火力点序）`main_lr/sub_lr`（主/僚左右）`getTarget()`（目标实体：.x/.y/.hp…）`getChara()`（发射者）`getField()`（场地规则查询）`to_c`（目标方位 cos）/`to_s`（sin）`directc`（运动方向 16 象限 0-15）

**个体逐帧**：`t`（个体帧龄）+ 各类私有（点向 `acc`/`turn_arg`/`speed_max`/`lost_max/lost_min/lost_if`；轨道 `func` 自参）。

**角色参数**（选择器/条件）：`copyall` `hp/allhp/hpper` `x/y/d/directc` + 特殊复数（has_random/has_laser/has_nodes/has_render）+ 特殊单数（closest/farthest/downst/upst/boss/player）。

## 4. 伤害管线（被弹结算）

```
hit_damage() =
  damage_override ≥ 0 ? override           # inheritdamage 继承覆盖（m74）
  : tag==LASER 且 t≤alarm_now ? -1(预警不判)
  : tag==LASER ? min(16, dmg_now)
  : dmg_now
  × maxf(mul_live, 0)                      # multi/overwrite 场地倍乘（出生捕获 mul_base+逐拍求值）
  → roundi 取整                             # 修饰结果取整（作者令）
→ 被弹哈希分组键 = hit_damage×4 + dmg_type(0一般/1穿透/2碎甲)
→ BattleEntity.take_hit(dmg, dmg_type, hit_angle)   # 部位由角度推导（武器-90°/机动+90°/本体0°）；AP 先吃
```

伤害来源：`eval_spawn_params()["dmg"]`（发射求值，可表达式）→ `dmg_now`；**inheritdamage** 步骤可整体覆盖（damage_override）；**setdamage**（章节操作）→ 发射者 `dmg_mul_tag`→弹幕 `mul_base` 出生捕获→multi/overwrite 规则范围逐拍改写 `mul_live`。

## 5. 装载与打包（参数从哪来）

- 官方表：`res://gameAssetBase/danmaku_event_{regular,physical,functed,laser,nodes}.csv`（单文件旧表兼容）；同表同名事件**先到先得**（regular 优先）
- mod 包：`res://mods` 与 `user://mods` 下 `*.thx`（zip）→ `Kit.load_thx()`：读 `danmaku_event.csv`→mod_events（覆盖官方同名）+`texture/` 运行时材质+**可选 `manifest.json`**（m126：`{"format":2,"plugins":[...],"domains":{...}}`——包声明插件未注册=警告不炸；随包签名链覆盖）
- 编辑器"导出"=把工作集写回官方表/包（**合并语义**：部署行打底+工作集覆盖）

## 6. 预留扩展位（"自定义弹幕解析代码作为项目元素"提案——待作者批复详情）

提案分三层，当前状态：

| 层 | 内容 | 状态 |
|---|---|---|
| **浅（本文档）** | 现有六类的参数/ctx/伤害完全文档化 | ✅ 本文 |
| **中（脚本解析器）** | 允许 .gd 作为**额外运动/伤害解析器**随 thxp/thxe 元素保存；运行时按注册 tag 分派到用户脚本（约定接口：`get_spawn(ctx)→初始状态` / `step(bullet, dt)` 每帧 / `hit_damage(bullet)→int` 可选） | 设计要点已列（见下），**等作者批复详情** |
| **深（内核内部）** | 暴露池化/DDM/C++ BulletHot 内部 | ❌ 不建议（性能红线：每弹每帧 GDScript 在 2335 弹量级=灾难；C++ 层不对第三方开放） |

**中层的四个待批问题**（作者 20261126："界限不清楚就再问一次详情"）：
1. **接口面**：自定义解析器拿到的上下文=完整 Bullet 个体（pos/t/mul_live/…）还是白名单快照？
2. **性能红线**：每弹每帧 GDScript vs 红线（60fps/10ms）——允许（标注性能警告）还是仅限低频弹种？
3. **伤害暴露面**：只允许"伤害公式"（hit_damage 等价）还是连 dmg_type/部位推导都可自定义？
4. **信任模型**：包内 .gd 无沙箱直接执行（签名链防篡改）——与 ModBox thxe 直玩同一信任级别，是否可接受？

## 附：相关源文件索引

| 文件 | 职责 |
|---|---|
| `core/danmaku/danmaku_event_data.gd` | 事件数据：CSV 解析/compile/eval_spawn_params/eval_color_ab/eval_repeat_params |
| `core/danmaku/bullet_runtime.gd` | 个体运行时：池化/六类 _step_*/hit_damage/grazed/mul |
| `core/danmaku/bullet_hash.gd` | 被弹空间哈希（C++ Th75BulletHashCpp 对照开关） |
| `core/danmaku/danmaku_expr.gd` | 表达式引擎（compile/execute_dict/uses_variable） |
| `core/danmaku/danmaku_tex.gd` | 材质运行时装载（字节流缓存） |
| `core/kit.gd` | 装载编排：load_char_flows/load_clips/load_thx/manifest |
