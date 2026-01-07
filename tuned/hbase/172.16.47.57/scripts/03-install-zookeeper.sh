#!/bin/bash
# ============================================================================
# ZooKeeper 安装脚本
# ============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 配置变量
ZK_VERSION="3.8.4"
ZK_INSTALL_DIR="/opt/zookeeper"
ZK_DATA_DIR="/data/zookeeper"
ZK_PORT=2181

install_zookeeper() {
    log_info "安装 ZooKeeper ${ZK_VERSION}..."

    local zk_url="https://downloads.apache.org/zookeeper/zookeeper-${ZK_VERSION}/apache-zookeeper-${ZK_VERSION}-bin.tar.gz"
    local zk_file="/tmp/apache-zookeeper-${ZK_VERSION}-bin.tar.gz"

    if [[ ! -f $zk_file ]]; then
        log_info "下载 ZooKeeper..."
        wget -O $zk_file $zk_url || {
            log_error "下载失败"
            exit 1
        }
    fi

    log_info "解压 ZooKeeper..."
    sudo tar -xzf $zk_file -C /opt
    sudo mv /opt/apache-zookeeper-${ZK_VERSION}-bin $ZK_INSTALL_DIR

    log_info "✓ ZooKeeper 安装完成"
}

configure_zookeeper() {
    log_info "配置 ZooKeeper..."

    # 创建配置文件
    sudo tee $ZK_INSTALL_DIR/conf/zoo.cfg > /dev/null <<EOF
# ZooKeeper 配置文件
tickTime=2000
initLimit=10
syncLimit=5
dataDir=${ZK_DATA_DIR}
clientPort=${ZK_PORT}
maxClientCnxns=60
autopurge.snapRetainCount=3
autopurge.purgeInterval=1

# 禁用内置管理员服务器（避免端口冲突）
admin.enableServer=false
EOF

    # 创建数据目录
    sudo mkdir -p $ZK_DATA_DIR
    sudo chown -R $USER:$USER $ZK_DATA_DIR

    # 创建myid文件（单机模式）
    echo "1" | sudo tee $ZK_DATA_DIR/myid > /dev/null

    log_info "✓ ZooKeeper 配置完成"
}

configure_env_vars() {
    log_info "配置 ZooKeeper 环境变量..."

    local env_file="$HOME/.bashrc"
    local zk_env="
# ZooKeeper Environment
export ZOOKEEPER_HOME=${ZK_INSTALL_DIR}
export PATH=\$ZOOKEEPER_HOME/bin:\$PATH
"

    if ! grep -q "ZOOKEEPER_HOME" $env_file; then
        echo "$zk_env" >> $env_file
        log_info "✓ 环境变量已添加"
    else
        log_info "环境变量已存在"
    fi
}

verify_installation() {
    log_info "验证 ZooKeeper 安装..."
    source ~/.bashrc
    which zkServer.sh && log_info "✓ ZooKeeper 命令可用" || log_error "ZooKeeper 命令不可用"
}

main() {
    log_info "=========================================="
    log_info "ZooKeeper 安装脚本"
    log_info "=========================================="
    log_info ""

    install_zookeeper
    configure_zookeeper
    configure_env_vars
    verify_installation

    log_info ""
    log_info "ZooKeeper 安装完成"
    log_info "执行: source ~/.bashrc 使环境变量生效"
    log_info "下一步: ./04-install-hadoop.sh"
}

main "$@"
