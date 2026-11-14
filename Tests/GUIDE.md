# THXGameKit 测试场景使用指南

> 本目录包含所有冒烟测试/探针场景。**这些不是游戏内容**——它们是开发者的
> 自动化验证工具。运行方式：Godot 编辑器打开本工程后在场景面板双击运行，
> 或命令行 `Godot_exe --path 工程目录 res://Tests/场景名.tscn`。

## 冒烟测试（核心功能验证，headless 可跑）

| 场景 | 验证内容 | 预期输出 |
|---|---|---|
| kit_smoke | 数据基底（事件表/材质/时间轴/角色表/.thx 往返） | KIT_OK |
| entity_smoke | EntityCore 实体底座（setup/移动/双朝向/被弹/杂兵钳制） | ENT_OK |
| editor_smoke | 编辑器装载+试炼场+三格式签名+角色表操作 | EDT_OK |
| ext_smoke | .thx 拓展包装载 | EXT_OK |

## 专项探针（特定功能回归）

| 场景 | 验证内容 | 预期输出 |
|---|---|---|
| round79_probe | 退出提问面板+展示画布交互+Presets+设置页 | R79_OK |
| round80_probe | 同上（更新版） | R80_OK |
| scenario_probe | .thxs 场景包往返+tscn 导出+四子标签+cfg 写回 | SCN_OK |
| thxp_probe | .thxp 双格式（打包↔引用）往返+备份 | THXP_OK |
| mm_align_probe | 弹幕渲染数学层（零偏心/偏心 MM 对齐） | MM_OK |
| title_round_probe | 标题+NI-S 清除+画布变量 | ROUND_OK |
| portrait_probe | 选人贴图链（th75 布局） | PORTRAIT_DONE |
| fps_min_probe | 最小帧率检测（真窗口） | fps 60 |
| fps_3phase_probe | 标题/编辑器/回标题 三段帧率（真窗口） | 每段 fps 数据 |
| window_exit_probe | 退出链真窗口取证（编辑器→面板→点击→回标题） | WINDOW_EXIT_OK |

## 运行方式

### Godot 编辑器
打开 THXGameKit 工程 → 场景面板 → Tests/ 子目录 → 双击 .tscn → F5

### 命令行（headless）
```
Godot_exe --headless --path 工程目录 res://Tests/kit_smoke.tscn
```

### 批处理（Windows）
```
Godot_exe --path 工程目录 res://Tests/kit_smoke.tscn
```
输出 `*_OK` = 通过，`*_FAIL N` = N 项失败

## 注意事项

- **fps_* 探针需真窗口跑**（headless 无渲染无意义）
- **diag_sentinel** = 哨兵自动取证（title_menu._ready 自动挂载，不需手动跑）
- **哨兵 csv 落盘位置**：`user://diag_sentinel_*.csv`
- **th75 宿主侧测试**：th75/Tests/wrap_*.tscn（wrapper 模式挂 root）
