# GBase 8a v9.5.2 - 三节点集群部署

## 部署信息

- **版本**: v9.5.2
- **部署模式**: 3节点 MPP 集群
- **协调器节点**: gbase_gc1, gbase_gc2, gbase_gc3
- **数据节点**: gbase_gc1, gbase_gc2, gbase_gc3

## 新版本特性

相比 v8.6.1，v9.5.2 提供以下改进：
- 性能优化提升 30%+
- 支持更多数据类型
- 增强的安全性
- 更好的 SQL 兼容性
- 改进的监控工具

## 目录说明

```
3-node-cluster/
├── scripts/            # 部署和管理脚本
├── config-templates/   # 配置文件模板
└── docs/              # 版本文档
```

## 部署步骤

### 1. 准备部署配置

编辑 `scripts/deploy-gbase-3node.sh`，配置以下信息：

```bash
# 节点信息
NODE1_IP="172.16.47.51"   # gbase_gc1
NODE2_IP="172.16.47.52"   # gbase_gc2
NODE3_IP="172.16.47.53"   # gbase_gc3

# 安装目录
INSTALL_BASE="/opt/gbase"

# 数据目录
DATA_DIR="/data/gbase"
```

### 2. 执行部署

```bash
cd services/gbase/versions/v9.5.2/3-node-cluster/
bash scripts/deploy-gbase-3node.sh
```

### 3. 验证部署

```bash
# 检查集群状态
gbase_query_status

# 测试连接
gccli -u root -p

# 查看版本
SELECT VERSION();
```

## 配置文件

- **gcluster配置**: 协调器配置文件（新增参数）
- **gnode配置**: 数据节点配置文件（优化参数）
- **用户配置**: 用户和权限配置（增强安全）
- **性能配置**: 性能调优参数

## 管理命令

```bash
# 启动集群
gbase_start_all

# 停止集群
gbase_stop_all

# 查看状态
gbase_query_status

# 查看性能指标
gbase_show_performance
```

## 注意事项

1. 部署前请确保所有节点网络互通
2. 配置 SSH 免密登录
3. 关闭防火墙和 SELinux
4. 确保磁盘空间充足
5. v9.5.2 要求更高内存配置（建议 64GB+）

## 升级说明

从 v8.6.1 升级到 v9.5.2:
```bash
# 1. 备份数据
gbase_backup_all

# 2. 停止集群
gbase_stop_all

# 3. 执行升级
bash scripts/upgrade-to-v9.5.2.sh

# 4. 启动集群
gbase_start_all

# 5. 验证
gbase_query_status
```

## 故障排查

查看日志文件:
```bash
tail -f /opt/gbase/log/gcluster.log
tail -f /opt/gbase/log/gnode.log
tail -f /opt/gbase/log/upgradelog.log
```

## 性能优化建议

1. **内存配置**: 建议 64GB 以上
2. **SSD 存储**: 使用 NVMe SSD 提升性能
3. **网络优化**: 使用万兆网络
4. **参数调优**: 根据业务场景调整配置参数
