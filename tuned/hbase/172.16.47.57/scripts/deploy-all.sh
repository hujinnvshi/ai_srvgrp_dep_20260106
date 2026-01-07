#!/bin/bash
# ============================================================================
# HBase一键部署脚本 (适配root用户)
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
JAVA_VERSION="1.8.0_412"
JAVA_INSTALL_DIR="/opt/java/jdk${JAVA_VERSION}"
ZK_VERSION="3.8.4"
ZK_INSTALL_DIR="/opt/zookeeper"
HADOOP_VERSION="3.3.6"
HADOOP_INSTALL_DIR="/opt/hadoop"
HBASE_VERSION="2.5.10"
HBASE_INSTALL_DIR="/opt/hbase"

# 检查端口
check_ports() {
    log_info "检查端口占用..."
    local ports=(2181 9000 9870 9866 16010 16030)
    local occupied=()

    for port in "${ports[@]}"; do
        if netstat -tuln 2>/dev/null | grep -q ":$port " || \
           ss -tuln 2>/dev/null | grep -q ":$port "; then
            occupied+=("$port")
        fi
    done

    if [[ ${#occupied[@]} -gt 0 ]]; then
        log_warn "以下端口已被占用: ${occupied[*]}"
        log_info "继续部署可能需要手动停止占用这些端口的服务"
    fi
}

# 安装JDK
install_jdk() {
    log_info "安装JDK 8..."

    if [[ -d $JAVA_INSTALL_DIR ]]; then
        log_info "JDK已安装，跳过"
        export JAVA_HOME=$JAVA_INSTALL_DIR
        return 0
    fi

    local jdk_url="https://download.java.net/java/GA/jdk8u412/b08/jdk-8u412-linux-x64.tar.gz"
    local jdk_file="/tmp/jdk-8u412-linux-x64.tar.gz"

    if [[ ! -f $jdk_file ]]; then
        log_info "下载JDK..."
        wget -O $jdk_file $jdk_url || {
            log_error "下载失败"
            exit 1
        }
    fi

    mkdir -p /opt/java
    tar -xzf $jdk_file -C /opt/java
    export JAVA_HOME=$JAVA_INSTALL_DIR

    log_info "✓ JDK安装完成"
}

# 安装ZooKeeper
install_zookeeper() {
    log_info "安装ZooKeeper..."

    if [[ -d $ZK_INSTALL_DIR ]]; then
        log_info "ZooKeeper已安装，跳过"
        return 0
    fi

    local zk_url="https://downloads.apache.org/zookeeper/zookeeper-${ZK_VERSION}/apache-zookeeper-${ZK_VERSION}-bin.tar.gz"
    local zk_file="/tmp/apache-zookeeper-${ZK_VERSION}-bin.tar.gz"

    if [[ ! -f $zk_file ]]; then
        log_info "下载ZooKeeper..."
        wget -O $zk_file $zk_url || {
            log_error "下载失败"
            exit 1
        }
    fi

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

# 安装Hadoop
install_hadoop() {
    log_info "安装Hadoop..."

    if [[ -d $HADOOP_INSTALL_DIR ]]; then
        log_info "Hadoop已安装，跳过"
        return 0
    fi

    local hadoop_url="https://downloads.apache.org/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz"
    local hadoop_file="/tmp/hadoop-${HADOOP_VERSION}.tar.gz"

    if [[ ! -f $hadoop_file ]]; then
        log_info "下载Hadoop..."
        wget -O $hadoop_file $hadoop_url || {
            log_error "下载失败"
            exit 1
        }
    fi

    tar -xzf $hadoop_file -C /opt
    mv /opt/hadoop-${HADOOP_VERSION} $HADOOP_INSTALL_DIR

    # 配置Hadoop
    mkdir -p /data/hadoop/{hdfs/tmp,hdfs/namenode,hdfs/datanode}

    # hadoop-env.sh
    sed -i "s|export JAVA_HOME=.*|export JAVA_HOME=$JAVA_HOME|" $HADOOP_INSTALL_DIR/etc/hadoop/hadoop-env.sh

    # core-site.xml
    cat > $HADOOP_INSTALL_DIR/etc/hadoop/core-site.xml <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
    <property>
        <name>fs.defaultFS</name>
        <value>hdfs://localhost:9000</value>
    </property>
    <property>
        <name>hadoop.tmp.dir</name>
        <value>/data/hadoop/hdfs/tmp</value>
    </property>
</configuration>
EOF

    # hdfs-site.xml
    cat > $HADOOP_INSTALL_DIR/etc/hadoop/hdfs-site.xml <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
    <property>
        <name>dfs.replication</name>
        <value>1</value>
    </property>
    <property>
        <name>dfs.namenode.name.dir</name>
        <value>/data/hadoop/hdfs/namenode</value>
    </property>
    <property>
        <name>dfs.datanode.data.dir</name>
        <value>/data/hadoop/hdfs/datanode</value>
    </property>
</configuration>
EOF

    log_info "✓ Hadoop安装完成"
}

# 安装HBase
install_hbase() {
    log_info "安装HBase..."

    if [[ -d $HBASE_INSTALL_DIR ]]; then
        log_info "HBase已安装，跳过"
        return 0
    fi

    local hbase_url="https://downloads.apache.org/hbase/${HBASE_VERSION}/hbase-${HBASE_VERSION}-bin.tar.gz"
    local hbase_file="/tmp/hbase-${HBASE_VERSION}-bin.tar.gz"

    if [[ ! -f $hbase_file ]]; then
        log_info "下载HBase..."
        wget -O $hbase_file $hbase_url || {
            log_error "下载失败"
            exit 1
        }
    fi

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

    # hbase-site.xml
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
</configuration>
EOF

    log_info "✓ HBase安装完成"
}

# 配置环境变量
configure_env() {
    log_info "配置环境变量..."

    local env_file="/root/.bashrc"
    cat >> $env_file <<'ENVEOF'

# Hadoop/HBase Environment
export JAVA_HOME=/opt/java/jdk1.8.0_412
export ZOOKEEPER_HOME=/opt/zookeeper
export HADOOP_HOME=/opt/hadoop
export HBASE_HOME=/opt/hbase
export PATH=$PATH:$JAVA_HOME/bin:$ZOOKEEPER_HOME/bin:$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$HBASE_HOME/bin
ENVEOF

    export JAVA_HOME=/opt/java/jdk1.8.0_412
    export ZOOKEEPER_HOME=/opt/zookeeper
    export HADOOP_HOME=/opt/hadoop
    export HBASE_HOME=/opt/hbase
    export PATH=$PATH:$JAVA_HOME/bin:$ZOOKEEPER_HOME/bin:$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$HBASE_HOME/bin

    log_info "✓ 环境变量配置完成"
}

# 启动服务
start_services() {
    log_info "启动服务..."

    # 启动ZooKeeper
    log_info "启动ZooKeeper..."
    $ZK_INSTALL_DIR/bin/zkServer.sh start
    sleep 3

    # 格式化HDFS
    if [[ ! -d /data/hadoop/hdfs/namenode/current ]]; then
        log_info "格式化HDFS..."
        $HADOOP_HOME/bin/hdfs namenode -format -force
    fi

    # 启动Hadoop
    log_info "启动Hadoop..."
    $HADOOP_HOME/sbin/start-dfs.sh
    sleep 5

    # 启动HBase
    log_info "启动HBase..."
    $HBASE_INSTALL_DIR/bin/start-hbase.sh
    sleep 5

    log_info "✓ 所有服务启动完成"
}

# 测试服务
test_services() {
    log_info "测试服务..."

    log_info "1. 检查Java版本:"
    java -version 2>&1 | head -1

    log_info "2. 检查ZooKeeper:"
    echo "ruok" | nc localhost 2181 2>/dev/null || echo "ZooKeeper未响应"

    log_info "3. 检查Hadoop:"
    $HADOOP_HOME/bin/hdfs dfsadmin -report 2>&1 | head -5

    log_info "4. 检查HBase进程:"
    jps | grep -E "(QuorumPeerMain|NameNode|DataNode|HMaster)"

    log_info "5. 端口监听状态:"
    netstat -tuln | grep -E ":(2181|9000|16010|16030|9870) " || true
}

# 主函数
main() {
    log_info "=========================================="
    log_info "HBase一键部署开始"
    log_info "=========================================="
    log_info ""

    check_ports
    install_jdk
    install_zookeeper
    install_hadoop
    install_hbase
    configure_env
    start_services

    log_info ""
    log_info "=========================================="
    log_info "部署完成!"
    log_info "=========================================="

    test_services

    log_info ""
    log_info "Web UI访问地址:"
    log_info "  Hadoop: http://172.16.47.57:9870"
    log_info "  HBase:  http://172.16.47.57:16010"
    log_info ""
    log_info "测试命令:"
    log_info "  hbase shell"
}

main "$@"
