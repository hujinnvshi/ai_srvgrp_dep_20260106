#!/bin/bash
# ============================================================================
# HBase 安装脚本 (单机模式)
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
HBASE_VERSION="2.5.10"
HBASE_INSTALL_DIR="/opt/hbase"
HBASE_DATA_DIR="/data/hbase"

install_hbase() {
    log_info "安装 HBase ${HBASE_VERSION}..."

    local hbase_url="https://downloads.apache.org/hbase/${HBASE_VERSION}/hbase-${HBASE_VERSION}-bin.tar.gz"
    local hbase_file="/tmp/hbase-${HBASE_VERSION}-bin.tar.gz"

    if [[ ! -f $hbase_file ]]; then
        log_info "下载 HBase..."
        wget -O $hbase_file $hbase_url || {
            log_error "下载失败"
            exit 1
        }
    fi

    log_info "解压 HBase..."
    sudo tar -xzf $hbase_file -C /opt
    sudo mv /opt/hbase-${HBASE_VERSION} $HBASE_INSTALL_DIR

    log_info "✓ HBase 安装完成"
}

configure_hbase() {
    log_info "配置 HBase..."

    # 创建数据目录
    sudo mkdir -p ${HBASE_DATA_DIR}/{tmp,logs}
    sudo chown -R $USER:$USER $HBASE_DATA_DIR

    # 配置 hbase-env.sh
    local java_home=$(dirname $(dirname $(readlink -f $(which java))))
    sudo tee $HBASE_INSTALL_DIR/conf/hbase-env.sh > /dev/null <<EOF
# HBase 环境配置
export JAVA_HOME=$java_home
export HBASE_CLASSPATH=$HBASE_INSTALL_DIR/conf
export HBASE_MANAGES_ZK=false
export HBASE_HEAPSIZE=8192
export HBASE_OFFHEAPSIZE=4g

# 禁用HBase自带的ZK，使用外部ZK
export HBASE_MANAGES_ZK=false

# GC配置
export HBASE_OPTS="\$HBASE_OPTS -XX:+UseConcMarkSweepGC"
EOF

    # 配置 hbase-site.xml
    local hostname=$(hostname)
    sudo tee $HBASE_INSTALL_DIR/conf/hbase-site.xml > /dev/null <<EOF
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
    <!-- HBase 数据目录 -->
    <property>
        <name>hbase.rootdir</name>
        <value>file://${HBASE_DATA_DIR}</value>
    </property>

    <!-- 单机模式配置 -->
    <property>
        <name>hbase.cluster.distributed</name>
        <value>false</value>
    </property>

    <!-- 临时目录 -->
    <property>
        <name>hbase.tmp.dir</name>
        <value>${HBASE_DATA_DIR}/tmp</value>
    </property>

    <!-- ZooKeeper 配置 -->
    <property>
        <name>hbase.zookeeper.quorum</name>
        <value>localhost</value>
    </property>
    <property>
        <name>hbase.zookeeper.property.clientPort</name>
        <value>2181</value>
    </property>
    <property>
        <name>hbase.zookeeper.property.dataDir</name>
        <value>/data/zookeeper</value>
    </property>

    <!-- Web UI 端口 -->
    <property>
        <name>hbase.master.info.port</name>
        <value>16010</value>
    </property>
    <property>
        <name>hbase.regionserver.info.port</name>
        <value>16030</value>
    </property>

    <!-- 性能优化 -->
    <property>
        <name>hbase.regionserver.handler.count</name>
        <value>50</value>
    </property>
    <property>
        <name>hfile.format.version</name>
        <value>3</value>
    </property>
    <property>
        <name>hbase.hstore.blockingStoreFiles</name>
        <value>15</value>
    </property>

    <!-- RPC 配置 -->
    <property>
        <name>hbase.regionserver.throughput.controller</name>
        <value>org.apache.hadoop.hbase.regionserver.compactions.PressureAwareCompactionThroughputController</value>
    </property>
</configuration>
EOF

    log_info "✓ HBase 配置完成"
}

configure_env_vars() {
    log_info "配置 HBase 环境变量..."

    local env_file="$HOME/.bashrc"
    local hbase_env="
# HBase Environment
export HBASE_HOME=${HBASE_INSTALL_DIR}
export HBASE_CONF_DIR=\$HBASE_HOME/conf
export PATH=\$PATH:\$HBASE_HOME/bin
"

    if ! grep -q "HBASE_HOME" $env_file; then
        echo "$hbase_env" >> $env_file
        log_info "✓ 环境变量已添加"
    else
        log_info "环境变量已存在"
    fi
}

main() {
    log_info "=========================================="
    log_info "HBase 安装脚本"
    log_info "=========================================="
    log_info ""

    install_hbase
    configure_hbase
    configure_env_vars

    log_info ""
    log_info "HBase 安装完成"
    log_info "执行: source ~/.bashrc 使环境变量生效"
    log_info "下一步: ./06-start-all.sh"
}

main "$@"
