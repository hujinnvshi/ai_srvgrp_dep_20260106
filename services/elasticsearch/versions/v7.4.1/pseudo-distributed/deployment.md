# Elasticsearch 7.4.1 伪分布式集群部署指南

## 环境信息

- **目标服务器**: 172.16.47.57
- **部署路径**: /data
- **ES版本**: 7.4.1
- **部署模式**: 伪分布式集群（单机多节点）
- **执行用户**: root

## 架构设计

### 节点规划

在单台服务器上启动3个ES节点：

| 节点名称 | 节点角色 | 端口 | 数据路径 |
|---------|----------|------|----------|
| es-node-1 | master + data | 9200/9300 | /data/elasticsearch/node1 |
| es-node-2 | master + data | 9201/9301 | /data/elasticsearch/node2 |
| es-node-3 | master + data | 9202/9302 | /data/elasticsearch/node3 |

### 端口规划

- HTTP端口: 9200, 9201, 9202
- Transport端口: 9300, 9301, 9302

---

## 部署前检查清单

### 1. 系统环境检查

```bash
# 检查操作系统版本
cat /etc/redhat-release

# 检查内核版本
uname -r

# 检查可用内存
free -h

# 检查磁盘空间
df -h /data

# 检查CPU
lscpu | grep "^CPU(s):"
```

**最低要求**:
- 内存: 至少4GB（推荐8GB+）
- 磁盘: 至少20GB可用空间
- CPU: 至少2核

### 2. 端口占用检测

```bash
# 检查HTTP端口 9200-9202
for port in 9200 9201 9202; do
  echo "=== 检查端口 $port ==="
  netstat -tunlp | grep ":$port " || echo "端口 $port 可用"
done

# 检查Transport端口 9300-9302
for port in 9300 9301 9302; do
  echo "=== 检查端口 $port ==="
  netstat -tunlp | grep ":$port " || echo "端口 $port 可用"
done

# 如果端口被占用，查看占用进程
netstat -tunlp | grep -E ":(920[0-2]|930[0-2]) "
```

### 3. Java环境检查

```bash
# 检查Java版本
java -version

# 检查JAVA_HOME
echo $JAVA_HOME

# 如果未安装Java，Elasticsearch 7.4.1自带JDK
```

### 4. 系统参数检查

```bash
# 检查vm.max_map_count（需要至少262144）
sysctl vm.max_map_count

# 检查文件描述符限制
ulimit -n

# 检查最大进程数
ulimit -u
```

---

## 部署步骤

### 步骤1: 系统参数配置

```bash
# 1.1 设置vm.max_map_count
cat >> /etc/sysctl.conf << 'EOF'
# Elasticsearch 配置
vm.max_map_count=262144
EOF

# 应用配置
sysctl -p

# 验证
sysctl vm.max_map_count

# 1.2 设置文件描述符限制（临时）
ulimit -n 65536
ulimit -u 4096

# 永久设置（推荐）
cat >> /etc/security/limits.conf << 'EOF'
# Elasticsearch 用户限制
* soft nofile 65536
* hard nofile 65536
* soft nproc 4096
* hard nproc 4096
EOF
```

### 步骤2: 创建部署目录

```bash
# 创建基础目录
mkdir -p /data/elasticsearch

# 创建各节点目录
mkdir -p /data/elasticsearch/node1
mkdir -p /data/elasticsearch/node2
mkdir -p /data/elasticsearch/node3

# 创建日志目录
mkdir -p /data/elasticsearch/logs/node1
mkdir -p /data/elasticsearch/logs/node2
mkdir -p /data/elasticsearch/logs/node3

# 创建数据目录
mkdir -p /data/elasticsearch/data/node1
mkdir -p /data/elasticsearch/data/node2
mkdir -p /data/elasticsearch/data/node3

# 设置权限
chmod -R 755 /data/elasticsearch

# 验证目录结构
tree /data/elasticsearch -L 2
```

### 步骤3: 下载Elasticsearch

```bash
# 进入安装目录
cd /data/elasticsearch

# 下载 Elasticsearch 7.4.1
wget https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-7.4.1-linux-x86_64.tar.gz

# 如果下载慢，使用国内镜像
# wget https://mirrors.tuna.tsinghua.edu.cn/elasticstack/7.4.1/elasticsearch-linux-x86_64.tar.gz

# 解压
tar -xzf elasticsearch-7.4.1-linux-x86_64.tar.gz

# 重命名（可选）
# mv elasticsearch-7.4.1 elasticsearch-base

# 验证
ls -la /data/elasticsearch/elasticsearch-7.4.1/
```

### 步骤4: 配置节点1

```bash
# 创建节点1配置文件
cat > /data/elasticsearch/node1/elasticsearch.yml << 'EOF'
# 集群名称
cluster.name: es-pseudo-cluster

# 节点名称
node.name: es-node-1

# 节点角色
node.master: true
node.data: true
node.ingest: true

# 网络配置
network.host: 172.16.47.57
http.port: 9200
transport.port: 9300

# 数据和日志路径
path.data: /data/elasticsearch/data/node1
path.logs: /data/elasticsearch/logs/node1

# 集群发现
discovery.seed_hosts: ["172.16.47.57:9300", "172.16.47.57:9301", "172.16.47.57:9302"]
cluster.initial_master_nodes: ["es-node-1", "es-node-2", "es-node-3"]

# 内存锁定
bootstrap.memory_lock: false

# 单机开发模式允许
discovery.type: zen

# 防止分片未分配导致的集群状态异常
cluster.routing.allocation.disk.threshold_enabled: true
cluster.routing.allocation.disk.watermark.low: 85%
cluster.routing.allocation.disk.watermark.high: 90%
cluster.routing.allocation.disk.watermark.flood_stage: 95%

# 安全配置（可选，生产环境建议开启）
# xpack.security.enabled: false
# xpack.security.transport.ssl.enabled: false
EOF

# 配置JVM内存
cat > /data/elasticsearch/node1/jvm.options << 'EOF'
-Xms1g
-Xmx1g
-XX:+UseConcMarkSweepGC
-XX:CMSInitiatingOccupancyFraction=75
-XX:+UseCMSInitiatingOccupancyOnly
-Dfile.encoding=UTF-8
-Djava.io.tmpdir=${ES_TMPDIR}
-XX:+HeapDumpOnOutOfMemoryError
-XX:HeapDumpPath=/data/elasticsearch/logs/node1
EOF
```

### 步骤5: 配置节点2

```bash
# 创建节点2配置文件
cat > /data/elasticsearch/node2/elasticsearch.yml << 'EOF'
# 集群名称
cluster.name: es-pseudo-cluster

# 节点名称
node.name: es-node-2

# 节点角色
node.master: true
node.data: true
node.ingest: true

# 网络配置
network.host: 172.16.47.57
http.port: 9201
transport.port: 9301

# 数据和日志路径
path.data: /data/elasticsearch/data/node2
path.logs: /data/elasticsearch/logs/node2

# 集群发现
discovery.seed_hosts: ["172.16.47.57:9300", "172.16.47.57:9301", "172.16.47.57:9302"]
cluster.initial_master_nodes: ["es-node-1", "es-node-2", "es-node-3"]

# 内存锁定
bootstrap.memory_lock: false

# 单机开发模式允许
discovery.type: zen

cluster.routing.allocation.disk.threshold_enabled: true
cluster.routing.allocation.disk.watermark.low: 85%
cluster.routing.allocation.disk.watermark.high: 90%
cluster.routing.allocation.disk.watermark.flood_stage: 95%
EOF

# 配置JVM内存
cat > /data/elasticsearch/node2/jvm.options << 'EOF'
-Xms1g
-Xmx1g
-XX:+UseConcMarkSweepGC
-XX:CMSInitiatingOccupancyFraction=75
-XX:+UseCMSInitiatingOccupancyOnly
-Dfile.encoding=UTF-8
-Djava.io.tmpdir=${ES_TMPDIR}
-XX:+HeapDumpOnOutOfMemoryError
-XX:HeapDumpPath=/data/elasticsearch/logs/node2
EOF
```

### 步骤6: 配置节点3

```bash
# 创建节点3配置文件
cat > /data/elasticsearch/node3/elasticsearch.yml << 'EOF'
# 集群名称
cluster.name: es-pseudo-cluster

# 节点名称
node.name: es-node-3

# 节点角色
node.master: true
node.data: true
node.ingest: true

# 网络配置
network.host: 172.16.47.57
http.port: 9202
transport.port: 9302

# 数据和日志路径
path.data: /data/elasticsearch/data/node3
path.logs: /data/elasticsearch/logs/node3

# 集群发现
discovery.seed_hosts: ["172.16.47.57:9300", "172.16.47.57:9301", "172.16.47.57:9302"]
cluster.initial_master_nodes: ["es-node-1", "es-node-2", "es-node-3"]

# 内存锁定
bootstrap.memory_lock: false

# 单机开发模式允许
discovery.type: zen

cluster.routing.allocation.disk.threshold_enabled: true
cluster.routing.allocation.disk.watermark.low: 85%
cluster.routing.allocation.disk.watermark.high: 90%
cluster.routing.allocation.disk.watermark.flood_stage: 95%
EOF

# 配置JVM内存
cat > /data/elasticsearch/node3/jvm.options << 'EOF'
-Xms1g
-Xmx1g
-XX:+UseConcMarkSweepGC
-XX:CMSInitiatingOccupancyFraction=75
-XX:+UseCMSInitiatingOccupancyOnly
-Dfile.encoding=UTF-8
-Djava.io.tmpdir=${ES_TMPDIR}
-XX:+HeapDumpOnOutOfMemoryError
-XX:HeapDumpPath=/data/elasticsearch/logs/node3
EOF
```

### 步骤7: 创建启动脚本

```bash
# 创建节点1启动脚本
cat > /data/elasticsearch/start-node1.sh << 'EOF'
#!/bin/bash
export ES_HOME=/data/elasticsearch/elasticsearch-7.4.1
export ES_PATH_CONF=/data/elasticsearch/node1
export ES_JAVA_OPTS="-Des.path.conf=$ES_PATH_CONF"

cd $ES_HOME
nohup $ES_HOME/bin/elasticsearch -E $ES_PATH_CONF > /data/elasticsearch/logs/node1/console.log 2>&1 &

echo "节点1启动中，PID: $!"
sleep 3
tail -20 /data/elasticsearch/logs/node1/console.log
EOF

# 创建节点2启动脚本
cat > /data/elasticsearch/start-node2.sh << 'EOF'
#!/bin/bash
export ES_HOME=/data/elasticsearch/elasticsearch-7.4.1
export ES_PATH_CONF=/data/elasticsearch/node2
export ES_JAVA_OPTS="-Des.path.conf=$ES_PATH_CONF"

cd $ES_HOME
nohup $ES_HOME/bin/elasticsearch -E $ES_PATH_CONF > /data/elasticsearch/logs/node2/console.log 2>&1 &

echo "节点2启动中，PID: $!"
sleep 3
tail -20 /data/elasticsearch/logs/node2/console.log
EOF

# 创建节点3启动脚本
cat > /data/elasticsearch/start-node3.sh << 'EOF'
#!/bin/bash
export ES_HOME=/data/elasticsearch/elasticsearch-7.4.1
export ES_PATH_CONF=/data/elasticsearch/node3
export ES_JAVA_OPTS="-Des.path.conf=$ES_PATH_CONF"

cd $ES_HOME
nohup $ES_HOME/bin/elasticsearch -E $ES_PATH_CONF > /data/elasticsearch/logs/node3/console.log 2>&1 &

echo "节点3启动中，PID: $!"
sleep 3
tail -20 /data/elasticsearch/logs/node3/console.log
EOF

# 设置执行权限
chmod +x /data/elasticsearch/start-node*.sh
```

### 步骤8: 创建停止脚本

```bash
cat > /data/elasticsearch/stop-all.sh << 'EOF'
#!/bin/bash
echo "停止 Elasticsearch 集群..."

# 查找所有ES进程
PIDS=$(ps aux | grep 'elasticsearch' | grep -v grep | awk '{print $2}')

if [ -z "$PIDS" ]; then
    echo "没有运行的 Elasticsearch 进程"
else
    echo "找到以下进程:"
    ps aux | grep 'elasticsearch' | grep -v grep
    echo ""
    echo "正在停止..."
    kill $PIDS
    sleep 5

    # 如果进程仍然存在，强制杀死
    REMAINING=$(ps aux | grep 'elasticsearch' | grep -v grep | awk '{print $2}')
    if [ ! -z "$REMAINING" ]; then
        echo "强制停止进程..."
        kill -9 $REMAINING
    fi

    echo "集群已停止"
fi
EOF

chmod +x /data/elasticsearch/stop-all.sh
```

### 步骤9: 启动集群

```bash
# 依次启动节点
echo "=== 启动节点1 ==="
/data/elasticsearch/start-node1.sh

sleep 10

echo "=== 启动节点2 ==="
/data/elasticsearch/start-node2.sh

sleep 10

echo "=== 启动节点3 ==="
/data/elasticsearch/start-node3.sh

sleep 15
```

---

## 验证部署

### 1. 检查进程

```bash
# 查看所有ES进程
ps aux | grep elasticsearch | grep -v grep

# 应该看到3个Java进程
```

### 2. 检查端口

```bash
# 检查HTTP端口
netstat -tunlp | grep -E ":(9200|9201|9202) "

# 检查Transport端口
netstat -tunlp | grep -E ":(9300|9301|9302) "
```

### 3. 检查集群健康状态

```bash
# 检查集群健康
curl -X GET 'http://172.16.47.57:9200/_cluster/health?pretty'

# 预期输出: status为green或yellow
# number_of_nodes应该为3
```

### 4. 查看节点信息

```bash
# 查看所有节点
curl -X GET 'http://172.16.47.57:9200/_cat/nodes?v'

# 查看集群详细信息
curl -X GET 'http://172.16.47.57:9200/_cluster/state?pretty'
```

### 5. 查看日志

```bash
# 节点1日志
tail -f /data/elasticsearch/logs/node1/es-pseudo-cluster.log

# 节点2日志
tail -f /data/elasticsearch/logs/node2/es-pseudo-cluster.log

# 节点3日志
tail -f /data/elasticsearch/logs/node3/es-pseudo-cluster.log
```

---

## 使用指南

### 基本索引操作

```bash
# 1. 创建索引
curl -X PUT 'http://172.16.47.57:9200/test-index' -H 'Content-Type: application/json' -d'
{
  "settings": {
    "number_of_shards": 3,
    "number_of_replicas": 1
  },
  "mappings": {
    "properties": {
      "title": {
        "type": "text"
      },
      "content": {
        "type": "text"
      },
      "timestamp": {
        "type": "date"
      }
    }
  }
}
'

# 2. 查看索引
curl -X GET 'http://172.16.47.57:9200/_cat/indices?v'

# 3. 插入文档
curl -X POST 'http://172.16.47.57:9200/test-index/_doc' -H 'Content-Type: application/json' -d'
{
  "title": "测试文档",
  "content": "这是一个测试内容",
  "timestamp": "2026-01-06T10:00:00"
}
'

# 4. 搜索文档
curl -X GET 'http://172.16.47.57:9200/test-index/_search?pretty' -H 'Content-Type: application/json' -d'
{
  "query": {
    "match_all": {}
  }
}
'

# 5. 删除索引
curl -X DELETE 'http://172.16.47.57:9200/test-index'
```

### 集群管理

```bash
# 1. 查看分片分布
curl -X GET 'http://172.16.47.57:9200/_cat/shards?v'

# 2. 查看集群设置
curl -X GET 'http://172.16.47.57:9200/_cluster/settings?pretty'

# 3. 查看节点统计
curl -X GET 'http://172.16.47.57:9200/_nodes/stats?pretty'

# 4. 查看节点信息
curl -X GET 'http://172.16.47.57:9200/_nodes?pretty'
```

---

## 集群维护

### 日常维护

#### 1. 健康检查

```bash
# 创建健康检查脚本
cat > /data/elasticsearch/health-check.sh << 'EOF'
#!/bin/bash

echo "=== Elasticsearch 集群健康检查 ==="
echo ""

# 检查集群状态
echo "1. 集群状态:"
curl -s 'http://172.16.47.57:9200/_cluster/health?pretty' | grep -E "cluster_name|status|number_of_nodes|number_of_data_nodes"

echo ""

# 检查节点
echo "2. 节点列表:"
curl -s 'http://172.16.47.57:9200/_cat/nodes?v'

echo ""

# 检查索引
echo "3. 索引列表:"
curl -s 'http://172.16.47.57:9200/_cat/indices?v'

echo ""

# 检查磁盘使用
echo "4. 磁盘使用:"
df -h /data/elasticsearch

echo ""

# 检查进程
echo "5. 进程状态:"
ps aux | grep 'elasticsearch' | grep -v grep | wc -l
echo "运行的ES进程数"
EOF

chmod +x /data/elasticsearch/health-check.sh

# 定期执行
/data/elasticsearch/health-check.sh
```

#### 2. 日志清理

```bash
# 清理7天前的日志
find /data/elasticsearch/logs -name "*.log" -mtime +7 -delete

# 或者创建日志清理脚本
cat > /data/elasticsearch/clean-logs.sh << 'EOF'
#!/bin/bash
# 清理7天前的日志
find /data/elasticsearch/logs -name "*.log" -mtime +7 -delete
echo "日志清理完成: $(date)"
EOF

chmod +x /data/elasticsearch/clean-logs.sh

# 添加到crontab（每天凌晨2点执行）
# crontab -e
# 0 2 * * * /data/elasticsearch/clean-logs.sh >> /data/elasticsearch/logs/clean.log 2>&1
```

#### 3. 数据备份

```bash
# 注册快照仓库
curl -X PUT 'http://172.16.47.57:9200/_snapshot/backup' -H 'Content-Type: application/json' -d'
{
  "type": "fs",
  "settings": {
    "location": "/data/elasticsearch/backup"
  }
}
'

# 创建备份目录
mkdir -p /data/elasticsearch/backup

# 创建快照
curl -X PUT 'http://172.16.47.57:9200/_snapshot/backup/snapshot_1?wait_for_completion=true&pretty'

# 查看快照
curl -X GET 'http://172.16.47.57:9200/_snapshot/backup/_all?pretty'

# 恢复快照
curl -X POST 'http://172.16.47.57:9200/_snapshot/backup/snapshot_1/_restore?pretty'
```

### 性能优化

#### 1. JVM内存调整

如果服务器内存充足，可以增加JVM堆内存：

```bash
# 编辑各节点的jvm.options文件
# 例如调整为2GB
vi /data/elasticsearch/node1/jvm.options
# 修改: -Xms2g -Xmx2g

vi /data/elasticsearch/node2/jvm.options
vi /data/elasticsearch/node3/jvm.options

# 重启集群
/data/elasticsearch/stop-all.sh
sleep 10
/data/elasticsearch/start-node1.sh
sleep 10
/data/elasticsearch/start-node2.sh
sleep 10
/data/elasticsearch/start-node3.sh
```

#### 2. 分片配置优化

```bash
# 根据数据量调整分片数
# 对于小数据集，可以减少分片数
curl -X PUT 'http://172.16.47.57:9200/test-index' -H 'Content-Type: application/json' -d'
{
  "settings": {
    "number_of_shards": 1,
    "number_of_replicas": 1
  }
}
'
```

### 故障排查

#### 1. 节点无法启动

```bash
# 查看日志
tail -100 /data/elasticsearch/logs/node1/es-pseudo-cluster.log

# 常见问题：
# - 端口被占用: 检查9200-9202, 9300-9302端口
# - 内存不足: 调整JVM堆内存
# - 权限问题: 检查目录权限
# - 配置错误: 检查elasticsearch.yml语法
```

#### 2. 集群状态为red

```bash
# 查看未分配的分片
curl -X GET 'http://172.16.47.57:9200/_cat/shards?v' | grep UNASSIGNED

# 查看原因
curl -X GET 'http://172.16.47.57:9200/_cluster/allocation/explain?pretty'

# 解决方案
curl -X POST 'http://172.16.47.57:9200/_cluster/reroute?retry_failed=true'
```

#### 3. 性能问题

```bash
# 查看慢日志
curl -X GET 'http://172.16.47.57:9200/_nodes/stats/indices?pretty'

# 查看线程池
curl -X GET 'http://172.16.47.57:9200/_cat/thread_pool?v'
```

### 集群重启

```bash
# 1. 停止集群
/data/elasticsearch/stop-all.sh

# 2. 等待所有进程结束
sleep 10

# 3. 验证进程已停止
ps aux | grep elasticsearch | grep -v grep

# 4. 依次启动节点
/data/elasticsearch/start-node1.sh
sleep 10
/data/elasticsearch/start-node2.sh
sleep 10
/data/elasticsearch/start-node3.sh
sleep 15

# 5. 验证集群健康
curl -X GET 'http://172.16.47.57:9200/_cluster/health?pretty'
```

---

## 监控脚本

### 实时监控脚本

```bash
cat > /data/elasticsearch/monitor.sh << 'EOF'
#!/bin/bash

while true; do
  clear
  echo "=== Elasticsearch 集群实时监控 ==="
  echo "时间: $(date '+%Y-%m-%d %H:%M:%S')"
  echo ""

  # 集群状态
  echo "【集群状态】"
  curl -s 'http://172.16.47.57:9200/_cluster/health?pretty' | grep -E "cluster_name|status|number_of_nodes|active_shards"
  echo ""

  # 节点列表
  echo "【节点列表】"
  curl -s 'http://172.16.47.57:9200/_cat/nodes?v'
  echo ""

  # 索引统计
  echo "【索引统计】"
  curl -s 'http://172.16.47.57:9200/_cat/indices?v' | head -5
  echo ""

  # 系统资源
  echo "【系统资源】"
  echo "CPU: $(top -bn1 | grep 'Cpu(s)' | awk '{print $2}' | cut -d'%' -f1)%"
  echo "内存: $(free | grep Mem | awk '{printf("%.1f%%\n", ($3/$2) * 100.0)}')"
  echo "磁盘: $(df -h /data | tail -1 | awk '{print $5}')"
  echo ""

  sleep 10
done
EOF

chmod +x /data/elasticsearch/monitor.sh

# 运行监控
/data/elasticsearch/monitor.sh
```

---

## 注意事项

### 安全建议

1. **生产环境**: 配置xpack安全，启用认证
2. **防火墙**: 限制9200-9202端口访问
3. **备份**: 定期备份数据
4. **监控**: 配置告警监控

### 性能建议

1. **JVM堆内存**: 不超过31GB，设置为物理内存的50%
2. **分片数**: 单个分片20-50GB
3. **副本**: 至少1个副本保证高可用
4. **刷新间隔**: 根据需求调整refresh_interval

### 维护建议

1. **定期检查**: 集群健康、磁盘空间、日志
2. **版本升级**: 先在测试环境验证
3. **压力测试**: 上线前进行性能测试
4. **文档记录**: 记录所有变更和问题

---

## 附录

### A. 常用命令速查

```bash
# 启动集群
/data/elasticsearch/start-node1.sh && sleep 10 && /data/elasticsearch/start-node2.sh && sleep 10 && /data/elasticsearch/start-node3.sh

# 停止集群
/data/elasticsearch/stop-all.sh

# 健康检查
curl -X GET 'http://172.16.47.57:9200/_cluster/health?pretty'

# 查看节点
curl -X GET 'http://172.16.47.57:9200/_cat/nodes?v'

# 查看索引
curl -X GET 'http://172.16.47.57:9200/_cat/indices?v'

# 查看分片
curl -X GET 'http://172.16.47.57:9200/_cat/shards?v'
```

### B. 配置文件位置

```
/data/elasticsearch/
├── elasticsearch-7.4.1/          # ES安装目录
├── node1/                        # 节点1配置
│   ├── elasticsearch.yml
│   └── jvm.options
├── node2/                        # 节点2配置
│   ├── elasticsearch.yml
│   └── jvm.options
├── node3/                        # 节点3配置
│   ├── elasticsearch.yml
│   └── jvm.options
├── data/                         # 数据目录
│   ├── node1/
│   ├── node2/
│   └── node3/
├── logs/                         # 日志目录
│   ├── node1/
│   ├── node2/
│   └── node3/
├── start-node1.sh                # 启动脚本
├── start-node2.sh
├── start-node3.sh
├── stop-all.sh                   # 停止脚本
├── health-check.sh               # 健康检查
├── monitor.sh                    # 监控脚本
└── clean-logs.sh                 # 日志清理
```

### C. 故障排查流程

1. **检查日志**: tail -f /data/elasticsearch/logs/node*/es-pseudo-cluster.log
2. **检查端口**: netstat -tunlp | grep -E "920[0-2]|930[0-2]"
3. **检查进程**: ps aux | grep elasticsearch
4. **检查配置**: 验证elasticsearch.yml语法
5. **检查资源**: free -h, df -h
6. **查看集群状态**: curl获取健康状态

### D. 联系支持

遇到问题时，请准备以下信息：
1. 错误日志
2. 集群状态
3. 配置文件
4. 系统资源使用情况

---

**文档版本**: 1.0
**更新日期**: 2026-01-06
**维护人员**: AI服务组
