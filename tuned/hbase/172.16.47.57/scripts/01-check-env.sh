#!/bin/bash
# ============================================================================
# 环境检查和前置准备脚本
# ============================================================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查是否为root用户
check_root() {
    log_info "检查用户权限..."
    if [[ $EUID -eq 0 ]]; then
        log_error "请不要使用root用户运行此脚本"
        exit 1
    fi
    log_info "✓ 用户权限检查通过"
}

# 检查操作系统
check_os() {
    log_info "检查操作系统..."
    if [[ ! -f /etc/redhat-release ]]; then
        log_warn "未检测到RedHat/CentOS系统，继续执行可能存在问题"
    fi
    log_info "✓ 操作系统检查通过"
}

# 检查并安装必要的工具
check_dependencies() {
    log_info "检查必要的系统工具..."

    local required_tools=("wget" "tar" "curl" "ssh" "rsync")
    local missing_tools=()

    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done

    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_warn "缺少以下工具: ${missing_tools[*]}"
        log_info "尝试安装缺失的工具..."

        if command -v yum &> /dev/null; then
            sudo yum install -y "${missing_tools[@]}" || {
                log_error "工具安装失败"
                exit 1
            }
        elif command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y "${missing_tools[@]}" || {
                log_error "工具安装失败"
                exit 1
            }
        else
            log_error "无法自动安装工具，请手动安装: ${missing_tools[*]}"
            exit 1
        fi
    fi

    log_info "✓ 系统工具检查完成"
}

# 检查系统资源
check_system_resources() {
    log_info "检查系统资源..."

    # 检查内存
    local total_mem_gb=$(free -g | awk '/^Mem:/{print $2}')
    log_info "总内存: ${total_mem_gb}GB"

    if [[ $total_mem_gb -lt 8 ]]; then
        log_warn "内存不足8GB，可能影响性能"
    else
        log_info "✓ 内存检查通过"
    fi

    # 检查磁盘空间
    local disk_space=$(df -h / | awk 'NR==2 {print $4}')
    log_info "可用磁盘空间: ${disk_space}"

    log_info "✓ 系统资源检查完成"
}

# 检查端口占用
check_ports() {
    log_info "检查HBase相关端口占用情况..."

    # 定义需要检查的端口
    local ports=(
        "16000:HBase_Master"
        "16010:HBase_Master_Info"
        "16020:HBase_RegionServer"
        "16030:HBase_RegionServer_Info"
        "9000:Hadoop_NameNode"
        "9870:Hadoop_NameNode_Web"
        "9866:Hadoop_DataNode"
        "9864:Hadoop_DataNode_Web"
        "2181:ZooKeeper"
        "8080:ZooKeeper_Admin"
    )

    local occupied_ports=()

    for port_info in "${ports[@]}"; do
        local port=$(echo $port_info | cut -d: -f1)
        local name=$(echo $port_info | cut -d: -f2)

        if netstat -tuln 2>/dev/null | grep -q ":$port " || \
           ss -tuln 2>/dev/null | grep -q ":$port "; then
            log_warn "端口 $port ($name) 已被占用"
            occupied_ports+=("$port($name)")
        else
            log_info "✓ 端口 $port ($name) 可用"
        fi
    done

    if [[ ${#occupied_ports[@]} -gt 0 ]]; then
        log_error "以下端口已被占用: ${occupied_ports[*]}"
        log_info "请执行以下命令检查并停止占用端口的进程："
        log_info "  sudo lsof -i :<端口号>"
        log_info "  或"
        log_info "  sudo netstat -tulnp | grep <端口号>"
        read -p "是否继续部署? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "部署已取消"
            exit 1
        fi
    else
        log_info "✓ 所有必要端口均可用"
    fi
}

# 检查Java环境
check_java() {
    log_info "检查Java环境..."

    if command -v java &> /dev/null; then
        local java_version=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}')
        log_info "检测到Java版本: $java_version"

        # 检查是否为Java 8
        if [[ $java_version == 1.8.* ]]; then
            log_info "✓ Java版本符合要求 (1.8)"
            export JAVA_HOME=$(dirname $(dirname $(readlink -f $(which java))))
            log_info "JAVA_HOME: $JAVA_HOME"
            return 0
        else
            log_warn "建议使用Java 8，当前版本: $java_version"
        fi
    else
        log_warn "未检测到Java环境"
    fi

    return 1
}

# 检查主机名和DNS
check_hostname() {
    log_info "检查主机名配置..."

    local hostname=$(hostname)
    local hostname_ip=$(hostname -I | awk '{print $1}')

    log_info "主机名: $hostname"
    log_info "IP地址: $hostname_ip"

    # 检查/etc/hosts
    if grep -q "$hostname" /etc/hosts; then
        log_info "✓ /etc/hosts配置正确"
    else
        log_warn "/etc/hosts中未找到主机名映射"
        log_info "建议添加以下内容到/etc/hosts:"
        log_info "  $hostname_ip $hostname"
    fi
}

# 配置系统参数
configure_system_params() {
    log_info "配置系统参数..."

    # 检查是否已配置
    if [[ -f /etc/sysctl.d/99-hbase.conf ]]; then
        log_info "系统参数配置文件已存在"
        return 0
    fi

    log_info "创建系统参数配置文件..."
    sudo tee /etc/sysctl.d/99-hbase.conf > /dev/null <<EOF
# HBase系统参数优化
# 增加文件描述符限制
fs.file-max = 655350

# 增加网络参数
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216

# 虚拟内存参数
vm.swappiness = 10
vm.overcommit_memory = 1
EOF

    log_info "应用系统参数..."
    sudo sysctl -p /etc/sysctl.d/99-hbase.conf

    log_info "✓ 系统参数配置完成"
}

# 配置limits
configure_limits() {
    log_info "配置用户资源限制..."

    local limits_file="/etc/security/limits.d/99-hbase.conf"

    if [[ -f $limits_file ]]; then
        log_info "资源限制配置文件已存在"
        return 0
    fi

    log_info "创建资源限制配置文件..."
    sudo tee $limits_file > /dev/null <<EOF
# HBase用户资源限制
*  soft  nofile  655350
*  hard  nofile  655350
*  soft  nproc   655350
*  hard  nproc   655350
*  soft  memlock unlimited
*  hard  memlock unlimited
EOF

    log_info "✓ 资源限制配置完成"
    log_warn "需要重新登录才能生效"
}

# 禁用防火墙或开放端口
configure_firewall() {
    log_info "配置防火墙..."

    if command -v firewall-cmd &> /dev/null; then
        if systemctl is-active --quiet firewalld; then
            log_info "检测到firewalld正在运行"
            log_warn "建议开放以下端口或临时停止防火墙："
            log_info "  HBase: 16000, 16010, 16020, 16030"
            log_info "  Hadoop: 9000, 9870, 9866, 9864"
            log_info "  ZooKeeper: 2181, 8080"
            log_info ""
            log_info "临时停止防火墙命令: sudo systemctl stop firewalld"
            log_info "永久停止防火墙命令: sudo systemctl disable firewalld"
        fi
    elif command -v ufw &> /dev/null; then
        if ufw status | grep -q "Status: active"; then
            log_info "检测到ufw正在运行"
            log_warn "需要开放相关端口"
        fi
    else
        log_info "未检测到防火墙或防火墙未运行"
    fi
}

# 禁用SELinux
check_selinux() {
    log_info "检查SELinux状态..."

    if command -v getenforce &> /dev/null; then
        local selinux_status=$(getenforce)
        log_info "SELinux状态: $selinux_status"

        if [[ $selinux_status == "Enforcing" ]]; then
            log_warn "SELinux处于强制模式，可能导致HBase运行异常"
            log_info "临时关闭: sudo setenforce 0"
            log_info "永久关闭: 编辑 /etc/selinux/config，设置 SELINUX=disabled"
        fi
    fi
}

# 创建必要的目录
create_directories() {
    log_info "创建必要的目录..."

    local base_dirs=(
        "/opt/hbase"
        "/opt/hadoop"
        "/opt/zookeeper"
        "/data/hbase"
        "/data/hadoop"
        "/data/zookeeper"
        "/var/log/hbase"
        "/var/log/hadoop"
        "/var/log/zookeeper"
    )

    for dir in "${base_dirs[@]}"; do
        if [[ ! -d $dir ]]; then
            sudo mkdir -p "$dir"
            sudo chown $USER:$USER "$dir"
            log_info "✓ 创建目录: $dir"
        else
            log_info "✓ 目录已存在: $dir"
        fi
    done

    log_info "✓ 目录创建完成"
}

# 主函数
main() {
    log_info "=========================================="
    log_info "HBase环境检查和前置准备"
    log_info "=========================================="
    log_info ""

    check_root
    check_os
    check_dependencies
    check_system_resources
    check_ports
    check_hostname
    check_selinux

    log_info ""
    log_info "=========================================="
    log_info "配置系统参数"
    log_info "=========================================="

    configure_system_params
    configure_limits
    configure_firewall
    create_directories

    log_info ""
    log_info "=========================================="
    log_info "环境检查完成"
    log_info "=========================================="

    # 检查Java
    if ! check_java; then
        log_warn "未检测到Java 8环境"
        log_info "请运行 ./02-install-jdk.sh 安装JDK"
    fi

    log_info ""
    log_info "下一步："
    log_info "1. 如未安装JDK，请运行: ./02-install-jdk.sh"
    log_info "2. 安装ZooKeeper: ./03-install-zookeeper.sh"
    log_info "3. 安装Hadoop: ./04-install-hadoop.sh"
    log_info "4. 安装HBase: ./05-install-hbase.sh"
    log_info "5. 启动所有服务: ./06-start-all.sh"
}

# 运行主函数
main "$@"
