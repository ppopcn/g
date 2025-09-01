#!/bin/bash

# 颜色定义
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 脚本版本
VERSION="1.0.0"

# 全局变量
SELECTED_IMPLEMENTATION=""
SELECTED_MODE=""
CUSTOM_PORT=""
CUSTOM_PASSWD=""
CUSTOM_METHOD=""

# 显示欢迎界面
show_welcome() {
    clear
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}   Shadowsocks 一键部署集成脚本 v${VERSION}${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo -e ""
    echo -e "${GREEN}支持三种实现方式：${NC}"
    echo -e "  • GOST - 多协议代理工具"
    echo -e "  • go-shadowsocks2 - Go语言实现"
    echo -e "  • shadowsocks-rust - Rust语言实现"
    echo -e ""
    echo -e "${YELLOW}注意：如果您在使用云服务器，请确保在云服务商控制面板中已设置安全组规则，放行相应端口。${NC}"
    echo -e ""
}

# 第一个交互界面：选择实现方式
select_implementation() {
    echo -e "${BLUE}=== 步骤 1/3：选择代理实现方式 ===${NC}"
    echo -e ""
    echo -e "${GREEN}1. GOST${NC}"
    echo -e "   • 多协议支持 (SS + SSU)"
    echo -e "   • 版本: v3.2.3"
    echo -e "   • 特点: 功能丰富，性能优秀"
    echo -e ""
    echo -e "${GREEN}2. go-shadowsocks2${NC}"
    echo -e "   • 纯Go实现"
    echo -e "   • 版本: v0.1.5"
    echo -e "   • 特点: 轻量级，兼容性好"
    echo -e ""
    echo -e "${GREEN}3. shadowsocks-rust${NC}"
    echo -e "   • Rust实现"
    echo -e "   • 版本: v1.23.5"
    echo -e "   • 特点: 高性能，内存安全"
    echo -e ""
    echo -e "${RED}4. 退出脚本${NC}"
    echo -e ""
    
    while true; do
        read -p "请选择实现方式 [1-4]: " choice
        case $choice in
            1)
                SELECTED_IMPLEMENTATION="gost"
                echo -e "${GREEN}已选择: GOST${NC}"
                break
                ;;
            2)
                SELECTED_IMPLEMENTATION="go-shadowsocks2"
                echo -e "${GREEN}已选择: go-shadowsocks2${NC}"
                break
                ;;
            3)
                SELECTED_IMPLEMENTATION="shadowsocks-rust"
                echo -e "${GREEN}已选择: shadowsocks-rust${NC}"
                break
                ;;
            4)
                echo -e "${YELLOW}感谢使用，再见！${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}无效的选择，请输入 1-4${NC}"
                ;;
        esac
    done
    sleep 1
}

# 第二个交互界面：选择配置模式
select_config_mode() {
    clear
    echo -e "${BLUE}=== 步骤 2/3：选择配置模式 ===${NC}"
    echo -e ""
    echo -e "已选择实现方式: ${GREEN}${SELECTED_IMPLEMENTATION}${NC}"
    echo -e ""
    echo -e "${GREEN}1. 使用默认配置 [推荐]${NC}"
    echo -e "   • 端口: 8989"
    echo -e "   • 密码: qwe123"
    echo -e "   • 加密方式: aes-256-gcm"
    echo -e ""
    echo -e "${GREEN}2. 手动输入配置${NC}"
    echo -e "   • 自定义端口、密码和加密方式"
    echo -e ""
    echo -e "${RED}3. 返回上一步${NC}"
    echo -e ""
    
    while true; do
        read -p "请选择配置模式 [1-3]: " choice
        case $choice in
            1)
                SELECTED_MODE="default"
                echo -e "${GREEN}已选择: 默认配置${NC}"
                break
                ;;
            2)
                SELECTED_MODE="custom"
                echo -e "${GREEN}已选择: 手动输入配置${NC}"
                break
                ;;
            3)
                show_welcome
                select_implementation
                select_config_mode
                return
                ;;
            *)
                echo -e "${RED}无效的选择，请输入 1-3${NC}"
                ;;
        esac
    done
    sleep 1
}

# 显示加密方法选项
show_encryption_methods() {
    case $SELECTED_IMPLEMENTATION in
        "gost")
            echo -e "${CYAN}GOST 支持的加密方法：${NC}"
            echo -e "${GREEN}AEAD 加密方法 (推荐):${NC}"
            echo -e "  1. aes-128-gcm"
            echo -e "  2. aes-256-gcm ${YELLOW}[默认]${NC}"
            echo -e "  3. chacha20-ietf-poly1305"
            echo -e "  4. xchacha20-ietf-poly1305"
            echo -e ""
            echo -e "${GREEN}Shadowsocks 2022 方法:${NC}"
            echo -e "  5. 2022-blake3-aes-128-gcm"
            echo -e "  6. 2022-blake3-aes-256-gcm"
            echo -e "  7. 2022-blake3-chacha20-poly1305"
            ;;
        "go-shadowsocks2")
            echo -e "${CYAN}go-shadowsocks2 支持的加密方法：${NC}"
            echo -e "${GREEN}AEAD 加密方法:${NC}"
            echo -e "  1. aes-128-gcm"
            echo -e "  2. aes-256-gcm ${YELLOW}[默认]${NC}"
            echo -e "  3. chacha20-ietf-poly1305"
            echo -e "  4. xchacha20-ietf-poly1305"
            ;;
        "shadowsocks-rust")
            echo -e "${CYAN}shadowsocks-rust 支持的加密方法：${NC}"
            echo -e "${GREEN}AEAD 加密方法:${NC}"
            echo -e "  1. aes-128-gcm"
            echo -e "  2. aes-256-gcm ${YELLOW}[默认]${NC}"
            echo -e "  3. chacha20-ietf-poly1305"
            echo -e "  4. xchacha20-ietf-poly1305"
            echo -e ""
            echo -e "${GREEN}Shadowsocks 2022 方法:${NC}"
            echo -e "  5. 2022-blake3-aes-128-gcm"
            echo -e "  6. 2022-blake3-aes-256-gcm"
            echo -e "  7. 2022-blake3-chacha20-poly1305"
            echo -e ""
            echo -e "${GREEN}其他方法:${NC}"
            echo -e "  8. none (无加密)"
            echo -e "  9. plain (明文)"
            ;;
    esac
}

# 获取加密方法
get_encryption_method() {
    show_encryption_methods
    echo -e ""
    
    while true; do
        read -p "请选择加密方法编号 (直接回车使用默认 aes-256-gcm): " method_choice
        
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
                    *) echo -e "${RED}无效的选择，请输入 1-7${NC}" ;;
                esac
                ;;
            "go-shadowsocks2")
                case $method_choice in
                    1) CUSTOM_METHOD="aes-128-gcm"; break ;;
                    2) CUSTOM_METHOD="aes-256-gcm"; break ;;
                    3) CUSTOM_METHOD="chacha20-ietf-poly1305"; break ;;
                    4) CUSTOM_METHOD="xchacha20-ietf-poly1305"; break ;;
                    *) echo -e "${RED}无效的选择，请输入 1-4${NC}" ;;
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
                    *) echo -e "${RED}无效的选择，请输入 1-9${NC}" ;;
                esac
                ;;
        esac
    done
}

# 第三个交互界面：自定义配置
custom_configuration() {
    clear
    echo -e "${BLUE}=== 步骤 3/3：自定义配置 ===${NC}"
    echo -e ""
    echo -e "已选择实现方式: ${GREEN}${SELECTED_IMPLEMENTATION}${NC}"
    echo -e ""
    
    # 输入端口
    while true; do
        read -p "请输入端口号 (1-65535，直接回车使用默认 8989): " port_input
        if [ -z "$port_input" ]; then
            CUSTOM_PORT="8989"
            break
        elif [[ "$port_input" =~ ^[0-9]+$ ]] && [ "$port_input" -ge 1 ] && [ "$port_input" -le 65535 ]; then
            CUSTOM_PORT="$port_input"
            break
        else
            echo -e "${RED}无效的端口号，请输入 1-65535 之间的数字${NC}"
        fi
    done
    
    echo -e "${GREEN}端口设置为: $CUSTOM_PORT${NC}"
    echo -e ""
    
    # 输入密码
    while true; do
        read -p "请输入密码 (直接回车使用默认 qwe123): " passwd_input
        if [ -z "$passwd_input" ]; then
            CUSTOM_PASSWD="qwe123"
            break
        elif [ ${#passwd_input} -ge 4 ]; then
            CUSTOM_PASSWD="$passwd_input"
            break
        else
            echo -e "${RED}密码长度至少为4个字符${NC}"
        fi
    done
    
    echo -e "${GREEN}密码设置为: $CUSTOM_PASSWD${NC}"
    echo -e ""
    
    # 选择加密方法
    get_encryption_method
    echo -e "${GREEN}加密方法设置为: $CUSTOM_METHOD${NC}"
    echo -e ""
}

# 显示配置摘要
show_configuration_summary() {
    clear
    echo -e "${BLUE}=== 配置摘要 ===${NC}"
    echo -e ""
    echo -e "实现方式: ${GREEN}${SELECTED_IMPLEMENTATION}${NC}"
    echo -e "配置模式: ${GREEN}${SELECTED_MODE}${NC}"
    
    if [ "$SELECTED_MODE" = "default" ]; then
        echo -e "端口: ${GREEN}8989${NC}"
        echo -e "密码: ${GREEN}qwe123${NC}"
        echo -e "加密方式: ${GREEN}aes-256-gcm${NC}"
    else
        echo -e "端口: ${GREEN}${CUSTOM_PORT}${NC}"
        echo -e "密码: ${GREEN}${CUSTOM_PASSWD}${NC}"
        echo -e "加密方式: ${GREEN}${CUSTOM_METHOD}${NC}"
    fi
    
    echo -e ""
    echo -e "${YELLOW}确认以上配置并开始安装？${NC}"
    echo -e ""
    echo -e "${GREEN}1. 确认并开始安装${NC}"
    echo -e "${RED}2. 重新配置${NC}"
    echo -e "${RED}3. 退出脚本${NC}"
    echo -e ""
    
    while true; do
        read -p "请选择 [1-3]: " choice
        case $choice in
            1)
                echo -e "${GREEN}开始安装...${NC}"
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
                echo -e "${YELLOW}感谢使用，再见！${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}无效的选择，请输入 1-3${NC}"
                ;;
        esac
    done
}

# 执行安装
execute_installation() {
    echo -e ""
    echo -e "${CYAN}======================================${NC}"
    echo -e "${CYAN}  开始安装 ${SELECTED_IMPLEMENTATION}${NC}"
    echo -e "${CYAN}======================================${NC}"
    echo -e ""
    
    # 构建命令参数
    if [ "$SELECTED_MODE" = "default" ]; then
        # 使用默认配置
        case $SELECTED_IMPLEMENTATION in
            "gost")
                echo -e "${GREEN}执行命令: sh g.sh${NC}"
                sh g.sh
                ;;
            "go-shadowsocks2")
                echo -e "${GREEN}执行命令: sh s.sh${NC}"
                sh s.sh
                ;;
            "shadowsocks-rust")
                echo -e "${GREEN}执行命令: sh ssr.sh${NC}"
                sh ssr.sh
                ;;
        esac
    else
        # 使用自定义配置
        case $SELECTED_IMPLEMENTATION in
            "gost")
                echo -e "${GREEN}执行命令: sh g.sh -port ${CUSTOM_PORT} -passwd ${CUSTOM_PASSWD} -method ${CUSTOM_METHOD}${NC}"
                sh g.sh -port "${CUSTOM_PORT}" -passwd "${CUSTOM_PASSWD}" -method "${CUSTOM_METHOD}"
                ;;
            "go-shadowsocks2")
                echo -e "${GREEN}执行命令: sh s.sh -port ${CUSTOM_PORT} -passwd ${CUSTOM_PASSWD} -method ${CUSTOM_METHOD}${NC}"
                sh s.sh -port "${CUSTOM_PORT}" -passwd "${CUSTOM_PASSWD}" -method "${CUSTOM_METHOD}"
                ;;
            "shadowsocks-rust")
                echo -e "${GREEN}执行命令: sh ssr.sh -port ${CUSTOM_PORT} -passwd ${CUSTOM_PASSWD} -method ${CUSTOM_METHOD}${NC}"
                sh ssr.sh -port "${CUSTOM_PORT}" -passwd "${CUSTOM_PASSWD}" -method "${CUSTOM_METHOD}"
                ;;
        esac
    fi
    
    echo -e ""
    echo -e "${CYAN}======================================${NC}"
    echo -e "${CYAN}  安装完成！${NC}"
    echo -e "${CYAN}======================================${NC}"
}

# 检查依赖脚本
check_dependencies() {
    local missing_scripts=()
    
    if [ ! -f "g.sh" ]; then
        missing_scripts+=("g.sh")
    fi
    
    if [ ! -f "s.sh" ]; then
        missing_scripts+=("s.sh")
    fi
    
    if [ ! -f "ssr.sh" ]; then
        missing_scripts+=("ssr.sh")
    fi
    
    if [ ${#missing_scripts[@]} -gt 0 ]; then
        echo -e "${RED}错误：缺少必要的脚本文件！${NC}"
        echo -e "${RED}缺少的文件: ${missing_scripts[*]}${NC}"
        echo -e ""
        echo -e "${YELLOW}请确保以下文件存在于当前目录：${NC}"
        echo -e "  • g.sh (GOST 安装脚本)"
        echo -e "  • s.sh (go-shadowsocks2 安装脚本)"
        echo -e "  • ssr.sh (shadowsocks-rust 安装脚本)"
        echo -e ""
        exit 1
    fi
}

# 主函数
main() {
    # 检查依赖
    check_dependencies
    
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