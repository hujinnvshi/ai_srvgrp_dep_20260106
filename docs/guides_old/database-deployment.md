# 数据库部署指南

本文档介绍 MySQL PXC、达梦、Oracle RAC、GoldenDB 等数据库的部署流程和最佳实践。

## 目录
- [MySQL PXC 部署](#mysql-pxc-部署)
- [达梦数据库部署](#达梦数据库部署)
- [Oracle RAC 部署](#oracle-rac-部署)
- [GoldenDB 部署](#goldendb-部署)

---

## MySQL PXC 部署

### 版本支持
- 5.7.x
- 8.0.x (推荐)

### 架构说明

Percona XtraDB Cluster (PXC) 是基于 Galera 的 MySQL 同步多主集群。

#### 特性
- 同步复制
- 多主写入
- 自动故障转移
- 热备份

### 环境要求

#### 硬件要求
| 节点数 | 最小配置 | 推荐配置 |
|-------|----------|----------|
| 3节点 | 4C/8G/100G | 8C/16G/500G SSD |

#### 网络要求
- 低延迟网络 (< 1ms)
- 带宽 ≥ 1Gbps
- 端口开放: 3306, 4444, 4567, 4568

### 部署步骤

#### 1. 安装 Percona Repository
```bash
sudo yum install -y https://repo.percona.com/yum/percona-release-latest.noarch.rpm
sudo percona-release setup-only pxc-80
```

#### 2. 安装 PXC
```bash
sudo yum install -y Percona-XtraDB-Cluster-full-80
```

#### 3. 配置 my.cnf

**节点1**
```ini
[mysqld]
# 基本配置
server-id=1
datadir=/var/lib/mysql

# PXC 配置
wsrep_provider=/usr/lib64/galera4/libgalera_smm.so
wsrep_cluster_name=pxc-cluster
wsrep_cluster_address=gcomm://node1,node2,node3
wsrep_node_name=node1
wsrep_node_address=node1_ip

# SST 配置
wsrep_sst_method=xtrabackup-v2
wsrep_sst_auth=sst_user:sst_password

# 二进制日志
log-bin=mysql-bin
binlog_format=ROW
```

**节点2/3**: 修改 server-id 和 wsrep_node_name/wsrep_node_address

#### 4. 启动集群

**第一个节点**
```bash
sudo systemctl start mysql@bootstrap
```

**其他节点**
```bash
sudo systemctl start mysql
```

#### 5. 创建 SST 用户
```sql
CREATE USER 'sst_user'@'localhost' IDENTIFIED BY 'sst_password';
GRANT RELOAD, LOCK TABLES, PROCESS, REPLICATION CLIENT ON *.* TO 'sst_user'@'localhost';
FLUSH PRIVILEGES;
```

#### 6. 验证集群状态
```sql
SHOW STATUS LIKE 'wsrep%';
```

关键指标:
- wsrep_cluster_size: 应该是 3
- wsrep_cluster_status: Primary
- wsrep_ready: ON

### 集群管理

#### 节点维护
```bash
# 停止节点
sudo systemctl stop mysql

# 启动节点
sudo systemctl start mysql

# 查看集群状态
mysql -e "SHOW STATUS LIKE 'wsrep_cluster_size';"
```

#### 备份
```bash
# 全量备份
xtrabackup --backup --target-dir=/backup/full \
  --user=root --password=password

# 增量备份
xtrabackup --backup --target-dir=/backup/inc1 \
  --incremental-basedir=/backup/full
```

### 性能优化

#### 配置优化
```ini
# InnoDB 缓冲池
innodb_buffer_pool_size=4G

# 并发线程
innodb_thread_concurrency=0

# 日志配置
innodb_log_file_size=512M
innodb_flush_log_at_trx_commit=1
```

#### 流控调优
```ini
wsrep_slave_threads=4
wsrep_max_ws_size=2G
```

---

## 达梦数据库部署

### 版本支持
- DM7
- DM8 (推荐)

### 部署模式

#### 单机模式
适用于开发测试。

#### 主备模式
一个主库，一个或多个备库，支持故障切换。

#### 集群模式
DMDSC 集群，多节点共享存储。

### 环境要求

#### 硬件要求
| 角色 | 最小配置 | 推荐配置 |
|------|----------|----------|
| 主库 | 4C/8G/100G | 8C/16G/500G SSD |
| 备库 | 4C/8G/100G | 8C/16G/500G SSD |

### 部署步骤 (主备模式)

#### 1. 安装软件
```bash
# 挂载镜像
mount -o loop dm8_setup.iso /mnt

# 运行安装程序
cd /mnt
./DMInstall.bin -i
```

#### 2. 初始化数据库
```bash
cd /opt/dmdbms/bin
./dminit path=/opt/dmdbms/data PAGE_SIZE=16 LOG_SIZE=256
```

#### 3. 配置主库

**dm.ini**
```ini
PORT_NUM = 5236
DW_MODE = 0
DW_INACTIVE_INTERVAL = 60
```

**dmmal.ini**
```ini
MAL_CHECK_INTERVAL = 5
MAL_CONN_FAIL_INTERVAL = 5
[MAL_INST1]
  MAL_INST_NAME = GRP1_RT_01
  MAL_HOST = 192.168.1.1
  MAL_PORT = 5337
[MAL_INST2]
  MAL_INST_NAME = GRP1_RT_02
  MAL_HOST = 192.168.1.2
  MAL_PORT = 5337
```

**dmarch.ini**
```ini
[ARCHIVE_LOCAL1]
  ARCH_TYPE = LOCAL
  ARCH_DEST = /opt/dmdbms/arch
[ARCHIVE_REALTIME1]
  ARCH_TYPE = REALTIME
  ARCH_DEST = GRP1_RT_02
```

**dmwatcher.ini**
```ini
[GRP1]
  DW_TYPE = GLOBAL
  DW_MODE = AUTO
  DW_ERROR_TIME = 10
  INST_RECOVER_TIME = 60
  INST_INI_PATH /opt/dmdbms/data/dm.ini
```

#### 4. 启动主库
```bash
./dmserver /opt/dmdbms/data/dm.ini mount

# 连接并设置为主库
./disql
SP_SET_PARA_VALUE(2,'DW_MODE',1);
ALTER DATABASE STANDBY REDOLOG GROUP '/opt/dmdbms/data/standby01.log' SIZE 256;
ALTER DATABASE STANDBY REDOLOG GROUP '/opt/dmdbms/data/standby02.log' SIZE 256;
SP_SET_OGUID(123456);
ALTER DATABASE PRIMARY;
```

#### 5. 配置备库

复制主库配置文件，修改相关参数后启动。

#### 6. 启动守护进程
```bash
./dmwatcher /opt/dmdbms/data/dmwatcher.ini
```

### 数据守护管理

#### 查看状态
```sql
SELECT * FROM V$DW_INSTANCE;
```

#### 主备切换
```bash
# 停止主库守护进程
dmwatcher_stop

# 备库自动接管为主库
```

---

## Oracle RAC 部署

### 版本支持
- 11gR2
- 12cR2
- 19c (推荐)
- 21c

### 架构说明

Oracle Real Application Clusters (RAC) 允许多台服务器共享访问同一个 Oracle 数据库。

#### 组件
- **Grid Infrastructure**: 集群件 + ASM
- **RAC Database**: 数据库实例
- **Shared Storage**: 共享存储
- **Private Network**: 私有网络
- **Virtual IP**: 虚拟 IP
- **SCAN**: 单客户端访问名

### 环境要求

#### 硬件要求
| 组件 | 最小配置 | 推荐配置 |
|------|----------|----------|
| 节点 | 2节点 | 2-4节点 |
| CPU | 4C | 8C+ |
| 内存 | 8G | 16G+ |
| 共享存储 | 100G | 500G+ |

#### 网络要求
- Public Network: 业务网络
- Private Network: 心跳网络 (低延迟)
- Storage Network: 存储 (如使用 ASM)

### 部署步骤

#### 1. 系统准备
```bash
# 配置主机名
hostnamectl set-hostname racnode1

# 配置 /etc/hosts
192.168.1.10 racnode1
192.168.1.11 racnode2
192.168.1.12 racnode1-vip
192.168.1.13 racnode2-vip
192.168.1.14 rac-scan
192.168.1.15 rac-scan
192.168.1.16 rac-scan

# 配置内核参数
vi /etc/sysctl.conf
fs.aio-max-nr = 1048576
fs.file-max = 6815744
kernel.shmall = 2097152
kernel.shmmax = 1073741824
kernel.sem = 250 32000 100 128
net.ipv4.ip_local_port_range = 9000 65500

# 创建用户和组
groupadd -g 1000 oinstall
groupadd -g 1001 dba
useradd -u 1000 -g oinstall -G dba oracle

# 配置资源限制
vi /etc/security/limits.conf
oracle soft nproc 2047
oracle hard nproc 16384
oracle soft nofile 1024
oracle hard nofile 65536
```

#### 2. 配置共享存储

```bash
# 使用 multipath 配置多路径
multipath -ll

# 分区
fdisk /dev/mapper/mpathX

# 使用 ASM
oracleasm createdisk DATA1 /dev/mapper/mpathX1
oracleasm createdisk FRA1 /dev/mapper/mpathX2
```

#### 3. 安装 Grid Infrastructure

```bash
# 解压安装包
unzip linux.x64_19c_grid_home.zip

# 运行安装程序
./gridSetup.sh
```

选择配置:
- Cluster type: Standard Cluster
- Node names: racnode1, racnode2
- SCAN: rac-scan
- Network: Public, Private
- Storage: ASM

#### 4. 安装 RAC Database

```bash
# 解压安装包
unzip linux.x64_19c_database.zip

# 运行安装程序
./runInstaller
```

配置:
- Database type: General Purpose
- Storage: ASM
- RAC: 2-node

#### 5. 验证

```bash
# 检查集群状态
crsctl check cluster

# 检查资源
crsctl status resource -t

# 检查实例
srvctl status instance -d orcl -n racnode1
```

### 集群管理

#### 资源管理
```bash
# 启动资源
srvctl start database -d orcl

# 停止资源
srvctl stop database -d orcl

# 查看状态
srvctl status database -d orcl
```

#### 节点管理
```bash
# 添加节点
./addnode.sh

# 删除节点
./deinstall -local
```

### 备份恢复

#### RMAN 备份
```bash
rman target /

RMAN> BACKUP DATABASE;
RMAN> BACKUP ARCHIVELOG ALL;
RMAN> BACKUP CONTROLFILE;
```

#### 数据泵
```bash
# 导出
expdp system/password DIRECTORY=dp_dir DUMPFILE=exp.dmp LOGFILE=exp.log FULL=y

# 导入
impdp system/password DIRECTORY=dp_dir DUMPFILE=exp.dmp LOGFILE=imp.log FULL=y
```

---

## GoldenDB 部署

### 环境要求

#### 硬件要求
| 角色 | 最小配置 | 推荐配置 |
|------|----------|----------|
| 数据节点 | 4C/8G/100G | 8C/16G/500G SSD |

### 部署步骤

#### 1. 安装软件
[根据官方安装文档]

#### 2. 配置集群
[配置集群参数]

#### 3. 启动服务
[启动和验证]

---

## 通用最佳实践

### 安全配置

1. **最小权限原则**
   - 只授予必要的权限
   - 定期审计用户权限

2. **网络安全**
   - 限制数据库端口访问
   - 使用 SSL/TLS 加密连接

3. **审计日志**
   - 启用审计日志
   - 定期检查日志

### 性能优化

1. **索引优化**
   - 合理创建索引
   - 定期重建索引

2. **SQL 优化**
   - 使用 EXPLAIN 分析执行计划
   - 优化慢查询

3. **参数调优**
   - 缓冲池大小
   - 连接数配置
   - 日志配置

### 高可用设计

1. **备份策略**
   - 全量备份 + 增量备份
   - 异地备份
   - 定期验证备份

2. **监控告警**
   - 数据库状态监控
   - 性能指标监控
   - 异常告警

3. **灾难恢复**
   - 制定恢复流程
   - 定期演练
   - RTO/RPO 目标

---

## 参考资源
- [Percona XtraDB Cluster 文档](https://docs.percona.com/percona-xtradb-cluster/)
- [达梦数据库文档](https://www.dameng.com/)
- [Oracle RAC 文档](https://docs.oracle.com/en/database/oracle/oracle-database/)
