@echo off
:: 切换到项目所在磁盘和目录 (/d 参数非常重要，否则无法跨盘符)
cd /d "D:\PycharmSpace\ZUST--login-main\srun-login"

echo Starting ZUST Network Login...
:: 启动脚本
python login.py --name  "loginZUST-NET"

:: 防止报错闪退，保留窗口查看日志（稳定后可去掉下面这几行）
echo.
pause

