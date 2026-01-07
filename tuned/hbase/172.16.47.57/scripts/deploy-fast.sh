#!/bin/bash
# ============================================================================
# HBase快速部署脚本 - 使用国内镜像源
# ============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 使用阿里云镜像源
ALIYUN_MIRROR="https://mirrors.aliyun.com/apache"

# 配置变量
ZK_VERSION="3.8.4"
ZK_INSTALL_DIR="/opt/zookeeper"
HBASE_VERSION="2.5.10"
HBASE_INSTALL_DIR="/opt/hbase"
JAVA_HOME="/usr/lib/jvm/jdk1.8.0_341"
HADOOP_HOME="/opt/hadoop"

# 检查环境
check_environment() {
    log_info "检查现有环境..."
    log_info "✓ Java: $(java -version 2>&1 | head -1)"
    log_info "✓ Hadoop: $HADOOP_HOME"

    # 检查端口
    local ports=(2181 16010 16030)
    for port in "${ports[@]}"; do
        if netstat -tuln 2>/dev/null | grep -q ":$port "; then
            log_warn "端口 $port 已被占用"
        fi
    done
}

# 快速安装ZooKeeper
install_zookeeper() {
    log_info "安装ZooKeeper..."

    if [[ -d $ZK_INSTALL_DIR ]]; then
        log_info "ZooKeeper已安装"
        if jps | grep -q QuorumPeerMain; then
            log_info "✓ ZooKeeper正在运行"
        fi
        return 0
    fi

    # 使用阿里云镜像
    local zk_url="${ALIYUN_MIRROR}/zookeeper/zookeeper-${ZK_VERSION}/apache-zookeeper-${ZK_VERSION}-bin.tar.gz"
    local zk_file="/tmp/zk-${ZK_VERSION}.tar.gz"

    log_info "从阿里云镜像下载..."
    wget -O $zk_file "$zk_url" || {
        log_error "下载失败"
        return 1
    }

    log_info "解压并安装..."
    tar -xzf $zk_file -C /opt
    mv /opt/apache-zookeeper-${ZK_VERSION}-bin $ZK_INSTALL_DIR

    # 配置
    mkdir -p /data/zookeeper
    echo "1" > /data/zookeeper/myid

    cat > $ZK_INSTALL_DIR/conf/zoo.cfg <<'EOF'
tickTime=2000
dataDir=/data/zookeeper
clientPort=2181
maxClientCnxns=60
admin.enableServer=false
EOF

    log_info "✓ ZooKeeper安装完成"
}

# 快速安装HBase
install_hbase() {
    log_info "安装HBase..."

    if [[ -d $HBASE_INSTALL_DIR ]]; then
        log_info "HBase已安装"
        return 0
    fi

    # 使用阿里云镜像
    local hbase_url="${ALIYUN_MIRROR}/hbase/${HBASE_VERSION}/hbase-${HBASE_VERSION}-bin.tar.gz"
    local hbase_file="/tmp/hbase-${HBASE_VERSION}.tar.gz"

    log_info "从阿里云镜像下载..."
    wget -O $hbase_file "$hbase_url" || {
        log_error "下载失败"
        return 1
    }

    log_info "解压并安装..."
    tar -xzf $hbase_file -C /opt
    mv /opt/hbase-${HBASE_VERSION} $HBASE_INSTALL_DIR

    # 配置HBase (单机文件系统模式)
    mkdir -p /data/hbase/tmp

    cat > $HBASE_INSTALL_DIR/conf/hbase-env.sh <<EOF
export JAVA_HOME=$JAVA_HOME
export HBASE_MANAGES_ZK=false
export HBASE_HEAPSIZE=8192
EOF

    cat > $HBASE_INSTALL_DIR/conf/hbase-site.xml <<'EOF'
<?xml version="1.0"?>
<configuration>
    <property>
        <name>hbase.rootdir</name>
        <value>file:///data/hbase</value>
    </property>
    <property>
        <name>hbase.cluster.distributed</name>
        <value>false</value>
    </property>
    <property>
        <name>hbase.zookeeper.quorum</name>
        <value>localhost</value>
    </property>
    <property>
        <name>hbase.zookeeper.property.clientPort</name>
        <value>2181</value>
    </property>
</configuration>
EOF

    # 配置环境变量
    grep -q "HBASE_HOME" /root/.bashrc || cat >> /root/.bashrc <<'ENVEOF'
export HBASE_HOME=/opt/hbase
export PATH=$PATH:$HBASE_HOME/bin
ENVEOF

    log_info "✓ HBase安装完成"
}

# 启动服务
start_services() {
    log_info "启动服务..."

    # 启动ZooKeeper
    if ! jps | grep -q QuorumPeerMain; then
        log_info "启动ZooKeeper..."
        $ZK_INSTALL_DIR/bin/zkServer.sh start
        sleep 2
    fi

    # 启动HBase
    if ! jps | grep -q HMaster; then
        log_info "启动HBase..."
        $HBASE_INSTALL_DIR/bin/start-hbase.sh
        sleep 3
    fi

    log_info "✓ 服务启动完成"
}

# 快速测试
test_quick() {
    log_info ""
    log_info "=========================================="
    log_info "快速测试"
    log_info "=========================================="

    log_info "进程状态:"
    jps | grep -E "(QuorumPeerMain|HMaster|HRegionServer)" || log_warn "未找到HBase进程"

    log_info ""
    log_info "端口状态:"
    netstat -tuln 2>/dev/null | grep -E ":(2181|16010|16030) " || log_warn "未找到监听端口"

    log_info ""
    log_info "创建测试表..."
    echo "create 'test', 'cf'" | $HBASE_INSTALL_DIR/bin/hbase shell -n > /dev/null 2>&1 && \
    echo "put 'test', 'row1', 'cf:a', 'hello'" | $HBASE_INSTALL_DIR/bin/hbase shell -n > /dev/null 2>&1 && \
    log_info "✓ 基本功能正常" || log_warn "功能测试失败"

    log_info ""
    log_info "Web UI:"
    log_info "  http://172.16.47.57:16010"
}

# 主函数
main() {
    log_info "=========================================="
    log_info "HBase快速部署 (阿里云镜像)"
    log_info "=========================================="
    log_info ""

    check_environment
    install_zookeeper || exit 1
    install_hbase || exit 1
    start_services
    test_quick

    log_info ""
    log_info "部署完成!"
}

main "$@"
