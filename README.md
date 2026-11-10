# THXGameKit

**弹幕专题游戏制作内核**（Godot 4.x Addon 式）——把弹幕运行逻辑、角色信息处理、
时间轴、弹幕编辑器等统一为类 Godot Addons 的内核；具体玩法（自走棋 / STG /
RPG / Roguelike）作为内核插件接入。

**首个插件玩法**：[THX75 东方消望纪-无欲拾食纪](https://github.com/Xlonia/THX75)
（Touhou Xenothers: Keshinozoshiki）——弹幕决斗自走棋。

## 状态

`架构咨询中`（2026-11-11）——内核边界划分提案与开放问题见
[docs/ARCHITECTURE-PROPOSAL.md](docs/ARCHITECTURE-PROPOSAL.md)，
代码抽取尚未开始。

## 愿景

- **内核（Kit）**：玩法无关的弹幕引擎底座——弹幕运行时（六类型/表达式/
  事件/池化/GPU 加速）、弹幕图 DDM（所见即所判）、时间轴与火控骨架、
  通用编辑器、实体底座（判定/移动/朝向）。
- **玩法插件（Plug）**：可选能力包——弹幕智能感知（热力图族/AI 抽象层）、
  自走棋玩法包（THX75 的态势/阶段/机控/经济）、未来的 STG 波次包等。
- **游戏（Game）**：单个成品游戏自己的数据、UI、角色与剧情。

## 关系图

```
THX75（游戏）── 自走棋玩法插件 ──┐
                                ├── THXGameKit（内核：弹幕运行时/编辑器/DDM/时间轴）
未来 STG 游戏 ── STG 玩法插件 ──┘
```

## 许可证

待定（架构咨询问题 #1）。
