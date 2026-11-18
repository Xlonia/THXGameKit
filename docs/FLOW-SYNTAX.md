# 流程伪脚本表达规范（v2，试点）

> 定位：符卡页伪节点图（横排流程步骤）是**节点图生态的试点**。本规范 v2
> 按作者三决定返工：①选择器=函数调用式（沿 C++/GDScript 类方法习惯，
> 不特立独行）②**流程=代码块中的函数，横排框=形参**（编辑器自动读取
> 形参声明生成输入框——原生 op 与开发者新增 op 同一机制）③iterate 系=
> 通用容器查询（对应 GDScript `Array.filter`/随机取样；C++ 无内建，
> 由内核 EntityOps 统一实现，任何实体类型通用）。

## 一、流程=函数

每个 op 是一个函数；编辑器横排的框数与顺序=**该函数的形参表**（自动读取，
无需为每个 op 手工排框）。存储格式不变（`{op,arg,params}`——arg=第 0 形参
的历史承载，读取按形参表拆分）。

形参声明（内核 `FlowSignature.SIGNATURES`）：

```
"revolt": [
    {"name": "目标", "type": "entity", "hint": "角色定位器：closest()/enemies()/randomp(命题)/iterate(命题,类型)；留空=敌侧随机", "dflt": ""},
]
```

开发者新增 op：在 SIGNATURES 加一条声明即可——编辑器自动生成对应数量的
输入框（未声明=单 string 形参兜底，也能用）。

## 二、形参类型（沿 C++/GDScript 类方法习惯）

| 类型 | 语义 | 书写 |
|---|---|---|
| entity | 角色（目标定位器） | 函数调用式（见三） |
| danmaku_sel | 弹幕选择器 | 留空=全场敌对弹；`sel:shape=circle,r=120` 几何限定 |
| event | 弹幕事件名 | 裸名（`onami`） |
| clip | 片段名 | 裸名（`clip_xxx`） |
| int/float/string | 标量 | 字面量 |

泛型前缀（`ev:`/`c:`）**废止**——类型已由形参表声明，值一律裸名。

## 三、目标定位器（entity 类型）——函数调用式

**单词类选择器也写括号**（与编程语言调用习惯一致，不做裸词特例）：

| 表达式 | 语义 |
|---|---|
| `closest()` | 最近者（=nearest()/closet() 兼容） |
| `farthest()` | 最远者 |
| `upst()` / `downst()` | 最上方者 / 最下方者 |
| `boss()` | Boss（章节系统就绪后生效） |
| `player()` | 玩家自机 |
| `self()` | 施法者本人 |
| `random()` | 随机个体 |
| `enemy()` | 敌侧最近 |
| `enemies()` | 敌侧全部（**含杂兵**——角色=队伍成员+各自杂兵，作者 20261118 定义变革） |

**命题查询类**（scheme 通用选择器调用节）：

| 表达式 | 语义 | 对应通用容器办法 |
|---|---|---|
| `iterate(命题)` | 当前实体类型中满足命题的全部个体 | GDScript `Array.filter`（C++ 手写循环——内核统一实现） |
| `randomp(命题)` | 满足命题的随机个体 | filter+随机取样 |
| `geniterate(命题,类型)` | 全部种类中满足命题者的特定类型 | filter+类型二次筛 |

命题上下文变量：`x y d hp allhp hpper ap pp`（与弹幕表达式同一引擎；
`>>` `<<` `==` `!` `&` `|` 等算式逻辑与弹幕 CSV 完全一致）。
例：`iterate(hp>>5)` = 所有 hp>5 的角色。

## 四、弹幕选择器（danmaku_sel 类型）——与定位器分开

选**弹幕个体**（非角色）：留空=全场敌对弹；`sel:shape=circle,r=N` 圆内；
`sel:t_max=N` 存续超 N 帧。不写括号函数（它是几何/谓词限定，不是实体查询）。

## 五、角色操作语义锚定（m93 确认，不变）

**符卡流程的一切角色操作，动作发出者=施法者本人。** revolt 策反后目标锚
同步为新锁定者；danmaku 发射点=施法者、目标=定位器。

## 六、存储与解析对照

| 概念 | 存储/代码 | 入口 |
|---|---|---|
| 步骤 | `{op,arg,params}` | `CharFlowData.parse_step` |
| 形参表 | SIGNATURES | `FlowSignature.params_of/split_args/join_args` |
| 目标定位器 | params（函数调用式） | `EntityOps.resolve` |
| 弹幕选择器 | params（sel:/留空） | `BulletOps.select` |
