# LittleCare

LittleCare 是一款面向亲近关系的健康记录与关心应用。

它不想把健康变成冰冷的指标打卡，也不把亲人之间的关系简化成提醒和监督。在原子化的时代，很多人和父母、伴侣、朋友相隔很远，日常牵挂常常来得细碎、安静，又很难开口。LittleCare 希望让这些牵挂有一个温柔的落点：把血压、血糖、血脂这些真实记录，变成彼此看见、回应和放心的方式。

## 现在能做什么

- 记录血压、血糖、血脂等健康数据
- 查看趋势图、横屏趋势和当天明细
- 创建或加入亲友群组
- 将自己的健康记录分享给指定群组
- 查看群组成员近况
- 向亲友发送关心，并支持快捷回应和自定义回应
- 使用手机号和恢复码找回账号
- 管理群组名称、备注、成员和历史记录分享范围

## 下载

目前只支持 Android 安装包下载。

请在 GitHub Release 中下载：

- `LittleCare.apk`

安装前，Android 设备可能会提示“允许安装未知来源应用”。这是因为当前版本暂未上架应用商店。

## 项目状态

这是 LittleCare 的第一个可测试版本，重点验证核心体验：

- 记录健康数据是否顺手
- 群组分享是否清晰可靠
- 远距离亲友之间的“看见”和“回应”是否自然
- 文案和界面是否足够克制、温情、不打扰

推送通知、更多云服务适配和正式应用商店发布仍在后续规划中。

## 技术栈

- Flutter
- Riverpod
- Firebase Auth
- Cloud Firestore
- Android APK 构建

## 本地运行

演示模式：

```powershell
flutter run
```

Firebase 模式：

```powershell
flutter run --dart-define=USE_FIREBASE=true
```

构建 Android 调试包：

```powershell
flutter build apk --debug --dart-define=USE_FIREBASE=true
```

## 说明

仓库不会提交本地工具链、构建产物、Firebase 私有配置和 APK 文件。APK 会作为 Release 附件发布。
