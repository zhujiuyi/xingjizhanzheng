# 测试与辅助文件

| 路径 | 用途 | Git 管理 |
| --- | --- | --- |
| `check-env.sh` | 检查工作区目录和本机工具；不安装软件 | 跟踪 |
| `build_catalog.py` | 从 `code/database/` 的结构与种子 SQL 重建正式数值库 | 跟踪 |
| `run_godot.sh` | 使用锁定引擎打开工程或执行命令 | 跟踪 |
| `probes/`、`prepare_godot_probe.py` | 原生数据库/渲染/Blender 技术探针，运行产物在 tmp | 跟踪 |
| `verify_toolchain_downloads.py`、`vendor_sqlite.py`、`install_desktop_templates.py` | 官方包摘要检查与已核验桌面依赖准备 | 跟踪 |
| `tests/` | 可重复执行的测试及测试专用数据 | 跟踪 |
| `tmp/` | 实验、下载、临时文件和中间产物 | 仅跟踪占位文件 |
| `logs/` | 环境检查、运行和测试日志 | 仅跟踪占位文件 |

从工作区根目录运行 `sh jiaoben/check-env.sh`。脚本也可从其他目录调用，会按脚本所在位置定位工作区。

正式游戏逻辑和运行资源放在 `code/`；对外或长期使用的说明放在 `doc/`。下载缓存可以删除，正式源文件与测试成果不能当作临时文件清理。

数值检查入口为 `tests/test_balance.py`；加 `--report` 将结果写入 `logs/数值校验报告.md`。报告可重建，持久的范围说明和验收结果摘要维护在 [开发准备度](../doc/16-开发准备度与缺口清单.md)。测试中的公式是独立参考模型，不代表 Godot 玩法或进度存档已实现。

首版内容检查见 `tests/test_content.py`，进度 DDL/夹具检查见18，接口/占位及 `tests/test_rng_contract.py` 随机流契约检查见21，实际工具链及 `prepare_progress_probe.py` 正式SQL原生探针复现见22。运行专用探针时不得向正式用户档写入数据。
