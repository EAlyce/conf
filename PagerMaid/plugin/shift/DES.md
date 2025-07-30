# 智能转发助手插件

📢 一个用于频道/群组/私聊的智能消息自动转发插件，支持多种转发规则、消息类型过滤、备份和关键词过滤。

## 功能介绍
- 自动转发频道/群组/用户消息到目标
- 支持消息类型过滤（文字、图片、视频等）
- 支持静默转发通知
- 备份历史消息功能
- 转发统计、暂停与恢复转发
- 关键词过滤，支持增删查
- 支持序号批量操作

## 命令示例
- `shift set @source @target silent photo`  
- `shift del @source`  
- `shift backup @source @target text`  
- `shift list`  
- `shift stats`  
- `shift pause @source`  
- `shift resume @source`  
- `shift filter @source add 广告 垃圾`  
- `shift filter @source del 广告`  
- `shift filter @source list`

## 注意事项
- 仅频道/群组可用 `silent` 静默选项  
- 转发给个人或机器人时，`silent` 失效  
- 请确保目标未屏蔽账号  
- 遵守隐私法规  
