# Elasticsearch 故障排查思维指南

## 概述

本文档总结了在实际工作中积累的 Elasticsearch 故障排查思维模式和最佳实践，适用于 ES 7.x 及以上版本。

---

## 一、故障排查核心思维框架

### 1.1 分层诊断法（自底向上）

```
第1层: 基础设施层
   ↓ 操作系统、网络、磁盘、内存
第2层: 运行环境层
   ↓ JDK/JRE 版本、环境变量、配置文件
第3层: 应用服务层
   ↓ ES 进程、端口、日志
第4层: 数据功能层
   ↓ 索引、分片、查询性能
```

### 1.2 排查问题清单（5W1H）

- **What**: 出现什么问题？（症状）
- **Where**: 问题出现在哪里？（范围）
- **When**: 什么时候开始？（时间点）
- **Who**: 谁报告的问题？（用户/系统）
- **Why**: 为什么会出现？（根因）
- **How**: 如何复现和解决？（方案）

---

## 二、常见问题场景与排查思路

### 2.1 ES 无法启动

#### 症状
- 启动脚本执行后进程立即退出
- 端口未监听
- 日志中有错误信息

#### 排查步骤

```bash
# 1. 检查进程状态
ps aux | grep '[e]lasticsearch'

# 2. 检查端口监听
netstat -tlnp | grep -E ':(9200|9300)'
# 或
ss -tlnp | grep -E ':(9200|9300)'

# 3. 查看启动日志
tail -100 $ES_HOME/logs/console.log
tail -100 $ES_HOME/logs/$ES_CLUSTER_NAME.log

# 4. 检查配置文件语法
cat $ES_HOME/config/elasticsearch.yml

# 5. 检查文件权限
ls -la $ES_HOME/
```

#### 常见原因与解决方案

| 问题 | 原因 | 解决方案 |
|------|------|----------|
| JAVA_HOME 错误 | 系统使用错误的 JDK | 在启动脚本中 `unset JAVA_HOME` |
| 内存不足 | JVM 堆内存过大 | 调整 jvm.options 中的 -Xms/-Xmx |
| 端口冲突 | 端口被占用 | 修改 elasticsearch.yml 中的端口配置 |
| 权限问题 | 文件归属不正确 | `chown -R elastic:elastic $ES_HOME` |
| 配置错误 | YAML 格式错误 | 检查配置文件语法 |

---

### 2.2 JDK 版本兼容性问题

#### 关键发现
ES 会自动使用 bundled JDK，但如果系统设置了 JAVA_HOME 环境变量，ES 会优先使用系统 JDK。

#### 排查命令

```bash
# 1. 检查 bundled JDK 版本
$ES_HOME/jdk/bin/java -version

# 2. 检查系统 JDK 版本
java -version

# 3. 检查当前 ES 使用的 JDK
ps aux | grep '[e]lasticsearch' | awk '{print $11}'
```

#### 解决方案（重要！）

在启动脚本中添加 `unset JAVA_HOME`：

```bash
#!/bin/bash
export ES_HOME=/data2/elasticsearch
ES_USER=elastic

# 关键：清除 JAVA_HOME，让 ES 使用 bundled JDK
su - $ES_USER -c "cd $ES_HOME && unset JAVA_HOME && nohup \$ES_HOME/bin/elasticsearch > \$ES_HOME/logs/console.log 2>&1 &"
```

#### JDK 版本对应关系

| ES 版本 | 最低 JDK 要求 | Bundled JDK |
|---------|--------------|-------------|
| 7.x | JDK 11 | OpenJDK 12/13 |
| 6.x | JDK 8 | OpenJDK 8/10 |
| 8.x | JDK 17 | OpenJDK 17+ |

---

### 2.3 多实例部署问题

#### 症状
- 多个 ES 实例无法同时运行
- 端口冲突
- 数据混淆

#### 排查清单

```bash
# 1. 检查端口分配
netstat -tlnp | grep java

# 2. 检查集群名称
grep 'cluster.name' $ES_HOME/config/elasticsearch.yml

# 3. 检查数据目录
grep 'path.data' $ES_HOME/config/elasticsearch.yml

# 4. 检查进程归属
ps aux | grep '[e]lasticsearch' | awk '{print $1, $11, $12, $13}'
```

#### 最佳实践配置

| 配置项 | 实例1 | 实例2 |
|--------|-------|-------|
| 安装目录 | /data2/elasticsearch | /data3/elasticsearch |
| HTTP 端口 | 9200 | 9210 |
| Transport 端口 | 9300 | 9310 |
| 集群名称 | es-single-node | es-701-single-node |
| 节点名称 | es-node-1 | es-701-node-1 |
| 数据目录 | /data2/elasticsearch/data | /data3/elasticsearch/data |
| 日志目录 | /data2/elasticsearch/logs | /data3/elasticsearch/logs |

---

### 2.4 性能问题

#### 症状
- 查询响应慢
- CPU 使用率高
- 内存溢出

#### 排查步骤

```bash
# 1. 检查集群健康
curl 'http://localhost:9200/_cluster/health?pretty'

# 2. 检查节点状态
curl 'http://localhost:9200/_cat/nodes?v'

# 3. 检查索引状态
curl 'http://localhost:9200/_cat/indices?v'

# 4. 检查分片分配
curl 'http://localhost:9200/_cat/shards?v'

# 5. 查看线程池
curl 'http://localhost:9200/_cat/thread_pool?v'

# 6. 查看任务
curl 'http://localhost:9200/_tasks?detailed=true&pretty'
```

#### 性能优化建议

1. **JVM 堆内存**
   - 建议：不超过 31GB
   - 设置：-Xms 和 -Xmx 保持一致
   - 公式：Min(31GB, 50% 物理内存)

2. **分片配置**
   - 单分片大小：20-50GB
   - 避免过度分片

3. **查询优化**
   - 使用 filter 而非 query（不需要评分时）
   - 避免深度分页
   - 使用 scroll API 导出大数据

---

### 2.5 数据问题

#### 症状
- 数据丢失
- 索引红色状态
- 分片未分配

#### 排查步骤

```bash
# 1. 检查分片状态
curl 'http://localhost:9200/_cat/shards?v&h=index,shard,prirep,state,unassigned.reason'

# 2. 查看未分配分片原因
curl 'http://localhost:9200/_cluster/allocation/explain?pretty'

# 3. 手动分配分片
curl -X POST 'http://localhost:9200/_cluster/reroute?retry_failed=true'

# 4. 检查磁盘空间
df -h $ES_HOME
```

---

## 三、系统化测试方法

### 3.1 基础功能测试清单

```bash
# 1. 集群信息
curl 'http://localhost:9200'

# 2. 集群健康
curl 'http://localhost:9200/_cluster/health?pretty'

# 3. 节点信息
curl 'http://localhost:9200/_cat/nodes?v'

# 4. 索引列表
curl 'http://localhost:9200/_cat/indices?v'

# 5. 创建测试索引
curl -X PUT 'http://localhost:9200/test_index' -H 'Content-Type: application/json' -d '{
  "settings": {
    "number_of_shards": 1,
    "number_of_replicas": 0
  }
}'

# 6. 插入文档
curl -X POST 'http://localhost:9200/test_index/_doc/1' -H 'Content-Type: application/json' -d '{
  "title": "测试文档",
  "content": "这是一个测试"
}'

# 7. 查询文档
curl -X POST 'http://localhost:9200/test_index/_search' -H 'Content-Type: application/json' -d '{
  "query": {
    "match_all": {}
  }
}'

# 8. 更新文档
curl -X POST 'http://localhost:9200/test_index/_update/1' -H 'Content-Type: application/json' -d '{
  "doc": {
    "title": "更新后的标题"
  }
}'

# 9. 删除文档
curl -X DELETE 'http://localhost:9200/test_index/_doc/1'

# 10. 删除索引
curl -X DELETE 'http://localhost:9200/test_index'
```

### 3.2 压力测试建议

```bash
# 使用 esrally 进行性能测试
# 安装
pip install esrally

# 测试
esrally --track=geonames --target-hosts=localhost:9200 --pipeline=benchmark-only
```

---

## 四、日志分析方法

### 4.1 关键日志位置

```bash
# 控制台日志（如果使用 nohup）
$ES_HOME/logs/console.log

# 主日志
$ES_HOME/logs/$CLUSTER_NAME.log

# 慢查询日志
$ES_HOME/logs/$CLUSTER_NAME_index_search_slowlog.log

# GC 日志
$ES_HOME/logs/gc.log
```

### 4.2 日志分析技巧

```bash
# 1. 查看错误日志
grep -i 'error' $ES_HOME/logs/*.log

# 2. 查看警告信息
grep -i 'warning' $ES_HOME/logs/*.log

# 3. 查看最近的日志
tail -f $ES_HOME/logs/$CLUSTER_NAME.log

# 4. 统计错误类型
grep -i 'error' $ES_HOME/logs/*.log | awk '{print $5}' | sort | uniq -c | sort -rn
```

---

## 五、预防性维护建议

### 5.1 日常监控指标

```bash
# 1. 集群健康状态（green/yellow/red）
# 2. JVM 堆内存使用率
# 3. CPU 使用率
# 4. 磁盘空间（建议低于 85%）
# 5. 查询响应时间
# 6. 索引速率
# 7. 合并队列大小
```

### 5.2 定期维护任务

- [ ] 每周检查磁盘空间
- [ ] 每月清理旧日志
- [ ] 每月检查分片健康状态
- [ ] 定期备份重要数据
- [ ] 监控 GC 频率和耗时

---

## 六、快速参考命令

```bash
# === 基础检查 ===
# 查看 ES 版本
curl 'http://localhost:9200'

# 集群健康
curl 'http://localhost:9200/_cluster/health?pretty'

# 节点列表
curl 'http://localhost:9200/_cat/nodes?v'

# 索引列表
curl 'http://localhost:9200/_cat/indices?v'

# === 进程管理 ===
# 查找 ES 进程
ps aux | grep '[e]lasticsearch'

# 查看端口
netstat -tlnp | grep -E ':(9200|9300)'

# === 性能分析 ===
# 查看 JVM 统计
curl 'http://localhost:9200/_nodes/stats?pretty'

# 查看线程池
curl 'http://localhost:9200/_cat/thread_pool?v'

# 查看任务
curl 'http://localhost:9200/_tasks?detailed=true&pretty'

# === 故障排查 ===
# 查看未分配分片
curl 'http://localhost:9200/_cat/shards?v' | grep UNASSIGNED

# 查看分片未分配原因
curl 'http://localhost:9200/_cluster/allocation/explain?pretty'

# 重试失败分片
curl -X POST 'http://localhost:9200/_cluster/reroute?retry_failed=true'
```

---

## 七、常见错误码及含义

| HTTP 状态码 | 含义 | 常见原因 |
|------------|------|----------|
| 200 | 成功 | 请求正常执行 |
| 201 | 已创建 | 文档创建成功 |
| 400 | 错误请求 | 查询语法错误 |
| 404 | 未找到 | 索引或文档不存在 |
| 409 | 冲突 | 版本冲突 |
| 500 | 服务器错误 | ES 内部错误 |
| 503 | 服务不可用 | 集群不可用 |

---

## 八、总结

### 核心思维模式

1. **分层诊断**：从底层到上层逐层排查
2. **系统化测试**：建立完整的测试清单
3. **日志驱动**：充分利用日志信息
4. **预防为主**：建立监控和维护机制

### 关键要点

- ✅ JDK 版本兼容性是首要检查项
- ✅ 环境变量 JAVA_HOME 会覆盖 bundled JDK
- ✅ 多实例部署需要严格的端口和目录隔离
- ✅ 启动脚本是解决环境问题的关键环节
- ✅ 完整的测试流程可以验证所有功能
- ✅ 环境信息文档化有助于后续维护

---

**文档版本**: 1.0
**创建时间**: 2026-01-14
**适用版本**: Elasticsearch 7.x
**维护者**: DevOps Team
