#!/bin/bash

# 自动修改SSH端口脚本
# 使用方法: ./changesshport.sh {PORT} 或 sh changesshport.sh {PORT}

# 检查是否提供了端口号
if [ -z "$1" ]; then
    echo "错误: 请提供端口号"
    echo "使用方法: $0 {PORT}"
    exit 1
fi

SSH_PORT=$1

# 验证端口号是否合法
if ! [[ "$SSH_PORT" =~ ^[0-9]+$ ]] || [ "$SSH_PORT" -lt 1 ] || [ "$SSH_PORT" -gt 65535 ]; then
    echo "错误: 端口号必须是1-65535之间的数字"
    exit 1
fi

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
echo "正在修改SSH端口为: $SSH_PORT"

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
sed -i "s/^#*Port [0-9]*/Port $SSH_PORT/" /etc/ssh/sshd_config

# 如果没有找到Port配置行，则添加
if ! grep -q "^Port " /etc/ssh/sshd_config; then
    echo "Port $SSH_PORT" >> /etc/ssh/sshd_config
fi

# 根据系统类型执行相应操作
case "$OS_TYPE" in
    centos)
        echo "CentOS/RedHat系统处理中..."
        
        # 安装SELinux管理工具（如果未安装）
        if ! command -v semanage &> /dev/null; then
            yum install -y policycoreutils-python-utils
        fi
        
        # SELinux设置
        if command -v semanage &> /dev/null; then
            echo "配置SELinux允许新端口..."
            semanage port -a -t ssh_port_t -p tcp $SSH_PORT 2>/dev/null || \
            semanage port -m -t ssh_port_t -p tcp $SSH_PORT
        fi
        
        # 防火墙设置
        if command -v firewall-cmd &> /dev/null; then
            echo "配置firewalld防火墙..."
            firewall-cmd --permanent --add-port=$SSH_PORT/tcp
            firewall-cmd --reload
        elif command -v iptables &> /dev/null; then
            echo "配置iptables防火墙..."
            iptables -I INPUT -p tcp --dport $SSH_PORT -j ACCEPT
            service iptables save
        fi
        
        # 重启SSH服务
        systemctl restart sshd
        ;;
        
    ubuntu)
        echo "Ubuntu/Debian系统处理中..."
        
        # 防火墙设置
        if command -v ufw &> /dev/null; then
            echo "配置UFW防火墙..."
            ufw allow $SSH_PORT/tcp
        elif command -v iptables &> /dev/null; then
            echo "配置iptables防火墙..."
            iptables -I INPUT -p tcp --dport $SSH_PORT -j ACCEPT
            iptables-save > /etc/iptables/rules.v4
        fi
        
        # 重启SSH服务
        systemctl restart ssh
        ;;
        
    alpine)
        echo "Alpine系统处理中..."
        
        # 防火墙设置 (Alpine使用nftables)
        if command -v nft &> /dev/null; then
            echo "配置nftables防火墙..."
            nft add rule inet filter input tcp dport $SSH_PORT accept
        elif command -v iptables &> /dev/null; then
            echo "配置iptables防火墙..."
            iptables -I INPUT -p tcp --dport $SSH_PORT -j ACCEPT
        fi
        
        # 重启SSH服务
        rc-service sshd restart
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
