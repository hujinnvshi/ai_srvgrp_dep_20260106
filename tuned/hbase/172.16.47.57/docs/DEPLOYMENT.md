# HBase 2.5.10 单机版部署手册

## 📋 目录

1. [环境要求](#环境要求)
2. [架构说明](#架构说明)
3. [端口规划](#端口规划)
4. [快速部署](#快速部署)
5. [详细部署步骤](#详细部署步骤)
6. [验证测试](#验证测试)
7. [常用操作](#常用操作)
8. [故障排查](#故障排查)
9. [性能优化](#性能优化)
10. [数据备份](#数据备份)

---

## 环境要求

### 硬件要求

| 资源 | 最低配置 | 推荐配置 |
|-----|---------|---------|
| CPU | 4核 | 8核+ |
| 内存 | 8GB | 32GB+ |
| 磁盘 | 100GB | 500GB+ SSD |

### 软件要求

| 软件 | 版本要求 |
|-----|---------|
| 操作系统 | CentOS 7+ / Ubuntu 18.04+ |
| JDK | 1.8.0_412 (Java 8) |
| Hadoop | 3.3.6 |
| ZooKeeper | 3.8.4 |
| HBase | 2.5.10 |

### 网络要求

- 服务器IP: `172.16.47.57`
- 主机名解析: `/etc/hosts` 中需要配置主机名映射

---

## 架构说明

### 单机部署架构

```
┌─────────────────────────────────────────────────────┐
│                  172.16.47.57                        │
├─────────────────────────────────────────────────────┤
│                                                       │
│  ┌──────────────┐                                   │
│  │   ZooKeeper  │  (端口: 2181)                     │
│  │   3.8.4      │                                   │
│  └──────┬───────┘                                   │
│         │                                            │
│  ┌──────▼────────┐                                  │
│  │    Hadoop     │  (端口: 9000, 9870, 9866)       │
│  │    3.3.6      │  - NameNode                      │
│  │               │  - DataNode                      │
│  └──────┬────────┘                                  │
│         │                                            │
│  ┌──────▼────────┐                                  │
│  │    HBase      │  (端口: 16010, 16030)           │
│  │    2.5.10     │  - HBase Master                 │
│  │               │  - RegionServer                 │
│  └───────────────┘                                  │
│                                                       │
└─────────────────────────────────────────────────────┘
```

### 数据目录结构

```
/opt/                    # 安装目录
├── java/
│   └── jdk1.8.0_412/    # JDK
├── zookeeper/           # ZooKeeper 安装目录
├── hadoop/              # Hadoop 安装目录
└── hbase/               # HBase 安装目录

/data/                   # 数据目录
├── zookeeper/           # ZooKeeper 数据
├── hadoop/              # Hadoop HDFS 数据
└── hbase/               # HBase 数据
```

---

## 端口规划

### ZooKeeper 端口

| 端口 | 用途 | 说明 |
|-----|------|------|
| 2181 | 客户端连接端口 | ZooKeeper客户端连接 |
| 8080 | 管理端口 | 已禁用以避免冲突 |

### Hadoop 端口

| 端口 | 用途 | 说明 |
|-----|------|------|
| 9000 | NameNode RPC | HDFS RPC通信 |
| 9870 | NameNode Web UI | HDFS管理界面 |
| 9866 | DataNode传输 | 数据传输端口 |
| 9864 | DataNode Web UI | DataNode管理界面 |

### HBase 端口

| 端口 | 用途 | 说明 |
|-----|------|------|
| 16000 | HBase Master RPC | Master RPC通信 |
| 16010 | HBase Master Web UI | Master管理界面 |
| 16020 | RegionServer RPC | RegionServer RPC通信 |
| 16030 | RegionServer Web UI | RegionServer管理界面 |

---

## 快速部署

### 前提条件

```bash
# 1. 上传部署包到服务器
scp -r tuned/hbase/172.16.47.57 user@172.16.47.57:/opt/deployment/

# 2. 登录服务器
ssh user@172.16.47.57

# 3. 进入脚本目录
cd /opt/deployment/scripts
```

### 一键部署

```bash
# 给脚本添加执行权限
chmod +x *.sh

# 按顺序执行
./01-check-env.sh          # 环境检查
./02-install-jdk.sh        # 安装JDK
source ~/.bashrc           # 使环境变量生效
./03-install-zookeeper.sh  # 安装ZooKeeper
./04-install-hadoop.sh     # 安装Hadoop
./05-install-hbase.sh      # 安装HBase
source ~/.bashrc           # 再次使环境变量生效
./06-start-all.sh start    # 启动所有服务
```

---

## 详细部署步骤

### 第一步: 环境检查

```bash
bash 01-check-env.sh
```

**检查内容:**
- ✓ 用户权限 (不使用root运行)
- ✓ 系统工具 (wget, tar, curl等)
- ✓ 系统资源 (内存、磁盘)
- ✓ **端口占用检查** (所有必需端口)
- ✓ 主机名配置
- ✓ SELinux状态
- ✓ 防火墙配置

**端口检查详情:**

脚本会自动检查以下端口是否被占用:

```bash
检查端口占用情况:
- 16000 (HBase Master)
- 16010 (HBase Master Web)
- 16020 (RegionServer)
- 16030 (RegionServer Web)
- 9000 (Hadoop NameNode)
- 9870 (NameNode Web UI)
- 9866 (DataNode)
- 9864 (DataNode Web)
- 2181 (ZooKeeper)
- 8080 (ZooKeeper Admin)
```

**如有端口被占用:**

```bash
# 查看端口占用
sudo netstat -tulnp | grep <端口号>

# 或
sudo lsof -i :<端口号>

# 停止占用端口的进程
sudo kill -9 <PID>

# 或者临时关闭防火墙
sudo systemctl stop firewalld
```

### 第二步: 安装JDK

```bash
bash 02-install-jdk.sh
source ~/.bashrc
java -version
```

**预期输出:**
```
java version "1.8.0_412"
Java(TM) SE Runtime Environment (build 1.8.0_412-b08)
Java HotSpot(TM) 64-Bit Server VM (build 25.412-b08, mixed mode)
```

### 第三步: 安装ZooKeeper

```bash
bash 03-install-zookeeper.sh
source ~/.bashrc

# 验证安装
which zkServer.sh
zkServer.sh status
```

### 第四步: 安装Hadoop

```bash
bash 04-install-hadoop.sh
source ~/.bashrc

# 验证安装
hdfs version
```

### 第五步: 安装HBase

```bash
bash 05-install-hbase.sh
source ~/.bashrc

# 验证安装
hbase version
```

### 第六步: 启动所有服务

```bash
bash 06-start-all.sh start
```

**启动顺序:**
1. ZooKeeper
2. Hadoop HDFS
3. HBase

---

## 验证测试

### 1. 检查服务状态

```bash
bash 06-start-all.sh status
```

**预期输出:**
```
==========================================
服务状态
==========================================

[INFO] ✓ ZooKeeper 正在运行 (1/1 端口可达)
[INFO] ✓ Hadoop 正在运行 (3/3 端口可达)
[INFO] ✓ HBase 正在运行 (2/2 端口可达)
```

### 2. 测试服务可用性

```bash
bash 06-start-all.sh test
```

### 3. 访问Web UI

| 服务 | URL | 用户名/密码 |
|-----|-----|-----------|
| Hadoop NameNode | http://172.16.47.57:9870 | 无 |
| HBase Master | http://172.16.47.57:16010 | 无 |

### 4. 命令行测试

```bash
# 测试ZooKeeper
echo "ruok" | nc localhost 2181
# 输出: imok

# 测试Hadoop HDFS
hdfs dfs -mkdir /test
hdfs dfs -ls /
hdfs dfs -rm -r /test

# 测试HBase
hbase shell
version
list
exit
```

### 5. 创建HBase表测试

```bash
# 进入HBase Shell
hbase shell

# 创建表
create 'test_table', 'cf'

# 插入数据
put 'test_table', 'row1', 'cf:col1', 'value1'
put 'test_table', 'row2', 'cf:col2', 'value2'

# 查询数据
scan 'test_table'

# 获取单行
get 'test_table', 'row1'

# 删除表
disable 'test_table'
drop 'test_table'

# 退出
exit
```

---

## 常用操作

### 服务管理

```bash
# 启动所有服务
bash 06-start-all.sh start

# 停止所有服务
bash 06-start-all.sh stop

# 重启所有服务
bash 06-start-all.sh restart

# 查看状态
bash 06-start-all.sh status
```

### 单独管理服务

```bash
# ZooKeeper
/opt/zookeeper/bin/zkServer.sh start
/opt/zookeeper/bin/zkServer.sh stop
/opt/zookeeper/bin/zkServer.sh status

# Hadoop
/opt/hadoop/sbin/start-dfs.sh
/opt/hadoop/sbin/stop-dfs.sh

# HBase
/opt/hbase/bin/start-hbase.sh
/opt/hbase/bin/stop-hbase.sh
```

### 查看日志

```bash
# 使用脚本查看
bash 06-start-all.sh logs zk        # ZooKeeper日志
bash 06-start-all.sh logs hadoop    # Hadoop日志
bash 06-start-all.sh logs hbase     # HBase日志

# 直接查看
tail -f /opt/zookeeper/logs/zookeeper-*.log
tail -f /opt/hadoop/logs/hadoop-*-namenode-*.log
tail -f /opt/hbase/logs/hbase-*-master-*.log
```

### HBase Shell常用命令

```bash
# 进入Shell
hbase shell

# 通用命令
version                     # 查看版本
status                      # 查看状态
table_help                  # 表帮助
whoami                      # 当前用户

# DDL操作
list                        # 列出所有表
create 'table', 'cf'        # 创建表
describe 'table'            # 表结构
disable 'table'             # 禁用表
drop 'table'                # 删除表
truncate 'table'            # 清空表

# DML操作
put 'table', 'row', 'cf:col', 'value'   # 插入数据
get 'table', 'row'                      # 获取行
scan 'table'                            # 扫描表
delete 'table', 'row', 'cf:col'         # 删除列
count 'table'                           # 统计行数
```

---

## 故障排查

### 问题1: 端口被占用

**症状:**
```
[ERROR] 端口 2181 已被占用
```

**解决方法:**
```bash
# 1. 查找占用进程
sudo netstat -tulnp | grep 2181
# 或
sudo lsof -i :2181

# 2. 停止进程
sudo kill -9 <PID>

# 3. 如果是防火墙，临时关闭
sudo systemctl stop firewalld
# 或开放端口
sudo firewall-cmd --add-port=2181/tcp --permanent
sudo firewall-cmd --reload
```

### 问题2: Java版本不匹配

**症状:**
```
java.lang.UnsupportedClassVersionError
```

**解决方法:**
```bash
# 检查Java版本
java -version

# 确保使用Java 8
sudo alternatives --config java
# 选择 /opt/java/jdk1.8.0_412/bin/java

# 或设置JAVA_HOME
export JAVA_HOME=/opt/java/jdk1.8.0_412
```

### 问题3: NameNode未格式化

**症状:**
```
org.apache.hadoop.hdfs.server.common.InconsistentFSStateException
```

**解决方法:**
```bash
# 停止Hadoop
/opt/hadoop/sbin/stop-dfs.sh

# 删除旧数据
rm -rf /data/hadoop/hdfs/namenode/*
rm -rf /data/hadoop/hdfs/datanode/*

# 重新格式化
/opt/hadoop/bin/hdfs namenode -format

# 启动Hadoop
/opt/hadoop/sbin/start-dfs.sh
```

### 问题4: ZooKeeper连接失败

**症状:**
```
Connection refused to localhost:2181
```

**解决方法:**
```bash
# 检查ZooKeeper状态
/opt/zookeeper/bin/zkServer.sh status

# 查看日志
tail -f /opt/zookeeper/logs/zookeeper-*.log

# 重启ZooKeeper
/opt/zookeeper/bin/zkServer.sh restart

# 检查myid文件
cat /data/zookeeper/myid
# 应该输出: 1
```

### 问题5: HBase无法连接HDFS

**症状:**
```
java.io.IOException: Failed to connect
```

**解决方法:**
```bash
# 1. 检查HDFS状态
/opt/hadoop/bin/hdfs dfsadmin -report

# 2. 检查HDFS安全模式
/opt/hadoop/bin/hdfs dfsadmin -safemode get

# 3. 如果在安全模式，强制退出
/opt/hadoop/bin/hdfs dfsadmin -safemode leave

# 4. 重启HBase
/opt/hbase/bin/stop-hbase.sh
/opt/hbase/bin/start-hbase.sh
```

### 问题6: 内存不足

**症状:**
```
java.lang.OutOfMemoryError: Java heap space
```

**解决方法:**
```bash
# 调整HBase堆内存
vim /opt/hbase/conf/hbase-env.sh
# 修改: export HBASE_HEAPSIZE=8192 (单位MB)

# 调整Hadoop堆内存
vim /opt/hadoop/etc/hadoop/hadoop-env.sh
# 添加: export HADOOP_HEAPSIZE=4096

# 重启服务
bash 06-start-all.sh restart
```

---

## 性能优化

### 1. 操作系统优化

已在 `01-check-env.sh` 中自动配置:

```bash
# 查看系统参数
sudo sysctl -a | grep -E "file-max|swappiness"

# 手动调整 (如需要)
sudo sysctl -w vm.swappiness=10
sudo sysctl -w fs.file-max=655350
```

### 2. HBase性能调优

编辑 `/opt/hbase/conf/hbase-site.xml`:

```xml
<!-- 增加MemStore大小 -->
<property>
    <name>hbase.hregion.memstore.flush.size</name>
    <value>268435456</value> <!-- 256MB -->
</property>

<!-- 调整Block缓存 -->
<property>
    <name>hfile.block.cache.size</name>
    <value>0.4</value> <!-- 40%堆内存 -->
</property>

<!-- 增加RPC处理线程 -->
<property>
    <name>hbase.regionserver.handler.count</name>
    <value>100</value>
</property>
```

### 3. Hadoop性能调优

编辑 `/opt/hadoop/etc/hadoop/hdfs-site.xml`:

```xml
<!-- 增加数据传输缓冲区 -->
<property>
    <name>dfs.transfer.buffer.size</name>
    <value>131072</value> <!-- 128KB -->
</property>

<!-- 调整副本数 (生产环境建议3) -->
<property>
    <name>dfs.replication</name>
    <value>1</value> <!-- 单机设置为1 -->
</property>
```

### 4. JVM垃圾回收优化

编辑 `/opt/hbase/conf/hbase-env.sh`:

```bash
# 使用G1垃圾收集器 (Java 8+)
export HBASE_OPTS="$HBASE_OPTS -XX:+UseG1GC"
export HBASE_OPTS="$HBASE_OPTS -XX:MaxGCPauseMillis=200"
export HBASE_OPTS="$HBASE_OPTS -XX:ParallelGCThreads=8"
export HBASE_OPTS="$HBASE_OPTS -XX:ConcGCThreads=2"
```

---

## 数据备份

### HBase数据备份

```bash
# 1. 导出表数据
hbase org.apache.hadoop.hbase.mapreduce.Export \
  <table_name> \
  /backup/hbase/<table_name>_$(date +%Y%m%d)

# 2. 通过HDFS备份
hdfs dfs -getmerge /hbase/data/default/<table_name> \
  /backup/<table_name>.hfile

# 3. 快照备份
hbase snapshot create -n <snapshot_name> -t <table_name>
hbase snapshot export -snapshot <snapshot_name> \
  -copy-to /backup/hbase/snapshot
```

### HDFS数据备份

```bash
# 1. 使用distcp备份
hadoop distcp \
  hdfs://localhost:9000/hbase \
  hdfs://backup-namenode:9000/backup/hbase

# 2. 导出元数据
hdfs dfsadmin -fetchImage /backup/hdfs/fsimage_$(date +%Y%m%d)
```

### 恢复数据

```bash
# 1. 导入表数据
hbase org.apache.hadoop.hbase.mapreduce.Import \
  <table_name> \
  /backup/hbase/<table_name>_20250106

# 2. 从快照恢复
hbase snapshot restore -snapshot <snapshot_name> -t <table_name>
```

---

## 附录

### A. 配置文件位置

| 服务 | 配置文件 |
|-----|---------|
| ZooKeeper | `/opt/zookeeper/conf/zoo.cfg` |
| Hadoop | `/opt/hadoop/etc/hadoop/*.xml` |
| HBase | `/opt/hbase/conf/hbase-site.xml` |

### B. 日志文件位置

| 服务 | 日志目录 |
|-----|---------|
| ZooKeeper | `/opt/zookeeper/logs/` |
| Hadoop | `/opt/hadoop/logs/` |
| HBase | `/opt/hbase/logs/` |

### C. 卸载方法

```bash
# 停止所有服务
bash 06-start-all.sh stop

# 删除安装目录
sudo rm -rf /opt/{java,zookeeper,hadoop,hbase}

# 删除数据目录
sudo rm -rf /data/{zookeeper,hadoop,hbase}

# 删除环境变量
vim ~/.bashrc
# 删除Java/ZooKeeper/Hadoop/HBase相关配置

# 删除系统配置
sudo rm -f /etc/sysctl.d/99-hbase.conf
sudo rm -f /etc/security/limits.d/99-hbase.conf
```

### D. 参考文档

- [Hadoop官方文档](https://hadoop.apache.org/docs/stable/)
- [HBase官方文档](https://hbase.apache.org/book.html)
- [ZooKeeper官方文档](https://zookeeper.apache.org/doc/current/)

---

## 维护团队

- **文档版本**: 1.0
- **创建日期**: 2026-01-07
- **维护团队**: AI服务组
- **联系方式**: 查看项目README

---

**注意**: 本文档适用于单机学习和测试环境。生产环境部署需要额外考虑高可用、安全性、备份恢复等方面。
