# 大数据组件部署指南

本文档介绍 Hadoop、Hive、HBase 等大数据组件的部署流程和最佳实践。

## 目录
- [Hadoop 部署](#hadoop-部署)
- [Hive 部署](#hive-部署)
- [HBase 部署](#hbase-部署)

---

## Hadoop 部署

### 版本支持
- 2.10.x (LTS)
- 3.3.x (推荐)

### 环境要求

#### 硬件要求
| 角色 | 最小配置 | 推荐配置 |
|------|----------|----------|
| NameNode | 4C/8G/100G | 8C/16G/500G SSD |
| DataNode | 4C/8G/1T | 8C/16G/4T |
| ResourceManager | 4C/8G/100G | 8C/16G/200G |

#### 软件要求
- Java: JDK 1.8 (Hadoop 2.x) / JDK 8 或 11 (Hadoop 3.x)
- OS: CentOS 7+ / Ubuntu 18.04+
- SSH: 免密登录配置

### 部署模式

#### 1. 单机模式
适用于开发和测试。

#### 2. 伪分布式模式
单机模拟分布式环境，用于学习和小规模测试。

#### 3. 完全分布式模式
生产环境推荐使用。

### 部署步骤

#### 1. 环境准备
```bash
# 安装 JDK
sudo yum install -y java-1.8.0-openjdk java-1.8.0-openjdk-devel

# 配置环境变量
export JAVA_HOME=/usr/lib/jvm/java-1.8.0-openjdk
export PATH=$JAVA_HOME/bin:$PATH

# 创建 Hadoop 用户
sudo useradd -m hadoop
sudo passwd hadoop
```

#### 2. 下载安装包
```bash
wget https://downloads.apache.org/hadoop/common/hadoop-3.3.6/hadoop-3.3.6.tar.gz
tar -xzf hadoop-3.3.6.tar.gz
sudo mv hadoop-3.3.6 /opt/hadoop
sudo chown -R hadoop:hadoop /opt/hadoop
```

#### 3. 配置文件

**core-site.xml**
```xml
<configuration>
  <property>
    <name>fs.defaultFS</name>
    <value>hdfs://namenode:9000</value>
  </property>
  <property>
    <name>hadoop.tmp.dir</name>
    <value>/opt/hadoop/tmp</value>
  </property>
</configuration>
```

**hdfs-site.xml**
```xml
<configuration>
  <property>
    <name>dfs.replication</name>
    <value>3</value>
  </property>
  <property>
    <name>dfs.namenode.name.dir</name>
    <value>/opt/hadoop/hdfs/namenode</value>
  </property>
  <property>
    <name>dfs.datanode.data.dir</name>
    <value>/opt/hadoop/hdfs/datanode</value>
  </property>
</configuration>
```

**yarn-site.xml**
```xml
<configuration>
  <property>
    <name>yarn.nodemanager.aux-services</name>
    <value>mapreduce_shuffle</value>
  </property>
  <property>
    <name>yarn.resourcemanager.hostname</name>
    <value>resourcemanager</value>
  </property>
</configuration>
```

#### 4. 初始化 HDFS
```bash
hdfs namenode -format
```

#### 5. 启动服务
```bash
# 启动 HDFS
start-dfs.sh

# 启动 YARN
start-yarn.sh
```

#### 6. 验证
```bash
# 检查进程
jps

# 查看 HDFS 状态
hdfs dfsadmin -report

# Web UI
# HDFS: http://namenode:9870
# YARN: http://resourcemanager:8088
```

### 高可用配置

生产环境建议配置 HDFS HA 和 YARN HA。

#### HDFS HA
- 使用 Zookeeper 进行自动故障转移
- 配置多个 NameNode (Active/Standby)
- 使用 JournalNode 共享编辑日志

#### YARN HA
- 配置多个 ResourceManager
- 使用 Zookeeper 进行选举

---

## Hive 部署

### 版本支持
- 2.3.x
- 3.1.x (推荐)

### 环境要求
- Hadoop 集群已部署
- Java 8+
- 元数据库: MySQL 5.7+ / PostgreSQL 9.5+

### 部署架构

#### 部署模式
1. **内嵌模式**: 元数据存储在本地 Derby (仅测试)
2. **本地模式**: 元数据存储在独立数据库
3. **远程模式**: 元数据存储在独立数据库，推荐生产使用

### 部署步骤

#### 1. 安装
```bash
wget https://downloads.apache.org/hive/hive-3.1.3/apache-hive-3.1.3-bin.tar.gz
tar -xzf apache-hive-3.1.3-bin.tar.gz
sudo mv apache-hive-3.1.3-bin /opt/hive
```

#### 2. 配置元数据库
```sql
CREATE DATABASE hive_metastore;
CREATE USER 'hive'@'%' IDENTIFIED BY 'hive_password';
GRANT ALL PRIVILEGES ON hive_metastore.* TO 'hive'@'%';
FLUSH PRIVILEGES;
```

#### 3. 配置文件

**hive-site.xml**
```xml
<configuration>
  <property>
    <name>javax.jdo.option.ConnectionURL</name>
    <value>jdbc:mysql://localhost:3306/hive_metastore</value>
  </property>
  <property>
    <name>javax.jdo.option.ConnectionDriverName</name>
    <value>com.mysql.jdbc.Driver</value>
  </property>
  <property>
    <name>javax.jdo.option.ConnectionUserName</name>
    <value>hive</value>
  </property>
  <property>
    <name>javax.jdo.option.ConnectionPassword</name>
    <value>hive_password</value>
  </property>
</configuration>
```

#### 4. 初始化元数据
```bash
schematool -dbType mysql -initSchema
```

#### 5. 启动服务
```bash
# 启动 Metastore
hive --service metastore &

# 启动 HiveServer2
hive --service hiveserver2 &
```

### 性能优化

#### 执行引擎
- 使用 Tez 或 Spark 替代 MapReduce
- 配置 LLAP (Live Long and Process)

#### 分区策略
- 合理设计分区字段
- 使用动态分区
- 定期清理过期分区

---

## HBase 部署

### 版本支持
- 1.4.x
- 2.4.x (推荐)

### 环境要求
- Hadoop 集群已部署
- Zookeeper 集群
- Java 8+

### 部署架构

#### 组件说明
- **HMaster**: 管理元数据，负载均衡
- **RegionServer**: 处理读写请求
- **Zookeeper**: 协调服务

### 部署步骤

#### 1. 安装
```bash
wget https://downloads.apache.org/hbase/2.4.16/hbase-2.4.16-bin.tar.gz
tar -xzf hbase-2.4.16-bin.tar.gz
sudo mv hbase-2.4.16 /opt/hbase
```

#### 2. 配置文件

**hbase-site.xml**
```xml
<configuration>
  <property>
    <name>hbase.rootdir</name>
    <value>hdfs://namenode:9000/hbase</value>
  </property>
  <property>
    <name>hbase.cluster.distributed</name>
    <value>true</value>
  </property>
  <property>
    <name>hbase.zookeeper.quorum</name>
    <value>zk1,zk2,zk3</value>
  </property>
</configuration>
```

**regionservers**
```
regionserver-01
regionserver-02
regionserver-03
```

#### 3. 启动服务
```bash
start-hbase.sh
```

#### 4. 验证
```bash
# 连接 HBase
hbase shell

# Web UI
# http://hbase-master:16010
```

### 数据模型设计

#### RowKey 设计
- 避免热点
- 合理的长度
- 利用排序特性

#### 列族设计
- 控制列族数量 (1-3个)
- 合理设置版本数
- 配置压缩和块缓存

---

## 监控和运维

### 监控指标

#### Hadoop
- HDFS 使用率
- DataNode 存活数量
- YARN 资源使用率
- 任务执行情况

#### Hive
- 查询执行时间
- Metastore 连接数
- 并发查询数

#### HBase
- RegionServer 负载
- Region 数量和分布
- 请求 QPS
- 缓存命中率

### 常用命令

#### HDFS
```bash
# 查看 HDFS 状态
hdfs dfsadmin -report

# 重新平衡
hdfs balancer

# 安全模式
hdfs dfsadmin -safemode enter/leave
```

#### YARN
```bash
# 查看队列
yarn application -list

# 杀死任务
yarn application -kill <app_id>
```

#### HBase
```bash
# balance
hbase balancer

# major_compact
hbase shell > major_compact '<table_name>'
```

### 备份恢复

#### HDFS 快照
```bash
hdfs dfs -createSnapshot /path snapshot_name
hdfs dfs -deleteSnapshot /path snapshot_name
```

#### HBase 备份
```bash
# 导出
hbase org.apache.hadoop.hbase.mapreduce.Export <table> <output>

# 导入
hbase org.apache.hadoop.hbase.mapreduce.Import <table> <input>
```

---

## 故障排查

### 常见问题

#### HDFS
- NameNode 启动失败: 检查 edits 日志
- DataNode 无法连接: 检查防火墙和端口
- 丢块问题: 检查磁盘健康状态

#### Hive
- 连接失败: 检查 Metastore 和 HiveServer2 状态
- 查询慢: 检查执行计划和资源分配

#### HBase
- RegionServer 死亡: 检查 GC 日志和内存配置
- 读写超时: 调整超时参数

---

## 参考资源
- [Apache Hadoop 官方文档](https://hadoop.apache.org/docs/)
- [Apache Hive 官方文档](https://hive.apache.org/)
- [Apache HBase 官方文档](https://hbase.apache.org/book.html)
