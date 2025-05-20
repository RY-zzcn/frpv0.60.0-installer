# FRP v0.60.0 一键安装脚本

这是一个用于快速安装和配置 FRP (Fast Reverse Proxy) v0.60.0 的Linux一键安装脚本，支持服务端(frps)和客户端(frpc)的自动化部署。

## 功能特点

- 自动检测系统类型和架构
- 支持各种Linux发行版（CentOS, Ubuntu, Debian等）
- 支持x86_64和ARM架构
- 自动创建systemd服务实现开机自启
- 交互式配置，简单易用
- 支持多种代理类型配置（TCP, HTTP, HTTPS, UDP等）
- 提供完整的服务管理命令
- 支持一键卸载功能

## 使用方法

### 快速安装

#### 方法一：直接运行（推荐）

```bash
bash <(curl -s https://raw.githubusercontent.com/RY-zzcn/frpv0.60.0-installer/main/frp_installer.sh)
```

或者使用wget：

```bash
bash <(wget -O- https://raw.githubusercontent.com/RY-zzcn/frpv0.60.0-installer/main/frp_installer.sh)
```

#### 方法二：下载后运行

1. 下载脚本:

```bash
wget https://raw.githubusercontent.com/RY-zzcn/frpv0.60.0-installer/main/frp_installer.sh -O frp_installer.sh
```

2. 添加执行权限:

```bash
chmod +x frp_installer.sh
```

3. 执行脚本:

```bash
./frp_installer.sh
```

### 菜单选项

脚本提供以下功能菜单:

1. 安装 FRP 服务端 - 在公网服务器上安装frps
2. 安装 FRP 客户端 - 在内网设备上安装frpc
3. 卸载 FRP 服务端 - 完全移除frps
4. 卸载 FRP 客户端 - 完全移除frpc
5. 退出 - 退出脚本

### 服务管理

安装完成后，可以使用以下命令管理服务:

```bash
# 启动服务
systemctl start frps  # 服务端
systemctl start frpc  # 客户端

# 停止服务
systemctl stop frps   # 服务端
systemctl stop frpc   # 客户端

# 重启服务
systemctl restart frps  # 服务端
systemctl restart frpc  # 客户端

# 查看服务状态
systemctl status frps  # 服务端
systemctl status frpc  # 客户端
```

### 配置文件位置

- 服务端配置文件: `/etc/frp/frps.ini`
- 客户端配置文件: `/etc/frp/frpc.ini`
- 服务端日志文件: `/var/log/frps.log`

## 支持的代理类型

1. **TCP端口转发** - 适用于SSH, 游戏服务器等
2. **HTTP网站服务** - 适用于内网Web应用
3. **HTTPS网站服务** - 适用于内网HTTPS Web应用
4. **UDP端口转发** - 适用于DNS, VOIP等
5. **SSH服务** - 快速配置SSH转发
6. **远程桌面** - 快速配置RDP转发

## 注意事项

- 请确保使用root用户或具有sudo权限的用户运行脚本
- 安装前请确保系统已正确设置防火墙规则
- 为了安全起见，请修改默认的用户名和密码
- Token建议使用复杂的随机字符串提高安全性

## 问题排查

如果您在使用过程中遇到问题，请检查:

1. 服务是否正常运行: `systemctl status frps` 或 `systemctl status frpc`
2. 查看日志文件: `tail -f /var/log/frps.log`
3. 检查防火墙配置，确保端口已开放
4. 确认配置文件中的地址和端口设置正确

## 授权许可

该项目使用 MIT 许可证 - 详见 LICENSE 文件 