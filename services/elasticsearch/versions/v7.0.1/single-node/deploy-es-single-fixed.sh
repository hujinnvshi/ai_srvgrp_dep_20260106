#!/bin/bash
# Elasticsearch 7.0.1 单节点自动部署脚本
# 目标服务器: 172.16.47.57
# 部署路径: /data3
# 执行用户: root
# 端口: HTTP 9210, Transport 9310

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 配置变量
ES_VERSION="7.0.1"
ES_HOME="/data3/elasticsearch"
ES_DATA="/data3/elasticsearch/data"
ES_LOGS="/data3/elasticsearch/logs"
ES_PORT="9210"
ES_TRANSPORT_PORT="9310"
ES_USER="elastic"

echo -e "${GREEN}"
echo "=========================================="
echo "  Elasticsearch 7.0.1 单节点部署"
echo "=========================================="
echo -e "${NC}"
echo ""
echo "部署信息："
echo "  版本: $ES_VERSION"
echo "  安装目录: $ES_HOME"
echo "  数据目录: $ES_DATA"
echo "  日志目录: $ES_LOGS"
echo "  HTTP端口: $ES_PORT"
echo "  Transport端口: $ES_TRANSPORT_PORT"
echo ""

# 步骤1: 创建目录结构
echo -e "${YELLOW}[1/8]${NC} 创建目录结构..."
mkdir -p $ES_DATA
mkdir -p $ES_LOGS
mkdir -p $ES_HOME/config
echo -e "${GREEN}✅ 目录创建完成${NC}"

# 步骤2: 下载ES
echo -e "${YELLOW}[2/8]${NC} 下载 Elasticsearch $ES_VERSION..."
cd /data3
if [ ! -f "elasticsearch-$ES_VERSION-linux-x86_64.tar.gz" ]; then
    echo "开始下载..."
    wget https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-$ES_VERSION-linux-x86_64.tar.gz
    echo -e "${GREEN}✅ 下载完成${NC}"
else
    echo -e "${GREEN}✅ 安装包已存在，跳过下载${NC}"
fi

# 步骤3: 解压
echo -e "${YELLOW}[3/8]${NC} 解压安装包..."
if [ ! -d "$ES_HOME" ] || [ ! -f "$ES_HOME/bin/elasticsearch" ]; then
    echo "正在解压..."
    tar -xzf elasticsearch-$ES_VERSION-linux-x86_64.tar.gz
    mv elasticsearch-$ES_VERSION elasticsearch-temp
    # 复制文件到目标目录
    cp -r elasticsearch-temp/* $ES_HOME/
    rm -rf elasticsearch-temp
    echo -e "${GREEN}✅ 解压完成${NC}"
else
    echo -e "${GREEN}✅ ES已安装，跳过解压${NC}"
fi

# 步骤4: 创建配置文件
echo -e "${YELLOW}[4/8]${NC} 创建配置文件..."
cat > $ES_HOME/config/elasticsearch.yml << 'EOF'
# 集群名称
cluster.name: es-701-single-node

# 节点名称
node.name: es-701-node-1

# 网络配置
network.host: 0.0.0.0
http.port: 9210
transport.port: 9310

# 数据和日志路径
path.data: /data3/elasticsearch/data
path.logs: /data3/elasticsearch/logs

# 单节点模式
discovery.type: single-node

# 内存锁定
bootstrap.memory_lock: false

# 安全配置（生产环境建议开启）
# xpack.security.enabled: false
# xpack.security.transport.ssl.enabled: false

# 防止分片未分配
cluster.routing.allocation.disk.threshold_enabled: true
cluster.routing.allocation.disk.watermark.low: 85%
cluster.routing.allocation.disk.watermark.high: 90%
cluster.routing.allocation.disk.watermark.flood_stage: 95%
EOF

echo -e "${GREEN}✅ 配置文件创建完成${NC}"

# 步骤5: 配置JVM内存
echo -e "${YELLOW}[5/8]${NC} 配置JVM内存..."
# 根据系统内存自动配置（建议不超过31GB，设置为物理内存的50%）
TOTAL_MEM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
TOTAL_MEM_GB=$((TOTAL_MEM_KB / 1024 / 1024))
HEAP_SIZE=$((TOTAL_MEM_GB / 2))

# 限制最大31GB
if [ $HEAP_SIZE -gt 31 ]; then
    HEAP_SIZE=31
fi

cat > $ES_HOME/config/jvm.options << EOF
-Xms${HEAP_SIZE}g
-Xmx${HEAP_SIZE}g

-XX:+UseConcMarkSweepGC
-XX:CMSInitiatingOccupancyFraction=75
-XX:+UseCMSInitiatingOccupancyOnly

-Dfile.encoding=UTF-8
-Djava.io.tmpdir=\${ES_TMPDIR}

-XX:+HeapDumpOnOutOfMemoryError
-XX:HeapDumpPath=/data3/elasticsearch/logs

8-10:-XX:+PrintGCDetails
8-10:-XX:+PrintGCTimeStamps
8-10:-XX:+PrintGCDateStamps
8-10:-XX:+PrintGCCause
8-10:-XX:+PrintGCApplicationStoppedTime
EOF

echo -e "${GREEN}✅ JVM配置完成（堆内存: ${HEAP_SIZE}GB）${NC}"

# 步骤6: 创建启动脚本
echo -e "${YELLOW}[6/8]${NC} 创建启动脚本..."
cat > /data3/start-es-701.sh << 'EOF'
#!/bin/bash
export ES_HOME=/data3/elasticsearch
cd $ES_HOME
nohup $ES_HOME/bin/elasticsearch > $ES_HOME/logs/console.log 2>&1 &
echo "Elasticsearch 7.0.1 启动中，PID: $!"
sleep 3
tail -20 $ES_HOME/logs/console.log
EOF

chmod +x /data3/start-es-701.sh

cat > /data3/stop-es-701.sh << 'EOF'
#!/bin/bash
echo "停止 Elasticsearch 7.0.1..."
PIDS=$(ps aux | grep 'elasticsearch' | grep 'data3' | grep -v grep | awk '{print $2}')
if [ -z "$PIDS" ]; then
    echo "没有运行的 Elasticsearch 7.0.1 进程"
else
    echo "找到以下进程:"
    ps aux | grep 'elasticsearch' | grep 'data3' | grep -v grep
    echo ""
    kill $PIDS
    sleep 5
    REMAINING=$(ps aux | grep 'elasticsearch' | grep 'data3' | grep -v grep | awk '{print $2}')
    if [ ! -z "$REMAINING" ]; then
        echo "强制停止进程..."
        kill -9 $REMAINING
    fi
    echo "Elasticsearch 7.0.1 已停止"
fi
EOF

chmod +x /data3/stop-es-701.sh

echo -e "${GREEN}✅ 启动脚本创建完成${NC}"

# 步骤7: 启动ES
echo -e "${YELLOW}[7/8]${NC} 启动 Elasticsearch..."
cd $ES_HOME
# 停止可能存在的旧进程
/data3/stop-es-701.sh 2>/dev/null || true
sleep 2
# 启动新进程
/data3/start-es-701.sh

# 等待ES启动
echo ""
echo "等待 Elasticsearch 启动..."
for i in {1..30}; do
    if curl -s http://localhost:9210 >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Elasticsearch 启动成功！${NC}"
        break
    fi
    if [ $i -eq 30 ]; then
        echo -e "${RED}❌ Elasticsearch 启动超时${NC}"
        echo "请检查日志: tail -f $ES_LOGS/es-701-single-node.log"
        exit 1
    fi
    sleep 2
    echo -n "."
done
echo ""

# 步骤8: 验证
echo -e "${YELLOW}[8/8]${NC} 验证部署..."
echo ""
echo "=== 集群信息 ==="
curl -s http://localhost:9210
echo ""
echo ""
echo "=== 节点信息 ==="
curl -s http://localhost:9210/_cat/nodes?v
echo ""
echo ""
echo "=== 健康检查 ==="
curl -s http://localhost:9210/_cluster/health?pretty
echo ""
echo ""
echo "=== 插件列表 ==="
curl -s http://localhost:9210/_cat/plugins?v
echo ""

echo -e "${GREEN}"
echo "=========================================="
echo "  ✅ 部署完成！"
echo "=========================================="
echo -e "${NC}"
echo ""
echo "服务信息："
echo "  版本: Elasticsearch $ES_VERSION"
echo "  部署路径: $ES_HOME"
echo "  数据目录: $ES_DATA"
echo "  日志目录: $ES_LOGS"
echo "  HTTP端口: $ES_PORT"
echo "  Transport端口: $ES_TRANSPORT_PORT"
echo "  访问地址: http://172.16.47.57:9210"
echo ""
echo "管理命令："
echo "  启动: /data3/start-es-701.sh"
echo "  停止: /data3/stop-es-701.sh"
echo "  查看日志: tail -f $ES_LOGS/es-701-single-node.log"
echo ""
echo "测试命令："
echo "  curl http://localhost:9210"
echo "  curl http://localhost:9210/_cat/health?v"
echo ""
echo -e "${YELLOW}注意：${NC}"
echo "  - 本版本使用端口 9210/9310，与 7.4.1 版本（9200/9300）不冲突"
echo "  - 如需外网访问，请配置防火墙开放9210端口"
echo "  - 生产环境建议配置 xpack 安全认证"
echo "  - 日志文件: $ES_LOGS/es-701-single-node.log"
echo ""
