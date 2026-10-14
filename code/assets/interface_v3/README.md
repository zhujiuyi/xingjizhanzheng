# 中文字体与第三版界面材质

`interface-v3` 是独立表现包，保留 `interface-v2`、机库模型和旧79项正式资源原始字节。世界存档兼容身份不由此包修改；客户端资源检查和实际导出由整合构建负责。

字体为官方 [Noto Sans CJK SC](https://github.com/notofonts/noto-cjk/tree/main/Sans/OTF/SimplifiedChinese) 的 Regular 与 Medium 两个字重，均为版本2.004；固定官方仓库提交 `f8d157532fbfaeda587e826d4cd5b21a49186f7c`。原始OTF未修改、未裁剪，来源及摘要见 `sources.json`。

| 文件 | 字节 | SHA256 | 官方Git blob |
| --- | ---: | --- | --- |
| `NotoSansCJKsc-Regular.otf` | 16,437,364 | `2c76254f6fc379fddfce0a7e84fb5385bb135d3e399294f6eeb6680d0365b74b` | `dc15562470b4f842321894787a0d066879ccff8b` |
| `NotoSansCJKsc-Medium.otf` | 16,523,632 | `ca094f6b0001fb048ca39ddd797a0cdb0179e1e55c6561e111c49c3e6a61d7b7` | `00b01dff38ff8d0a345c53d64a71bfcf9ec55522` |

官方 Medium 的 family 名是 `Noto Sans CJK SC Medium`（Noto CJK 每个字重是独立 family）。本包按资源路径预加载，不做 family 名查找，因此不受影响。

实测度量（`jiaoben/tests/font_metrics_v3.gd`，报告 `jiaoben/logs/font-metrics-v3.json`）：**行高、上伸、下伸两字重完全相同**（11/13/15/20/28 px 下分别为 17/20/23/30/42），**纯中文串步进完全相同**，含拉丁字母或数字的串 Medium 宽 1–4 px（随字号增长：8 位数字 +1 px @11–13、+2 @15–20、+3 @28）。因此换字重**不改行高、不改中文排版**，只在含数字/拉丁的串上产生几个像素的宽度差；依赖自动尺寸的容器不受影响，固定宽度容器与"文字不超出控件"的验收须在改字重后复查。

字体遵循官方 [SIL Open Font License 1.1](https://raw.githubusercontent.com/notofonts/noto-cjk/f8d157532fbfaeda587e826d4cd5b21a49186f7c/Sans/LICENSE)，可随软件嵌入和分发，需保留许可及版权，不单独出售字体。本包同时包含原始 `LICENSE-OFL.txt` 和从字体元数据提取的 `FONT_COPYRIGHT.txt`。没有复制 PingFang、微软雅黑或其他系统字体文件。

`XJUITheme.font()` 返回同一个预加载 `FontFile`，禁用系统回退；Theme 控件和机库 `Label3D` 使用该资源。`font/plate/flat/button_style/create/texture/decorate` 原有API保留，新增 `focus_style`。固定字体减少跨平台字体替换、缺字及字号度量差异；中文是否正确仍需实际渲染验证，不能仅凭系统有中文字体推断。

| 资源 | 用途 |
| --- | --- |
| `NotoSansCJKsc-Regular.otf`、许可、版权 | 共享中文字体及可分发权利信息 |
| `ui_panel.svg`、`ui_button.svg` | 原创切角细线框、玻璃底色、边缘刻度 |
| `ui_focus.svg` | 高对比键盘焦点角标 |
| `ui_chevron.svg`、`ui_slider_handle.svg` | 下拉和滑块的矢量功能标识，不依赖符号字体 |
| `ui_glass.gdshader` | 低振幅静态微网格与边缘冷光，不读取屏幕、不动画闪烁 |

9个资源的原始文件摘要纳入 `manifest.json`；SVG/shader是本项目原创源码，无商业游戏资源提取。清单逻辑哈希对删除 `manifest_sha256` 自身字段后的 JSON 计算，使用 UTF-8、`ensure_ascii=False`、键排序和紧凑分隔符。README/来源索引属于说明，不作为运行资源。

字形检查入口为 `jiaoben/tests/font_v3_glyphs.py`：直接读取官方OTF的Unicode cmap，对源码和只读SQLite内容中的中文、常用标点、箭头、ASCII及常见拉丁/希腊符号逐字符验证，并检查UTF-8替换字；不允许系统回退掩盖缺字。发现旧UI装饰符 `▰`、`▸` 不在字体内，整合已分别改为矢量小块与ASCII `>`。

本轮已验证99个源码文件、84张SQLite表涉及的817个字符，缺字与UTF-8替换字均为0，结果见 `jiaoben/logs/font-v3-glyph-report.json`。`jiaoben/tests/font_theme_v3.gd` 独立字体场景 headless **29/29 PASS**，原生 Metal / Forward+ **34/34 PASS、5张截图**，完整日志未见错误、警告或泄漏。检查FontFile身份、禁止系统回退、实际引擎字形、9项原始摘要、导入资源和四名人员Label3D；人工查看1440×900、1280×720及100%/200%样本与实际职业近景，未见乱码、豆腐块或装饰符缺字。

原生样本截图位于 `jiaoben/logs/font-v3-skin-*.png`、`font-v3-profession-label-1280x720.png`。该验证是独立字体/Theme场景，不冒充完整HUD实战、Windows实机或最终发布包验收。整合后的控制布局与实际导出仍由客户端验收负责；本包已锁定，尚未据此宣称新版最终交付。
