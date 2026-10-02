# 首版静态占位资产

四个 `.tscn` 只含四船几何、CharacterBody3D/BoxShape3D、槽位挂点与表现定位点，无玩法脚本、相机、特效、音频或数据库值。项目根目录为 `code/` 时，manifest 中的 `res://assets/placeholders/…` 路径有效。

- [manifest.json](manifest.json)：实际资源路径、文件 SHA-256、资产版 `placeholder-b-v1`。manifest 哈希对去掉 `manifest_sha256` 字段后的 UTF-8 JSON 计算，键排序、无空白、非 ASCII 不转义；换行不参与。资源文件哈希按文件原始字节计算。
- [资源与表现规格](../../../doc/20-资源表现与界面实施规格.md)：尺寸、挂点、朝向与碰撞层协议。
- [模块契约](../../../doc/21-模块接口与开发验收规格.md)：工厂、资源版和内容档兼容检查。

节点属性中的 `motion_mode=1` 表示 floating、`collision_layer=2`/`collision_mask=3` 为固定协议；这些不是舰船速度、伤害或平衡配置。场景不移动，需后续权威模拟与工厂绑定。

修改碰撞或挂点必须更新资产版本和 manifest；不能在旧档上静默替换。文件导入/解析结果以 Godot headless 验证为准，静态场景存在不代表已经可玩。
