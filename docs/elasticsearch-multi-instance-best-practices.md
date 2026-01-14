# Elasticsearch 多实例部署最佳实践

## 概述

本文档总结了在同一服务器上部署多个 Elasticsearch 实例的最佳实践，基于实际生产环境经验整理。

---

## 一、多实例部署场景

### 1.1 适用场景

✅ **推荐场景**
- 不同版本 ES 共存（如 7.0.1 和 7.4.1）
- 不同业务数据隔离
- 开发/测试/生产环境分离
- 资源独立分配

❌ **不推荐场景**
- 同一业务的集群分片（应使用集群模式）
- 资源受限的小型服务器
- 追求极致性能的场景

---

## 二、部署规划

### 2.1 资源规划清单

#### 硬件要求

| 资源 | 最小配置 | 推荐配置 | 说明 |
|------|---------|---------|------|
| CPU | 4核 | 8核+ | 每实例至少 2 核 |
| 内存 | 8GB | 32GB+ | 每实例堆内存 + 留 50% 给系统 |
| 磁盘 | 50GB | 500GB+ | SSD 推荐 |
| 网络 | 1Gbps | 10Gbps | 多实例流量叠加 |

#### JVM 内存分配公式

```
单个实例堆内存 = Min(31GB, 物理内存 × 50% / 实例数量)

示例：251GB 内存，2 个实例
单个实例 = Min(31GB, 251 × 50% / 2) = Min(31GB, 62.75GB) = 31GB
```

### 2.2 实例配置清单

#### 配置项对照表

| 配置项 | 实例 1 | 实例 2 | 实例 3 | 说明 |
|--------|--------|--------|--------|------|
| **安装目录** | | | | |
| ES_HOME | /data2/elasticsearch | /data3/elasticsearch | /data4/elasticsearch | 完全独立 |
| **网络配置** | | | | |
| HTTP 端口 | 9200 | 9210 | 9220 | 递增 10 |
| Transport 端口 | 9300 | 9310 | 9320 | 递增 10 |
| **集群配置** | | | | |
| cluster.name | es-cluster-1 | es-cluster-2 | es-cluster-3 | 不同集群名 |
| node.name | es-node-1 | es-node-2 | es-node-3 | 唯一节点名 |
| discovery.type | single-node | single-node | single-node | 单节点模式 |
| **数据路径** | | | | |
| path.data | /data2/elasticsearch/data | /data3/elasticsearch/data | /data4/elasticsearch/data | 完全独立 |
| path.logs | /data2/elasticsearch/logs | /data3/elasticsearch/logs | /data4/elasticsearch/logs | 完全独立 |
| **JVM 配置** | | | | |
| -Xms/-Xmx | 1g | 31g | 16g | 根据需求分配 |
| **运行用户** | | | | |
| 用户 | elastic | elastic | elastic | 可相同 |
| **监控端口** | | | | |
| 访问地址 | http://IP:9200 | http://IP:9210 | http://IP:9220 | 不同端口 |

---

## 三、部署步骤

### 3.1 准备工作

```bash
# 1. 创建运行用户（如果不存在）
sudo useradd -m elastic
sudo passwd elastic

# 2. 创建数据目录
sudo mkdir -p /data2/elasticsearch
sudo mkdir -p /data3/elasticsearch
sudo mkdir -p /data4/elasticsearch

# 3. 设置权限
sudo chown -R elastic:elastic /data2/elasticsearch
sudo chown -R elastic:elastic /data3/elasticsearch
sudo chown -R elastic:elastic /data4/elasticsearch
```

### 3.2 解压安装

```bash
# 实例 1
cd /data2
tar -xzf elasticsearch-7.4.1-linux-x86_64.tar.gz
mv elasticsearch-7.4.1 elasticsearch
chown -R elastic:elastic elasticsearch

# 实例 2
cd /data3
tar -xzf elasticsearch-7.0.1-linux-x86_64.tar.gz
mv elasticsearch-7.0.1 elasticsearch
chown -R elastic:elastic elasticsearch

# 实例 3（如需要）
cd /data4
tar -xzf elasticsearch-8.x.x-linux-x86_64.tar.gz
mv elasticsearch-8.x.x elasticsearch
chown -R elastic:elastic elasticsearch
```

### 3.3 配置文件修改

#### 实例 1: /data2/elasticsearch/config/elasticsearch.yml

```yaml
# 集群名称
cluster.name: es-cluster-1

# 节点名称
node.name: es-node-1

# 网络配置
network.host: 0.0.0.0
http.port: 9200
transport.port: 9300

# 数据和日志路径
path.data: /data2/elasticsearch/data
path.logs: /data2/elasticsearch/logs

# 单节点模式
discovery.type: single-node

# 内存锁定
bootstrap.memory_lock: false

# 防止分片未分配
cluster.routing.allocation.disk.threshold_enabled: true
cluster.routing.allocation.disk.watermark.low: 85%
cluster.routing.allocation.disk.watermark.high: 90%
cluster.routing.allocation.disk.watermark.flood_stage: 95%
```

#### 实例 2: /data3/elasticsearch/config/elasticsearch.yml

```yaml
# 集群名称（不同！）
cluster.name: es-cluster-2

# 节点名称（不同！）
node.name: es-node-2

# 网络配置（端口不同！）
network.host: 0.0.0.0
http.port: 9210
transport.port: 9310

# 数据和日志路径（不同！）
path.data: /data3/elasticsearch/data
path.logs: /data3/elasticsearch/logs

# 单节点模式
discovery.type: single-node

# 内存锁定
bootstrap.memory_lock: false

# 防止分片未分配
cluster.routing.allocation.disk.threshold_enabled: true
cluster.routing.allocation.disk.watermark.low: 85%
cluster.routing.allocation.disk.watermark.high: 90%
cluster.routing.allocation.disk.watermark.flood_stage: 95%
```

#### 实例 3: /data4/elasticsearch/config/elasticsearch.yml

```yaml
# 参照上述模式修改
# 重点是：端口 9220/9320，路径 /data4
```

### 3.4 JVM 内存配置

#### 实例 1: /data2/elasticsearch/config/jvm.options

```bash
-Xms1g
-Xmx1g
```

#### 实例 2: /data3/elasticsearch/config/jvm.options

```bash
-Xms31g
-Xmx31g
```

#### 实例 3: /data4/elasticsearch/config/jvm.options

```bash
-Xms16g
-Xmx16g
```

---

## 四、启动脚本（重要！）

### 4.1 通用启动脚本模板

#### /data2/elasticsearch/start-es.sh

```bash
#!/bin/bash

export ES_HOME=/data2/elasticsearch
ES_USER=elastic

# 检查是否以 root 运行
if [ "$(whoami)" != "root" ]; then
    echo "错误: 必须以 root 用户运行此脚本"
    exit 1
fi

cd $ES_HOME

echo "====================================="
echo "启动 Elasticsearch (实例 1)"
echo "节点名称: es-node-1"
echo "HTTP 端口: 9200"
echo "Transport 端口: 9300"
echo "====================================="
echo "以 $ES_USER 用户启动 Elasticsearch..."
echo "使用 ES 目录下的 JDK: $ES_HOME/jdk"

# 关键：清除 JAVA_HOME，让 ES 使用 bundled JDK
su - $ES_USER -c "cd $ES_HOME && unset JAVA_HOME && nohup $ES_HOME/bin/elasticsearch > $ES_HOME/logs/console.log 2>&1 &"

echo "Elasticsearch 启动中..."

sleep 5

tail -30 $ES_HOME/logs/console.log
echo ""
echo "检查服务状态..."
sleep 2
if netstat -tlnp 2>/dev/null | grep -q ':9200' || ss -tlnp 2>/dev/null | grep -q ':9200'; then
    echo "✅ Elasticsearch (实例 1) 启动成功！"
    echo "访问地址: http://172.16.47.57:9200"
else
    echo "⚠️  端口 9200 未监听，请检查日志"
fi
```

#### /data3/elasticsearch/start-es.sh

```bash
#!/bin/bash

export ES_HOME=/data3/elasticsearch
ES_USER=elastic

if [ "$(whoami)" != "root" ]; then
    echo "错误: 必须以 root 用户运行此脚本"
    exit 1
fi

cd $ES_HOME

echo "====================================="
echo "启动 Elasticsearch (实例 2)"
echo "节点名称: es-node-2"
echo "HTTP 端口: 9210"
echo "Transport 端口: 9310"
echo "====================================="
echo "以 $ES_USER 用户启动 Elasticsearch..."
echo "使用 ES 目录下的 JDK: $ES_HOME/jdk"

# 关键：清除 JAVA_HOME，让 ES 使用 bundled JDK
su - $ES_USER -c "cd $ES_HOME && unset JAVA_HOME && nohup $ES_HOME/bin/elasticsearch > $ES_HOME/logs/console.log 2>&1 &"

echo "Elasticsearch 启动中..."

sleep 5

tail -30 $ES_HOME/logs/console.log
echo ""
echo "检查服务状态..."
sleep 2
if netstat -tlnp 2>/dev/null | grep -q ':9210' || ss -tlnp 2>/dev/null | grep -q ':9210'; then
    echo "✅ Elasticsearch (实例 2) 启动成功！"
    echo "访问地址: http://172.16.47.57:9210"
else
    echo "⚠️  端口 9210 未监听，请检查日志"
fi
```

### 4.2 通用停止脚本模板

#### stop-es.sh (所有实例通用，只需修改 ES_HOME)

```bash
#!/bin/bash

ES_USER=elastic
ES_HOME=/data2/elasticsearch  # 每个实例修改此路径

echo "====================================="
echo "停止 Elasticsearch"
echo "实例路径: $ES_HOME"
echo "====================================="

echo "正在查找 Elasticsearch 进程..."
PIDS=$(ps aux | grep '[e]lasticsearch' | grep "$ES_HOME" | awk '{print $2}')

if [ -z "$PIDS" ]; then
    echo "没有运行的 Elasticsearch 进程"
    echo ""
    # 检查端口
    PORT=$(echo $ES_HOME | grep -o 'data[0-9]' | grep -o '[0-9]')
    PORT_NUM=$((9200 + (PORT - 2) * 10))
    if netstat -tlnp 2>/dev/null | grep -q ":$PORT_NUM" || ss -tlnp 2>/dev/null | grep -q ":$PORT_NUM"; then
        echo "⚠️  端口 $PORT_NUM 仍在监听，可能有其他进程占用"
    else
        echo "✅ 端口已释放"
    fi
    exit 0
fi

echo "找到进程: $PIDS"
echo "正在停止..."
kill $PIDS

sleep 5

REMAINING=$(ps aux | grep '[e]lasticsearch' | grep "$ES_HOME" | awk '{print $2}')
if [ -n "$REMAINING" ]; then
    echo "强制停止进程..."
    kill -9 $REMAINING
    sleep 2
fi

# 验证端口是否释放
sleep 1
PORT=$(echo $ES_HOME | grep -o 'data[0-9]' | grep -o '[0-9]')
PORT_NUM=$((9200 + (PORT - 2) * 10))
if netstat -tlnp 2>/dev/null | grep -q ":$PORT_NUM" || ss -tlnp 2>/dev/null | grep -q ":$PORT_NUM"; then
    echo "⚠️  端口仍在监听"
else
    echo "✅ Elasticsearch 已停止"
fi
```

### 4.3 赋予执行权限

```bash
chmod +x /data2/elasticsearch/start-es.sh
chmod +x /data2/elasticsearch/stop-es.sh
chmod +x /data3/elasticsearch/start-es.sh
chmod +x /data3/elasticsearch/stop-es.sh
# ... 其他实例
```

---

## 五、启动顺序与验证

### 5.1 启动顺序

```bash
# 1. 启动实例 1
cd /data2/elasticsearch && bash start-es.sh

# 2. 等待 10 秒
sleep 10

# 3. 启动实例 2
cd /data3/elasticsearch && bash start-es.sh

# 4. 等待 10 秒
sleep 10

# 5. 启动实例 3（如果需要）
cd /data4/elasticsearch && bash start-es.sh
```

### 5.2 验证步骤

```bash
# 1. 检查所有进程
ps aux | grep '[e]lasticsearch'

# 2. 检查所有端口
netstat -tlnp | grep -E ':(9200|9210|9220|9300|9310|9320)'

# 3. 测试每个实例
curl http://localhost:9200
curl http://localhost:9210
curl http://localhost:9220

# 4. 检查集群健康
curl 'http://localhost:9200/_cluster/health?pretty'
curl 'http://localhost:9210/_cluster/health?pretty'
curl 'http://localhost:9220/_cluster/health?pretty'
```

---

## 六、端口冲突检测

### 6.1 检测脚本

```bash
#!/bin/bash
# check-ports.sh - 端口冲突检测脚本

echo "检查 Elasticsearch 端口占用情况..."
echo "====================================="

# 定义端口列表
PORTS=(9200 9210 9220 9300 9310 9320)

for PORT in "${PORTS[@]}"; do
    if netstat -tlnp 2>/dev/null | grep -q ":$PORT" || ss -tlnp 2>/dev/null | grep -q ":$PORT"; then
        PID=$(netstat -tlnp 2>/dev/null | grep ":$PORT" | awk '{print $7}' | cut -d'/' -f1)
        echo "⚠️  端口 $PORT 已被占用 (PID: $PID)"
    else
        echo "✅ 端口 $PORT 可用"
    fi
done

echo "====================================="
```

### 6.2 实时监控脚本

```bash
#!/bin/bash
# monitor-es.sh - 多实例监控脚本

while true; do
    clear
    echo "====================================="
    echo "Elasticsearch 多实例监控"
    echo "时间: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "====================================="
    echo ""

    # 实例 1
    echo "实例 1 (端口 9200):"
    if curl -s http://localhost:9200 > /dev/null 2>&1; then
        echo "  状态: ✅ 运行中"
        curl -s 'http://localhost:9200/_cluster/health?pretty' | grep 'status' | awk '{print "  集群: " $0}'
    else
        echo "  状态: ❌ 未运行"
    fi
    echo ""

    # 实例 2
    echo "实例 2 (端口 9210):"
    if curl -s http://localhost:9210 > /dev/null 2>&1; then
        echo "  状态: ✅ 运行中"
        curl -s 'http://localhost:9210/_cluster/health?pretty' | grep 'status' | awk '{print "  集群: " $0}'
    else
        echo "  状态: ❌ 未运行"
    fi
    echo ""

    echo "====================================="
    echo "按 Ctrl+C 退出"
    echo "====================================="

    sleep 10
done
```

---

## 七、常见问题与解决方案

### 7.1 端口冲突

**症状**: 启动失败，日志显示 "address already in use"

**解决方案**:
```bash
# 1. 查找占用端口的进程
netstat -tlnp | grep :9200

# 2. 停止占用端口的进程
kill -9 <PID>

# 3. 修改配置文件中的端口
vim $ES_HOME/config/elasticsearch.yml
```

### 7.2 内存不足

**症状**: 启动后 OOM (Out of Memory)

**解决方案**:
```bash
# 1. 降低堆内存
vim $ES_HOME/config/jvm.options
# 修改 -Xms 和 -Xmx 为更小的值

# 2. 确保物理内存充足
free -h

# 3. 调整 swap
sysctl vm.swappiness=10
```

### 7.3 JDK 版本冲突

**症状**: ES 启动时使用错误的 JDK 版本

**解决方案**: 在启动脚本中添加 `unset JAVA_HOME`（已在上述脚本中体现）

### 7.4 数据混淆

**症状**: 不同实例的数据相互干扰

**解决方案**: 确保 path.data 和 path.logs 完全独立

---

## 八、性能优化建议

### 8.1 资源隔离

```bash
# 使用 cgroups 限制资源（可选）
cgcreate -g cpu,memory:/es-instance-1
cgset -r cpu.shares=512 es-instance-1
cgset -r memory.limit_in_bytes=34359738368 es-instance-1  # 32GB
```

### 8.2 磁盘 I/O 优化

```bash
# 使用独立的磁盘（推荐）
# 实例 1: /data2 (独立磁盘或分区)
# 实例 2: /data3 (独立磁盘或分区)

# 挂载选项优化（/etc/fstab）
/dev/sdb1 /data2 ext4 defaults,noatime,nodiratime 0 2
/dev/sdc1 /data3 ext4 defaults,noatime,nodiratime 0 2
```

### 8.3 网络优化

```bash
# 调整 TCP 参数（/etc/sysctl.conf）
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
```

---

## 九、监控与告警

### 9.1 监控指标

| 指标 | 实例 1 | 实例 2 | 实例 3 |
|------|--------|--------|--------|
| 服务状态 | http://localhost:9200 | http://localhost:9210 | http://localhost:9220 |
| 集群健康 | _cluster/health | _cluster/health | _cluster/health |
| JVM 堆内存 | _nodes/stats | _nodes/stats | _nodes/stats |
| CPU 使用率 | _nodes/stats | _nodes/stats | _nodes/stats |
| 磁盘空间 | df -h /data2 | df -h /data3 | df -h /data4 |

### 9.2 简单监控脚本

```bash
#!/bin/bash
# health-check.sh - 健康检查脚本

INSTANCES=(
    "实例1:9200:/data2"
    "实例2:9210:/data3"
    "实例3:9220:/data4"
)

for INSTANCE in "${INSTANCES[@]}"; do
    IFS=':' read -r NAME PORT PATH <<< "$INSTANCE"
    echo "检查 $NAME (端口 $PORT)..."

    # 检查端口
    if netstat -tlnp 2>/dev/null | grep -q ":$PORT"; then
        echo "  ✅ 端口 $PORT 正常"

        # 检查 API
        if curl -s "http://localhost:$PORT" > /dev/null; then
            echo "  ✅ API 响应正常"

            # 检查集群健康
            STATUS=$(curl -s "http://localhost:$PORT/_cluster/health" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
            echo "  集群状态: $STATUS"
        else
            echo "  ⚠️  API 无响应"
        fi
    else
        echo "  ❌ 端口 $PORT 未监听"
    fi

    # 检查磁盘空间
    DISK_USAGE=$(df -h "$PATH" | tail -1 | awk '{print $5}' | sed 's/%//')
    if [ $DISK_USAGE -gt 85 ]; then
        echo "  ⚠️  磁盘使用率: $DISK_USAGE%"
    else
        echo "  ✅ 磁盘使用率: $DISK_USAGE%"
    fi

    echo ""
done
```

---

## 十、总结与最佳实践

### 10.1 核心原则

1. **完全隔离**: 每个实例的目录、端口、集群名必须完全独立
2. **资源规划**: 根据物理内存合理分配 JVM 堆内存
3. **启动脚本**: 统一使用 `unset JAVA_HOME` 确保 bundled JDK
4. **验证测试**: 启动后全面验证端口、API、集群状态
5. **文档记录**: 每个实例的配置信息必须文档化

### 10.2 检查清单

部署前检查：
- [ ] 端口未占用
- [ ] 磁盘空间充足
- [ ] 物理内存足够
- [ ] 目录权限正确
- [ ] 配置文件语法正确

启动后检查：
- [ ] 进程正常运行
- [ ] 端口正常监听
- [ ] API 可以访问
- [ ] 集群状态正常
- [ ] 日志无错误

### 10.3 快速参考

```bash
# === 启动所有实例 ===
for dir in /data2/elasticsearch /data3/elasticsearch /data4/elasticsearch; do
    cd $dir && bash start-es.sh
    sleep 10
done

# === 停止所有实例 ===
for dir in /data2/elasticsearch /data3/elasticsearch /data4/elasticsearch; do
    cd $dir && bash stop-es.sh
done

# === 检查所有实例 ===
for port in 9200 9210 9220; do
    echo "检查端口 $port:"
    curl -s "http://localhost:$port" | grep -E '(name|number)'
    echo ""
done
```

---

**文档版本**: 1.0
**创建时间**: 2026-01-14
**适用版本**: Elasticsearch 7.x
**维护者**: DevOps Team
