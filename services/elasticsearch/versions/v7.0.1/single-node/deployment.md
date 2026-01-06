# Elasticsearch 7.0.1 单节点部署指南

## 环境信息

- **目标服务器**: 172.16.47.57
- **部署路径**: /data3
- **ES版本**: 7.0.1
- **部署模式**: 单节点
- **执行用户**: root
- **HTTP端口**: 9210
- **Transport端口**: 9310

## 版本说明

### 与 7.4.1 版本的区别

本部署在**同一台服务器**上运行与 7.4.1 版本不同的实例，主要区别：

| 项目 | 7.4.1 版本 | 7.0.1 版本 |
|------|-----------|-----------|
| 部署路径 | /data2/elasticsearch | /data3/elasticsearch |
| HTTP端口 | 9200 | 9210 |
| Transport端口 | 9300 | 9310 |
| 集群名称 | es-single-node | es-701-single-node |
| 节点名称 | es-node-1 | es-701-node-1 |

### 为什么要部署 7.0.1 版本？

1. **版本兼容性测试**: 测试应用在不同 ES 版本下的兼容性
2. **平滑升级**: 在升级到新版本前进行迁移测试
3. **功能对比**: 对比不同版本之间的功能差异
4. **多版本并存**: 支持不同应用使用不同版本的 ES

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

# 检查 /data3 磁盘空间
df -h /data3

# 检查CPU
lscpu | grep "^CPU(s):"
```

**最低要求**:
- 内存: 至少4GB（推荐8GB+）
- 磁盘: 至少20GB可用空间
- CPU: 至少2核

### 2. 端口占用检测

```bash
# 检查HTTP端口 9210
netstat -tunlp | grep ":9210 " || echo "端口 9210 可用"

# 检查Transport端口 9310
netstat -tunlp | grep ":9310 " || echo "端口 9310 可用"

# 检查 7.4.1 版本端口
netstat -tunlp | grep -E ":(9200|9300) "
```

### 3. Java环境检查

```bash
# 检查Java版本
java -version

# 检查JAVA_HOME
echo $JAVA_HOME

# Elasticsearch 7.0.1 自带 JDK
```

### 4. 系统参数检查

```bash
# 检查vm.max_map_count（需要至少262144）
sysctl vm.max_map_count

# 检查文件描述符限制
ulimit -n

# 检查最大进程数
ulimit -u

# 如果未配置，参考 7.4.1 部署文档进行配置
```

---

## 快速部署

### 使用自动部署脚本

```bash
# 1. 上传部署脚本到服务器
scp services/elasticsearch/versions/v7.0.1/single-node/deploy-es-single-fixed.sh root@172.16.47.57:/root/

# 2. 登录服务器
ssh root@172.16.47.57

# 3. 创建 /data3 目录（如果不存在）
mkdir -p /data3

# 4. 赋予执行权限
chmod +x /root/deploy-es-single-fixed.sh

# 5. 执行部署脚本
cd /root
./deploy-es-single-fixed.sh
```

脚本会自动完成以下步骤：
1. 创建目录结构
2. 下载 Elasticsearch 7.0.1
3. 解压安装
4. 配置 elasticsearch.yml
5. 配置 JVM 内存
6. 创建启动/停止脚本
7. 启动服务
8. 验证部署

---

## 手动部署步骤

如果需要手动部署，请按照以下步骤操作：

### 步骤1: 创建目录结构

```bash
# 创建基础目录
mkdir -p /data3/elasticsearch
mkdir -p /data3/elasticsearch/data
mkdir -p /data3/elasticsearch/logs
mkdir -p /data3/elasticsearch/config

# 设置权限
chmod -R 755 /data3/elasticsearch
```

### 步骤2: 下载安装包

```bash
# 进入安装目录
cd /data3

# 下载 Elasticsearch 7.0.1
wget https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-7.0.1-linux-x86_64.tar.gz

# 解压
tar -xzf elasticsearch-7.0.1-linux-x86_64.tar.gz

# 复制文件到目标目录
mv elasticsearch-7.0.1 elasticsearch-temp
cp -r elasticsearch-temp/* /data3/elasticsearch/
rm -rf elasticsearch-temp
```

### 步骤3: 配置 elasticsearch.yml

```bash
cat > /data3/elasticsearch/config/elasticsearch.yml << 'EOF'
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
```

### 步骤4: 配置 JVM 内存

```bash
# 根据系统内存自动配置
TOTAL_MEM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
TOTAL_MEM_GB=$((TOTAL_MEM_KB / 1024 / 1024))
HEAP_SIZE=$((TOTAL_MEM_GB / 2))

# 限制最大31GB
if [ $HEAP_SIZE -gt 31 ]; then
    HEAP_SIZE=31
fi

cat > /data3/elasticsearch/config/jvm.options << EOF
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
```

### 步骤5: 创建启动脚本

```bash
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
```

### 步骤6: 启动服务

```bash
# 启动 Elasticsearch 7.0.1
/data3/start-es-701.sh

# 等待启动（约30秒）
sleep 30
```

---

## 验证部署

### 1. 检查进程

```bash
# 查看 7.0.1 进程
ps aux | grep 'elasticsearch' | grep 'data3' | grep -v grep

# 查看所有 ES 进程（包括 7.4.1）
ps aux | grep elasticsearch | grep -v grep
```

### 2. 检查端口

```bash
# 检查 7.0.1 端口
netstat -tunlp | grep -E ":(9210|9310) "

# 检查所有 ES 端口
netstat -tunlp | grep -E ":(9200|9210|9300|9310) "
```

### 3. 检查服务健康

```bash
# 检查 7.0.1 版本
curl http://localhost:9210

# 预期输出包含 "version" : "7.0.1"

# 检查集群健康
curl http://localhost:9210/_cluster/health?pretty

# 检查节点信息
curl http://localhost:9210/_cat/nodes?v
```

### 4. 同时测试两个版本

```bash
# 测试 7.4.1 版本
echo "=== Elasticsearch 7.4.1 ==="
curl -s http://localhost:9200 | grep version

# 测试 7.0.1 版本
echo "=== Elasticsearch 7.0.1 ==="
curl -s http://localhost:9210 | grep version
```

---

## 使用指南

### 基本索引操作

```bash
# 1. 创建索引
curl -X PUT 'http://172.16.47.57:9210/test-index' -H 'Content-Type: application/json' -d'
{
  "settings": {
    "number_of_shards": 1,
    "number_of_replicas": 0
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
curl -X GET 'http://172.16.47.57:9210/_cat/indices?v'

# 3. 插入文档
curl -X POST 'http://172.16.47.57:9210/test-index/_doc' -H 'Content-Type: application/json' -d'
{
  "title": "测试文档 - ES 7.0.1",
  "content": "这是一个在 Elasticsearch 7.0.1 上的测试内容",
  "timestamp": "2026-01-06T10:00:00"
}
'

# 4. 搜索文档
curl -X GET 'http://172.16.47.57:9210/test-index/_search?pretty' -H 'Content-Type: application/json' -d'
{
  "query": {
    "match_all": {}
  }
}
'

# 5. 删除索引
curl -X DELETE 'http://172.16.47.57:9210/test-index'
```

### 管理命令

```bash
# 启动
/data3/start-es-701.sh

# 停止
/data3/stop-es-701.sh

# 查看日志
tail -f /data3/elasticsearch/logs/es-701-single-node.log

# 查看控制台日志
tail -f /data3/elasticsearch/logs/console.log

# 重启服务
/data3/stop-es-701.sh
sleep 5
/data3/start-es-701.sh
```

---

## 版本对比测试

### 数据迁移测试

```bash
# 从 7.0.1 导出数据
# 创建快照仓库
curl -X PUT 'http://localhost:9210/_snapshot/backup' -H 'Content-Type: application/json' -d'
{
  "type": "fs",
  "settings": {
    "location": "/data3/elasticsearch/backup"
  }
}
'

mkdir -p /data3/elasticsearch/backup

# 创建快照
curl -X PUT 'http://localhost:9210/_snapshot/backup/snapshot_1?wait_for_completion=true&pretty'

# 查看快照
curl -X GET 'http://localhost:9210/_snapshot/backup/_all?pretty'
```

### 性能对比

```bash
# 在两个版本上创建相同的索引进行性能测试

# 7.4.1 版本
echo "=== Testing ES 7.4.1 ==="
time curl -X POST 'http://localhost:9200/test-perf/_doc' -H 'Content-Type: application/json' -d'
{
  "title": "Performance Test",
  "content": "This is a performance test document",
  "timestamp": "2026-01-06T10:00:00"
}'

# 7.0.1 版本
echo "=== Testing ES 7.0.1 ==="
time curl -X POST 'http://localhost:9210/test-perf/_doc' -H 'Content-Type: application/json' -d'
{
  "title": "Performance Test",
  "content": "This is a performance test document",
  "timestamp": "2026-01-06T10:00:00"
}'
```

---

## 故障排查

### 1. 端口冲突

```bash
# 检查端口占用
netstat -tunlp | grep -E ":(9210|9310) "

# 如果端口被占用，查找进程
lsof -i :9210
lsof -i :9310

# 停止占用端口的进程
kill -9 <PID>
```

### 2. 内存不足

```bash
# 查看系统内存
free -h

# 调整 JVM 堆内存
vi /data3/elasticsearch/config/jvm.options
# 修改 -Xms 和 -Xmx 值

# 重启服务
/data3/stop-es-701.sh
/data3/start-es-701.sh
```

### 3. 启动失败

```bash
# 查看日志
tail -100 /data3/elasticsearch/logs/es-701-single-node.log

# 检查配置文件
cat /data3/elasticsearch/config/elasticsearch.yml

# 验证 Java 环境
java -version

# 检查系统参数
sysctl vm.max_map_count
ulimit -n
```

### 4. 集群状态异常

```bash
# 检查集群健康
curl http://localhost:9210/_cluster/health?pretty

# 查看节点信息
curl http://localhost:9210/_cat/nodes?v

# 查看未分配的分片
curl http://localhost:9210/_cat/shards?v | grep UNASSIGNED
```

---

## 开机自启动

### 创建 systemd 服务

```bash
cat > /etc/systemd/system/elasticsearch-701.service << 'EOF'
[Unit]
Description=Elasticsearch 7.0.1
Documentation=http://www.elastic.co
Wants=network-online.target
After=network-online.target

[Service]
Type=notify
RuntimeDirectory=elasticsearch
PrivateTmp=true
Environment=ES_HOME=/data3/elasticsearch
Environment=ES_PATH_CONF=/data3/elasticsearch/config
WorkingDirectory=/data3/elasticsearch

ExecStart=/data3/elasticsearch/bin/elasticsearch
StandardOutput=journal
StandardError=journal
SyslogIdentifier=elasticsearch-701

# Restart policy
Restart=always
RestartSec=10

# Resource limits
LimitNOFILE=65536
LimitNPROC=4096
LimitAS=infinity
LimitFSIZE=infinity
TimeoutStopSec=0

# Security
NoNewPrivileges=true
MemoryLimit=32G

[Install]
WantedBy=multi-user.target
EOF

# 重载 systemd
systemctl daemon-reload

# 启用开机自启
systemctl enable elasticsearch-701.service

# 启动服务
systemctl start elasticsearch-701.service

# 查看状态
systemctl status elasticsearch-701.service

# 查看日志
journalctl -u elasticsearch-701.service -f
```

---

## 监控脚本

### 健康检查脚本

```bash
cat > /data3/health-check-701.sh << 'EOF'
#!/bin/bash

echo "=== Elasticsearch 7.0.1 健康检查 ==="
echo "时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# 检查服务状态
echo "1. 服务状态:"
if curl -s http://localhost:9210 >/dev/null 2>&1; then
    echo "✅ 服务运行正常"
else
    echo "❌ 服务未运行"
    exit 1
fi

echo ""

# 检查版本
echo "2. 版本信息:"
curl -s http://localhost:9210 | grep -E "version|cluster_name"

echo ""

# 检查集群健康
echo "3. 集群健康:"
curl -s http://localhost:9210/_cluster/health?pretty | grep -E "status|number_of_nodes"

echo ""

# 检查进程
echo "4. 进程状态:"
PROCESS_COUNT=$(ps aux | grep 'elasticsearch' | grep 'data3' | grep -v grep | wc -l)
echo "运行的 ES 7.0.1 进程数: $PROCESS_COUNT"

echo ""

# 检查端口
echo "5. 端口状态:"
netstat -tunlp | grep -E ":(9210|9310) " || echo "端口未监听"

echo ""

# 检查磁盘使用
echo "6. 磁盘使用:"
df -h /data3 | tail -1

echo ""

# 检查日志大小
echo "7. 日志大小:"
du -sh /data3/elasticsearch/logs/*
EOF

chmod +x /data3/health-check-701.sh

# 执行检查
/data3/health-check-701.sh
```

---

## 注意事项

### 端口管理

1. **7.0.1 版本端口**: 9210 (HTTP), 9310 (Transport)
2. **7.4.1 版本端口**: 9200 (HTTP), 9300 (Transport)
3. 确保防火墙同时开放所需端口
4. 应用连接时注意区分端口

### 资源隔离

1. **数据目录**: /data3 与 /data2 分离
2. **日志目录**: 独立的日志文件
3. **进程管理**: 使用不同的启动脚本
4. **资源限制**: 根据实际情况调整 JVM 内存

### 安全建议

1. **生产环境**: 启用 xpack 安全认证
2. **网络隔离**: 使用防火墙限制访问
3. **定期备份**: 备份重要数据
4. **监控告警**: 配置监控和告警

### 版本共存

1. **独立进程**: 两个版本作为独立进程运行
2. **资源竞争**: 注意内存和磁盘资源分配
3. **端口冲突**: 确保端口不冲突
4. **数据独立**: 两个版本的数据完全独立

---

## 附录

### A. 配置文件位置

```
/data3/elasticsearch/
├── bin/                    # 可执行文件
├── config/                 # 配置文件
│   ├── elasticsearch.yml   # 主配置文件
│   └── jvm.options         # JVM 配置
├── data/                   # 数据目录
├── logs/                   # 日志目录
│   ├── es-701-single-node.log
│   └── console.log
├── plugins/                # 插件目录
└── lib/                    # 依赖库
```

### B. 常用命令

```bash
# 启动
/data3/start-es-701.sh

# 停止
/data3/stop-es-701.sh

# 重启
/data3/stop-es-701.sh && sleep 5 && /data3/start-es-701.sh

# 健康检查
curl http://localhost:9210/_cluster/health?pretty

# 查看节点
curl http://localhost:9210/_cat/nodes?v

# 查看索引
curl http://localhost:9210/_cat/indices?v

# 查看日志
tail -f /data3/elasticsearch/logs/es-701-single-node.log
```

### C. 与 7.4.1 对比

| 功能 | 7.0.1 | 7.4.1 | 说明 |
|-----|-------|-------|------|
| 端口 | 9210/9310 | 9200/9300 | 避免冲突 |
| 路径 | /data3 | /data2 | 数据分离 |
| 集群名 | es-701-single-node | es-single-node | 独立集群 |
| 节点名 | es-701-node-1 | es-node-1 | 独立节点 |

### D. 版本共存管理

```bash
# 同时启动两个版本
echo "=== 启动 Elasticsearch 7.4.1 ==="
/data2/start-es.sh
sleep 10

echo "=== 启动 Elasticsearch 7.0.1 ==="
/data3/start-es-701.sh
sleep 10

# 检查两个版本状态
echo "=== Elasticsearch 7.4.1 ==="
curl -s http://localhost:9200 | grep version

echo "=== Elasticsearch 7.0.1 ==="
curl -s http://localhost:9210 | grep version

# 同时停止
/data2/stop-es.sh
/data3/stop-es-701.sh
```

---

**文档版本**: 1.0
**ES版本**: 7.0.1
**更新日期**: 2026-01-06
**维护人员**: AI服务组
