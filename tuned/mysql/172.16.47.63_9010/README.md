# MySQL 172.16.47.63:9010 优化实例

## 快速信息

- **服务**: MySQL 5.7.39
- **实例**: MySQL5739_ISAS_6003
- **服务器**: 172.16.47.63 (oracle)
- **端口**: 9010
- **优化日期**: 2026-01-06
- **状态**: ✅ 运行中

---

## 优化效果

| 指标 | 优化前 | 优化后 | 改善 |
|------|--------|--------|------|
| **MySQL 内存** | 158GB | 12.6GB | ⬇️ 92% |
| **系统可用内存** | 15GB | 161GB | ⬆️ 973% |
| **内存使用率** | 86% | 20% | ⬇️ 66% |

---

## 快速命令

### SSH 连接
```bash
ssh root@172.16.47.63
```

### 服务管理
```bash
# 启动
systemctl start mysql-6003

# 停止
systemctl stop mysql-6003

# 重启
systemctl restart mysql-6003

# 状态
systemctl status mysql-6003

# 日志
journalctl -u mysql-6003 -f
```

### MySQL 连接
```bash
# Socket 连接
mysql -uroot -p'password' -S/old-data/MySQL5739_ISAS_6003/data/mysql.sock

# TCP 连接
mysql -h127.0.0.1 -P9010 -uroot -p'password'
```

---

## 文件位置

### 配置文件
- **当前配置**: `/old-data/MySQL5739_ISAS_6003/base/5739/my.cnf`
- **备份配置**: `/old-data/MySQL5739_ISAS_6003/base/5739/my.cnf.backup.20260106_173952`

### 日志文件
- **错误日志**: `/old-data/MySQL5739_ISAS_6003/log/mysqldb-error.err`
- **慢查询日志**: `/old-data/MySQL5739_ISAS_6003/log/mysqldb-query.err`

### systemd 服务
- **服务文件**: `/etc/systemd/system/mysql-6003.service`

---

## 主要优化变更

1. **内存优化**: innodb_buffer_pool_size: 134G → 100G
2. **移除废弃配置**: query_cache (640M)
3. **连接数优化**: max_connections: 15000 → 2000
4. **启用慢查询**: slow_query_log: OFF → ON
5. **IO 优化**: innodb_io_capacity: 200 → 2000
6. **刷盘策略**: flush_log_at_trx_commit: 1 → 2

---

## 回滚

如需回滚到原始配置：
```bash
systemctl stop mysql-6003
cp /old-data/MySQL5739_ISAS_6003/base/5739/my.cnf.backup.20260106_173952 \
   /old-data/MySQL5739_ISAS_6003/base/5739/my.cnf
systemctl start mysql-6003
```

---

## 详细文档

- [优化说明文档](docs/OPTIMIZATION.md) - 详细的优化说明和原理
- [部署报告](docs/DEPLOYMENT-SUCCESS.md) - 部署成功报告
- [分析报告](docs/optimization-report.md) - 优化前的分析报告

---

## 注意事项

⚠️ **刷盘策略**: 当前配置为性能优化模式，可能丢失 1 秒数据
⚠️ **密码验证**: MySQL root 密码需要确认
⚠️ **持续监控**: 建议监控 Buffer Pool 命中率和慢查询

---

**维护**: AI服务组 | **版本**: 1.0 | **日期**: 2026-01-06
