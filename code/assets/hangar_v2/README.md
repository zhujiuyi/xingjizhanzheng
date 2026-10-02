# 机库与金属材质表现资源

`hangar-v2` 是独立的运行时表现包。模型和 Shader 由本项目原创编写；六个 Blender 编辑源放在 `source/`，该目录以 `.gdignore` 排除引擎导入。`manifest.json` 的 11 个运行资源带 SHA-256；旧 `art-full-v1` 的 79 个资源和 catalog 身份均保持不变。

机库采用粗糙钢蓝金属、深灰凹槽、青色导航灯和少量琥珀色安全标识。76×64 米的展览甲板包含维修导轨、吊臂、货箱、工作台、星空舷窗和四名服务人员。人物约两米高，采用原创风格化人体、完整面部与四肢；站务有军帽和指挥板，工业有安全帽、护目镜与扳手，科研有白外套、灰发和分析板，补给有货运背心和物资箱。头部和手臂采用刚性关节动作，未使用蒙皮骨骼或拟真人体扫描。六个 GLB 合计 78,696 个三角形，按材质和刚性关节合并。

`XJStationHangar.configure(ship_def_id, catalog)` 可在加入场景树前调用，加入后通过 `get_camera()` 获取独立机库镜头。`change_ship(ship_def_id)` 只取正式舰船 wrapper 的 `VisualRoot` 并展示为 26 米长，完全不包含碰撞或游戏状态。镜头使用斜向构图、独立 `Camera3D.environment`、第 20 可见层和相同灯光层。当前展台默认在 Y=15000；镜头目标使用根节点的局部坐标变换，已测试额外平移。宿主在停靠时隐藏星区、显示机库并激活镜头，离港时隐藏和停用机库。

可调用 `focus_service("operations" | "industry" | "research" | "supplies")` 看服务人员近景，传空字符串返回舰船总览。`get_service_anchor(role)` 返回对应人物节点。动作只在机库可见时运行，不引用世界快照、不写存档。镜头、模型缩放、低幅动作和窗口天空属于展览资源元数据。

`XJSurfaceStyle.apply_ship(root)` 应在正式模型实例化和敌方染色后调用。它只为 `_hull/_dark/_trim` 表面复制 PBR 参数，加入三轴采样纹理、低幅导数法线和粗糙度变化，支持原有无 UV 舰体。它保留原配色，逐表面处理，保持 `_glass/_glow` 及几何、挂点、碰撞不变，重复调用不会重复复制材质。金属纹理引用独立 `interface-v2/metal_albedo.png`，其生成来源与摘要以 interface 清单为准。

复现：

```sh
/Users/a0000/Applications/Blender-4.5.14.app/Contents/MacOS/Blender --background --python jiaoben/art/build_hangar_v2.py
python3.14 jiaoben/art/build_hangar_manifest.py
sh jiaoben/run_godot.sh --headless --editor --path code --quit
sh jiaoben/run_godot.sh --headless --path code --script ../jiaoben/art/test_hangar_v2.gd
sh jiaoben/run_godot.sh --path code --script ../jiaoben/art/preview_hangar_v2.gd -- --mode=overview --ship=battleship_bastion
sh jiaoben/run_godot.sh --path code --script ../jiaoben/art/preview_surface_v2.gd -- --mode=fleet
```

2026-10-03 已在 Godot 4.7.2 / Metal Forward+ / Apple M1 Pro 原生检查四职业近景、雨燕/铁砧/磐垒总览、九舰星空材质与玩家/静默敌舰原材质对照；截图放 `jiaoben/tmp/art/`。161 项运行断言通过，覆盖展览无物理节点、偏移镜头、九舰网格/变换/玻璃/发光保持、配色保持与幂等。

1440×900 独立场景的最终总览观察到 205 次绘制调用；四职业近景约 72–137 次。`Performance.TIME_PROCESS` 常见采样约 15–20.5ms；补给视角曾观察到 52.7ms，单独重测为 8.63ms。这是共享开发机的进程监测，包含窗口焦点和系统调度影响，不能作为 GPU 帧耗时或稳定 60fps 的认证。主客户端 UI 叠加、导出包和 Windows 原生性能仍由集成验收覆盖。

最终连续微纹理选定后再次原生复查，实际载入纹理的 `has_mipmaps()` 为 true；磐垒机库总览为 205 次绘制、TIME_PROCESS 16.4518ms，九舰星空为 63 次绘制。截图保存成功并逐图查看，舰体、势力颜色、玻璃和灯光保持清晰，无明显板缝截断或黑化。此复查不改变机库自有 11 项资源摘要。
