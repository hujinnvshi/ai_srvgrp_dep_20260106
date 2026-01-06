# 集群服务部署指南

本文档介绍 Elasticsearch、Zookeeper 等集群服务的部署流程和最佳实践。

## 目录
- [Elasticsearch 部署](#elasticsearch-部署)
- [Zookeeper 部署](#zookeeper-部署)

---

## Elasticsearch 部署

### 版本支持
- 7.10.x
- 7.17.x (LTS)
- 8.x (推荐)

### 架构说明

#### 节点类型
- **Master-eligible**: 负责集群状态管理
- **Data**: 存储数据和执行查询
- **Coordinating**: 协调节点，分发查询
- **Ingest**: 数据预处理节点

### 环境要求

#### 硬件要求
| 节点类型 | 最小配置 | 推荐配置 |
|----------|----------|----------|
| Master | 2C/4G/50G | 4C/8G/100G |
| Data | 4C/8G/500G SSD | 8C/16G/1T SSD |
| Coordinating | 2C/4G/50G | 4C/8G/100G |
| Ingest | 2C/4G/50G | 4C/8G/100G |

#### 软件要求
- Java: ES 8.x 自带 JDK
- OS: CentOS 7+ / Ubuntu 18.04+
- 内存: 建议不超过 64G

### 部署步骤

#### 1. 安装 ES

**RPM/CentOS**
```bash
# 导入 GPG key
rpm --import https://artifacts.elastic.co/GPG-KEY-elasticsearch

# 添加 repository
cat > /etc/yum.repos.d/elasticsearch.repo << EOF
[elasticsearch]
name=Elasticsearch repository
baseurl=https://artifacts.elastic.co/packages/8.x/yum
gpgcheck=1
gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
enabled=0
autorefresh=1
type=rpm-md
EOF

# 安装
sudo yum install --enablerepo=elasticsearch elasticsearch
```

**Debian/Ubuntu**
```bash
# 导入 GPG key
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -

# 添加 repository
sudo apt-get install apt-transport-https
echo "deb https://artifacts.elastic.co/packages/8.x/apt stable main" | sudo tee /etc/apt/sources.list.d/elastic-8.x.list

# 安装
sudo apt-get update && sudo apt-get install elasticsearch
```

#### 2. 配置 elasticsearch.yml

**Master-Data 节点**
```yaml
cluster.name: es-prod-cluster
node.name: es-node-01
node.roles: [master, data]

network.host: 0.0.0.0
http.port: 9200
transport.port: 9300

discovery.seed_hosts: ["es-node-01", "es-node-02", "es-node-03"]
cluster.initial_master_nodes: ["es-node-01", "es-node-02", "es-node-03"]

path.data: /var/lib/elasticsearch
path.logs: /var/log/elasticsearch

# 内存锁定
bootstrap.memory_lock: true

# 安全配置
xpack.security.enabled: true
xpack.security.transport.ssl.enabled: true
xpack.security.transport.ssl.verification_mode: certificate
xpack.security.transport.ssl.keystore.path: elastic-certificates.p12
xpack.security.transport.ssl.truststore.path: elastic-certificates.p12

# 生产建议配置
action.destructive_requires_name: true
cluster.routing.allocation.disk.threshold_enabled: true
cluster.routing.allocation.disk.watermark.low: 85%
cluster.routing.allocation.disk.watermark.high: 90%
cluster.routing.allocation.disk.watermark.flood_stage: 95%
```

**Coordinating 节点**
```yaml
cluster.name: es-prod-cluster
node.name: es-coord-01
node.roles: []

# 不存储数据，只做协调
# 配置与 Data 节点类似的 discovery 和 security 配置
```

#### 3. 配置 JVM 内存

编辑 `/etc/elasticsearch/jvm.options`:
```
-Xms8g
-Xmx8g
```

建议设置为物理内存的 50%，最大不超过 31G。

#### 4. 配置内存锁定

编辑 `/usr/lib/systemd/system/elasticsearch.service`:
```
[Service]
LimitMEMLOCK=infinity
```

```bash
sudo systemctl daemon-reload
```

#### 5. 生成 TLS 证书

```bash
# 生成 CA
/usr/share/elasticsearch/bin/elasticsearch-certutil ca

# 生成证书
/usr/share/elasticsearch/bin/elasticsearch-certutil cert --ca elastic-stack-ca.p12

# 复制到各节点
scp elastic-certificates.p12 node1:/etc/elasticsearch/
scp elastic-certificates.p12 node2:/etc/elasticsearch/
```

#### 6. 启动服务

```bash
sudo systemctl start elasticsearch
sudo systemctl enable elasticsearch
```

#### 7. 设置密码

```bash
/usr/share/elasticsearch/bin/elasticsearch-setup-passwords interactive
```

#### 8. 验证

```bash
# 检查集群健康
curl -u elastic:password http://localhost:9200/_cluster/health?pretty

# 查看节点
curl -u elastic:password http://localhost:9200/_cat/nodes?v

# 查看索引
curl -u elastic:password http://localhost:9200/_cat/indices?v
```

### 集群管理

#### 分片管理

```bash
# 查看分片状态
curl -u elastic:password http://localhost:9200/_cat/shards?v

# 移动分片
curl -u elastic:password -X POST 'localhost:9200/_cluster/reroute' -H 'Content-Type: application/json' -d'
{
  "commands": [
    {
      "move": {
        "index": "index_name",
        "shard": 0,
        "from_node": "node1",
        "to_node": "node2"
      }
    }
  ]
}
'

# 分配失败的分片
curl -u elastic:password -X POST 'localhost:9200/_cluster/reroute?retry_failed=true'
```

#### 索引管理

```bash
# 创建索引
curl -u elastic:password -X PUT 'localhost:9200/my-index' -H 'Content-Type: application/json' -d'
{
  "settings": {
    "number_of_shards": 3,
    "number_of_replicas": 2,
    "refresh_interval": "1s"
  }
}
'

# 删除索引
curl -u elastic:password -X DELETE 'localhost:9200/my-index'

# 关闭索引
curl -u elastic:password -X POST 'localhost:9200/my-index/_close'

# 打开索引
curl -u elastic:password -X POST 'localhost:9200/my-index/_open'
```

### 性能优化

#### 索引设计
- 合理设置分片数
- 避免过度分片
- 使用 Rollover 管理时间序列索引

#### 查询优化
- 使用 filter 上下文
- 避免深度分页
- 使用 scroll 或 search_after

#### 缓存优化
```yaml
indices.queries.cache.size: 20%
indices.requests.cache.size: 5%
```

### 备份恢复

#### 配置快照仓库

```bash
# 注册仓库
curl -u elastic:password -X PUT 'localhost:9200/_snapshot/backup' -H 'Content-Type: application/json' -d'
{
  "type": "fs",
  "settings": {
    "location": "/backup/elasticsearch"
  }
}
'

# 创建快照
curl -u elastic:password -X PUT 'localhost:9200/_snapshot/backup/snapshot_1?wait_for_completion=true'

# 恢复快照
curl -u elastic:password -X POST 'localhost:9200/_snapshot/backup/snapshot_1/_restore'
```

### 监控

#### 关键指标
- 集群健康状态
- 节点 CPU/内存使用
- JVM 堆内存使用
- 磁盘 I/O
- 索引速率
- 搜索延迟
- 拒绝的线程数

---

## Zookeeper 部署

### 版本支持
- 3.5.x
- 3.8.x (推荐)

### 架构说明

Zookeeper 是一个分布式的协调服务，主要用于：
- 配置管理
- 命名服务
- 分布式锁
- 领导选举

### 环境要求

#### 硬件要求
| 节点数 | 最小配置 | 推荐配置 |
|-------|----------|----------|
| 3节点 | 2C/2G/50G | 4C/4G/100G |
| 5节点 | 2C/2G/50G | 4C/4G/100G |

注意: 集群节点数必须是奇数

#### 软件要求
- Java: JDK 8+
- OS: CentOS 7+ / Ubuntu 18.04+

### 部署步骤

#### 1. 下载安装

```bash
wget https://downloads.apache.org/zookeeper/zookeeper-3.8.3/apache-zookeeper-3.8.3-bin.tar.gz
tar -xzf apache-zookeeper-3.8.3-bin.tar.gz
sudo mv apache-zookeeper-3.8.3-bin /opt/zookeeper
```

#### 2. 创建数据目录

```bash
sudo mkdir -p /opt/zookeeper/data
sudo mkdir -p /opt/zookeeper/logs
```

#### 3. 配置 zoo.cfg

```bash
cd /opt/zookeeper/conf
cp zoo_sample.cfg zoo.cfg
```

编辑 `zoo.cfg`:
```ini
tickTime=2000
initLimit=10
syncLimit=5
dataDir=/opt/zookeeper/data
dataLogDir=/opt/zookeeper/logs
clientPort=2181
maxClientCnxns=60
autopurge.snapRetainCount=3
autopurge.purgeInterval=1

# 集群配置
server.1=zk-01:2888:3888
server.2=zk-02:2888:3888
server.3=zk-03:2888:3888

# 性能优化
preAllocSize=64M
snapCount=100000
skipList=true
forceSync=no
```

#### 4. 配置 myid

在每个节点的 dataDir 下创建 myid 文件:

**zk-01**
```bash
echo "1" | sudo tee /opt/zookeeper/data/myid
```

**zk-02**
```bash
echo "2" | sudo tee /opt/zookeeper/data/myid
```

**zk-03**
```bash
echo "3" | sudo tee /opt/zookeeper/data/myid
```

#### 5. 配置环境变量

```bash
cat >> ~/.bashrc << 'EOF'
export ZOOKEEPER_HOME=/opt/zookeeper
export PATH=$PATH:$ZOOKEEPER_HOME/bin
EOF

source ~/.bashrc
```

#### 6. 创建 systemd 服务

```bash
cat > /etc/systemd/system/zookeeper.service << 'EOF'
[Unit]
Description=Zookeeper Service
After=network.target

[Service]
Type=forking
User=zookeeper
Group=zookeeper
Environment="JAVA_HOME=/usr/lib/jvm/java-1.8.0-openjdk"
Environment="ZOO_LOG_DIR=/opt/zookeeper/logs"
ExecStart=/opt/zookeeper/bin/zkServer.sh start
ExecStop=/opt/zookeeper/bin/zkServer.sh stop
ExecReload=/opt/zookeeper/bin/zkServer.sh restart
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable zookeeper
```

#### 7. 启动服务

```bash
sudo systemctl start zookeeper
```

#### 8. 验证

```bash
# 查看状态
zkServer.sh status

# 连接测试
zkCli.sh -server localhost:2181

# 在 CLI 中
ls /
create /test "data"
get /test
delete /test
```

### 集群管理

#### 节点状态

```bash
# 查看模式 (leader/follower/observer)
echo stat | nc localhost 2181

# 查看配置
echo conf | nc localhost 2181

# 查看连接
echo cons | nc localhost 2181

# 查看会话
echo dump | nc localhost 2181
```

#### 四字命令

```bash
# ruok: 测试服务是否正常
echo ruok | nc localhost 2181
# 返回: imok

# mntr: 监控信息
echo mntr | nc localhost 2181

# srst: 重置统计信息
echo srst | nc localhost 2181
```

### 监控

#### 关键指标
- 延迟 (avg/min/max latency)
- 请求/响应统计
- 网络流量
- 节点状态
- Watch 数量
- 数据大小

#### 监控命令

```bash
# 使用 mntr 获取所有监控指标
echo mntr | nc localhost 2181

# 输出示例:
# zk_version  3.8.3
# zk_avg_latency  0
# zk_max_latency  0
# zk_packets_received  10
# zk_packets_sent  9
# zk_num_alive_connections  1
# zk_outstanding_requests  0
# zk_server_state  leader
# zk_znode_count  4
```

### 备份恢复

#### 备份

```bash
# 快照文件
cp -r /opt/zookeeper/data/version-2 /backup/zookeeper/snapshot_$(date +%Y%m%d)

# 事务日志
cp -r /opt/zookeeper/logs/version-2 /backup/zookeeper/txlog_$(date +%Y%m%d)
```

#### 恢复

```bash
# 停止服务
zkServer.sh stop

# 恢复数据
rm -rf /opt/zookeeper/data/version-2
cp -r /backup/zookeeper/snapshot_20260106 /opt/zookeeper/data/version-2

# 启动服务
zkServer.sh start
```

### 性能优化

#### JVM 配置

编辑 `/opt/zookeeper/bin/zkEnv.sh`:
```bash
export JVMFLAGS="-Xms2g -Xmx2g -XX:+UseG1GC -XX:MaxGCPauseMillis=200"
```

#### 配置优化

```ini
# tickTime: 心跳时间间隔
tickTime=2000

# initLimit: 初始连接同步超时
initLimit=10

# syncLimit: 请求同步超时
syncLimit=5

# maxClientCnxns: 最大客户端连接数
maxClientCnxns=60

# sessionTimeout: 会话超时时间
# 在客户端配置

# 预分配空间
preAllocSize=64M

# 快照数量
snapCount=100000

# 跳过列表
skipList=true
```

### 故障排查

#### 常见问题

1. **节点无法连接**
   - 检查防火墙规则
   - 检查端口监听状态
   - 检查 myid 配置

2. **选举失败**
   - 确保节点数为奇数
   - 检查网络连通性
   - 查看日志确定原因

3. **性能问题**
   - 检查磁盘 I/O
   - 调整 JVM 内存
   - 考虑使用 Observer 节点

---

## 最佳实践

### Elasticsearch

1. **架构设计**
   - 分离 Master、Data、Coordinating 节点
   - 使用 Hot-Warm 架构管理时间序列数据
   - 合理规划分片和副本

2. **索引管理**
   - 使用 Index Template
   - 配置 ILM (索引生命周期管理)
   - 定期删除过期索引

3. **查询优化**
   - 使用 filter 查询
   - 避免通配符查询
   - 合理使用缓存

### Zookeeper

1. **节点规划**
   - 生产环境至少 3 节点
   - 使用奇数个节点
   - 考虑使用 Observer 节点扩展读能力

2. **数据管理**
   - 控制 znode 数据大小 (< 1M)
   - 合理设置 Watch
   - 及时清理临时节点

3. **监控告警**
   - 监控延迟
   - 监控网络流量
   - 监控磁盘使用

---

## 参考资源
- [Elasticsearch 官方文档](https://www.elastic.co/guide/en/elasticsearch/reference/current/index.html)
- [Zookeeper 官方文档](https://zookeeper.apache.org/doc/)
