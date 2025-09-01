# Shadowsocks 一键部署脚本集合

支持的平台：debian/ubuntu/centos/alpine

## 🚀 快速开始 (推荐)

使用集成脚本，提供交互式界面：
```bash
sh all.sh
```

## 📋 单独使用各实现脚本

### GOST (多协议代理工具)
```bash
# 使用默认配置
sh g.sh

# 使用自定义配置
sh g.sh -port 8989 -passwd qwe123 -method aes-256-gcm
```

### go-shadowsocks2 (Go语言实现)
```bash
# 使用默认配置
sh s.sh

# 使用自定义配置
sh s.sh -port 8989 -passwd qwe123 -method aes-256-gcm
```

### shadowsocks-rust (Rust语言实现)
```bash
# 使用默认配置
sh ssr.sh

# 使用自定义配置
sh ssr.sh -port 8989 -passwd qwe123 -method aes-256-gcm
```

## 🔧 功能特性

- **多平台支持**: Debian、Ubuntu、CentOS、Alpine Linux
- **多种实现**: GOST、go-shadowsocks2、shadowsocks-rust
- **交互式配置**: 友好的菜单界面
- **自动化安装**: 一键部署，自动配置服务
- **安全优化**: 自动处理防火墙和SELinux
- **服务管理**: 支持 systemd 和 OpenRC

## 📝 默认配置

- **端口**: 8989
- **密码**: qwe123  
- **加密方式**: aes-256-gcm

## ⚠️ 注意事项

如果您在使用云服务器，请确保在云服务商控制面板中已设置安全组规则，放行相应端口。

