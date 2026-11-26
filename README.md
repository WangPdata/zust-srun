# srun-login

浙江科技大学（ZUST）校园网 Wi-Fi 自动登录工具，适配深澜（srun）认证系统。

通过模拟官方客户端（`srun`）的登录流程（设备指纹 + 参数加密 + Challenge 校验）实现无人值守登录，可在后台常驻运行，掉线后自动重连。适用于宿舍、实验室等需要长时间保持在线的场景。

## 功能特性

- **无人值守**：启动即检测在线状态，掉线自动重新认证，无需手动点网页
- **多账号轮换**：`auth.json` 可配置多个账号，掉线时随机选取账号重登，适合一号一设备或多人共用
- **定时保活**：每 3 分钟检查一次在线状态；每 6 小时主动刷新一次会话，避免认证超时被踢下线
- **协议还原**：完整复刻深澜认证的 `get_challenge` / `srun_bx1` 加密流程与设备指纹（Windows / macOS / Linux 多套 UA 与设备标识）
- **日志落盘**：运行日志写入 `srun_login.log`，按 10 MB 自动轮转，方便排查失败原因
- **跨平台**：Windows 下提供 `login.bat` 一键启动，Linux 下可用 `nohup` 或 `systemd` 常驻

## 目录结构

```
ZUST--login-main/
├── login.bat              # Windows 一键启动脚本
├── README.md              # 本说明
├── .gitignore
└── srun-login/
    ├── login.py           # 主程序：认证流程 + 定时调度
    ├── auth.json          # 账号密码（本地私密文件，不纳入版本控制）
    ├── requirements.txt   # Python 依赖
    ├── srun_login.log     # 运行日志（自动生成，不纳入版本控制）
    └── utils/
        ├── base.py        # Base64 / 字节填充工具
        ├── device.py      # 设备指纹与 UA 池
        ├── hash.py        # MD5 / HMAC 封装
        └── xencode.py     # srun_bx1 参数加密实现
```

## 环境要求

- Python 3.9 及以上（已在 3.9 / 3.10 验证）
- 三方依赖：

```
requests==2.32.3
loguru==0.7.2
apscheduler==3.10.4
```

## 快速开始

### 1. 安装依赖

```bash
cd srun-login
pip install -r requirements.txt
```

国内网络建议加镜像源加速：

```bash
pip install -r requirements.txt -i https://pypi.tuna.tsinghua.edu.cn/simple
```

### 2. 配置账号

在 `srun-login` 目录下新建 `auth.json`（**文件名固定，程序按相对路径读取**），内容为账号数组：

```json
[
  {"username": "你的学号", "password": "你的密码"},
  {"username": "备用学号", "password": "备用密码"}
]
```

只需单账号时可只写一项。注意 JSON 格式：数组用方括号，最后一项后面**不要加逗号**，中文标点会导致解析失败。

该文件含明文密码，已被 `.gitignore` 排除，请勿提交到任何仓库；如需要，可另存一份 `auth.example.json` 模板用于分享。

### 3. 启动

Windows：直接双击根目录的 `login.bat`，脚本会先切换到 `srun-login` 目录再执行主程序。

命令行方式（两个平台通用）：

```bash
cd srun-login
python login.py
```

Linux 后台常驻：

```bash
cd srun-login
nohup python3 login.py >/dev/null 2>&1 &
```

## 运行机制

程序启动后由 APScheduler 的 `BlockingScheduler` 驱动两个任务：

- **check（每 3 分钟）**：查询当前 IP 的在线状态。返回非 `ok` 即判定掉线，从 `auth.json` 中随机挑选账号重新认证；若返回 `4xx` 视为账号密码错误，间隔 2 秒继续重试换号。
- **refresh（每 6 小时）**：主动注销后重新登录，刷新会话时长，防止长时间在线被服务端强制下线。

认证服务器地址固定为 `http://10.33.0.2/`（`login.py` 第 45 行）。如所处网络环境（教学区 / 生活区 / 其他校区）认证地址不同，修改该行即可。

## 开机自启

Windows —— 
方法1、任务计划程序：

1. 创建任务，操作选「启动程序」，程序填 `login.bat` 的完整路径
2. 触发器选「登录时」或「开机时」，勾选「不管用户是否登录都要运行」
3. 因脚本末尾含 `pause`，进程会常驻一个命令行窗口；若不希望常驻，可把 `pause` 改为 `exit /b 0`

方法2、win+R shell:startup 中粘入login.bat
Linux —— systemd：

```ini
[Unit]
Description=srun login
After=network-online.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/python3 /path/to/srun-login/login.py
WorkingDirectory=/path/to/srun-login
Restart=always

[Install]
WantedBy=multi-user.target
```

注意 `WorkingDirectory` 必须指向含 `auth.json` 的 `srun-login` 目录。

## 常见问题

**日志提示 `please check auth.json`**
文件缺失或 JSON 语法错误（最常见是最后一项多了逗号、用了中文引号）。程序读不到配置会直接退出。

**日志出现 `4xx` 并不断换号重试**
该账号的学号或密码不正确，或账号已被禁用。

**`Failed to get IP`**
未处于校园网环境，或认证前尚未从 DHCP 拿到地址。连上校园 Wi-Fi 后再启动。

**手动在 PyCharm 里运行却找不到 auth.json**
PyCharm 默认工作目录是项目根目录，而非 `srun-login`。把运行配置的 Working Directory 设为 `srun-login`，或直接在终端 `cd` 进去再执行。

**日志文件越来越大**
`loguru` 已配置 `rotation="10 MB"` 自动切分，旧文件可随时删除。

## 许可

MIT License。

本项目基于 [Jack-Chen-Hi/HDU--login-main](https://github.com/Jack-Chen-Hi/HDU--login-main) 二次开发，登录协议与加密实现沿用上游思路；在此基础上调整为 ZUST 网络环境并补充了本机启动与自启方案。原文中的图片配置流程记录见 [CSDN 博客](https://blog.csdn.net/qq_63860529/article/details/155944278)。
