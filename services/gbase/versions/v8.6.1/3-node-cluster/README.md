# GBase 8a v8.6.1 - 三节点集群部署

## 部署信息

- **版本**: v8.6.1
- **部署模式**: 3节点 MPP 集群
- **协调器节点**: gbase_gc1, gbase_gc2, gbase_gc3
- **数据节点**: gbase_gc1, gbase_gc2, gbase_gc3

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
cd services/gbase/versions/v8.6.1/3-node-cluster/
bash scripts/deploy-gbase-3node.sh
```

### 3. 验证部署

```bash
# 检查集群状态
gbase_query_status

# 测试连接
gccli -u root -p
```

## 配置文件

- **gcluster配置**: 协调器配置文件
- **gnode配置**: 数据节点配置文件
- **用户配置**: 用户和权限配置

## 管理命令

```bash
# 启动集群
gbase_start_all

# 停止集群
gbase_stop_all

# 查看状态
gbase_query_status
```

## 注意事项

1. 部署前请确保所有节点网络互通
2. 配置 SSH 免密登录
3. 关闭防火墙和 SELinux
4. 确保磁盘空间充足

## 故障排查

查看日志文件:
```bash
tail -f /opt/gbase/log/gcluster.log
tail -f /opt/gbase/log/gnode.log
```
