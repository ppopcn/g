好的，我理解了，需要完美适配这四个系统，包括Alpine Linux的OpenRC。

我已经对脚本进行了修改，增加了对Alpine Linux的OpenRC服务管理方式的判断和处理。现在，脚本会根据检测到的操作系统类型，采用对应的服务管理方式来创建服务文件并设置开机自启。

请看修改后的 `g.sh` 脚本：

```bash
#!/bin/bash

# 默认参数
PORT=""
PASSWD=""
METHOD=""

# 解析命令行参数
while [[ "$#" -gt 0 ]]; do
	case "$1" in
		-port)
			PORT="$2"
			shift
			;;
		-passwd)
			PASSWD="$2"
			shift
			;;
		-method)
			METHOD="$2"
			shift
			;;
		*)
			echo "未知参数: $1"
			exit 1
			;;
	esac
	shift
done

# 检查必要参数是否提供
if [ -z "$PORT" ] || [ -z "$PASSWD" ] || [ -z "$METHOD" ]; then
	echo "用法: sh g.sh -port <端口> -passwd <密码> -method <加密方法>"
	echo "示例: sh g.sh -port 8989 -passwd qwe123 -method aes-256-gcm"
	exit 1
fi

# 第一步: 判断系统并初始化环境
echo "正在检测操作系统并初始化环境..."

SERVICE_MANAGER="" # 记录服务管理器类型
if grep -Eqi "centos|redhat|rhel" /etc/os-release; then
	OS="centos"
	SERVICE_MANAGER="systemd"
	echo "检测到 CentOS 系统 (使用 Systemd)。"
	yum install -y curl bash wget sudo tar || { echo "安装依赖失败，请检查网络或权限。"; exit 1; }
elif grep -Eqi "debian" /etc/os-release; then
	OS="debian"
	SERVICE_MANAGER="systemd"
	echo "检测到 Debian 系统 (使用 Systemd)。"
	apt update && apt install -y curl bash wget sudo tar || { echo "安装依赖失败，请检查网络或权限。"; exit 1; }
elif grep -Eqi "ubuntu" /etc/os-release; then
	OS="ubuntu"
	SERVICE_MANAGER="systemd"
	echo "检测到 Ubuntu 系统 (使用 Systemd)。"
	apt update && apt install -y curl bash wget sudo tar || { echo "安装依赖失败，请检查网络或权限。"; exit 1; }
elif grep -Eqi "alpine" /etc/os-release; then
	OS="alpine"
	SERVICE_MANAGER="openrc"
	echo "检测到 Alpine Linux 系统 (使用 OpenRC)。"
	apk update && apk add curl bash wget sudo tar openrc || { echo "安装依赖失败，请检查网络或权限。"; exit 1; }
else
	echo "不支持的操作系统。"
	exit 1
fi

# 第二步: 下载 gost 并解压到 /root/gost
echo "正在下载和解压 gost..."
GOST_URL="https://github.com/go-gost/gost/releases/download/v3.2.3/gost_3.2.3_linux_amd64.tar.gz"
DOWNLOAD_PATH="/tmp/gost_3.2.3_linux_amd64.tar.gz"
GOST_DIR="/root" # gost 可执行文件最终路径 /root/gost

wget -O "$DOWNLOAD_PATH" "$GOST_URL" || { echo "下载 gost 失败，请检查网络。"; exit 1; }
tar -xzf "$DOWNLOAD_PATH" -C "$GOST_DIR" gost || { echo "解压 gost 失败。"; exit 1; }
rm -f "$DOWNLOAD_PATH" # 清理下载文件
chmod +x /root/gost # 赋予执行权限

echo "gost 已下载并解压到 /root/gost。"

# 第三步: 根据不同的服务管理器创建服务并设置开机自启
echo "正在创建服务配置文件并设置开机自启..."

if [ "$SERVICE_MANAGER" == "systemd" ]; then
	SERVICE_FILE="/etc/systemd/system/gost.service"
	cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=gost
After=network.target

[Service]
Type=simple
ExecStart=/root/gost -L=ss://${METHOD}:${PASSWD}@:${PORT} -L=ssu://${METHOD}:${PASSWD}@:${PORT}
Restart=always

[Install]
WantedBy=multi-user.target
EOF
	systemctl daemon-reload
	systemctl enable gost
	systemctl restart gost
	echo "gost.service (Systemd) 已成功创建、启动并设置开机自启。"
elif [ "$SERVICE_MANAGER" == "openrc" ]; then
	SERVICE_FILE="/etc/init.d/gost"
	cat > "$SERVICE_FILE" <<EOF
#!/sbin/openrc-run

name="gost"
description="gost proxy service"
command="/root/gost"
command_args="-L=ss://${METHOD}:${PASSWD}@:${PORT} -L=ssu://${METHOD}:${PASSWD}@:${PORT}"
command_background="yes" # 后台运行
pidfile="/var/run/gost.pid" # PID文件

depend() {
	net
}

start_stop_daemon_args="--user root --group root" # 以root用户运行

EOF
	chmod +x "$SERVICE_FILE"
	rc-update add gost default
	rc-service gost restart
	echo "gost (OpenRC) 已成功创建、启动并设置开机自启。"
else
	echo "未知服务管理器类型，无法设置开机自启。"
	exit 1
fi

echo "配置信息:"
echo "	端口: $PORT"
echo "	密码: $PASSWD"
echo "	方法: $METHOD"
if [ "$SERVICE_MANAGER" == "systemd" ]; then
	echo "您可以通过 'systemctl status gost' 查看服务状态。"
elif [ "$SERVICE_MANAGER" == "openrc" ]; then
	echo "您可以通过 'rc-service gost status' 查看服务状态。"
fi
```