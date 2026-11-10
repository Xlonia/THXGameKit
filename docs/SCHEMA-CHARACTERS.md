# 角色表列归属（作者裁定 20261111）

> 狭义本体列=内核定义与读取；插件列=保留在文件中、由对应玩法插件读取。

## 必填列（缺行=无效角色）

`Name`（本地化键名）· `Cruise`（快机速度）· `Normal`（慢机速度）· `Determine`（判定）
· `main_y / sub_x / sub_y / main_poi_x / main_poi_y / sub_poi_x / sub_poi_y`（火力点排布）
· `main_para_rat / main_seco_rat / sub_para_rat`（火力占比）

## 本体列（内核读取）——含必填列之外

`NameZH / NameJP / NameEN`（三语名）· `Main_Cd / Sub_Cd`（火力冷却——由用户决定
该角色用时间轴还是 Cd，故属本体）· `Weapon_Muti`（火力点乘数——排布，待确认）

## 槽位列（结构，编辑器管理）

`main_evs / sub_evs / rest_evs / skill_evs / spell_evs`

## 插件列（自走棋插件读取）

`Mag / Phy / ID / Char_Raid / Char_Allfire / Char_Blitz / Char_Cover /
Char_Elast / Char_Delay / Char_Feint`

## 未分类（待作者补裁定）

`Team`（队伍/建队序）、`Defend`（结界规模——疑为自走棋插件列）

## 勘误

- `main_seco_rat` 列名与 th75 代码旧读法 `main_seci_rat` 不一致——20261111 已在
  th75 全代码统一改为 `main_seco_rat`（修正"次要点数占比从未被读到"的静默缺陷）。

## 表语义（作者 20261111）

- **privates**：角色根据触发器产生、替换或清除的**次级角色**（THX75=开局/退下等）。
  未来可与 Node/Node_new 类弹幕互通——即便互通，各有自己的预设而均应保留。
- **enemy**：未来 STG 计划中，按照时间轴或触发器**独立出场**的角色。
