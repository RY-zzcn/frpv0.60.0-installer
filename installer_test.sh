#!/bin/bash

# FRP安装测试脚本
# 用于测试frp_installer.sh脚本的兼容性和环境检测功能

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PLAIN='\033[0m'

# 检查系统信息
check_system() {
    echo -e "${BLUE}正在检测系统信息...${PLAIN}"
    
    # 检查系统类型
    if [[ -f /etc/redhat-release ]]; then
        release="centos"
        echo -e "${GREEN}系统类型: CentOS/RHEL${PLAIN}"
    elif cat /etc/issue | grep -q -E -i "debian"; then
        release="debian"
        echo -e "${GREEN}系统类型: Debian${PLAIN}"
    elif cat /etc/issue | grep -q -E -i "ubuntu"; then
        release="ubuntu"
        echo -e "${GREEN}系统类型: Ubuntu${PLAIN}"
    elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat"; then
        release="centos"
        echo -e "${GREEN}系统类型: CentOS/RHEL${PLAIN}"
    elif cat /proc/version | grep -q -E -i "debian"; then
        release="debian"
        echo -e "${GREEN}系统类型: Debian${PLAIN}"
    elif cat /proc/version | grep -q -E -i "ubuntu"; then
        release="ubuntu"
        echo -e "${GREEN}系统类型: Ubuntu${PLAIN}"
    elif cat /proc/version | grep -q -E -i "centos|red hat|redhat"; then
        release="centos"
        echo -e "${GREEN}系统类型: CentOS/RHEL${PLAIN}"
    else
        echo -e "${YELLOW}未知系统类型，程序将尝试继续安装${PLAIN}"
    fi

    # 检查系统位数
    if [[ $(getconf WORD_BIT) = '32' && $(getconf LONG_BIT) = '64' ]]; then
        arch="amd64"
        echo -e "${GREEN}系统架构: x86_64${PLAIN}"
    else
        arch="386"
        echo -e "${GREEN}系统架构: x86${PLAIN}"
    fi

    # ARM架构检测
    if [[ $(uname -m) == "aarch64" ]]; then
        arch="arm64"
        echo -e "${GREEN}系统架构: ARM64${PLAIN}"
    elif [[ $(uname -m) == "arm"* ]]; then
        arch="arm"
        echo -e "${GREEN}系统架构: ARM${PLAIN}"
    fi
    
    # 检查系统内核版本
    kernel_version=$(uname -r)
    echo -e "${GREEN}内核版本: ${kernel_version}${PLAIN}"
    
    # 检查系统发行版本
    if [[ -f /etc/os-release ]]; then
        os_name=$(grep "PRETTY_NAME" /etc/os-release | sed 's/PRETTY_NAME=//g' | sed 's/\"//g')
        echo -e "${GREEN}系统版本: ${os_name}${PLAIN}"
    fi
}

# 检查网络连接
check_network() {
    echo -e "${BLUE}正在检测网络连接...${PLAIN}"
    
    # 测试GitHub连接
    echo -n "GitHub连接: "
    if ping -c 1 github.com > /dev/null 2>&1; then
        echo -e "${GREEN}正常${PLAIN}"
    else
        echo -e "${RED}异常${PLAIN}"
        echo -e "${YELLOW}建议: 请检查您的网络连接或DNS设置${PLAIN}"
    fi
    
    # 测试FRP下载链接
    echo -n "FRP下载链接: "
    if curl --connect-timeout 5 -s https://github.com/fatedier/frp/releases/tag/v0.60.0 > /dev/null; then
        echo -e "${GREEN}正常${PLAIN}"
    else
        echo -e "${RED}异常${PLAIN}"
        echo -e "${YELLOW}建议: 可能需要科学上网或使用镜像站点${PLAIN}"
    fi
    
    # 获取公网IP
    echo -n "公网IP: "
    public_ip=$(curl -s https://ipinfo.io/ip || curl -s https://api.ipify.org)
    if [[ -n "$public_ip" ]]; then
        echo -e "${GREEN}${public_ip}${PLAIN}"
    else
        echo -e "${RED}获取失败${PLAIN}"
    fi
}

# 检查依赖环境
check_dependencies() {
    echo -e "${BLUE}正在检测依赖环境...${PLAIN}"
    
    # 检查常用命令
    dependencies=("wget" "curl" "tar" "systemctl")
    
    for cmd in "${dependencies[@]}"; do
        echo -n "检测 $cmd: "
        if command -v $cmd > /dev/null 2>&1; then
            echo -e "${GREEN}已安装${PLAIN}"
        else
            echo -e "${RED}未安装${PLAIN}"
            echo -e "${YELLOW}建议: 安装程序将尝试自动安装 $cmd${PLAIN}"
        fi
    done
}

# 检查端口占用
check_ports() {
    echo -e "${BLUE}正在检测关键端口占用情况...${PLAIN}"
    
    ports=(7000 7500 80 443)
    
    for port in "${ports[@]}"; do
        echo -n "检测端口 $port: "
        if netstat -tuln | grep -q ":$port "; then
            echo -e "${RED}已被占用${PLAIN}"
            process=$(netstat -tulnp | grep ":$port " | awk '{print $7}')
            echo -e "${YELLOW}占用进程: $process${PLAIN}"
        else
            echo -e "${GREEN}可用${PLAIN}"
        fi
    done
}

# 检查防火墙状态
check_firewall() {
    echo -e "${BLUE}正在检测防火墙状态...${PLAIN}"
    
    # 检查firewalld
    echo -n "firewalld状态: "
    if command -v firewall-cmd > /dev/null 2>&1; then
        if systemctl is-active firewalld > /dev/null 2>&1; then
            echo -e "${YELLOW}运行中${PLAIN}"
            echo -e "${YELLOW}建议: 请确保已放行FRP所需端口${PLAIN}"
        else
            echo -e "${GREEN}未运行${PLAIN}"
        fi
    else
        echo -e "${GREEN}未安装${PLAIN}"
    fi
    
    # 检查iptables
    echo -n "iptables状态: "
    if command -v iptables > /dev/null 2>&1; then
        rules_count=$(iptables -L | grep -c "")
        if [[ $rules_count -gt 10 ]]; then
            echo -e "${YELLOW}已配置规则${PLAIN}"
            echo -e "${YELLOW}建议: 请确保已放行FRP所需端口${PLAIN}"
        else
            echo -e "${GREEN}无限制规则${PLAIN}"
        fi
    else
        echo -e "${GREEN}未安装${PLAIN}"
    fi
}

# 测试磁盘性能
test_disk_performance() {
    echo -e "${BLUE}正在测试磁盘性能...${PLAIN}"
    
    # 创建临时测试目录
    test_dir="/tmp/frp_test"
    mkdir -p $test_dir
    
    # 测试写入速度
    echo -n "磁盘写入速度: "
    write_speed=$(dd if=/dev/zero of=$test_dir/test_file bs=1M count=100 2>&1 | grep -o ".*MB/s")
    echo -e "${GREEN}${write_speed}${PLAIN}"
    
    # 测试读取速度
    echo -n "磁盘读取速度: "
    read_speed=$(dd if=$test_dir/test_file of=/dev/null bs=1M 2>&1 | grep -o ".*MB/s")
    echo -e "${GREEN}${read_speed}${PLAIN}"
    
    # 清理测试文件
    rm -rf $test_dir
}

# 主函数
main() {
    echo -e "${YELLOW}======================================${PLAIN}"
    echo -e "${YELLOW}       FRP 环境测试工具              ${PLAIN}"
    echo -e "${YELLOW}======================================${PLAIN}"
    
    check_system
    echo -e "${YELLOW}======================================${PLAIN}"
    check_network
    echo -e "${YELLOW}======================================${PLAIN}"
    check_dependencies
    echo -e "${YELLOW}======================================${PLAIN}"
    check_ports
    echo -e "${YELLOW}======================================${PLAIN}"
    check_firewall
    echo -e "${YELLOW}======================================${PLAIN}"
    test_disk_performance
    echo -e "${YELLOW}======================================${PLAIN}"
    
    echo -e "${GREEN}测试完成!${PLAIN}"
    echo -e "${GREEN}如果所有检测都显示正常，您可以放心运行FRP安装脚本。${PLAIN}"
    echo -e "${YELLOW}如果有任何警告或错误，请参考上面的建议进行修复后再安装。${PLAIN}"
}

# 执行主函数
main 