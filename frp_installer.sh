#!/bin/bash

# FRP v0.60.0 一键安装脚本
# 作者: Claude
# 版本: 1.0

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PLAIN='\033[0m'

# FRP版本
FRP_VERSION="0.60.0"

# 检查是否为root用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}错误: 请使用root用户运行此脚本${PLAIN}"
        exit 1
    fi
}

# 检查系统信息
check_sys() {
    # 检查系统类型
    if [[ -f /etc/redhat-release ]]; then
        release="centos"
    elif cat /etc/issue | grep -q -E -i "debian"; then
        release="debian"
    elif cat /etc/issue | grep -q -E -i "ubuntu"; then
        release="ubuntu"
    elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat"; then
        release="centos"
    elif cat /proc/version | grep -q -E -i "debian"; then
        release="debian"
    elif cat /proc/version | grep -q -E -i "ubuntu"; then
        release="ubuntu"
    elif cat /proc/version | grep -q -E -i "centos|red hat|redhat"; then
        release="centos"
    fi

    # 检查系统位数
    if [[ $(getconf WORD_BIT) = '32' && $(getconf LONG_BIT) = '64' ]]; then
        arch="amd64"
    else
        arch="386"
    fi

    # ARM架构检测
    if [[ $(uname -m) == "aarch64" ]]; then
        arch="arm64"
    elif [[ $(uname -m) == "arm"* ]]; then
        arch="arm"
    fi
}

# 安装依赖
install_dependencies() {
    echo -e "${BLUE}正在安装依赖...${PLAIN}"
    if [[ ${release} == "centos" ]]; then
        yum update -y
        yum install -y wget tar curl
    else
        apt-get update -y
        apt-get install -y wget tar curl
    fi
}

# 下载FRP
download_frp() {
    echo -e "${BLUE}正在下载FRP ${FRP_VERSION}...${PLAIN}"
    mkdir -p /tmp/frp
    cd /tmp/frp
    wget -q --no-check-certificate -O frp.tar.gz https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/frp_${FRP_VERSION}_linux_${arch}.tar.gz
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}下载失败，请检查网络或稍后再试${PLAIN}"
        exit 1
    fi
    tar -zxf frp.tar.gz
    cd frp_${FRP_VERSION}_linux_${arch}
}

# 安装FRP服务端
install_frps() {
    echo -e "${BLUE}正在安装FRP服务端...${PLAIN}"
    mkdir -p /usr/local/frps
    cp -f ./frps /usr/local/frps/
    
    # 创建frps配置目录
    mkdir -p /etc/frp
    
    # 询问基本配置
    echo -e "${YELLOW}请设置frps基本配置${PLAIN}"
    read -p "绑定端口 [7000]: " bind_port
    bind_port=${bind_port:-7000}
    
    read -p "控制台端口 [7500]: " dashboard_port
    dashboard_port=${dashboard_port:-7500}
    
    read -p "控制台用户名 [admin]: " dashboard_user
    dashboard_user=${dashboard_user:-admin}
    
    read -p "控制台密码 [admin]: " dashboard_pwd
    dashboard_pwd=${dashboard_pwd:-admin}
    
    read -p "认证token [请设置复杂密码]: " token
    if [[ -z "${token}" ]]; then
        token=$(date +%s%N | md5sum | head -c 16)
        echo -e "${YELLOW}已自动生成token: ${token}${PLAIN}"
    fi
    
    # 创建frps.ini配置文件
    cat > /etc/frp/frps.ini << EOF
[common]
# 基础配置
bind_addr = 0.0.0.0
bind_port = ${bind_port}
kcp_bind_port = ${bind_port}

# 管理面板配置
dashboard_port = ${dashboard_port}
dashboard_user = ${dashboard_user}
dashboard_pwd = ${dashboard_pwd}

# HTTP/HTTPS配置
vhost_http_port = 80
vhost_https_port = 443
bind_udp_port = $(($bind_port + 1))

# 安全配置
token = ${token}
allow_ports = 2000-3000,3001,3003,4000-50000

# 日志配置
log_file = /var/log/frps.log
log_level = info
log_max_days = 3

# 高级配置
max_pool_count = 50
tcp_mux = true
EOF

    # 创建systemd服务
    cat > /etc/systemd/system/frps.service << EOF
[Unit]
Description=Frp Server Service
After=network.target

[Service]
Type=simple
User=nobody
Restart=on-failure
RestartSec=5s
ExecStart=/usr/local/frps/frps -c /etc/frp/frps.ini
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

    # 启动服务
    systemctl daemon-reload
    systemctl enable frps
    systemctl start frps
    
    # 检查服务状态
    if systemctl status frps > /dev/null 2>&1; then
        echo -e "${GREEN}FRP服务端安装成功!${PLAIN}"
        echo -e "----------------------"
        echo -e "服务端信息:"
        echo -e "----------------------"
        echo -e "控制台地址: http://$(curl -s https://ipinfo.io/ip):${dashboard_port}"
        echo -e "控制台用户名: ${dashboard_user}"
        echo -e "控制台密码: ${dashboard_pwd}"
        echo -e "绑定端口: ${bind_port}"
        echo -e "认证Token: ${token}"
        echo -e "----------------------"
        echo -e "服务控制:"
        echo -e "启动: systemctl start frps"
        echo -e "停止: systemctl stop frps"
        echo -e "重启: systemctl restart frps"
        echo -e "状态: systemctl status frps"
        echo -e "----------------------"
        echo -e "配置文件: /etc/frp/frps.ini"
        echo -e "日志文件: /var/log/frps.log"
        echo -e "----------------------"
    else
        echo -e "${RED}FRP服务端启动失败，请检查日志${PLAIN}"
        exit 1
    fi
}

# 安装FRP客户端
install_frpc() {
    echo -e "${BLUE}正在安装FRP客户端...${PLAIN}"
    mkdir -p /usr/local/frpc
    cp -f ./frpc /usr/local/frpc/
    
    # 创建frpc配置目录
    mkdir -p /etc/frp
    
    # 询问基本配置
    echo -e "${YELLOW}请设置frpc基本配置${PLAIN}"
    read -p "服务器地址: " server_addr
    while [[ -z "${server_addr}" ]]; do
        echo -e "${RED}服务器地址不能为空，请重新输入${PLAIN}"
        read -p "服务器地址: " server_addr
    done
    
    read -p "服务器端口 [7000]: " server_port
    server_port=${server_port:-7000}
    
    read -p "认证token: " token
    while [[ -z "${token}" ]]; do
        echo -e "${RED}认证token不能为空，请重新输入${PLAIN}"
        read -p "认证token: " token
    done
    
    # 创建frpc.ini基本配置文件
    cat > /etc/frp/frpc.ini << EOF
[common]
server_addr = ${server_addr}
server_port = ${server_port}
token = ${token}
EOF

    # 询问是否需要添加代理规则
    echo -e "${YELLOW}是否要添加代理规则？[y/n]: ${PLAIN}"
    read -p "" add_proxy
    while [[ "${add_proxy}" == "y" || "${add_proxy}" == "Y" ]]; do
        echo -e "${YELLOW}请选择代理类型:${PLAIN}"
        echo -e "1. TCP端口转发"
        echo -e "2. HTTP网站服务"
        echo -e "3. HTTPS网站服务"
        echo -e "4. UDP端口转发"
        echo -e "5. SSH服务"
        echo -e "6. 远程桌面"
        read -p "请选择 [1-6]: " proxy_type
        
        case "${proxy_type}" in
            1)
                read -p "代理名称 [tcp]: " proxy_name
                proxy_name=${proxy_name:-tcp}
                read -p "本地IP [127.0.0.1]: " local_ip
                local_ip=${local_ip:-127.0.0.1}
                read -p "本地端口: " local_port
                while [[ -z "${local_port}" ]]; do
                    echo -e "${RED}本地端口不能为空，请重新输入${PLAIN}"
                    read -p "本地端口: " local_port
                done
                read -p "远程端口: " remote_port
                while [[ -z "${remote_port}" ]]; do
                    echo -e "${RED}远程端口不能为空，请重新输入${PLAIN}"
                    read -p "远程端口: " remote_port
                done
                
                cat >> /etc/frp/frpc.ini << EOF

[${proxy_name}]
type = tcp
local_ip = ${local_ip}
local_port = ${local_port}
remote_port = ${remote_port}
EOF
                ;;
            2)
                read -p "代理名称 [web]: " proxy_name
                proxy_name=${proxy_name:-web}
                read -p "本地IP [127.0.0.1]: " local_ip
                local_ip=${local_ip:-127.0.0.1}
                read -p "本地端口: " local_port
                while [[ -z "${local_port}" ]]; do
                    echo -e "${RED}本地端口不能为空，请重新输入${PLAIN}"
                    read -p "本地端口: " local_port
                done
                read -p "自定义域名: " custom_domain
                while [[ -z "${custom_domain}" ]]; do
                    echo -e "${RED}自定义域名不能为空，请重新输入${PLAIN}"
                    read -p "自定义域名: " custom_domain
                done
                
                cat >> /etc/frp/frpc.ini << EOF

[${proxy_name}]
type = http
local_ip = ${local_ip}
local_port = ${local_port}
custom_domains = ${custom_domain}
EOF
                ;;
            3)
                read -p "代理名称 [https]: " proxy_name
                proxy_name=${proxy_name:-https}
                read -p "本地IP [127.0.0.1]: " local_ip
                local_ip=${local_ip:-127.0.0.1}
                read -p "本地端口: " local_port
                while [[ -z "${local_port}" ]]; do
                    echo -e "${RED}本地端口不能为空，请重新输入${PLAIN}"
                    read -p "本地端口: " local_port
                done
                read -p "自定义域名: " custom_domain
                while [[ -z "${custom_domain}" ]]; do
                    echo -e "${RED}自定义域名不能为空，请重新输入${PLAIN}"
                    read -p "自定义域名: " custom_domain
                done
                
                cat >> /etc/frp/frpc.ini << EOF

[${proxy_name}]
type = https
local_ip = ${local_ip}
local_port = ${local_port}
custom_domains = ${custom_domain}
EOF
                ;;
            4)
                read -p "代理名称 [udp]: " proxy_name
                proxy_name=${proxy_name:-udp}
                read -p "本地IP [127.0.0.1]: " local_ip
                local_ip=${local_ip:-127.0.0.1}
                read -p "本地端口: " local_port
                while [[ -z "${local_port}" ]]; do
                    echo -e "${RED}本地端口不能为空，请重新输入${PLAIN}"
                    read -p "本地端口: " local_port
                done
                read -p "远程端口: " remote_port
                while [[ -z "${remote_port}" ]]; do
                    echo -e "${RED}远程端口不能为空，请重新输入${PLAIN}"
                    read -p "远程端口: " remote_port
                done
                
                cat >> /etc/frp/frpc.ini << EOF

[${proxy_name}]
type = udp
local_ip = ${local_ip}
local_port = ${local_port}
remote_port = ${remote_port}
EOF
                ;;
            5)
                read -p "代理名称 [ssh]: " proxy_name
                proxy_name=${proxy_name:-ssh}
                read -p "本地IP [127.0.0.1]: " local_ip
                local_ip=${local_ip:-127.0.0.1}
                read -p "本地端口 [22]: " local_port
                local_port=${local_port:-22}
                read -p "远程端口: " remote_port
                while [[ -z "${remote_port}" ]]; do
                    echo -e "${RED}远程端口不能为空，请重新输入${PLAIN}"
                    read -p "远程端口: " remote_port
                done
                
                cat >> /etc/frp/frpc.ini << EOF

[${proxy_name}]
type = tcp
local_ip = ${local_ip}
local_port = ${local_port}
remote_port = ${remote_port}
EOF
                ;;
            6)
                read -p "代理名称 [rdp]: " proxy_name
                proxy_name=${proxy_name:-rdp}
                read -p "本地IP [127.0.0.1]: " local_ip
                local_ip=${local_ip:-127.0.0.1}
                read -p "本地端口 [3389]: " local_port
                local_port=${local_port:-3389}
                read -p "远程端口: " remote_port
                while [[ -z "${remote_port}" ]]; do
                    echo -e "${RED}远程端口不能为空，请重新输入${PLAIN}"
                    read -p "远程端口: " remote_port
                done
                
                cat >> /etc/frp/frpc.ini << EOF

[${proxy_name}]
type = tcp
local_ip = ${local_ip}
local_port = ${local_port}
remote_port = ${remote_port}
EOF
                ;;
            *)
                echo -e "${RED}无效选择，请重新选择${PLAIN}"
                ;;
        esac
        
        echo -e "${YELLOW}是否要继续添加其他代理规则？[y/n]: ${PLAIN}"
        read -p "" add_proxy
    done

    # 创建systemd服务
    cat > /etc/systemd/system/frpc.service << EOF
[Unit]
Description=Frp Client Service
After=network.target

[Service]
Type=simple
User=nobody
Restart=on-failure
RestartSec=5s
ExecStart=/usr/local/frpc/frpc -c /etc/frp/frpc.ini
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

    # 启动服务
    systemctl daemon-reload
    systemctl enable frpc
    systemctl start frpc
    
    # 检查服务状态
    if systemctl status frpc > /dev/null 2>&1; then
        echo -e "${GREEN}FRP客户端安装成功!${PLAIN}"
        echo -e "----------------------"
        echo -e "客户端信息:"
        echo -e "----------------------"
        echo -e "服务器地址: ${server_addr}"
        echo -e "服务器端口: ${server_port}"
        echo -e "认证Token: ${token}"
        echo -e "----------------------"
        echo -e "服务控制:"
        echo -e "启动: systemctl start frpc"
        echo -e "停止: systemctl stop frpc"
        echo -e "重启: systemctl restart frpc"
        echo -e "状态: systemctl status frpc"
        echo -e "----------------------"
        echo -e "配置文件: /etc/frp/frpc.ini"
        echo -e "----------------------"
    else
        echo -e "${RED}FRP客户端启动失败，请检查日志${PLAIN}"
        exit 1
    fi
}

# 卸载FRP服务端
uninstall_frps() {
    echo -e "${BLUE}正在卸载FRP服务端...${PLAIN}"
    systemctl stop frps
    systemctl disable frps
    rm -rf /usr/local/frps
    rm -f /etc/systemd/system/frps.service
    rm -f /etc/frp/frps.ini
    systemctl daemon-reload
    echo -e "${GREEN}FRP服务端卸载完成${PLAIN}"
}

# 卸载FRP客户端
uninstall_frpc() {
    echo -e "${BLUE}正在卸载FRP客户端...${PLAIN}"
    systemctl stop frpc
    systemctl disable frpc
    rm -rf /usr/local/frpc
    rm -f /etc/systemd/system/frpc.service
    rm -f /etc/frp/frpc.ini
    systemctl daemon-reload
    echo -e "${GREEN}FRP客户端卸载完成${PLAIN}"
}

# 显示菜单
show_menu() {
    clear
    echo -e "${YELLOW}======================================${PLAIN}"
    echo -e "${YELLOW}       FRP 一键安装管理脚本          ${PLAIN}"
    echo -e "${YELLOW}======================================${PLAIN}"
    echo -e "  ${GREEN}1.${PLAIN} 安装 FRP 服务端"
    echo -e "  ${GREEN}2.${PLAIN} 安装 FRP 客户端"
    echo -e "  ${GREEN}3.${PLAIN} 卸载 FRP 服务端"
    echo -e "  ${GREEN}4.${PLAIN} 卸载 FRP 客户端"
    echo -e "  ${GREEN}5.${PLAIN} 退出"
    echo -e "${YELLOW}======================================${PLAIN}"
    read -p "请输入数字 [1-5]: " num
    case "$num" in
        1)
            check_root
            check_sys
            install_dependencies
            download_frp
            install_frps
            ;;
        2)
            check_root
            check_sys
            install_dependencies
            download_frp
            install_frpc
            ;;
        3)
            check_root
            uninstall_frps
            ;;
        4)
            check_root
            uninstall_frpc
            ;;
        5)
            exit 0
            ;;
        *)
            echo -e "${RED}请输入正确的数字 [1-5]${PLAIN}"
            ;;
    esac
}

# 清理临时文件
cleanup() {
    if [[ -d "/tmp/frp" ]]; then
        rm -rf /tmp/frp
    fi
}

# 运行主程序
main() {
    show_menu
    cleanup
}

main 