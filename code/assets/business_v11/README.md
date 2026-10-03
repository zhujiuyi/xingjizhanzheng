# 业务列表图片

本目录提供市场、舰队、仓储、配装、制造、研究、设施与任务列表的静态图片。只维护稳定 ID 到图片的对应关系；价格、数量、科技条件、配装能力和持久状态继续由 SQLite 及现有业务服务决定。

九类舰体 PNG 均为本项目既有正式原创 `assets/ship_v3/*.glb` 的实际 Godot 原生渲染，应用现有工业 PBR 表面样式；未使用旧占位舰体、外部游戏截图或提取模型。图片为 256×256 RGBA，透明背景，实际模型的投影包围决定构图。渲染脚本拒绝 headless、空图与贴边裁切，运行时直接加载已导入的图片，不逐帧生成缩略图。

其余 114 个 SVG 为本项目脚本独立绘制的工业图示：60 种物品、4 项研究、4 种基地设施、40 项任务及6个通用图示。SVG 使用 256×256 viewbox，设备按正式数据库中的类型及科技等级显示不同造型或等级标记；不在资源内维护第二套游戏数值。普通配方复用其产出物品图片，舰体配方复用真实产出舰体图片。未知舰体显示明确的问号通用图示，不冒充某一类舰体。

全部图片的路径、文件摘要及9个正式模型的来源摘要见 [manifest.json](manifest.json)。174条映射仅包含 `kind`、`id`、`resource_path`，123项实际图片资源单独记录SHA与字节数。纹理入口为 `runtime/ui/item_portraits.gd` 的 `XJItemPortraits.texture(kind,id)` / `asset_path(kind,id)`，同一路径使用共享缓存。

本轮模型引用与SVG绘图均不需要购买素材或收费授权；这不改变整个项目的发布方式或授权。既有模型、材质及其外部微纹理的来源和原许可继续分别由 `assets/ship_v3/manifest.json`、`assets/interface_v2/manifest.json` 管理，不在此重新授权；Godot、字体与数据库扩展等上游组件也保留原许可。

重建入口为 `jiaoben/art/build_business_v11.py`；舰体渲染入口为 `jiaoben/art/render_business_v11.gd`，完成原生渲染后用构建脚本的 `--finalize` 刷新清单。具体命令及独占原生窗口要求见 `jiaoben/README.md`。本轮原生渲染记录在 `jiaoben/logs/business-v11-render.log` 与独立引擎日志 `business-v11-render-engine.log`；174映射/123摘要、PNG尺寸/透明度与SVG检查报告在 `jiaoben/logs/business-v11-assets-static-final.json`。日志是本机可重建的验证产物；整体业务和实际发布包的验收结论以 `doc/26-开发阶段与交付记录.md` 为准。
