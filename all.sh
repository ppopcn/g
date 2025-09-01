#!/bin/sh

# 脚本版本
VERSION="1.2.0"

# 全局变量
SELECTED_IMPLEMENTATION=""
SELECTED_MODE=""
CUSTOM_PORT=""
CUSTOM_PASSWD=""
CUSTOM_METHOD=""

# 显示欢迎界面
show_welcome() {
    clear
    echo "========================================"
    echo "   Shadowsocks 一键部署集成脚本 v${VERSION}"
    echo "========================================"
    echo ""
    echo "支持三种实现方式："
    echo "  • GOST - 多协议代理工具"
    echo "  • go-shadowsocks2 - Go语言实现"
    echo "  • shadowsocks-rust - Rust语言实现"
    echo ""
    echo "系统要求：需要 bash 支持（会自动检查）"
    echo "注意：如果您在使用云服务器，请确保在云服务商控制面板中已设置安全组规则，放行相应端口。"
    echo ""
}

# 第一个交互界面：选择实现方式
select_implementation() {
    echo "=== 步骤 1/3：选择代理实现方式 ==="
    echo ""
    echo "1. GOST"
    echo "   • 多协议支持 (SS + SSU)"
    echo "   • 版本: v3.2.3"
    echo "   • 特点: 功能丰富，性能优秀"
    echo ""
    echo "2. go-shadowsocks2"
    echo "   • 纯Go实现"
    echo "   • 版本: v0.1.5"
    echo "   • 特点: 轻量级，兼容性好"
    echo ""
    echo "3. shadowsocks-rust"
    echo "   • Rust实现"
    echo "   • 版本: v1.23.5"
    echo "   • 特点: 高性能，内存安全"
    echo ""
    echo "4. 退出脚本"
    echo ""
    
    while true; do
        printf "请选择实现方式 [1-4]: "
        read choice
        case $choice in
            1)
                SELECTED_IMPLEMENTATION="gost"
                echo "已选择: GOST"
                break
                ;;
            2)
                SELECTED_IMPLEMENTATION="go-shadowsocks2"
                echo "已选择: go-shadowsocks2"
                break
                ;;
            3)
                SELECTED_IMPLEMENTATION="shadowsocks-rust"
                echo "已选择: shadowsocks-rust"
                break
                ;;
            4)
                echo "感谢使用，再见！"
                exit 0
                ;;
            *)
                echo "无效的选择，请输入 1-4"
                ;;
        esac
    done
    sleep 1
}

# 第二个交互界面：选择配置模式
select_config_mode() {
    clear
    echo "=== 步骤 2/3：选择配置模式 ==="
    echo ""
    echo "已选择实现方式: ${SELECTED_IMPLEMENTATION}"
    echo ""
    echo "1. 使用默认配置 [推荐]"
    echo "   • 端口: 8989"
    echo "   • 密码: qwe123"
    echo "   • 加密方式: aes-256-gcm"
    echo ""
    echo "2. 手动输入配置"
    echo "   • 自定义端口、密码和加密方式"
    echo ""
    echo "3. 返回上一步"
    echo ""
    
    while true; do
        printf "请选择配置模式 [1-3]: "
        read choice
        case $choice in
            1)
                SELECTED_MODE="default"
                echo "已选择: 默认配置"
                break
                ;;
            2)
                SELECTED_MODE="custom"
                echo "已选择: 手动输入配置"
                break
                ;;
            3)
                show_welcome
                select_implementation
                select_config_mode
                return
                ;;
            *)
                echo "无效的选择，请输入 1-3"
                ;;
        esac
    done
    sleep 1
}

# 显示加密方法选项
show_encryption_methods() {
    case $SELECTED_IMPLEMENTATION in
        "gost")
            echo "GOST 支持的加密方法："
            echo "AEAD 加密方法 (推荐):"
            echo "  1. aes-128-gcm"
            echo "  2. aes-256-gcm [默认]"
            echo "  3. chacha20-ietf-poly1305"
            echo "  4. xchacha20-ietf-poly1305"
            echo ""
            echo "Shadowsocks 2022 方法:"
            echo "  5. 2022-blake3-aes-128-gcm"
            echo "  6. 2022-blake3-aes-256-gcm"
            echo "  7. 2022-blake3-chacha20-poly1305"
            ;;
        "go-shadowsocks2")
            echo "go-shadowsocks2 支持的加密方法："
            echo "AEAD 加密方法:"
            echo "  1. aes-128-gcm"
            echo "  2. aes-256-gcm [默认]"
            echo "  3. chacha20-ietf-poly1305"
            echo "  4. xchacha20-ietf-poly1305"
            ;;
        "shadowsocks-rust")
            echo "shadowsocks-rust 支持的加密方法："
            echo "AEAD 加密方法:"
            echo "  1. aes-128-gcm"
            echo "  2. aes-256-gcm [默认]"
            echo "  3. chacha20-ietf-poly1305"
            echo "  4. xchacha20-ietf-poly1305"
            echo ""
            echo "Shadowsocks 2022 方法:"
            echo "  5. 2022-blake3-aes-128-gcm"
            echo "  6. 2022-blake3-aes-256-gcm"
            echo "  7. 2022-blake3-chacha20-poly1305"
            echo ""
            echo "其他方法:"
            echo "  8. none (无加密)"
            echo "  9. plain (明文)"
            ;;
    esac
}

# 获取加密方法
get_encryption_method() {
    show_encryption_methods
    echo ""
    
    while true; do
        printf "请选择加密方法编号 (直接回车使用默认 aes-256-gcm): "
        read method_choice
        
        # 如果用户直接回车，使用默认值
        if [ -z "$method_choice" ]; then
            CUSTOM_METHOD="aes-256-gcm"
            break
        fi
        
        case $SELECTED_IMPLEMENTATION in
            "gost")
                case $method_choice in
                    1) CUSTOM_METHOD="aes-128-gcm"; break ;;
                    2) CUSTOM_METHOD="aes-256-gcm"; break ;;
                    3) CUSTOM_METHOD="chacha20-ietf-poly1305"; break ;;
                    4) CUSTOM_METHOD="xchacha20-ietf-poly1305"; break ;;
                    5) CUSTOM_METHOD="2022-blake3-aes-128-gcm"; break ;;
                    6) CUSTOM_METHOD="2022-blake3-aes-256-gcm"; break ;;
                    7) CUSTOM_METHOD="2022-blake3-chacha20-poly1305"; break ;;
                    *) echo "无效的选择，请输入 1-7" ;;
                esac
                ;;
            "go-shadowsocks2")
                case $method_choice in
                    1) CUSTOM_METHOD="aes-128-gcm"; break ;;
                    2) CUSTOM_METHOD="aes-256-gcm"; break ;;
                    3) CUSTOM_METHOD="chacha20-ietf-poly1305"; break ;;
                    4) CUSTOM_METHOD="xchacha20-ietf-poly1305"; break ;;
                    *) echo "无效的选择，请输入 1-4" ;;
                esac
                ;;
            "shadowsocks-rust")
                case $method_choice in
                    1) CUSTOM_METHOD="aes-128-gcm"; break ;;
                    2) CUSTOM_METHOD="aes-256-gcm"; break ;;
                    3) CUSTOM_METHOD="chacha20-ietf-poly1305"; break ;;
                    4) CUSTOM_METHOD="xchacha20-ietf-poly1305"; break ;;
                    5) CUSTOM_METHOD="2022-blake3-aes-128-gcm"; break ;;
                    6) CUSTOM_METHOD="2022-blake3-aes-256-gcm"; break ;;
                    7) CUSTOM_METHOD="2022-blake3-chacha20-poly1305"; break ;;
                    8) CUSTOM_METHOD="none"; break ;;
                    9) CUSTOM_METHOD="plain"; break ;;
                    *) echo "无效的选择，请输入 1-9" ;;
                esac
                ;;
        esac
    done
}

# 第三个交互界面：自定义配置
custom_configuration() {
    clear
    echo "=== 步骤 3/3：自定义配置 ==="
    echo ""
    echo "已选择实现方式: ${SELECTED_IMPLEMENTATION}"
    echo ""
    
    # 输入端口
    while true; do
        printf "请输入端口号 (1-65535，直接回车使用默认 8989): "
        read port_input
        if [ -z "$port_input" ]; then
            CUSTOM_PORT="8989"
            break
        elif echo "$port_input" | grep -q '^[0-9]\+$' && [ "$port_input" -ge 1 ] && [ "$port_input" -le 65535 ]; then
            CUSTOM_PORT="$port_input"
            break
        else
            echo "无效的端口号，请输入 1-65535 之间的数字"
        fi
    done
    
    echo "端口设置为: $CUSTOM_PORT"
    echo ""
    
    # 输入密码
    while true; do
        printf "请输入密码 (直接回车使用默认 qwe123): "
        read passwd_input
        if [ -z "$passwd_input" ]; then
            CUSTOM_PASSWD="qwe123"
            break
        elif [ ${#passwd_input} -ge 4 ]; then
            CUSTOM_PASSWD="$passwd_input"
            break
        else
            echo "密码长度至少为4个字符"
        fi
    done
    
    echo "密码设置为: $CUSTOM_PASSWD"
    echo ""
    
    # 选择加密方法
    get_encryption_method
    echo "加密方法设置为: $CUSTOM_METHOD"
    echo ""
}

# 显示配置摘要
show_configuration_summary() {
    clear
    echo "=== 配置摘要 ==="
    echo ""
    echo "实现方式: ${SELECTED_IMPLEMENTATION}"
    echo "配置模式: ${SELECTED_MODE}"
    
    if [ "$SELECTED_MODE" = "default" ]; then
        echo "端口: 8989"
        echo "密码: qwe123"
        echo "加密方式: aes-256-gcm"
    else
        echo "端口: ${CUSTOM_PORT}"
        echo "密码: ${CUSTOM_PASSWD}"
        echo "加密方式: ${CUSTOM_METHOD}"
    fi
    
    echo ""
    echo "确认以上配置并开始安装？"
    echo ""
    echo "1. 确认并开始安装"
    echo "2. 重新配置"
    echo "3. 退出脚本"
    echo ""
    
    while true; do
        printf "请选择 [1-3]: "
        read choice
        case $choice in
            1)
                echo "开始安装..."
                break
                ;;
            2)
                show_welcome
                select_implementation
                select_config_mode
                if [ "$SELECTED_MODE" = "custom" ]; then
                    custom_configuration
                fi
                show_configuration_summary
                return
                ;;
            3)
                echo "感谢使用，再见！"
                exit 0
                ;;
            *)
                echo "无效的选择，请输入 1-3"
                ;;
        esac
    done
}

# 下载指定的脚本文件
download_script() {
    local script_name="$1"
    local script_url=""
    
    case "$script_name" in
        "gost")
            script_url="https://raw.githubusercontent.com/ppopcn/g/refs/heads/main/g.sh"
            ;;
        "go-shadowsocks2")
            script_url="https://raw.githubusercontent.com/ppopcn/g/refs/heads/main/s.sh"
            ;;
        "shadowsocks-rust")
            script_url="https://raw.githubusercontent.com/ppopcn/g/refs/heads/main/ssr.sh"
            ;;
        *)
            echo "错误：未知的脚本类型: $script_name"
            return 1
            ;;
    esac
    
    local file_name=""
    case "$script_name" in
        "gost") file_name="g.sh" ;;
        "go-shadowsocks2") file_name="s.sh" ;;
        "shadowsocks-rust") file_name="ssr.sh" ;;
    esac
    
    echo "正在下载 ${script_name} 脚本..."
    echo "下载地址: ${script_url}"
    
    # 检查是否有下载工具
    if command -v wget >/dev/null 2>&1; then
        if wget -O "$file_name" "$script_url"; then
            chmod +x "$file_name"
            echo "✓ $file_name 下载成功"
            return 0
        else
            echo "✗ wget 下载失败"
        fi
    elif command -v curl >/dev/null 2>&1; then
        if curl -L -o "$file_name" "$script_url"; then
            chmod +x "$file_name"
            echo "✓ $file_name 下载成功"
            return 0
        else
            echo "✗ curl 下载失败"
        fi
    else
        echo "错误：系统中未找到 wget 或 curl 下载工具"
        echo "请先安装下载工具："
        echo "  • Debian/Ubuntu: apt update && apt install -y wget curl"
        echo "  • CentOS/RHEL: yum install -y wget curl 或 dnf install -y wget curl"
        echo "  • Alpine: apk add wget curl"
        return 1
    fi
    
    echo "下载失败，请检查网络连接"
    return 1
}

# 执行安装
execute_installation() {
    echo ""
    echo "======================================"
    echo "  开始安装 ${SELECTED_IMPLEMENTATION}"
    echo "======================================"
    echo ""
    
    # 根据选择的实现方式确定需要的脚本文件
    local script_file=""
    case $SELECTED_IMPLEMENTATION in
        "gost")
            script_file="g.sh"
            ;;
        "go-shadowsocks2")
            script_file="s.sh"
            ;;
        "shadowsocks-rust")
            script_file="ssr.sh"
            ;;
    esac
    
    # 检查脚本文件是否存在，不存在则下载
    if [ ! -f "$script_file" ]; then
        echo "检测到 $script_file 不存在，正在自动下载..."
        echo ""
        
        if ! download_script "$SELECTED_IMPLEMENTATION"; then
            echo ""
            echo "下载失败，无法继续安装"
            echo "请检查："
            echo "  1. 网络连接是否正常"
            echo "  2. GitHub 是否可访问"
            echo "  3. 是否安装了 wget 或 curl"
            echo ""
            echo "您也可以手动下载脚本文件："
            case $SELECTED_IMPLEMENTATION in
                "gost")
                    echo "  wget https://raw.githubusercontent.com/ppopcn/g/refs/heads/main/g.sh"
                    ;;
                "go-shadowsocks2")
                    echo "  wget https://raw.githubusercontent.com/ppopcn/g/refs/heads/main/s.sh"
                    ;;
                "shadowsocks-rust")
                    echo "  wget https://raw.githubusercontent.com/ppopcn/g/refs/heads/main/ssr.sh"
                    ;;
            esac
            exit 1
        fi
        echo ""
    else
        echo "✓ 检测到 $script_file 已存在"
        echo ""
    fi
    
    # 构建命令参数
    if [ "$SELECTED_MODE" = "default" ]; then
        # 使用默认配置
        case $SELECTED_IMPLEMENTATION in
            "gost")
                echo "执行命令: bash g.sh"
                bash g.sh
                ;;
            "go-shadowsocks2")
                echo "执行命令: bash s.sh"
                bash s.sh
                ;;
            "shadowsocks-rust")
                echo "执行命令: bash ssr.sh"
                bash ssr.sh
                ;;
        esac
    else
        # 使用自定义配置
        case $SELECTED_IMPLEMENTATION in
            "gost")
                echo "执行命令: bash g.sh -port ${CUSTOM_PORT} -passwd ${CUSTOM_PASSWD} -method ${CUSTOM_METHOD}"
                bash g.sh -port "${CUSTOM_PORT}" -passwd "${CUSTOM_PASSWD}" -method "${CUSTOM_METHOD}"
                ;;
            "go-shadowsocks2")
                echo "执行命令: bash s.sh -port ${CUSTOM_PORT} -passwd ${CUSTOM_PASSWD} -method ${CUSTOM_METHOD}"
                bash s.sh -port "${CUSTOM_PORT}" -passwd "${CUSTOM_PASSWD}" -method "${CUSTOM_METHOD}"
                ;;
            "shadowsocks-rust")
                echo "执行命令: bash ssr.sh -port ${CUSTOM_PORT} -passwd ${CUSTOM_PASSWD} -method ${CUSTOM_METHOD}"
                bash ssr.sh -port "${CUSTOM_PORT}" -passwd "${CUSTOM_PASSWD}" -method "${CUSTOM_METHOD}"
                ;;
        esac
    fi
    
    echo ""
    echo "======================================"
    echo "  安装完成！"
    echo "======================================"
}

# 检查 bash 环境
check_bash_support() {
    if ! command -v bash >/dev/null 2>&1; then
        echo "错误：系统中未找到 bash"
        echo "请先安装 bash："
        echo "  • Debian/Ubuntu: apt update && apt install -y bash"
        echo "  • CentOS/RHEL: yum install -y bash 或 dnf install -y bash"
        echo "  • Alpine: apk add bash"
        exit 1
    fi
}

# 主函数
main() {
    # 检查 bash 环境
    check_bash_support
    # 显示欢迎界面
    show_welcome
    
    # 步骤1：选择实现方式
    select_implementation
    
    # 步骤2：选择配置模式
    select_config_mode
    
    # 步骤3：如果选择自定义配置，进入配置界面
    if [ "$SELECTED_MODE" = "custom" ]; then
        custom_configuration
    fi
    
    # 显示配置摘要并确认
    show_configuration_summary
    
    # 执行安装
    execute_installation
}

# 脚本入口
main "$@"