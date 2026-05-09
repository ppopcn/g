#!/bin/sh

# 自动修改SSH端口脚本（POSIX兼容）
# 使用方法: curl -fsSL https://raw.githubusercontent.com/ppopcn/g/refs/heads/main/changesshport.sh | bash

# 交互式输入端口号
echo "请输入要修改的SSH端口号 (1-65535):"
read SSH_PORT

# 验证端口号是否合法
if [ -z "$SSH_PORT" ]; then
    echo "错误: 未输入端口号"
    exit 1
fi

case "$SSH_PORT" in
    ''|*[!0-9]*)
        echo "错误: 端口号必须是1-65535之间的数字"
        exit 1
        ;;
    *)
        if [ "$SSH_PORT" -lt 1 ] || [ "$SSH_PORT" -gt 65535 ]; then
            echo "错误: 端口号必须是1-65535之间的数字"
            exit 1
        fi
        ;;
esac

# 检测系统类型
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            centos|rhel|rocky|almalinux)
                echo "centos"
                ;;
            ubuntu|debian)
                echo "ubuntu"
                ;;
            alpine)
                echo "alpine"
                ;;
            *)
                echo "unknown"
                ;;
        esac
    elif [ -f /etc/redhat-release ]; then
        echo "centos"
    elif [ -f /etc/alpine-release ]; then
        echo "alpine"
    else
        echo "unknown"
    fi
}

OS_TYPE=$(detect_os)

echo "检测到系统类型: $OS_TYPE"
echo "将修改SSH端口为: $SSH_PORT"
echo ""
echo "按回车键确认并继续，或按 Ctrl+C 取消..."
read confirm

# 初始化系统：安装基础组件
echo "初始化系统：安装基础组件..."

case "$OS_TYPE" in
    centos)
        # CentOS/RHEL系列基础组件
        if command -v yum >/dev/null 2>&1; then
            yum install -y bash curl wget net-tools iproute 2>/dev/null
        elif command -v dnf >/dev/null 2>&1; then
            dnf install -y bash curl wget net-tools iproute2 2>/dev/null
        fi
        ;;
        
    ubuntu|debian)
        # Ubuntu/Debian系列基础组件
        if command -v apt-get >/dev/null 2>&1; then
            echo "更新apt包索引..."
            DEBIAN_FRONTEND=noninteractive apt-get update -qq 2>/dev/null
            echo "安装基础组件..."
            DEBIAN_FRONTEND=noninteractive apt-get install -y -qq curl wget bash sudo net-tools iproute2 2>/dev/null
        fi
        ;;
        
    alpine)
        # Alpine系列基础组件
        if command -v apk >/dev/null 2>&1; then
            apk add --no-cache bash curl wget net-tools iproute2 2>/dev/null
        fi
        ;;
esac

echo "基础组件安装完成"

# 备份SSH配置文件
echo "备份SSH配置文件..."
if [ -f /etc/ssh/sshd_config ]; then
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
else
    echo "错误: 找不到SSH配置文件 /etc/ssh/sshd_config"
    exit 1
fi

# 修改SSH配置文件
echo "修改SSH配置..."
if grep -q "^Port " /etc/ssh/sshd_config; then
    sed -i "s/^Port .*/Port $SSH_PORT/" /etc/ssh/sshd_config
else
    if grep -q "^#Port " /etc/ssh/sshd_config; then
        sed -i "s/^#Port .*/Port $SSH_PORT/" /etc/ssh/sshd_config
    else
        echo "Port $SSH_PORT" >> /etc/ssh/sshd_config
    fi
fi

# 根据系统类型执行相应操作
case "$OS_TYPE" in
    centos)
        echo "CentOS/RedHat系统处理中..."
        
        # 禁用SELinux
        echo "禁用SELinux..."
        setenforce 0 2>/dev/null
        if [ -f /etc/selinux/config ]; then
            sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config 2>/dev/null
        fi
        
        # 防火墙设置 - 优先使用firewalld
        if command -v firewall-cmd >/dev/null 2>&1; then
            echo "配置firewalld防火墙..."
            firewall-cmd --permanent --add-port="$SSH_PORT"/tcp 2>/dev/null
            firewall-cmd --reload 2>/dev/null
        elif command -v iptables >/dev/null 2>&1; then
            echo "配置iptables防火墙..."
            iptables -I INPUT -p tcp --dport "$SSH_PORT" -j ACCEPT 2>/dev/null
            service iptables save 2>/dev/null || iptables-save > /etc/sysconfig/iptables 2>/dev/null
        fi
        
        # 重启SSH服务
        if command -v systemctl >/dev/null 2>&1; then
            systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null
        elif command -v service >/dev/null 2>&1; then
            service sshd restart 2>/dev/null || service ssh restart 2>/dev/null
        fi
        ;;
        
    ubuntu)
        echo "Ubuntu/Debian系统处理中..."
        
        # 防火墙设置 - 优先使用UFW
        if command -v ufw >/dev/null 2>&1; then
            echo "配置UFW防火墙..."
            ufw allow "$SSH_PORT"/tcp 2>/dev/null
        elif command -v iptables >/dev/null 2>&1; then
            echo "配置iptables防火墙..."
            iptables -I INPUT -p tcp --dport "$SSH_PORT" -j ACCEPT 2>/dev/null
            if [ -f /etc/iptables/rules.v4 ]; then
                iptables-save > /etc/iptables/rules.v4 2>/dev/null
            fi
        fi
        
        # 重启SSH服务
        if command -v systemctl >/dev/null 2>&1; then
            systemctl restart ssh 2>/dev/null
        elif command -v service >/dev/null 2>&1; then
            service ssh restart 2>/dev/null
        fi
        ;;
        
    alpine)
        echo "Alpine系统处理中..."
        
        # 防火墙设置 - Alpine使用nftables或iptables
        if command -v nft >/dev/null 2>&1; then
            echo "配置nftables防火墙..."
            nft add rule inet filter input tcp dport "$SSH_PORT" accept 2>/dev/null
            # 保存规则
            nft list ruleset > /etc/nftables.conf 2>/dev/null
        elif command -v iptables >/dev/null 2>&1; then
            echo "配置iptables防火墙..."
            iptables -I INPUT -p tcp --dport "$SSH_PORT" -j ACCEPT 2>/dev/null
            # 安装iptables-save工具（如果未安装）
            if ! command -v iptables-save >/dev/null 2>&1; then
                apk add --no-cache iptables 2>/dev/null
            fi
            iptables-save > /etc/iptables.rules 2>/dev/null
        fi
        
        # 重启SSH服务
        if command -v rc-service >/dev/null 2>&1; then
            rc-service sshd restart 2>/dev/null
        elif command -v service >/dev/null 2>&1; then
            service sshd restart 2>/dev/null
        fi
        ;;
        
    *)
        echo "错误: 不支持的系统类型"
        exit 1
        ;;
esac

echo "================================"
echo "SSH端口修改完成！"
echo "新端口: $SSH_PORT"
echo "配置文件已备份到: /etc/ssh/sshd_config.bak"
echo "================================"
echo ""
echo "提示: 请使用新端口重新连接SSH:"
echo "ssh -p $SSH_PORT user@hostname"
echo ""
echo "如遇问题，可使用备份文件恢复:"
echo "cp /etc/ssh/sshd_config.bak /etc/ssh/sshd_config"
