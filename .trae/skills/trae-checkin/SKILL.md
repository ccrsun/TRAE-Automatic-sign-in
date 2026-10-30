---
name: "trae-checkin"
description: "为 Trae 账户执行每日签到，自动恢复凭证、运行签到脚本并汇报结果。当用户说「签到」「trae 签到」或要求执行 Trae 每日签到时调用。"
---

# Trae 每日签到

## 触发条件

用户说「签到」、「trae 签到」或要求执行 Trae 每日签到时调用本技能。

## 执行步骤

1. 切换到 `/workspace` 目录。
2. 如果 `/workspace/trae-checkin.env` 不存在而 `~/.trae-checkin.env` 存在，把后者复制到前者并执行 `chmod 600 /workspace/trae-checkin.env`。
3. 运行 `./trae-checkin.sh`，等待执行完毕。
4. 根据输出汇报结果：
   - **成功**：输出包含「签到成功」、`device_id` 及获得积分（0 积分表示今日已签过）。
   - **退出码 2 / 出现「Session 已失效」**：Session 过期，需重新登录。打开浏览器访问 https://www.trae.cn/login，请用户本人完成手机号 + 验证码登录；登录成功后读取 `X-Cloudide-Session` Cookie，更新 `/workspace/trae-checkin.env` 与 `~/.trae-checkin.env` 的 `TRAE_SESSION`，再次运行脚本补签。
   - **风控码 9074「当前参与用户太多」**：设备号被风控。把 `TRAE_DEVICE_ID` 换成一个新的、未使用过的 16 位数字，同步更新两个 env 文件后重试；成功后保持新设备号不变，并说明已更换。
   - **其他错误**：如实告知失败原因。

## 凭证位置

- 工作区凭证：`/workspace/trae-checkin.env`（可能随工作区重置丢失）
- 持久备份：`~/.trae-checkin.env`（更新 Session 或设备号时两处都要同步）

## 注意

- 不要把凭证写入任何会被提交到仓库的文件。
- 不要修改 `checkin.py` 的签到逻辑。
- 不要伪造或猜测 Session。
