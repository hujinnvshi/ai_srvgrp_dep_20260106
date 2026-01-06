# GBase 8a MPP 部署

## 目录结构

```
gbase/
├── common/                          # 通用配置和工具
│   ├── backup/                      # 备份脚本和配置
│   ├── monitoring/                  # 监控脚本和配置
│   ├── optimization/                # 性能优化配置
│   ├── recovery/                    # 恢复脚本
│   └── security/                    # 安全配置
├── versions/                        # 版本管理
│   ├── v8.6.1/                      # GBase 8a v8.6.1
│   │   └── 3-node-cluster/          # 三节点集群部署
│   │       ├── scripts/             # 部署脚本
│   │       ├── config-templates/    # 配置模板
│   │       └── docs/                # 文档
│   └── v9.5.2/                      # GBase 8a v9.5.2
│       └── 3-node-cluster/          # 三节点集群部署
│           ├── scripts/             # 部署脚本
│           ├── config-templates/    # 配置模板
│           └── docs/                # 文档
```

## 版本说明

### v8.6.1
- **发布日期**: 2021
- **特性**: 稳定版本，广泛用于生产环境
- **部署模式**: 3节点 MPP 集群

### v9.5.2
- **发布日期**: 2023
- **特性**: 新一代版本，性能优化
- **部署模式**: 3节点 MPP 集群

## 三节点集群架构

```
                    [客户端应用]
                          |
                    [负载均衡]
                          |
        +-----------------+-----------------+
        |                 |                 |
   [gbase_gc1]      [gbase_gc2]      [gbase_gc3]
   Coordinator       Coordinator       Coordinator
   (Data Node)       (Data Node)       (Data Node)
        |                 |                 |
        +-----------------+-----------------+
                          |
                   [共享存储集群]
```

## 部署前准备

### 服务器要求

**节点配置**:
- 3台服务器（gbase_gc1, gbase_gc2, gbase_gc3）
- 操作系统: CentOS 7.6+ / RHEL 7.6+
- CPU: 8核+
- 内存: 32GB+
- 磁盘: 500GB+ SSD

**网络要求**:
- 千兆网卡
- 内网互通
- 端口开放: 9136 (协调器), 19000 (数据节点)

### 软件依赖

```bash
# 1. 安装 JDK
yum install -y java-1.8.0-openjdk java-1.8.0-openjdk-devel

# 2. 安装依赖包
yum install -y libaio numactl

# 3. 配置 hosts 文件
cat >> /etc/hosts << EOF
<IP1> gbase_gc1
<IP2> gbase_gc2
<IP3> gbase_gc3
EOF

# 4. 配置 SSH 免密登录
ssh-keygen -t rsa
ssh-copy-id root@gbase_gc1
ssh-copy-id root@gbase_gc2
ssh-copy-id root@gbase_gc3

# 5. 关闭防火墙和 SELinux
systemctl stop firewalld
systemctl disable firewalld
setenforce 0
sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
```

## 快速开始

选择对应版本的目录进行部署：

```bash
# 例如部署 v8.6.1 三节点集群
cd services/gbase/versions/v8.6.1/3-node-cluster/

# 查看部署脚本
ls -la scripts/

# 执行部署
bash scripts/deploy-gbase-3node.sh
```

## 部署脚本说明

### 主要脚本

| 脚本名称 | 说明 |
|---------|------|
| `deploy-gbase-3node.sh` | 三节点集群一键部署脚本 |
| `init-gcluster.sh` | 初始化集群脚本 |
| `start-gbase.sh` | 启动 GBase 服务 |
| `stop-gbase.sh` | 停止 GBase 服务 |
| `check-status.sh` | 检查集群状态 |

### 配置文件模板

| 配置文件 | 说明 |
|---------|------|
| `gbase_8a_gcluster.conf` | 协调器配置模板 |
| `gbase_8a_gnode.conf` | 数据节点配置模板 |
| `gbase_8a_user.conf` | 用户权限配置 |

## 部署流程

1. **环境准备** - 检查系统配置和依赖
2. **安装部署** - 在所有节点安装 GBase 软件
3. **集群初始化** - 创建和配置 MPP 集群
4. **服务启动** - 启动协调器和数据节点
5. **验证测试** - 验证集群功能

## 常用操作

### 集群管理

```bash
# 查看集群状态
gbase_query_status

# 启动集群
gbase_start_all

# 停止集群
gbase_stop_all

# 重启集群
gbase_restart_all
```

### 数据库连接

```bash
# 命令行连接
gccli -u root -p

# SQL 示例
CREATE DATABASE testdb;
USE testdb;
CREATE TABLE test (id INT, name VARCHAR(100));
INSERT INTO test VALUES (1, 'GBase 8a');
SELECT * FROM test;
```

## 监控和维护

- **日志位置**: `/opt/gbase/log/`
- **数据目录**: `/opt/gbase/data/`
- **配置目录**: `/opt/gbase/etc/`

## 故障排查

### 常见问题

1. **节点无法启动**
   - 检查端口是否被占用
   - 查看日志文件
   - 验证网络连通性

2. **集群状态异常**
   - 检查所有节点服务状态
   - 验证配置文件
   - 重启集群服务

## 参考资料

- [GBase 8a 官方文档](https://www.gbase.cn/)
- [MPP 架构说明](https://www.gbase.cn/documentation)

## 联系方式

如有问题，请联系项目维护人员。
