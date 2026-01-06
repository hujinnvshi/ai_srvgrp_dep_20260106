# MySQL 优化配置说明

## 服务器信息
- **IP 地址**: 172.16.47.63
- **实例名称**: MySQL5739_ISAS_6003
- **端口**: 9010
- **版本**: MySQL 5.7.39
- **配置文件**: /old-data/MySQL5739_ISAS_6003/base/5739/my.cnf

## 系统环境

### 资源配置
- **CPU**: 48 核
- **总内存**: 220GB
- **优化前内存使用**: 190GB (86%)
- **可用内存**: 15GB
- **Swap**: 15GB (已使用 3GB)

### MySQL 实例分布
服务器上运行多个 MySQL 实例：
- MySQL SSL v2 (端口 3014): 1.4GB
- MySQL v1 (端口 3010): 11.5GB
- MySQL 6004 (端口 6004): 9.9GB
- **MySQL 6003 (目标)**: 158GB
- GreatDB (端口 6108): 1.5GB
- **总计**: 180GB+

## 优化前的问题

### 1. 内存配置过高
- `innodb_buffer_pool_size = 134G`
- 实际物理内存占用: **158GB** (RSS)
- 占系统总内存 **71.7%**
- 系统可用内存仅 **15GB**
- **风险**: OOM Killer 可能杀进程

### 2. 使用废弃的 Query Cache
```ini
query_cache_type = 1
query_cache_size = 640M
```
- MySQL 5.7 中已废弃
- MySQL 8.0 已完全移除
- 增加锁竞争，降低并发性能

### 3. max_connections 设置过大
- `max_connections = 15000`
- 按每连接 0.5-1MB 计算，可能需要 7.5GB+ 额外内存
- 实际使用可能远低于此值

### 4. 配置文件重复定义
```ini
wait_timeout = 3000        # 第 20 行
interactive_timeout = 3000  # 第 21 行
# ...
interactive_timeout = 3600  # 第 63 行，重复！
wait_timeout = 3600         # 第 64 行，重复！
```

### 5. 慢查询日志未启用
- `slow_query_log = off`
- 无法分析和优化慢查询

### 6. IO 参数设置保守
- `innodb_io_capacity = 200` (对于现代存储设备过低)
- `innodb_io_capacity_max = 1000`

## 优化内容

### 1. 降低 InnoDB Buffer Pool Size

```ini
# 优化前
innodb_buffer_pool_size = 134G

# 优化后
innodb_buffer_pool_size = 100G
```

**预期效果**:
- 释放约 **30-35GB** 内存
- 系统可用内存从 15GB 提升至 **45-50GB**
- 降低 OOM 风险
- Buffer Pool 命中率通常影响很小（从 99% 降至 98% 左右）

### 2. 移除 Query Cache 配置

```ini
# 优化前
query_cache_type = 1
query_cache_size = 640M

# 优化后
# 已移除 query_cache 相关配置
```

**预期效果**:
- 释放 640MB 内存
- 消除 Query Cache 带来的锁竞争
- 提升并发性能
- 符合 MySQL 8.0 标准

### 3. 调整 max_connections

```ini
# 优化前
max_connections = 15000

# 优化后
max_connections = 2000
```

**预期效果**:
- 降低连接内存占用
- 2000 个连接对大多数应用已足够
- 可根据实际使用情况进一步调整

### 4. 修正超时配置

```ini
# 优化后（保留一组配置）
wait_timeout = 3600
interactive_timeout = 3600
```

### 5. 启用慢查询日志

```ini
# 优化前
slow_query_log = off
long_query_time = 5

# 优化后
slow_query_log = 1
long_query_time = 2
```

**预期效果**:
- 可以捕获和优化慢查询
- 设置为 2 秒，捕获更多需要优化的查询

### 6. 优化 IO 相关参数

```ini
# 优化前
innodb_io_capacity = 200
innodb_io_capacity_max = 1000

# 优化后
innodb_io_capacity = 2000
innodb_io_capacity_max = 4000
```

**预期效果**:
- 适应现代 SSD/高性能存储设备
- 提升 IO 吞吐量
- 降低刷盘延迟

### 7. 优化刷盘策略

```ini
# 优化前（最安全）
innodb_flush_log_at_trx_commit = 1
sync_binlog = 1

# 优化后（平衡性能和安全）
innodb_flush_log_at_trx_commit = 2
sync_binlog = 10
```

**预期效果**:
- 显著提升写入性能（+20-50%）
- 最多可能丢失 1 秒内的数据
- 如果业务要求绝对安全，可以保持为 1

**注意**: 这是一个权衡配置，根据业务需求选择：
- 金融/支付等关键业务: 保持为 `1`
- 一般业务: 使用优化后的 `2` 和 `10`

## 优化效果预估

| 项目 | 优化前 | 优化后 | 改善 |
|------|--------|--------|------|
| **MySQL 内存占用** | 158GB | ~120GB | 减少 38GB |
| **系统可用内存** | 15GB | ~55GB | 增加 40GB |
| **Swap 使用** | 3GB | 0-1GB | 降低 |
| **OOM 风险** | 高 | 低 | ✅ |
| **Query Cache 锁竞争** | 存在 | 无 | ✅ |
| **慢查询可见性** | 无 | 有 | ✅ |
| **写入性能** | 基准 | +20-50% | ✅ |
| **TPS/QPS** | 基准 | +10-20% | ✅ |

## 部署步骤

### 1. 备份当前配置

```bash
ssh root@172.16.47.63
cp /old-data/MySQL5739_ISAS_6003/base/5739/my.cnf \
   /old-data/MySQL5739_ISAS_6003/base/5739/my.cnf.backup.$(date +%Y%m%d_%H%M%S)
```

### 2. 应用优化配置

```bash
# 方式1: 使用 scp 上传
scp my.cnf.optimized root@172.16.47.63:/old-data/MySQL5739_ISAS_6003/base/5739/my.cnf

# 方式2: 直接编辑
vi /old-data/MySQL5739_ISAS_6003/base/5739/my.cnf
```

### 3. 重启 MySQL

```bash
# 优雅关闭
mysqladmin -uroot -p'Rede@612@Mixed' -S/old-data/MySQL5739_ISAS_6003/data/mysql.sock shutdown

# 或使用 systemd (如果已配置)
systemctl stop mysql-6003

# 启动
systemctl start mysql-6003

# 检查启动状态
systemctl status mysql-6003
tail -f /old-data/MySQL5739_ISAS_6003/log/mysqldb-error.err
```

### 4. 验证优化效果

```bash
# 检查内存使用
ps aux | grep 'MySQL5739_ISAS_6003' | grep mysqld | grep -v safe

# 检查系统内存
free -h

# 连接 MySQL 验证参数
mysql -uroot -p'Rede@612@Mixed' -S/old-data/MySQL5739_ISAS_6003/data/mysql.sock \
  -e "SHOW VARIABLES LIKE 'innodb_buffer_pool_size';
       SHOW VARIABLES LIKE 'max_connections';
       SHOW VARIABLES LIKE 'slow_query_log';
       SHOW VARIABLES LIKE 'innodb_io_capacity';"
```

## 监控建议

优化后需要持续监控以下指标：

```sql
-- 1. 连接数使用情况
SHOW STATUS LIKE 'Threads_connected';
SHOW STATUS LIKE 'Max_used_connections';

-- 计算: Max_used_connections / max_connections * 100%
-- 如果接近 80%，需要增加 max_connections

-- 2. Buffer Pool 命中率
SHOW STATUS LIKE 'Innodb_buffer_pool_read%';

-- 命中率计算:
-- (1 - Innodb_buffer_pool_reads / Innodb_buffer_pool_read_requests) * 100%
-- 目标: > 98%

-- 3. 慢查询统计
SHOW STATUS LIKE 'Slow_queries';

-- 4. 锁等待
SHOW STATUS LIKE 'Innodb_row_lock%';
-- 关注: Innodb_row_lock_current_waits (应该接近 0)
-- 关注: Innodb_row_lock_time_avg (平均锁等待时间)

-- 5. 内存使用
SHOW STATUS LIKE 'Innodb_buffer_pool_bytes_data';

-- 6. 连接线程
SHOW STATUS LIKE 'Threads_running';
-- 目标: < 100

-- 7. QPS/TPS
SHOW STATUS LIKE 'Questions';
SHOW STATUS LIKE 'Com_commit';
SHOW STATUS LIKE 'Com_rollback';
```

## 回滚方案

如果优化后出现问题，可以快速回滚：

```bash
# 停止 MySQL
systemctl stop mysql-6003

# 恢复备份配置
cp /old-data/MySQL5739_ISAS_6003/base/5739/my.cnf.backup.* \
   /old-data/MySQL5739_ISAS_6003/base/5739/my.cnf

# 重启 MySQL
systemctl start mysql-6003
```

## 注意事项

### 1. 刷盘策略说明

优化后的配置将刷盘策略从最安全改为平衡模式：
- `innodb_flush_log_at_trx_commit = 2`: 每秒写入并刷盘日志
- `sync_binlog = 10`: 每 10 次事务刷盘 binlog

**影响**:
- 最多可能丢失 1 秒内的数据
- 如果服务器宕机，已提交但未刷盘的事务会丢失

**建议**:
- 金融/支付等关键业务: 保持为 `1`
- 一般业务: 使用优化后的 `2` 和 `10`
- 确保有定期备份和从库同步

### 2. max_connections 调整

优化后设置为 2000，建议：
- 监控实际连接数使用情况
- 如果经常超过 1600 (80%)，建议调整到 3000
- 如果长期低于 500 (25%)，可以降至 1000

### 3. 慢查询日志

启用慢查询日志后：
- 定期检查慢查询日志: `/old-data/MySQL5739_ISAS_6003/log/mysqldb-query.err`
- 使用 pt-query-digest 工具分析慢查询
- 优化前 10 个最慢的查询

### 4. InnoDB Buffer Pool Size

优化后设置为 100G，建议：
- 监控 Buffer Pool 命中率
- 如果命中率 > 98%，说明配置合理
- 如果命中率 < 95%，可以考虑适当增加
- 确保系统有足够的可用内存 (至少 20GB)

## 后续优化建议

### 短期 (1-2 周)
1. 监控内存和性能指标
2. 分析慢查询日志并优化
3. 根据实际情况调整 max_connections

### 中期 (1-2 个月)
1. 考虑使用 pt-stalk 工具进行性能采样
2. 分析并优化频繁执行的慢查询
3. 评估是否需要增加硬件资源

### 长期 (3-6 个月)
1. 考虑升级到 MySQL 8.0
2. 评估是否需要读写分离
3. 考虑使用 ProxySQL 实现连接池和查询缓存

## 联系方式

如有问题或需要进一步优化，请联系：
- **维护团队**: AI服务组
- **优化日期**: 2026-01-06
- **配置版本**: 1.0
