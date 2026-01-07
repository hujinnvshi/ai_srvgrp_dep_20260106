#!/bin/bash
# ============================================================================
# HBase快速部署脚本 (使用现有Hadoop和Java环境)
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
HBASE_VERSION="2.5.10"
HBASE_INSTALL_DIR="/opt/hbase"
JAVA_HOME="/usr/lib/jvm/jdk1.8.0_341"
HADOOP_HOME="/opt/hadoop"

# 检查环境
check_environment() {
    log_info "检查现有环境..."

    # 检查Java
    if command -v java &> /dev/null; then
        log_info "✓ Java已安装: $(java -version 2>&1 | head -1)"
    else
        log_error "Java未安装"
        exit 1
    fi

    # 检查Hadoop
    if [[ -d $HADOOP_HOME ]]; then
        log_info "✓ Hadoop已安装: $HADOOP_HOME"
    else
        log_error "Hadoop未安装"
        exit 1
    fi

    # 检查Hadoop服务
    if jps | grep -q NameNode; then
        log_info "✓ Hadoop服务正在运行"
    else
        log_warn "Hadoop服务未运行，请先启动Hadoop"
    fi

    # 检查端口
    log_info "检查HBase和ZooKeeper端口..."
    local ports=(2181 16010 16030)
    local occupied=()

    for port in "${ports[@]}"; do
        if netstat -tuln 2>/dev/null | grep -q ":$port " || \
           ss -tuln 2>/dev/null | grep -q ":$port "; then
            occupied+=("$port")
        fi
    done

    if [[ ${#occupied[@]} -gt 0 ]]; then
        log_warn "以下端口已被占用: ${occupied[*]}"
        log_info "可能已有ZooKeeper或HBase在运行"
    fi
}

# 安装ZooKeeper
install_zookeeper() {
    log_info "安装ZooKeeper ${ZK_VERSION}..."

    if [[ -d $ZK_INSTALL_DIR ]]; then
        log_info "ZooKeeper已安装，检查服务状态..."
        if jps | grep -q QuorumPeerMain; then
            log_info "✓ ZooKeeper正在运行"
            return 0
        else
            log_info "ZooKeeper已安装但未运行，稍后将启动"
            return 0
        fi
    fi

    local zk_url="https://dlcdn.apache.org/zookeeper/zookeeper-${ZK_VERSION}/apache-zookeeper-${ZK_VERSION}-bin.tar.gz"
    local zk_file="/tmp/apache-zookeeper-${ZK_VERSION}-bin.tar.gz"

    if [[ ! -f $zk_file ]]; then
        log_info "下载ZooKeeper..."
        wget -t 3 -T 30 -O $zk_file $zk_url || {
            log_error "下载失败，尝试备用源..."
            zk_url="https://archive.apache.org/dist/zookeeper/zookeeper-${ZK_VERSION}/apache-zookeeper-${ZK_VERSION}-bin.tar.gz"
            wget -t 3 -T 30 -O $zk_file $zk_url || {
                log_error "下载失败"
                exit 1
            }
        }
    fi

    log_info "解压ZooKeeper..."
    tar -xzf $zk_file -C /opt
    mv /opt/apache-zookeeper-${ZK_VERSION}-bin $ZK_INSTALL_DIR

    # 配置ZooKeeper
    mkdir -p /data/zookeeper
    echo "1" > /data/zookeeper/myid

    cat > $ZK_INSTALL_DIR/conf/zoo.cfg <<EOF
tickTime=2000
initLimit=10
syncLimit=5
dataDir=/data/zookeeper
clientPort=2181
maxClientCnxns=60
autopurge.snapRetainCount=3
autopurge.purgeInterval=1
admin.enableServer=false
EOF

    log_info "✓ ZooKeeper安装完成"
}

# 安装HBase
install_hbase() {
    log_info "安装HBase ${HBASE_VERSION}..."

    if [[ -d $HBASE_INSTALL_DIR ]]; then
        log_info "HBase已安装"
        return 0
    fi

    local hbase_url="https://dlcdn.apache.org/hbase/${HBASE_VERSION}/hbase-${HBASE_VERSION}-bin.tar.gz"
    local hbase_file="/tmp/hbase-${HBASE_VERSION}-bin.tar.gz"

    if [[ ! -f $hbase_file ]]; then
        log_info "下载HBase..."
        wget -t 3 -T 30 -O $hbase_file $hbase_url || {
            log_error "下载失败，尝试备用源..."
            hbase_url="https://archive.apache.org/dist/hbase/${HBASE_VERSION}/hbase-${HBASE_VERSION}-bin.tar.gz"
            wget -t 3 -T 30 -O $hbase_file $hbase_url || {
                log_error "下载失败"
                exit 1
            }
        }
    fi

    log_info "解压HBase..."
    tar -xzf $hbase_file -C /opt
    mv /opt/hbase-${HBASE_VERSION} $HBASE_INSTALL_DIR

    # 配置HBase
    mkdir -p /data/hbase/tmp

    # hbase-env.sh
    cat > $HBASE_INSTALL_DIR/conf/hbase-env.sh <<EOF
export JAVA_HOME=$JAVA_HOME
export HBASE_CLASSPATH=$HBASE_INSTALL_DIR/conf
export HBASE_MANAGES_ZK=false
export HBASE_HEAPSIZE=8192
export HBASE_OFFHEAPSIZE=4g
EOF

    # hbase-site.xml (使用本地文件系统模式)
    cat > $HBASE_INSTALL_DIR/conf/hbase-site.xml <<EOF
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
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
        <name>hbase.tmp.dir</name>
        <value>/data/hbase/tmp</value>
    </property>
    <property>
        <name>hbase.zookeeper.quorum</name>
        <value>localhost</value>
    </property>
    <property>
        <name>hbase.zookeeper.property.clientPort</name>
        <value>2181</value>
    </property>
    <property>
        <name>hbase.master.info.port</name>
        <value>16010</value>
    </property>
    <property>
        <name>hbase.regionserver.info.port</name>
        <value>16030</value>
    </property>
</configuration>
EOF

    # 配置环境变量
    if ! grep -q "HBASE_HOME" /root/.bashrc; then
        cat >> /root/.bashrc <<'ENVEOF'

# HBase Environment
export HBASE_HOME=/opt/hbase
export PATH=$PATH:$HBASE_HOME/bin
ENVEOF
    fi

    export HBASE_HOME=$HBASE_INSTALL_DIR
    export PATH=$PATH:$HBASE_HOME/bin

    log_info "✓ HBase安装完成"
}

# 启动服务
start_services() {
    log_info "启动服务..."

    # 启动ZooKeeper
    if ! jps | grep -q QuorumPeerMain; then
        log_info "启动ZooKeeper..."
        $ZK_INSTALL_DIR/bin/zkServer.sh start
        sleep 3

        if jps | grep -q QuorumPeerMain; then
            log_info "✓ ZooKeeper启动成功"
        else
            log_error "ZooKeeper启动失败"
            return 1
        fi
    else
        log_info "✓ ZooKeeper已在运行"
    fi

    # 启动HBase
    if ! jps | grep -q HMaster; then
        log_info "启动HBase..."
        $HBASE_INSTALL_DIR/bin/start-hbase.sh
        sleep 5

        if jps | grep -q HMaster; then
            log_info "✓ HBase启动成功"
        else
            log_error "HBase启动失败"
            return 1
        fi
    else
        log_info "✓ HBase已在运行"
    fi

    log_info "✓ 所有服务启动完成"
}

# 测试服务
test_services() {
    log_info ""
    log_info "=========================================="
    log_info "服务测试"
    log_info "=========================================="
    log_info ""

    log_info "1. Java版本:"
    java -version 2>&1 | head -1

    log_info ""
    log_info "2. 运行中的Java进程:"
    jps | grep -E "(QuorumPeerMain|HMaster|HRegionServer|NameNode|DataNode)"

    log_info ""
    log_info "3. ZooKeeper测试:"
    if echo "ruok" | nc localhost 2181 2>/dev/null | grep -q "imok"; then
        log_info "✓ ZooKeeper运行正常"
    else
        log_warn "ZooKeeper未响应"
    fi

    log_info ""
    log_info "4. 端口监听状态:"
    for port in 2181 16010 16030; do
        if netstat -tuln 2>/dev/null | grep -q ":$port "; then
            log_info "✓ 端口 $port 正在监听"
        else
            log_warn "✗ 端口 $port 未监听"
        fi
    done

    log_info ""
    log_info "5. HBase Shell测试:"
    log_info "创建测试表..."
    $HBASE_INSTALL_DIR/bin/hbase shell <<EOF
create 'test_table', 'cf'
put 'test_table', 'row1', 'cf:col1', 'value1'
scan 'test_table'
exit
EOF

    if [[ $? -eq 0 ]]; then
        log_info "✓ HBase功能测试通过"
    else
        log_warn "HBase功能测试失败"
    fi

    log_info ""
    log_info "=========================================="
    log_info "Web UI访问地址:"
    log_info "  HBase Master: http://172.16.47.57:16010"
    log_info "  HBase RegionServer: http://172.16.47.57:16030"
    log_info "=========================================="
}

# 主函数
main() {
    log_info "=========================================="
    log_info "HBase快速部署脚本"
    log_info "=========================================="
    log_info ""

    check_environment
    install_zookeeper
    install_hbase
    start_services
    test_services

    log_info ""
    log_info "部署完成！"
    log_info ""
    log_info "常用命令:"
    log_info "  启动HBase: $HBASE_INSTALL_DIR/bin/start-hbase.sh"
    log_info "  停止HBase: $HBASE_INSTALL_DIR/bin/stop-hbase.sh"
    log_info "  HBase Shell: $HBASE_INSTALL_DIR/bin/hbase shell"
}

main "$@"
