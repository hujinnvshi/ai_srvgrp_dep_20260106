# Elasticsearch 部署文档

## 概述

本项目包含多个版本的 Elasticsearch 部署配置，支持在同一台服务器上运行不同版本的 Elasticsearch 实例。

## 可用版本

### Elasticsearch 7.4.1

**部署模式**:
- 单节点部署 (Single Node)
- 伪分布式部署 (Pseudo-Distributed Cluster)

**配置信息**:
- 部署路径: `/data2/elasticsearch`
- HTTP端口: `9200` (单节点), `9200-9202` (伪分布式)
- Transport端口: `9300` (单节点), `9300-9302` (伪分布式)
- 集群名称: `es-single-node`, `es-pseudo-cluster`

**文档位置**:
- [单节点部署指南](versions/v7.4.1/single-node/deployment.md)
- [伪分布式部署指南](versions/v7.4.1/pseudo-distributed/deployment.md)

**快速开始**:
```bash
# 单节点部署
scp services/elasticsearch/versions/v7.4.1/single-node/deploy-es-single-fixed.sh root@172.16.47.57:/root/
ssh root@172.16.47.57
chmod +x /root/deploy-es-single-fixed.sh
./root/deploy-es-single-fixed.sh
```

---

### Elasticsearch 7.0.1

**部署模式**:
- 单节点部署 (Single Node)

**配置信息**:
- 部署路径: `/data3/elasticsearch`
- HTTP端口: `9210`
- Transport端口: `9310`
- 集群名称: `es-701-single-node`

**文档位置**:
- [单节点部署指南](versions/v7.0.1/single-node/deployment.md)

**快速开始**:
```bash
# 单节点部署
scp services/elasticsearch/versions/v7.0.1/single-node/deploy-es-single-fixed.sh root@172.16.47.57:/root/
ssh root@172.16.47.57
chmod +x /root/deploy-es-single-fixed.sh
./root/deploy-es-single-fixed.sh
```

---

## 版本对比

| 特性 | 7.4.1 版本 | 7.0.1 版本 |
|------|-----------|-----------|
| **部署路径** | /data2/elasticsearch | /data3/elasticsearch |
| **HTTP端口** | 9200 | 9210 |
| **Transport端口** | 9300 | 9310 |
| **集群名称** | es-single-node | es-701-single-node |
| **节点名称** | es-node-1 | es-701-node-1 |
| **部署模式** | 单节点/伪分布式 | 单节点 |
| **启动脚本** | /data2/start-es.sh | /data3/start-es-701.sh |
| **停止脚本** | /data2/stop-es.sh | /data3/stop-es-701.sh |

## 多版本共存

本项目的两个 Elasticsearch 版本设计为可以在同一台服务器上并存运行，主要用于：

1. **版本兼容性测试**: 测试应用在不同 ES 版本下的兼容性
2. **平滑升级**: 在升级到新版本前进行迁移测试
3. **功能对比**: 对比不同版本之间的功能差异
4. **多应用支持**: 不同应用使用不同版本的 ES

### 同时运行两个版本

```bash
# 启动 7.4.1 版本
/data2/start-es.sh
sleep 10

# 启动 7.0.1 版本
/data3/start-es-701.sh
sleep 10

# 验证两个版本
echo "=== Elasticsearch 7.4.1 ==="
curl -s http://localhost:9200 | grep version

echo "=== Elasticsearch 7.0.1 ==="
curl -s http://localhost:9210 | grep version

# 查看所有端口
netstat -tunlp | grep -E ":(9200|9210|9300|9310) "
```

### 停止所有版本

```bash
# 停止 7.4.1 版本
/data2/stop-es.sh

# 停止 7.0.1 版本
/data3/stop-es-701.sh
```

---

## 目录结构

```
services/elasticsearch/
├── README.md                                    # 本文档
├── common/                                      # 通用资源
│   ├── backup/                                  # 备份脚本和配置
│   ├── monitoring/                              # 监控脚本
│   └── optimization/                            # 性能优化配置
└── versions/                                    # 版本特定配置
    ├── v7.4.1/                                  # Elasticsearch 7.4.1
    │   ├── single-node/                         # 单节点部署
    │   │   ├── deploy-es-single-fixed.sh        # 自动部署脚本
    │   │   ├── deploy-es-single.sh              # 原始部署脚本
    │   │   └── fix-es-user.sh                   # 用户修复脚本
    │   └── pseudo-distributed/                  # 伪分布式部署
    │       └── deployment.md                    # 部署文档
    └── v7.0.1/                                  # Elasticsearch 7.0.1
        └── single-node/                         # 单节点部署
            ├── deploy-es-single-fixed.sh        # 自动部署脚本
            └── deployment.md                    # 部署文档
```

---

## 环境要求

### 系统要求

- **操作系统**: CentOS 7+, RHEL 7+, Ubuntu 18.04+
- **内存**: 至少 8GB（推荐 16GB+）
- **CPU**: 至少 2 核（推荐 4 核+）
- **磁盘**: 至少 40GB 可用空间（推荐 SSD）

### 软件要求

- **Java**: Elasticsearch 自带 JDK，无需单独安装
- **wget**: 用于下载安装包
- **bash**: 执行部署脚本

### 系统参数

```bash
# vm.max_map_count (必须)
vm.max_map_count=262144

# 文件描述符限制
* soft nofile 65536
* hard nofile 65536

# 最大进程数
* soft nproc 4096
* hard nproc 4096
```

---

## 快速开始

### 1. 选择版本并部署

根据需求选择合适的版本：

- **测试/开发**: 使用 Elasticsearch 7.4.1 单节点模式
- **生产环境**: 使用 Elasticsearch 7.4.1 伪分布式集群
- **兼容性测试**: 同时运行 7.4.1 和 7.0.1

### 2. 执行部署

```bash
# 上传部署脚本
scp services/elasticsearch/versions/<version>/single-node/deploy-es-single-fixed.sh root@172.16.47.57:/root/

# 登录服务器
ssh root@172.16.47.57

# 赋予执行权限
chmod +x /root/deploy-es-single-fixed.sh

# 执行部署
./root/deploy-es-single-fixed.sh
```

### 3. 验证部署

```bash
# 检查服务状态
curl http://localhost:<port>

# 查看集群健康
curl http://localhost:<port>/_cluster/health?pretty

# 查看节点信息
curl http://localhost:<port>/_cat/nodes?v
```

---

## 常用操作

### 服务管理

```bash
# Elasticsearch 7.4.1
/data2/start-es.sh          # 启动
/data2/stop-es.sh           # 停止

# Elasticsearch 7.0.1
/data3/start-es-701.sh      # 启动
/data3/stop-es-701.sh       # 停止
```

### 健康检查

```bash
# 检查 7.4.1
curl http://localhost:9200/_cluster/health?pretty

# 检查 7.0.1
curl http://localhost:9210/_cluster/health?pretty
```

### 查看日志

```bash
# 7.4.1 日志
tail -f /data2/elasticsearch/logs/es-single-node.log

# 7.0.1 日志
tail -f /data3/elasticsearch/logs/es-701-single-node.log
```

### 索引操作

```bash
# 创建索引
curl -X PUT 'http://localhost:<port>/test-index' -H 'Content-Type: application/json' -d'
{
  "settings": {
    "number_of_shards": 1,
    "number_of_replicas": 0
  }
}'

# 查看索引
curl http://localhost:<port>/_cat/indices?v

# 删除索引
curl -X DELETE http://localhost:<port>/test-index
```

---

## 故障排查

### 服务无法启动

1. **检查端口占用**:
   ```bash
   netstat -tunlp | grep -E ":(9200|9210|9300|9310) "
   ```

2. **检查日志**:
   ```bash
   tail -100 /data2/elasticsearch/logs/es-single-node.log
   tail -100 /data3/elasticsearch/logs/es-701-single-node.log
   ```

3. **检查系统参数**:
   ```bash
   sysctl vm.max_map_count
   ulimit -n
   ```

4. **检查进程**:
   ```bash
   ps aux | grep elasticsearch | grep -v grep
   ```

### 集群状态异常

```bash
# 查看集群健康
curl http://localhost:<port>/_cluster/health?pretty

# 查看未分配的分片
curl http://localhost:<port>/_cat/shards?v | grep UNASSIGNED

# 查看节点信息
curl http://localhost:<port>/_cat/nodes?v
```

### 性能问题

```bash
# 查看线程池
curl http://localhost:<port>/_cat/thread_pool?v

# 查看节点统计
curl http://localhost:<port>/_nodes/stats?pretty

# 查看索引统计
curl http://localhost:<port>/_cat/indices?v
```

---

## 监控和维护

### 日常维护

1. **定期健康检查**: 每天检查集群状态
2. **日志清理**: 定期清理旧日志文件
3. **数据备份**: 定期备份重要数据
4. **性能监控**: 监控 CPU、内存、磁盘使用率

### 监控脚本

各版本部署目录下包含健康检查脚本：

```bash
# 7.4.1 版本
/data2/health-check.sh

# 7.0.1 版本
/data3/health-check-701.sh
```

### 日志清理

```bash
# 清理 7 天前的日志
find /data2/elasticsearch/logs -name "*.log" -mtime +7 -delete
find /data3/elasticsearch/logs -name "*.log" -mtime +7 -delete
```

---

## 安全建议

### 生产环境配置

1. **启用安全认证**: 配置 xpack 安全
2. **网络隔离**: 使用防火墙限制访问
3. **SSL/TLS**: 启用加密传输
4. **定期备份**: 设置自动备份策略
5. **监控告警**: 配置监控和告警系统

### 防火墙配置

```bash
# 开放 Elasticsearch 7.4.1 端口
firewall-cmd --permanent --add-port=9200/tcp
firewall-cmd --permanent --add-port=9300/tcp

# 开放 Elasticsearch 7.0.1 端口
firewall-cmd --permanent --add-port=9210/tcp
firewall-cmd --permanent --add-port=9310/tcp

# 重载防火墙
firewall-cmd --reload
```

---

## 性能优化

### JVM 内存配置

```bash
# 编辑 jvm.options
vi /data2/elasticsearch/config/jvm.options
vi /data3/elasticsearch/config/jvm.options

# 设置堆内存（建议不超过 31GB，为物理内存的 50%）
-Xms4g
-Xmx4g
```

### 分片配置

```bash
# 根据数据量调整分片数
# 小数据集: 1-3 个分片
# 中等数据集: 3-6 个分片
# 大数据集: 6+ 个分片

# 创建索引时指定
curl -X PUT 'http://localhost:<port>/test-index' -H 'Content-Type: application/json' -d'
{
  "settings": {
    "number_of_shards": 3,
    "number_of_replicas": 1
  }
}'
```

### 刷新间隔优化

```bash
# 降低刷新频率以提高索引性能
curl -X PUT 'http://localhost:<port>/test-index' -H 'Content-Type: application/json' -d'
{
  "settings": {
    "refresh_interval": "30s"
  }
}'
```

---

## 数据迁移

### 从 7.0.1 迁移到 7.4.1

```bash
# 1. 在 7.0.1 上创建快照
curl -X PUT 'http://localhost:9210/_snapshot/backup' -H 'Content-Type: application/json' -d'
{
  "type": "fs",
  "settings": {
    "location": "/data3/elasticsearch/backup"
  }
}'

# 2. 创建快照
curl -X PUT 'http://localhost:9210/_snapshot/backup/snapshot_1?wait_for_completion=true&pretty'

# 3. 在 7.4.1 上注册相同仓库
curl -X PUT 'http://localhost:9200/_snapshot/backup' -H 'Content-Type: application/json' -d'
{
  "type": "fs",
  "settings": {
    "location": "/data2/elasticsearch/backup"
  }
}'

# 4. 恢复快照
curl -X POST 'http://localhost:9200/_snapshot/backup/snapshot_1/_restore?pretty'
```

---

## 版本升级建议

### 升级路径

1. **小版本升级**: 7.0.1 → 7.4.1（推荐）
2. **跨版本升级**: 7.x → 8.x（需要充分测试）
3. **滚动升级**: 在多节点集群中逐个升级

### 升级步骤

1. **备份数据**: 创建完整快照
2. **测试验证**: 在测试环境验证
3. **执行升级**: 在生产环境升级
4. **验证功能**: 确认所有功能正常

---

## 参考资源

### 官方文档

- [Elasticsearch 7.4.1 文档](https://www.elastic.co/guide/en/elasticsearch/reference/7.4/index.html)
- [Elasticsearch 7.0.1 文档](https://www.elastic.co/guide/en/elasticsearch/reference/7.0/index.html)
- [Elasticsearch 官方网站](https://www.elastic.co/)

### 相关工具

- [Kibana](https://www.elastic.co/kibana): 数据可视化
- [Logstash](https://www.elastic.co/logstash): 数据处理
- [Beats](https://www.elastic.co/beats): 数据采集

---

## 更新日志

### 2026-01-06

- 添加 Elasticsearch 7.0.1 单节点部署配置
- 完善版本对比文档
- 添加多版本共存指南
- 更新总览文档

### 2026-01-06 (初始版本)

- 添加 Elasticsearch 7.4.1 单节点部署
- 添加 Elasticsearch 7.4.1 伪分布式部署

---

## 联系方式

- **维护团队**: AI服务组
- **更新日期**: 2026-01-06
- **文档版本**: 1.0

---

## 许可证

本文档遵循项目许可证。

---

**注意**: 本文档和部署脚本仅供内部使用，生产环境部署前请充分测试。
