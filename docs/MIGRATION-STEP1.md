# 迁移记录 · 第一步：弹幕处理数据基底（2026-11-11）

## 目的清单（本轮做了什么、为什么）

| # | 事项 | 目的 | 来源 |
|---|---|---|---|
| 1 | `core/danmaku/danmaku_event_data.gd` | 弹幕事件数据与编译（六类型/CSV 读写/槽位常量）——所有弹幕的定义层 | th75 scripts/danmaku（忠实拷贝，零改动） |
| 2 | `core/danmaku/danmaku_expr.gd` | 表达式求值器（常量折叠 + C++ BulletHot 回退制）——字段表达式的执行层 | 同上 |
| 3 | `core/danmaku/danmaku_tex.gd` | 材质注册/运行时导入（.thx 材质缓存） | 同上 |
| 4 | `core/danmaku/timeline_data.gd` | 时间轴数据（0.1s tick；.gd 文本格式） | 同上 |
| 5 | `core/data/chara_db.gd` | 角色/杂兵 CSV 读写基建；**路径重定向**到内核 data/（仅 3 个路径常量，其余零改动） | th75 scripts/chara_db.gd |
| 6 | `core/kit.gd`（autoload THXKit） | 事件池/Mod 覆盖层/槽位解析/时间轴解析/官方表同步——自 game_globals 的**数据基底部分**移植（versus_* 玩法部分不迁） | th75 scripts/game_globals.gd |
| 7 | `data/characters.csv` | 角色表示例 = 晚汐（Youshio）一行（作者裁定 Q7：内核仓仅留晚汐数据作范例） | th75 gameAssetBase/Characters.csv |
| 8 | `data/danmaku_event*.csv` ×6 | 官方事件表 = 晚汐槽位引用的已存在事件（demo_youshio1）；其余表头占位 | th75 五表 |
| 9 | `data/enemy.csv` / `privates.csv` | 表头占位（编辑器必填基础设施；数据由玩法插件填充） | th75 |
| 10 | `data/textures/danmaku16pxs/`（11 件） | 16px 基准材质包（内核资产，58KB） | th75 gameAssetBase/shooting/ |
| 11 | `data/textures/chars/Youshio.PNG` | 晚汐角色贴图（示例） | th75 Players/Battle/Chars/ |
| 12 | README 三语 + LICENSE + 本文档 | Q9 三语文档 / Q1 MIT 落地 | — |

## 忠实性保证

- 四个纯数据文件（1-4）**逐字节拷贝、零改动**（已断言不含 GameGlobals 引用）
- chara_db 仅改 3 个路径常量（断言不含 gameAssetBase 残留）
- kit.gd 的函数体自 game_globals 逐函数移植，仅路径常量重定向；数据语义
  （同名先到先得/合并式同步/编辑器工作集优先）逐条保留原注释

## 已知缺口（下一步的输入）

1. **Youshio2 事件缺失**：晚汐 main_evs 引用了 Youshio2，但官方五表中无定义
   （示例数据按现状只带 demo_youshio1）——待作者在数据侧补定义或改槽位
2. **编辑器未迁**：弹幕编辑器（必备件）与实体底座是下一迁移步
3. **THX75 消费方式**：本内核以 submodule 被游戏引用后，th75 侧的同名类
   （DanmakuEventData 等）需删除改用内核副本——属"THX75 改造为参考实现"阶段
4. **C++ 扩展**：extension/（BulletHot 等）尚未入内核——数据基底阶段纯
   GDScript 回退路径即可运行；扩展迁移与 Windows 预编译分发属后续步

## 开放问题（请作者逐条答复——防歧义）

1. **角色表"狭义本体"列的精确清单**：我按您的回答拟定为
   `Name（键名）/ NameZH / NameJP / NameEN / Cruise / Normal / Weapon_Muti /
   main_y / sub_x / sub_y / main_poi_x / main_poi_y / sub_poi_x / sub_poi_y /
   main_para_rat / main_seci_rat / sub_para_rat`，另有 `Main_Cd / Sub_Cd`
   （火力冷却）——按"其余数据行由插件读取"的字面它们应属插件，但冷却算火力
   节奏的一部分……请圈定（或直接在 characters.csv 上划线）。
2. **privates.csv / enemy.csv**：我按"编辑器必备"放进了内核（表头占位）——确认？
3. **双仓并存的权威副本**：迁移过渡期，事件表的权威副本在 th75（现役）还是
   本仓（新基线）？建议：本仓为内核范本（仅晚汐），th75 继续自用其全量数据，
   待 AutoBattle 插件抽出后再统一。
4. **timeline .gd 目录**：内核示例库 `data/timelines/` 目前为空——是否放一条
   晚汐示例时间轴？
5. **类名策略**：内核当前沿用原类名（DanmakuEventData/CharaDB/DanmakuTex/
   TimelineData/DanmakuExpr）——THX75 以 submodule 消费时会与游戏侧副本
   冲突，届时删游戏侧副本即可；或现在就加前缀（TK/Kit 前缀=破坏性改名）。
   建议：保持原名，消费侧去重。
6. **autoload 名**：`THXKit`——与未来 THX75 的 GameGlobals 并存无冲突；
   AutoBattle 插件将来自带自己的 autoload。确认？
7. **mod 目录**：MOD_DIRS=["res://mods","user://mods"] 沿用——内核工程自己也
   会扫这两个目录，确认。
