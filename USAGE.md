# Shadowsocks 集成脚本使用示例

## 🎯 all.sh 集成脚本使用流程

### 第一步：启动脚本
```bash
sh all.sh
```

### 第二步：选择实现方式
脚本会显示如下界面：
```
=== 步骤 1/3：选择代理实现方式 ===

1. GOST
   • 多协议支持 (SS + SSU)
   • 版本: v3.2.3
   • 特点: 功能丰富，性能优秀

2. go-shadowsocks2
   • 纯Go实现
   • 版本: v0.1.5
   • 特点: 轻量级，兼容性好

3. shadowsocks-rust
   • Rust实现
   • 版本: v1.23.5
   • 特点: 高性能，内存安全

4. 退出脚本

请选择实现方式 [1-4]:
```

**选择建议：**
- **新手用户**: 选择 `1` (GOST) - 功能最全面
- **追求性能**: 选择 `3` (shadowsocks-rust) - 性能最佳
- **轻量需求**: 选择 `2` (go-shadowsocks2) - 占用资源最少

### 第三步：选择配置模式
```
=== 步骤 2/3：选择配置模式 ===

已选择实现方式: GOST

1. 使用默认配置 [推荐]
   • 端口: 8989
   • 密码: qwe123
   • 加密方式: aes-256-gcm

2. 手动输入配置
   • 自定义端口、密码和加密方式

3. 返回上一步

请选择配置模式 [1-3]:
```

**选择建议：**
- **快速部署**: 选择 `1` - 使用默认配置
- **自定义需求**: 选择 `2` - 手动配置

### 第四步：自定义配置（仅在选择手动配置时）
如果选择了手动配置，会依次提示：

#### 4.1 设置端口
```
请输入端口号 (1-65535，直接回车使用默认 8989):
```
**建议端口：** 8989, 443, 80, 8080

#### 4.2 设置密码
```
请输入密码 (直接回车使用默认 qwe123):
```
**安全建议：** 使用复杂密码，长度至少8位

#### 4.3 选择加密方法
不同实现支持的加密方法：

**GOST 支持的加密方法：**
- `aes-128-gcm` - 轻量级，速度快
- `aes-256-gcm` - 安全性高 [默认推荐]
- `chacha20-ietf-poly1305` - 移动设备友好
- `xchacha20-ietf-poly1305` - 增强版ChaCha20
- `2022-blake3-aes-128-gcm` - 新标准，高安全
- `2022-blake3-aes-256-gcm` - 新标准，最高安全
- `2022-blake3-chacha20-poly1305` - 新标准，移动优化

**go-shadowsocks2 支持的加密方法：**
- `aes-128-gcm`
- `aes-256-gcm` [推荐]
- `chacha20-ietf-poly1305`
- `xchacha20-ietf-poly1305`

**shadowsocks-rust 支持的加密方法：**
- 支持所有上述方法，额外支持：
- `none` - 无加密（测试用）
- `plain` - 明文传输（测试用）

### 第五步：确认配置并安装
脚本会显示配置摘要：
```
=== 配置摘要 ===

实现方式: GOST
配置模式: custom
端口: 8989
密码: mypassword
加密方式: aes-256-gcm

确认以上配置并开始安装？

1. 确认并开始安装
2. 重新配置
3. 退出脚本

请选择 [1-3]:
```

选择 `1` 开始自动安装。

## 🔧 常用服务管理命令

安装完成后，脚本会显示相关的管理命令：

### systemd 系统（大多数现代Linux）
```bash
# 查看服务状态
systemctl status [服务名]

# 重启服务
systemctl restart [服务名]

# 停止服务
systemctl stop [服务名]

# 查看日志
journalctl -f -u [服务名]
```

### OpenRC 系统（Alpine Linux）
```bash
# 查看服务状态
rc-service [服务名] status

# 重启服务
rc-service [服务名] restart

# 停止服务
rc-service [服务名] stop

# 查看日志
tail -f /var/log/[服务名].error.log
```

服务名对应关系：
- GOST: `gost`
- go-shadowsocks2: `shadowsocks`
- shadowsocks-rust: `shadowsocks-rust`

## 🚨 故障排除

### 常见问题

1. **端口被占用**
   ```bash
   # 检查端口占用
   netstat -tnlp | grep [端口号]
   # 或
   ss -tnlp | grep [端口号]
   ```

2. **服务启动失败**
   ```bash
   # 查看详细日志
   journalctl -u [服务名] --no-pager
   ```

3. **权限问题**
   - 确保以 root 用户运行脚本
   - 检查 SELinux 是否已正确禁用

4. **网络连接问题**
   - 检查云服务器安全组配置
   - 确认防火墙规则已清理

### 重新安装
如果需要重新安装或切换实现：
```bash
# 再次运行集成脚本
sh all.sh
```
脚本会自动清理旧的安装。

## 📊 性能建议

- **高并发场景**: 推荐 shadowsocks-rust
- **资源受限环境**: 推荐 go-shadowsocks2
- **功能需求丰富**: 推荐 GOST
- **加密方法选择**: 
  - Intel CPU: `aes-256-gcm`
  - ARM CPU: `chacha20-ietf-poly1305`
  - 最新设备: `2022-blake3-*` 系列