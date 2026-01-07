#!/bin/bash
# ============================================================================
# Hadoop 安装脚本 (伪分布式模式)
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
HADOOP_VERSION="3.3.6"
HADOOP_INSTALL_DIR="/opt/hadoop"
HADOOP_DATA_DIR="/data/hadoop"

install_hadoop() {
    log_info "安装 Hadoop ${HADOOP_VERSION}..."

    local hadoop_url="https://downloads.apache.org/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz"
    local hadoop_file="/tmp/hadoop-${HADOOP_VERSION}.tar.gz"

    if [[ ! -f $hadoop_file ]]; then
        log_info "下载 Hadoop..."
        wget -O $hadoop_file $hadoop_url || {
            log_error "下载失败"
            exit 1
        }
    fi

    log_info "解压 Hadoop..."
    sudo tar -xzf $hadoop_file -C /opt
    sudo mv /opt/hadoop-${HADOOP_VERSION} $HADOOP_INSTALL_DIR

    log_info "✓ Hadoop 安装完成"
}

configure_hadoop() {
    log_info "配置 Hadoop..."

    # 创建数据目录
    sudo mkdir -p ${HADOOP_DATA_DIR}/{hdfs/tmp,hdfs/namenode,hdfs/datanode}
    sudo chown -R $USER:$USER $HADOOP_DATA_DIR

    # 配置 hadoop-env.sh
    local java_home=$(dirname $(dirname $(readlink -f $(which java))))
    sudo sed -i "s|export JAVA_HOME=.*|export JAVA_HOME=$java_home|" $HADOOP_INSTALL_DIR/etc/hadoop/hadoop-env.sh

    # 配置 core-site.xml
    sudo tee $HADOOP_INSTALL_DIR/etc/hadoop/core-site.xml > /dev/null <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
    <property>
        <name>fs.defaultFS</name>
        <value>hdfs://localhost:9000</value>
    </property>
    <property>
        <name>hadoop.tmp.dir</name>
        <value>${HADOOP_DATA_DIR}/hdfs/tmp</value>
    </property>
</configuration>
EOF

    # 配置 hdfs-site.xml
    sudo tee $HADOOP_INSTALL_DIR/etc/hadoop/hdfs-site.xml > /dev/null <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
    <property>
        <name>dfs.replication</name>
        <value>1</value>
    </property>
    <property>
        <name>dfs.namenode.name.dir</name>
        <value>${HADOOP_DATA_DIR}/hdfs/namenode</value>
    </property>
    <property>
        <name>dfs.datanode.data.dir</name>
        <value>${HADOOP_DATA_DIR}/hdfs/datanode</value>
    </property>
    <property>
        <name>dfs.webhdfs.enabled</name>
        <value>true</value>
    </property>
</configuration>
EOF

    # 配置 mapred-site.xml
    sudo tee $HADOOP_INSTALL_DIR/etc/hadoop/mapred-site.xml > /dev/null <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
    <property>
        <name>mapreduce.framework.name</name>
        <value>yarn</value>
    </property>
    <property>
        <name>mapreduce.jobhistory.address</name>
        <value>localhost:10020</value>
    </property>
</configuration>
EOF

    # 配置 yarn-site.xml
    sudo tee $HADOOP_INSTALL_DIR/etc/hadoop/yarn-site.xml > /dev/null <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
    <property>
        <name>yarn.nodemanager.aux-services</name>
        <value>mapreduce_shuffle</value>
    </property>
    <property>
        <name>yarn.resourcemanager.hostname</name>
        <value>localhost</value>
    </property>
</configuration>
EOF

    log_info "✓ Hadoop 配置完成"
}

configure_env_vars() {
    log_info "配置 Hadoop 环境变量..."

    local env_file="$HOME/.bashrc"
    local hadoop_env="
# Hadoop Environment
export HADOOP_HOME=${HADOOP_INSTALL_DIR}
export HADOOP_CONF_DIR=\$HADOOP_HOME/etc/hadoop
export HADOOP_MAPRED_HOME=\$HADOOP_HOME
export HADOOP_COMMON_HOME=\$HADOOP_HOME
export HADOOP_HDFS_HOME=\$HADOOP_HOME
export YARN_HOME=\$HADOOP_HOME
export PATH=\$PATH:\$HADOOP_HOME/bin:\$HADOOP_HOME/sbin
"

    if ! grep -q "HADOOP_HOME" $env_file; then
        echo "$hadoop_env" >> $env_file
        log_info "✓ 环境变量已添加"
    else
        log_info "环境变量已存在"
    fi
}

format_namenode() {
    log_info "格式化 HDFS NameNode..."
    $HADOOP_INSTALL_DIR/bin/hdfs namenode -format
}

main() {
    log_info "=========================================="
    log_info "Hadoop 安装脚本"
    log_info "=========================================="
    log_info ""

    install_hadoop
    configure_hadoop
    configure_env_vars

    log_info ""
    log_info "Hadoop 安装完成"
    log_info "执行: source ~/.bashrc 使环境变量生效"
    log_info "下一步: ./05-install-hbase.sh"
}

main "$@"
