#!/bin/bash
# HBase最终部署和测试脚本

set -e

GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${GREEN}=========================================="
echo "HBase 2.5.10 单机版部署"
echo "==========================================${NC}"

# 1. 配置hbase-env.sh
cat > /opt/hbase/conf/hbase-env.sh <<'EOF'
export JAVA_HOME=/usr/lib/jvm/jdk1.8.0_341
export HBASE_MANAGES_ZK=true
export HBASE_HEAPSIZE=4096
# HBase配置
export HBASE_CLASSPATH=/opt/hbase/conf
# 禁用HBase自带的ZK的admin服务器
export HBASE_OPTS="$HBASE_OPTS -Dzookeeper.admin.enableServer=false"
EOF

echo "✓ hbase-env.sh配置完成"

# 2. 配置hbase-site.xml
cat > /opt/hbase/conf/hbase-site.xml <<'EOF'
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
  <property>
    <name>hbase.rootdir</name>
    <value>file:///data/hbase</value>
  </property>
  <property>
    <name>hbase.zookeeper.property.dataDir</name>
    <value>/data/hbase/zookeeper</value>
  </property>
  <property>
    <name>hbase.cluster.distributed</name>
    <value>false</value>
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

echo "✓ hbase-site.xml配置完成"

# 3. 启动HBase
echo "启动HBase..."
/opt/hbase/bin/start-hbase.sh

# 4. 等待启动
echo "等待服务启动..."
sleep 10

# 5. 检查进程
echo ""
echo "=========================================="
echo "检查HBase进程"
echo "=========================================="
jps | grep -E "(HMaster|HRegionServer|QuorumPeerMain)" || echo "未找到HBase进程"

# 6. 检查端口
echo ""
echo "=========================================="
echo "检查端口监听"
echo "=========================================="
netstat -tuln | grep -E ":(16010|16030|2181) " || echo "端口未监听"

# 7. 测试HBase功能
echo ""
echo "=========================================="
echo "测试HBase功能"
echo "=========================================="
echo "创建测试表并插入数据..."

/opt/hbase/bin/hbase shell <<'EOT'
create 'test', 'cf'
put 'test', 'row1', 'cf:name', 'HBase测试'
put 'test', 'row2', 'cf:version', '2.5.10'
scan 'test'
exit
EOT

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ HBase功能测试通过${NC}"
else
    echo "HBase功能测试失败"
fi

echo ""
echo "=========================================="
echo -e "${GREEN}部署完成!${NC}"
echo "=========================================="
echo "Web UI: http://172.16.47.57:16010"
echo "命令行: hbase shell"
echo ""
