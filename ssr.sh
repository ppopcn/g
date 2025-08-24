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
SS_RUST_VERSION="1.23.5" # shadowsocks-rust 固定版本

# 提醒用户检查云服务器安全组
echo -e "\n注意：如果您在使用云服务器，请确保在云服务商控制面板中已设置安全组规则，放行相应端口。"

# 如果没有命令行参数，显示交互式菜单
if [ $# -eq 0 ]; then
    echo -e "\n欢迎使用 Shadowsocks 安装脚本"
    echo -e "----------------------------------------"
    echo -e "${GREEN}1. 使用默认配置继续安装 [默认]${NC}"
    echo -e "   - 端口: ${PORT}"
    echo "   - 密码: ${PASSWD}"
    echo "   - 加密方式: ${METHOD}"
    echo -e "${BLUE}2. 退出脚本，请使用自定义参数${NC}"
    echo -e "----------------------------------------"
    read -p "请选择 [1/2] (默认: 1): " choice
    choice=${choice:-1} # 如果用户直接按回车，将choice设为1

    case "$choice" in
    1)
        echo -e "\n将使用默认配置继续安装..."
        sleep 1
        ;;
    2)
        echo -e "\n已退出脚本。请使用 'sh ssr.sh -port <端口> -passwd <密码> -method <加密方法>' 自定义安装。"
        exit 0
        ;;
    *)
        echo -e "${RED}无效选择，已退出。${NC}"
        exit 1
        ;;
    esac
else
    # 如果有命令行参数，重置默认值以接收输入
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

# 确保在命令行模式下，如果用户没有提供某些参数，则使用默认值
# 这里的逻辑是：如果用户提供了任何参数，我们就检查这三个核心参数。
# 如果用户一个参数都没提供（$# 为 0），那么上面的 if [ $# -eq 0 ] 已经处理了，会使用脚本内定义的默认值
# 注意：此处的判断逻辑已经简化，因为在 $# -eq 0 的情况下，PORT, PASSWD, METHOD 已经通过默认值或用户选择被设置。
# 只有在命令行参数模式下（$# > 0 且 PORT,PASSWD,METHOD 被清空），才需要重新赋默认值。
if [ -z "$PORT" ]; then # 假设只要有一个参数为空，就填充所有默认值
    PORT="8989"
fi
if [ -z "$PASSWD" ]; then
    PASSWD="qwe123"
fi
if [ -z "$METHOD" ]; then
    METHOD="aes-256-gcm"
fi

# 检查命令行模式下是否有参数遗漏
if [ "$#" -gt 0 ] && { [ -z "$PORT" ] || [ -z "$PASSWD" ] || [ -z "$METHOD" ]; }; then # 这里调整了判断，确保只有在命令行模式下且参数不完整时才报错
    echo -e "${RED}错误：参数不完整。请确保指定了端口、密码和加密方法。${NC}"
    echo "用法: sh ssr.sh -port <端口> -passwd <密码> -method <加密方法>"
    echo "示例: sh ssr.sh -port 8989 -passwd qwe123 -method aes-256-gcm"
    exit 1
fi

# 清理函数：清理所有旧的安装
cleanup_old_installation() {
    echo "正在清理旧的服务安装、二进制文件和残留进程..."

    # 定义所有可能的服务名称
    local -a service_names=("shadowsocks" "shadowsocks-rust" "gost")
    # 定义所有可能的二进制文件路径
    local -a binary_paths=("/root/shadowsocks2-linux" "/usr/local/bin/ssserver" "/root/gost")
    # 定义所有可能的进程名 (用于pgrep/pkill)
    local -a process_names=("shadowsocks2-linux" "ssserver" "gost")
    # 定义所有可能的PID文件路径
    local -a pid_files=("/var/run/shadowsocks.pid" "/var/run/shadowsocks-rust.pid" "/var/run/gost.pid")


    # 1. 停止并删除系统服务
    echo "清理 systemd / OpenRC 服务..."
    for name in "${service_names[@]}"; do
        if command -v systemctl >/dev/null 2>&1; then
            if systemctl is-active --quiet "$name" || systemctl is-enabled --quiet "$name"; then
                echo "    - 停止并禁用 systemd 服务: $name"
                systemctl stop "$name" >/dev/null 2>&1
                systemctl disable "$name" >/dev/null 2>&1
            fi
            if [ -f "/etc/systemd/system/$name.service" ]; then
                echo "    - 删除 systemd 服务文件: /etc/systemd/system/$name.service"
                rm -f "/etc/systemd/system/$name.service"
            fi
        fi

        if command -v rc-service >/dev/null 2>&1; then
            if rc-service "$name" status >/dev/null 2>&1; then # 检查OpenRC服务是否存在或运行
                echo "    - 停止并禁用 OpenRC 服务: $name"
                rc-service "$name" stop >/dev/null 2>&1
                rc-update del "$name" default >/dev/null 2>&1
            fi
            if [ -f "/etc/init.d/$name" ]; then
                echo "    - 删除 OpenRC 服务文件: /etc/init.d/$name"
                rm -f "/etc/init.d/$name"
            fi
        fi
    done

    # 重新加载 systemd daemon (如果systemctl存在)
    if command -v systemctl >/dev/null 2>&1; then
        systemctl daemon-reload
    fi


    # 2. 删除旧的二进制文件
    echo "清理旧的二进制程序..."
    for bin_path in "${binary_paths[@]}"; do
        if [ -f "$bin_path" ]; then
            echo "    - 删除二进制文件: $bin_path"
            rm -f "$bin_path"
        fi
    done


    # 3. 清理可能存在的进程
    echo "终止残留进程..."
    for p_name in "${process_names[@]}"; do
        if pgrep -f "$p_name" >/dev/null; then # 使用 -f 全匹配路径，更精确
            echo "    - 终止残留进程: $p_name"
            pkill -f "$p_name"
            sleep 1 # 等待进程终止
            if pgrep -f "$p_name" >/dev/null; then # 再次检查是否已经终止
                echo "      警告: 进程 $p_name 未能完全终止，尝试强制终止..."
                pkill -9 -f "$p_name"
            fi
        fi
    done


    # 4. 清理PID文件
    echo "清理PID文件..."
    for pid_file in "${pid_files[@]}"; do
        if [ -f "$pid_file" ]; then
            echo "    - 删除PID文件: $pid_file"
            rm -f "$pid_file"
        fi
    done

    echo "清理完成。"
}


# 在开始安装前执行清理
cleanup_old_installation

# 第一步: 判断系统并初始化环境
echo "正在检测操作系统并初始化环境..."

SERVICE_MANAGER=""    # 记录服务管理器类型
OS_ARCH="$(uname -m)" # 获取CPU架构
LIBC_TYPE="gnu"       # 默认为glibc系统
SS_RUST_URL=""        # Shadowsocks-rust 下载链接

# 首先检测服务管理器类型
if command -v systemctl >/dev/null 2>&1; then
    SERVICE_MANAGER="systemd"
elif command -v rc-service >/dev/null 2>&1; then
    SERVICE_MANAGER="openrc"
else
    echo "未检测到支持的服务管理器（systemd/openrc）"
    exit 1
fi

# 然后检测具体的操作系统类型和 libc 类型，并设定下载链接
if grep -Eqi "centos|redhat|rhel" /etc/os-release; then
    OS="centos"
    echo "检测到 CentOS/RHEL 系统 (使用 $SERVICE_MANAGER)。"
    LIBC_TYPE="gnu" # CentOS/RHEL 使用 glibc
    SS_RUST_URL="https://github.com/shadowsocks/shadowsocks-rust/releases/download/v${SS_RUST_VERSION}/shadowsocks-v${SS_RUST_VERSION}.x86_64-unknown-linux-gnu.tar.xz"

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
        dnf install -y curl bash wget sudo tar gzip xz || {
            echo "安装依赖失败，请检查网络或权限。"
            exit 1
        }
    else
        yum install -y curl bash wget sudo tar gzip xz || {
            echo "安装依赖失败，请检查网络或权限。"
            exit 1
        }
    fi
elif grep -Eqi "debian" /etc/os-release; then
    OS="debian"
    echo "检测到 Debian 系统 (使用 $SERVICE_MANAGER)。"
    LIBC_TYPE="gnu" # Debian 使用 glibc
    SS_RUST_URL="https://github.com/shadowsocks/shadowsocks-rust/releases/download/v${SS_RUST_VERSION}/shadowsocks-v${SS_RUST_VERSION}.x86_64-unknown-linux-gnu.tar.xz"
    apt update && apt install -y curl bash wget sudo tar gzip xz-utils || {
        echo "安装依赖失败，请检查网络或权限。"
        exit 1
    }
elif grep -Eqi "ubuntu" /etc/os-release; then
    OS="ubuntu"
    echo "检测到 Ubuntu 系统 (使用 $SERVICE_MANAGER)。"
    LIBC_TYPE="gnu" # Ubuntu 使用 glibc
    SS_RUST_URL="https://github.com/shadowsocks/shadowsocks-rust/releases/download/v${SS_RUST_VERSION}/shadowsocks-v${SS_RUST_VERSION}.x86_64-unknown-linux-gnu.tar.xz"
    apt update && apt install -y curl bash wget sudo tar gzip xz-utils || {
        echo "安装依赖失败，请检查网络或权限。"
        exit 1
    }
elif grep -Eqi "alpine" /etc/os-release; then
    OS="alpine"
    echo "检测到 Alpine Linux 系统 (使用 $SERVICE_MANAGER)。"
    LIBC_TYPE="musl" # Alpine 使用 musl libc
    SS_RUST_URL="https://github.com/shadowsocks/shadowsocks-rust/releases/download/v${SS_RUST_VERSION}/shadowsocks-v${SS_RUST_VERSION}.x86_64-unknown-linux-musl.tar.xz"
    apk update && apk add curl bash wget sudo tar gzip xz openrc || {
        echo "安装依赖失败，请检查网络或权限。"
        exit 1
    }
else
    echo -e "${RED}警告：未识别的操作系统。假设使用 glibc 构建，但这可能不兼容。${NC}"
    LIBC_TYPE="gnu" # 默认假设为 glibc
    SS_RUST_URL="https://github.com/shadowsocks/shadowsocks-rust/releases/download/v${SS_RUST_VERSION}/shadowsocks-v${SS_RUST_VERSION}.x86_64-unknown-linux-gnu.tar.xz"
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

# 第二步: 下载 shadowsocks-rust 并解压到 /usr/local/bin/
echo "正在下载和解压 shadowsocks-rust..."

# 确保 SS_RUST_URL 在操作系统检测后已经被赋值
if [ -z "$SS_RUST_URL" ]; then
    echo -e "${RED}错误：无法确定适合当前操作系统的 shadowsocks-rust 下载链接。${NC}"
    exit 1
fi

DOWNLOAD_PATH="/tmp/shadowsocks-rust.tar.xz" # 统一临时文件名为固定值
INSTALL_DIR="/usr/local/bin"                 # ssserver 可执行文件最终路径

echo "下载地址: ${SS_RUST_URL}"

# 下载并解压
wget -O "$DOWNLOAD_PATH" "$SS_RUST_URL" || {
    echo -e "${RED}下载 shadowsocks-rust 失败，请检查网络或 URL (${SS_RUST_URL}) 是否正确。${NC}"
    exit 1
}

# 解压到临时目录，然后移动可执行文件
if ! mkdir -p "/tmp/shadowsocks-rust-unpack"; then
    echo -e "${RED}创建临时解压目录失败。${NC}"
    exit 1
fi

if ! tar -Jxf "$DOWNLOAD_PATH" -C "/tmp/shadowsocks-rust-unpack"; then
    echo -e "${RED}解压 shadowsocks-rust 失败。${NC}"
    rm -rf "/tmp/shadowsocks-rust-unpack" # 清理
    exit 1
fi

# 移动 ssserver 到安装目录
if ! mv "/tmp/shadowsocks-rust-unpack/ssserver" "$INSTALL_DIR/ssserver"; then
    echo -e "${RED}移动 ssserver 到 ${INSTALL_DIR} 失败。${NC}"
    rm -rf "/tmp/shadowsocks-rust-unpack" # 清理
    exit 1
fi

# 清理下载文件和临时目录
rm -f "$DOWNLOAD_PATH"
rm -rf "/tmp/shadowsocks-rust-unpack"

# 设置权限
chmod +x "$INSTALL_DIR/ssserver" || {
    echo -e "${RED}设置执行权限失败。${NC}"
    exit 1
}

# 如果是CentOS系统，设置SELinux上下文
if [ "$OS" = "centos" ] && command -v chcon >/dev/null 2>&1; then
    echo "正在设置SELinux上下文..."
    chcon -t bin_t "$INSTALL_DIR/ssserver" >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "SELinux上下文设置成功"
    else
        echo "警告：SELinux上下文设置失败，如果SELinux未完全禁用，可能会导致权限问题"
    fi
fi

echo "shadowsocks-rust (ssserver) 已成功安装到 ${INSTALL_DIR}/ssserver。"

# 第三步: 根据不同的服务管理器创建服务并设置开机自启
echo "正在创建服务配置文件并设置开机自启..."

if [ "$SERVICE_MANAGER" = "systemd" ]; then
    SERVICE_FILE="/etc/systemd/system/shadowsocks-rust.service"

    # 清理已存在的服务
    if systemctl list-unit-files | grep -q "shadowsocks-rust.service"; then
        echo "检测到已存在的 shadowsocks-rust 服务，正在清理..."
        systemctl stop shadowsocks-rust >/dev/null 2>&1
        systemctl disable shadowsocks-rust >/dev/null 2>&1
        rm -f "$SERVICE_FILE"
        systemctl daemon-reload
    fi

    # 创建新服务
    cat >"$SERVICE_FILE" <<EOF
[Unit]
Description=Shadowsocks-rust Proxy Service
After=network.target
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=${INSTALL_DIR}/ssserver -s "[::]:${PORT}" -m "${METHOD}" -U -k "${PASSWD}"
StandardError=append:/var/log/shadowsocks-rust.error.log
Restart=always
RestartSec=3
User=root
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable shadowsocks-rust || {
        echo -e "${RED}启用 shadowsocks-rust 服务失败，请检查权限。${NC}"
        exit 1
    }
    systemctl restart shadowsocks-rust || {
        echo -e "${RED}启动 shadowsocks-rust 服务失败，请检查配置。${NC}"
        exit 1
    }
    echo "shadowsocks-rust.service (Systemd) 已成功创建、启动并设置开机自启。"
elif [ "$SERVICE_MANAGER" = "openrc" ]; then
    SERVICE_FILE="/etc/init.d/shadowsocks-rust"

    # 清理已存在的服务
    if [ -f "$SERVICE_FILE" ]; then
        echo "检测到已存在的 shadowsocks-rust 服务，正在清理..."
        rc-service shadowsocks-rust stop >/dev/null 2>&1
        rc-update del shadowsocks-rust default >/dev/null 2>&1
        rm -f "$SERVICE_FILE"
    fi

    # 创建新服务
    # 确保所需目录存在
    mkdir -p /var/log

    cat >"$SERVICE_FILE" <<EOF
#!/sbin/openrc-run

name="shadowsocks-rust"
description="Shadowsocks-rust proxy service"
command="${INSTALL_DIR}/ssserver"
command_args="-s \"[::]:${PORT}\" -m \"${METHOD}\" -U -k \"${PASSWD}\""
command_background="yes"
pidfile="/run/shadowsocks-rust.pid"
output_log="/var/log/shadowsocks-rust.error.log"
error_log="/var/log/shadowsocks-rust.error.log"
directory="${INSTALL_DIR}"

depend() {
    need net
    after net
}

start_pre() {
    # 确保日志文件存在并设置权限
    touch "/var/log/shadowsocks-rust.error.log"
    chown root:root "/var/log/shadowsocks-rust.error.log"
    chmod 644 "/var/log/shadowsocks-rust.error.log"
}

EOF
    chmod +x "$SERVICE_FILE"
    rc-update add shadowsocks-rust default
    rc-service shadowsocks-rust restart
    echo "shadowsocks-rust (OpenRC) 已成功创建、启动并设置开机自启。"
else
    echo "未知服务管理器类型，无法设置开机自启。"
    exit 1
fi

echo "配置信息:"
echo "	端口: $PORT"
echo "	密码: $PASSWD"
echo "	方法: $METHOD"
echo "	Shadowsocks-rust 版本: $SS_RUST_VERSION"

# 等待服务启动完全（给服务一些启动时间）
sleep 2

echo -e "\n端口监听状态:"
netstat -tnlp | grep ssserver || ss -tnlp | grep ssserver

echo -e "\n进程状态:"
ps aux | grep -v grep | grep ssserver

echo -e "\n服务状态:"
if [ "$SERVICE_MANAGER" = "systemd" ]; then
    # 显示服务状态，使用 --no-pager 选项并限制输出行数
    systemctl status shadowsocks-rust --no-pager -n 15
    # 等待3秒
    sleep 3

    echo -e "\n=== 常用命令说明 ==="
    echo "0) 查看服务状态:"
    echo "   systemctl status shadowsocks-rust"
    echo "1) 查看实时日志:"
    echo "   journalctl -f -u shadowsocks-rust.service"
    echo "   或者"
    echo "   tail -f /var/log/shadowsocks-rust.error.log"

    echo "2) 重启服务:"
    echo "   systemctl restart shadowsocks-rust"
    echo "3) 停止服务:"
    echo "   systemctl stop shadowsocks-rust"
    echo "4) 查看进程:"
    echo "   ps aux | grep -v grep | grep ssserver"
elif [ "$SERVICE_MANAGER" = "openrc" ]; then
    rc-service shadowsocks-rust status
    # 等待3秒
    sleep 3

    echo -e "\n=== 常用命令说明 ==="
    echo "0) 查看服务状态:"
    echo "   rc-service shadowsocks-rust status"

    echo "1) 查看实时日志:"
    echo "   tail -f /var/log/shadowsocks-rust.error.log"

    echo "2) 查看进程:"
    echo "   ps aux | grep -v grep | grep ssserver"

    echo "3) 重启服务:"
    echo "   rc-service shadowsocks-rust restart"
    echo "4) 停止服务:"
    echo "   rc-service shadowsocks-rust stop"
fi
