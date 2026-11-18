# 流程伪脚本表达规范（v1，试点）

> 定位：符卡页伪节点图（横排流程步骤）是**节点图生态的试点**——本规范定义
> 表达式的书写法；将来节点图的求值器直接复用同一套解析（kit 侧
> `CharFlowData.parse_step`/`EntityOps.resolve`/`FLOW_OPS`）。

## 一、步骤行结构（编辑器横排）

```
[op 键名] [框1: 参数1] [框2: 参数2] [↑排序] [↓] [✕删除] [⧉复制]
```

- **框1（参数1）**：op 的主参数（事件名/片段名/序号）——占位文字按 op 给范式；
- **框2（参数2）**：选择器或副参数——留空=按 op 的默认语义（各 op 不同，见下表）；
- 存储格式（spell.csv/danmaku_clip.csv 单元格）：`{"op":"…","arg":"…","params":"…"}`，
  其中 `arg`=框1、`params`=框2（历史字段名，语义=框1/框2）。

## 二、op 一览（框1 / 框2 / 留空语义）

| op | 框1 | 框2 | 留空语义 |
|---|---|---|---|
| svgresign | 序号（空=默认圆形） | — | 注册默认圆形，半径=档位（n80/s200/m500） |
| clean | — | `inspellrange` 或留空 | 留空=注册图形范围内消弹 |
| reflex | — | 弹幕选择器 | **全场敌对弹** |
| inverse | 事件名（替换目标） | 弹幕选择器 | 全场敌对弹 |
| inversep | 事件名（重生事件） | 弹幕选择器 | 全场敌对弹 |
| revolt | — | **目标定位器** | 敌侧随机角色 |
| inheritdamage | 事件名（伤害来源） | 弹幕选择器 | 全场敌对弹 |
| playclips | 片段名 | — | 播放一次该片段 |
| loopclips | 片段名 | — | 循环播放该片段（至符卡结束） |
| danmaku | 事件名（释放的弹幕） | **目标定位器** | 敌侧随机角色 |

## 三、选择器两种范式（scheme 角色选择器规范化）

1. **特殊选择器=单词直挂**（不写括号）：
   - `closet`（=closest=nearest）最近者
   - `farthest` 最远者
   - `self` 施法者本人
   - `random` 敌侧随机
   - `enemy` 敌侧最近（等价 closet）
   - `enemies` 敌侧全部角色（消望插件特殊 enemies 同表）
2. **参数选择器=iterate(命题)**：
   - `iterate(hp>>5)` 所有 hp>5 的角色
   - 命题上下文变量：`x y d hp allhp hpper ap pp`
   - 命题语法=弹幕表达式同一引擎（`>> <<` 即大于/小于，与弹幕 CSV 一致）

> **泛型前缀**：仅当参数里需要"另一类对象"时才加前缀——
> `ev:事件名`（弹幕事件）、`c:片段名`（片段）。选择器本体**不加前缀**
> （closet 直接打上去就是最近者）。旧写法 `sel:shape=circle,r=120`
> 仍然兼容（弹幕选择器的几何限定；留空=全场）。

## 四、弹幕选择器 vs 目标定位器（两套别混）

- **弹幕选择器**（reflex/inverse/inversep/inheritdamage 的框2）：
  选**弹幕个体**——留空=全场敌对弹；`sel:shape=circle,r=N` 圆内；`sel:t_max=N` 存续超 N 帧。
- **目标定位器**（revolt/danmaku 的框2）：
  选**角色**——特殊单词或 iterate(命题)，见第三节。

## 五、角色操作语义锚定（作者 20261118 确认）

> **符卡流程的一切角色操作，动作发出者=施法者本人。**
> 希洛妮娅的符卡不该发生在别的角色身上：
> - inversep 重生的弹幕以**原弹位置**为起点、施法者为发射源（gettarget 指向施法者的最近敌）；
> - revolt 策反后**共享目标锚同步**为新锁定者（gettarget 系表达式不再回头打策反前目标）；
> - danmaku 的发射点=施法者位置、目标=定位器（默认敌侧随机）。

## 六、存储与解析对照（给节点图求值器的接口约定）

| 概念 | 存储字段 | 解析入口 |
|---|---|---|
| 步骤 | `{op,arg,params}` | `CharFlowData.parse_step` |
| 弹幕选择器 | params（sel:/留空） | `BulletOps.select`（all/circle/band_x/band_y） |
| 目标定位器 | params（单词/iterate） | `EntityOps.resolve`（m93 新增） |
| op 注册与模板 | FLOW_OPS | 编辑器 FLOW_OPS/FLOW_ARG_HINT/FLOW_PARAMS_HINT |
