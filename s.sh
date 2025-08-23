#!/bin/bash

# 颜色定义
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 默认参数
PORT="8989"
PASSWD="qwe123"
METHOD="aes-256-gcm"

# 提醒用户检查云服务器安全组
echo -e "\n注意：如果您在使用云服务器，请确保在云服务商控制面板中已设置安全组规则，放行相应端口。"

# 如果没有命令行参数，显示交互式菜单
if [ $# -eq 0 ]; then
    echo -e "\n欢迎使用 Shadowsocks 安装脚本"
    echo -e "----------------------------------------"
    echo -e "${GREEN}1. 使用默认配置继续安装 [默认]${NC}"
    echo -e "   - 端口: 8989"
    echo -e "   - 密码: qwe123"
    echo -e "   - 加密方式: aes-256-gcm"
    echo -e "${BLUE}2. 退出脚本，使用自定义参数${NC}"
    echo -e "----------------------------------------"
    read -p "请选择 [1/2] (默认: 1): " choice
    choice=${choice:-1} # 如果用户直接按回车，将choice设为1

    case $choice in
    2)
        echo -e "\n要使用自定义参数，请按以下格式运行脚本："
        echo "sh s.sh -port <端口> -passwd <密码> -method <加密方法>"
        echo "示例: sh s.sh -port 8989 -passwd qwe123 -method aes-256-gcm"
        exit 0
        ;;
    1 | "")
        echo -e "\n将使用默认配置继续安装..."
        sleep 1
        ;;
    *)
        echo -e "\n无效的选择，将使用默认配置继续安装..."
        sleep 1
        ;;
    esac
else
    # 如果有命令行参数，重置默认值
    PORT=""
    PASSWD=""
    METHOD=""
fi

# 解析命令行参数
while [ "$#" -gt 0 ]; do
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

# 检查必要参数是否提供（仅在使用命令行参数时检查）
if [ $# -gt 0 ] && { [ -z "$PORT" ] || [ -z "$PASSWD" ] || [ -z "$METHOD" ]; }; then
    echo -e "${RED}错误：参数不完整${NC}"
    echo "用法: sh s.sh -port <端口> -passwd <密码> -method <加密方法>"
    echo "示例: sh s.sh -port 8989 -passwd qwe123 -method aes-256-gcm"
    exit 1
fi

# 清理函数：清理所有旧的安装
cleanup_old_installation() {
    echo "正在清理旧的 Shadowsocks 安装..."

    # 1. 停止并删除系统服务
    if command -v systemctl >/dev/null 2>&1; then
        echo "清理 systemd 服务..."
        systemctl stop shadowsocks >/dev/null 2>&1
        systemctl disable shadowsocks >/dev/null 2>&1
        rm -f /etc/systemd/system/shadowsocks.service
        systemctl daemon-reload
    fi

    if command -v rc-service >/dev/null 2>&1; then
        echo "清理 OpenRC 服务..."
        rc-service shadowsocks stop >/dev/null 2>&1
        rc-update del shadowsocks default >/dev/null 2>&1
        rm -f /etc/init.d/shadowsocks
    fi

    # 2. 删除旧的二进制文件
    if [ -f "/root/shadowsocks2-linux" ]; then
        echo "删除旧的 shadowsocks2-linux 程序..."
        rm -f "/root/shadowsocks2-linux"
    fi

    # 3. 清理可能存在的进程
    if pgrep shadowsocks2-linux >/dev/null; then
        echo "终止残留的 shadowsocks2-linux 进程..."
        pkill shadowsocks2-linux
    fi

    # 4. 清理PID文件
    rm -f /var/run/shadowsocks.pid >/dev/null 2>&1

    echo "清理完成。"
}

# 在开始安装前执行清理
cleanup_old_installation

# 第一步: 判断系统并初始化环境
echo "正在检测操作系统并初始化环境..."

SERVICE_MANAGER="" # 记录服务管理器类型

# 首先检测服务管理器类型
if command -v systemctl >/dev/null 2>&1; then
    SERVICE_MANAGER="systemd"
elif command -v rc-service >/dev/null 2>&1; then
    SERVICE_MANAGER="openrc"
else
    echo "未检测到支持的服务管理器（systemd/openrc）"
    exit 1
fi

# 然后检测具体的操作系统类型
if grep -Eqi "centos|redhat|rhel" /etc/os-release; then
    OS="centos"
    echo "检测到 CentOS/RHEL 系统 (使用 $SERVICE_MANAGER)。"

    # 处理SELinux
    echo "正在检查并禁用SELinux..."
    if command -v sestatus >/dev/null 2>&1; then
        if sestatus | grep -q "enabled"; then
            echo "检测到SELinux已启用，正在禁用..."
            # 临时禁用
            setenforce 0 >/dev/null 2>&1
            # 永久禁用
            if [ -f "/etc/selinux/config" ]; then
                sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
                sed -i 's/SELINUX=permissive/SELINUX=disabled/g' /etc/selinux/config
                echo "SELinux已被禁用，重启后生效"
            else
                echo "警告：未找到SELinux配置文件，无法永久禁用"
            fi
        else
            echo "SELinux已处于禁用状态"
        fi
    else
        echo "未检测到SELinux，跳过处理"
    fi

    # CentOS 8+ 使用 dnf，7 使用 yum
    if command -v dnf >/dev/null 2>&1; then
        dnf install -y curl bash wget sudo tar gzip || {
            echo "安装依赖失败，请检查网络或权限。"
            exit 1
        }
    else
        yum install -y curl bash wget sudo tar gzip || {
            echo "安装依赖失败，请检查网络或权限。"
            exit 1
        }
    fi
elif grep -Eqi "debian" /etc/os-release; then
    OS="debian"
    echo "检测到 Debian 系统 (使用 $SERVICE_MANAGER)。"
    apt update && apt install -y curl bash wget sudo tar gzip || {
        echo "安装依赖失败，请检查网络或权限。"
        exit 1
    }
elif grep -Eqi "ubuntu" /etc/os-release; then
    OS="ubuntu"
    echo "检测到 Ubuntu 系统 (使用 $SERVICE_MANAGER)。"
    apt update && apt install -y curl bash wget sudo tar gzip || {
        echo "安装依赖失败，请检查网络或权限。"
        exit 1
    }
elif grep -Eqi "alpine" /etc/os-release; then
    OS="alpine"
    echo "检测到 Alpine Linux 系统 (使用 $SERVICE_MANAGER)。"
    apk update && apk add curl bash wget sudo tar gzip openrc || {
        echo "安装依赖失败，请检查网络或权限。"
        exit 1
    }
else
    echo "警告：未识别的操作系统，但将继续尝试安装..."
fi

# 检查并卸载系统中的防火墙
echo "正在检查并清理防火墙..."

# 处理 firewalld
if command -v firewall-cmd >/dev/null 2>&1; then
    echo "检测到 firewalld，正在卸载..."
    systemctl stop firewalld >/dev/null 2>&1
    systemctl disable firewalld >/dev/null 2>&1
    if [ "$OS" = "centos" ]; then
        dnf -y remove firewalld >/dev/null 2>&1 || yum -y remove firewalld >/dev/null 2>&1
    fi
fi

# 处理 ufw
if command -v ufw >/dev/null 2>&1; then
    echo "检测到 ufw，正在卸载..."
    ufw disable >/dev/null 2>&1
    if [ "$OS" = "debian" ] || [ "$OS" = "ubuntu" ]; then
        apt -y remove ufw >/dev/null 2>&1
    fi
fi

# 处理 iptables
if command -v iptables >/dev/null 2>&1; then
    echo "检测到 iptables，正在清理规则并停止服务..."
    iptables -F
    iptables -X
    iptables -P INPUT ACCEPT
    iptables -P FORWARD ACCEPT
    iptables -P OUTPUT ACCEPT
    if command -v service >/dev/null 2>&1; then
        service iptables stop >/dev/null 2>&1
    fi
    if [ "$OS" = "centos" ]; then
        dnf -y remove iptables-services >/dev/null 2>&1 || yum -y remove iptables-services >/dev/null 2>&1
    fi
fi

echo "防火墙清理完成。"

# 第二步: 下载 go-shadowsocks2 并解压到 /root/shadowsocks2-linux
echo "正在下载和解压 go-shadowsocks2..."
SS_URL="https://github.com/shadowsocks/go-shadowsocks2/releases/download/v0.1.5/shadowsocks2-linux.gz"
DOWNLOAD_PATH="/tmp/shadowsocks2-linux.gz"
SS_DIR="/root" # shadowsocks2-linux 可执行文件最终路径 /root/shadowsocks2-linux

# 下载并解压（会自动覆盖已存在的文件）
wget -O "$DOWNLOAD_PATH" "$SS_URL" || {
    echo "下载 go-shadowsocks2 失败，请检查网络。"
    exit 1
}
gzip -d -c "$DOWNLOAD_PATH" > "$SS_DIR/shadowsocks2-linux" || {
    echo "解压 go-shadowsocks2 失败。"
    exit 1
}

# 清理下载文件
rm -f "$DOWNLOAD_PATH"

# 设置权限
chmod +x "$SS_DIR/shadowsocks2-linux" || {
    echo "设置执行权限失败。"
    exit 1
}

# 如果是CentOS系统，设置SELinux上下文
if [ "$OS" = "centos" ] && command -v chcon >/dev/null 2>&1; then
    echo "正在设置SELinux上下文..."
    chcon -t bin_t "$SS_DIR/shadowsocks2-linux" >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "SELinux上下文设置成功"
    else
        echo "警告：SELinux上下文设置失败，如果SELinux未完全禁用，可能会导致权限问题"
    fi
fi

echo "go-shadowsocks2 已成功安装到 $SS_DIR/shadowsocks2-linux。"

# 第三步: 根据不同的服务管理器创建服务并设置开机自启
echo "正在创建服务配置文件并设置开机自启..."

if [ "$SERVICE_MANAGER" = "systemd" ]; then
    SERVICE_FILE="/etc/systemd/system/shadowsocks.service"

    # 清理已存在的服务
    if systemctl list-unit-files | grep -q "shadowsocks.service"; then
        echo "检测到已存在的 shadowsocks 服务，正在清理..."
        systemctl stop shadowsocks >/dev/null 2>&1
        systemctl disable shadowsocks >/dev/null 2>&1
        rm -f "$SERVICE_FILE"
    fi

    # 创建新服务
    cat >"$SERVICE_FILE" <<EOF
[Unit]
Description=Shadowsocks
After=network.target
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/root/shadowsocks2-linux -s 'ss://${METHOD}:${PASSWD}@:${PORT}' -udp -verbose
StandardError=append:/var/log/shadowsocks.error.log
Restart=always
RestartSec=3
User=root
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable shadowsocks || {
        echo "启用服务失败，请检查权限。"
        exit 1
    }
    systemctl restart shadowsocks || {
        echo "启动服务失败，请检查配置。"
        exit 1
    }
    echo "shadowsocks.service (Systemd) 已成功创建、启动并设置开机自启。"
elif [ "$SERVICE_MANAGER" = "openrc" ]; then
    SERVICE_FILE="/etc/init.d/shadowsocks"

    # 清理已存在的服务
    if [ -f "$SERVICE_FILE" ]; then
        echo "检测到已存在的 shadowsocks 服务，正在清理..."
        rc-service shadowsocks stop >/dev/null 2>&1
        rc-update del shadowsocks default >/dev/null 2>&1
        rm -f "$SERVICE_FILE"
    fi

    # 创建新服务
    # 确保所需目录存在
    mkdir -p /var/log

    cat >"$SERVICE_FILE" <<EOF
#!/sbin/openrc-run

name="shadowsocks"
description="Shadowsocks proxy service"
command="/root/shadowsocks2-linux"
command_args="-s 'ss://${METHOD}:${PASSWD}@:${PORT}' -udp -verbose"
command_background="yes"
pidfile="/run/shadowsocks.pid"
output_log="/var/log/shadowsocks.error.log"
error_log="/var/log/shadowsocks.error.log"
directory="/root"

depend() {
    need net
    after net
}

start_pre() {
    # 确保日志文件存在并设置权限
    touch "/var/log/shadowsocks.error.log"
    chown root:root "/var/log/shadowsocks.error.log"
    chmod 644 "/var/log/shadowsocks.error.log"
}

EOF
    chmod +x "$SERVICE_FILE"
    rc-update add shadowsocks default
    rc-service shadowsocks restart
    echo "shadowsocks (OpenRC) 已成功创建、启动并设置开机自启。"
else
    echo "未知服务管理器类型，无法设置开机自启。"
    exit 1
fi

echo "配置信息:"
echo "	端口: $PORT"
echo "	密码: $PASSWD"
echo "	方法: $METHOD"

# 等待服务启动完全（给服务一些启动时间）
sleep 2

# 注意: 防火墙已被卸载,请确保在云服务商控制面板中放行相应端口
# echo -e "\n提示：由于已卸载系统防火墙，请确保在云服务商控制面板中已设置安全组规则，放行端口 $PORT"

echo -e "\n端口监听状态:"
netstat -tnlp | grep shadowsocks2-linux || ss -tnlp | grep shadowsocks2-linux

echo -e "\n进程状态:"
ps aux | grep -v grep | grep shadowsocks2-linux

echo -e "\n服务状态:"
if [ "$SERVICE_MANAGER" = "systemd" ]; then
    # 显示服务状态，使用 --no-pager 选项并限制输出行数
    systemctl status shadowsocks --no-pager -n 15
    # 等待3秒
    sleep 3

    echo -e "\n=== 常用命令说明 ==="
    echo "0) 查看服务状态:"
    echo "   systemctl status shadowsocks"
    echo "1) 查看实时日志:"
    echo "   journalctl -f -u shadowsocks.service"
    echo "   或者"
    echo "   tail -f /var/log/shadowsocks.error.log"

    echo "2) 重启服务:"
    echo "   systemctl restart shadowsocks"
    echo "3) 停止服务:"
    echo "   systemctl stop shadowsocks"
    echo "4) 查看进程:"
    echo "   ps aux | grep -v grep | grep shadowsocks2-linux"
elif [ "$SERVICE_MANAGER" = "openrc" ]; then
    rc-service shadowsocks status
    # 等待3秒
    sleep 3

    echo -e "\n=== 常用命令说明 ==="
    echo "0) 查看服务状态:"
    echo "   rc-service shadowsocks status"

    echo "1) 查看实时日志:"
    echo "   tail -f /var/log/shadowsocks.error.log"

    echo "2) 查看进程:"
    echo "   ps aux | grep -v grep | grep shadowsocks2-linux"

    echo "3) 重启服务:"
    echo "   rc-service shadowsocks restart"
    echo "4) 停止服务:"
    echo "   rc-service shadowsocks stop"
fi
