# 常见问题汇总

本文档汇总各服务部署和使用中的常见问题及解决方案。

## 目录
- [大数据组件问题](#大数据组件问题)
- [数据库问题](#数据库问题)
- [集群服务问题](#集群服务问题)

---

## 大数据组件问题

### Hadoop

#### NameNode 无法启动

**问题现象**: NameNode 启动失败，日志报错

**可能原因**:
1. 端口被占用
2. 配置文件错误
3. 元数据损坏
4. 权限问题

**解决方案**:
```bash
# 1. 检查端口
netstat -tunlp | grep 9000

# 2. 检查日志
tail -f /opt/hadoop/logs/hadoop-*-namenode-*.log

# 3. 检查配置
hdfs getconf -confKey fs.defaultFS

# 4. 检查权限
ls -ld /opt/hadoop

# 5. 如果是元数据问题，可以尝试恢复
hdfs namenode -recover
```

**预防措施**:
- 定期备份 fsimage 和 edits 日志
- 配置 HA 避免单点故障
- 监控磁盘空间

---

#### DataNode 无法连接

**问题现象**: DataNode 无法连接到 NameNode，集群显示 Live Nodes 为 0

**可能原因**:
1. 网络问题
2. 防火墙阻止
3. 版本不匹配
4. clusterID 不一致

**解决方案**:
```bash
# 1. 检查网络连通性
ping namenode
telnet namenode 9000

# 2. 检查防火墙
sudo firewall-cmd --list-all
sudo firewall-cmd --add-port=9000/tcp --permanent
sudo firewall-cmd --add-port=9866/tcp --permanent
sudo firewall-cmd --reload

# 3. 检查版本一致性
hadoop version

# 4. 检查 clusterID
cat /opt/hadoop/hdfs/datanode/current/VERSION
# 如果 clusterID 与 NameNode 不一致，需要删除并重新格式化
```

---

#### YARN 任务卡住

**问题现象**: 任务一直在 RUNNING 状态，但不推进

**可能原因**:
1. 资源不足
2. Container 限制
3. 调度器配置问题

**解决方案**:
```bash
# 1. 检查资源使用
yarn node -list

# 2. 检查队列
yarn application -list
yarn queue -status default

# 3. 查看 ResourceManager 日志
tail -f /opt/hadoop/logs/yarn-*-resourcemanager-*.log

# 4. 杀掉卡住的任务
yarn application -kill <app_id>

# 5. 调整资源配置
# 编辑 yarn-site.xml
# <property>
#   <name>yarn.scheduler.maximum-allocation-mb</name>
#   <value>16384</value>
# </property>
```

---

### Hive

#### Metastore 连接失败

**问题现象**: 无法连接到 Hive Metastore

**可能原因**:
1. Metastore 服务未启动
2. 数据库连接配置错误
3. 数据库服务不可用

**解决方案**:
```bash
# 1. 检查 Metastore 状态
jps | grep HiveMetaStore

# 2. 检查 Metastore 日志
tail -f /opt/hive/logs/hivemetastore.log

# 3. 测试数据库连接
mysql -h localhost -u hive -p

# 4. 重新启动 Metastore
hive --service metastore &
```

---

#### Hive 查询慢

**问题现象**: 查询执行时间过长

**可能原因**:
1. 没有使用分区
2. 小文件过多
3. 统计信息过期
4. 执行引擎效率低

**解决方案**:
```sql
-- 1. 使用分区
SHOW PARTITIONS table_name;

-- 2. 合并小文件
SET hive.merge.mapfiles=true;
SET hive.merge.mapredfiles=true;
SET hive.merge.size.per.task=256000000;
SET hive.merge.smallfiles.avgsize=16000000;

-- 3. 更新统计信息
ANALYZE TABLE table_name COMPUTE STATISTICS;
ANALYZE TABLE table_name COMPUTE STATISTICS FOR COLUMNS;

-- 4. 使用更高效的执行引擎
SET hive.execution.engine=tez;  -- 或 spark
```

---

### HBase

#### RegionServer 挂掉

**问题现象**: RegionServer 频繁挂掉

**可能原因**:
1. 内存不足 (OOM)
2. GC 频繁
3. 磁盘满
4. 长时间 GC 停顿

**解决方案**:
```bash
# 1. 检查内存
free -h

# 2. 检查 GC 日志
grep 'GC' /opt/hbase/logs/hbase-*-regionserver-*.log

# 3. 检查磁盘空间
df -h

# 4. 调整内存配置
# 编辑 hbase-env.sh
export HBASE_HEAPSIZE=8000
export HBASE_OFFHEAPSIZE=4000

# 5. 调整 GC 参数
export HBASE_OPTS="$HBASE_OPTS -XX:+UseG1GC -XX:MaxGCPauseMillis=200"
```

---

#### 写入慢

**问题现象**: HBase 写入性能差

**可能原因**:
1. MemStore 过大
2. WAL 刷盘频繁
3. Region 过多或过少
4. Compaction 频繁

**解决方案**:
```bash
# 1. 调整 MemStore
# 编辑 hbase-site.xml
<property>
  <name>hbase.hregion.memstore.flush.size</name>
  <value>134217728</value>  <!-- 128M -->
</property>

# 2. 优化 WAL
<property>
  <name>hbase.regionserver.wal.durable.sync</name>
  <value>false</value>
</property>

# 3. 手动触发 major compaction
hbase shell > major_compact 'table_name'

# 4. 检查 region 分布
hbase shell > balance_switch true
hbase shell > balancer
```

---

## 数据库问题

### MySQL PXC

#### 集群分裂

**问题现象**: wsrep_cluster_size 不一致，出现脑裂

**可能原因**:
1. 网络分区
2. 节点故障
3. 流控问题

**解决方案**:
```sql
-- 1. 检查集群状态
SHOW STATUS LIKE 'wsrep%';

-- 2. 查看集群大小
SHOW STATUS LIKE 'wsrep_cluster_size';

-- 3. 查看集群状态
SHOW STATUS LIKE 'wsrep_cluster_status';

-- 4. 如果处于 non-primary 状态，需要引导启动
-- 在最后一个退出的节点上执行
SET GLOBAL wsrep_provider_options='pc.bootstrap=true';

-- 5. 其他节点重新启动
systemctl restart mysql
```

---

#### 流控

**问题现象**: 写入性能差，wsrep_flow_control_paused 状态

**可能原因**:
1. 慢节点影响整个集群
2. 网络延迟
3. 写入量大

**解决方案**:
```sql
-- 1. 检查流控状态
SHOW STATUS LIKE 'wsrep_flow_control%';

-- 2. 增加发送队列
SET GLOBAL wsrep_max_ws_size = 2147483648;

-- 3. 增加复制线程
SET GLOBAL wsrep_slave_threads = 8;

-- 4. 临时禁用流控 (不推荐生产环境)
SET GLOBAL wsrep_slave_threads = 1;
```

---

### 达梦数据库

#### 主备切换失败

**问题现象**: 主库故障后，备库无法接管

**可能原因**:
1. 守护进程配置错误
2. 网络问题
3. 数据同步延迟

**解决方案**:
```bash
# 1. 检查守护进程状态
ps -ef | grep dmwatcher

# 2. 查看守护进程日志
tail -f /opt/dmdbms/log/dmwatcher.log

# 3. 检查数据同步
SELECT * FROM V$DW_INSTANCE;

# 4. 手动切换
# 在备库执行
SP_SET_OGUID(123456);
ALTER DATABASE STANDBY;
```

---

### Oracle RAC

#### 节点驱逐

**问题现象**: 节点被逐出集群

**可能原因**:
1. 私网网络问题
2. 节点负载过高
3. CSSD 心跳超时

**解决方案**:
```bash
# 1. 检查集群状态
crsctl check cluster

# 2. 检查私网连通性
ping other_node_private_ip

# 3. 检查网络配置
oifcfg getif

# 4. 查看日志
tail -f $ORACLE_HOME/log/hostname/cssd/ocssd.log

# 5. 调整 CSS 超时
crsctl set css misscount <value>
```

---

#### ASM 磁盘丢失

**问题现象**: ASM 磁盘组显示磁盘丢失

**可能原因**:
1. 磁盘故障
2. 路径问题
3. 权限问题

**解决方案**:
```bash
# 1. 检查磁盘状态
sqlplus / as sysasm
SELECT name, path, state FROM v$asm_disk;

# 2. 检查 multipath
multipath -ll

# 3. 重新扫描磁盘
echo "- - -" > /sys/class/scsi_host/host0/scan

# 4. 重新添加磁盘
ALTER DISKGROUP DATA ADD DISK '/dev/mapper/mpathX';
```

---

## 集群服务问题

### Elasticsearch

#### 集群不可用

**问题现象**: 集群状态为 red

**可能原因**:
1. 主分片未分配
2. 节点故障
3. 磁盘空间不足

**解决方案**:
```bash
# 1. 检查集群健康
curl -u elastic:password http://localhost:9200/_cluster/health?pretty

# 2. 查看未分配的分片
curl -u elastic:password http://localhost:9200/_cat/shards?v&h=index,shard,prirep,state,node | grep UNASSIGNED

# 3. 查看原因
curl -u elastic:password http://localhost:9200/_cluster/allocation/explain?pretty

# 4. 强制分配
curl -u elastic:password -X POST 'localhost:9200/_cluster/reroute?retry_failed=true'

# 5. 清理磁盘空间
df -h
# 删除不需要的索引
```

---

#### 查询超时

**问题现象**: 查询请求超时

**可能原因**:
1. 查询复杂度高
2. 数据量大
3. 资源不足

**解决方案**:
```bash
# 1. 分析慢查询
curl -u elastic:password http://localhost:9200/_tasks?detailed=true&actions=*search&pretty

# 2. 增加超时时间
curl -u elastic:password 'localhost:9200/my-index/_search?timeout=30s' ...

# 3. 使用异步查询
curl -u elastic:password -X POST 'localhost:9200/my-index/_search?wait_for_completion=false' ...

# 4. 优化查询
# 使用 filter 而不是 query
# 使用 term 而不是 wildcard
# 限制返回字段和数量
```

---

### Zookeeper

#### 选举失败

**问题现象**: 节点无法完成选举，集群不可用

**可能原因**:
1. 节点数不是奇数
2. 网络分区
3. 配置错误

**解决方案**:
```bash
# 1. 检查节点状态
echo stat | nc localhost 2181

# 2. 检查配置
cat /opt/zookeeper/conf/zoo.cfg

# 3. 检查 myid
cat /opt/zookeeper/data/myid

# 4. 检查网络连通性
# 确保所有节点可以互相通信

# 5. 重启服务
zkServer.sh restart
```

---

#### 连接数耗尽

**问题现象**: 无法创建新连接

**可能原因**:
1. 客户端未正确关闭连接
2. maxClientCnxns 设置过小

**解决方案**:
```bash
# 1. 查看当前连接数
echo cons | nc localhost 2181 | wc -l

# 2. 增加连接数限制
# 编辑 zoo.cfg
maxClientCnxns=200

# 3. 重启服务
zkServer.sh restart

# 4. 在客户端代码中确保连接正确关闭
```

---

## 排查工具

### 网络排查

```bash
# 测试连通性
ping <host>
telnet <host> <port>
nc -zv <host> <port>

# 检查端口监听
netstat -tunlp | grep <port>
ss -tunlp | grep <port>

# 抓包分析
tcpdump -i any port <port> -w dump.pcap
```

### 性能排查

```bash
# CPU
top
htop
mpstat 1

# 内存
free -h
vmstat 1

# 磁盘
df -h
iostat -x 1

# 进程
ps -ef | grep <process>
jps  # Java 进程
```

### 日志排查

```bash
# 实时查看
tail -f <log_file>

# 查看错误
grep -i error <log_file>

# 查看最近日志
tail -n 100 <log_file>

# 日志分析
grep -i "exception" <log_file> | tail -20
```

---

## 联系支持

如果问题仍然无法解决，请：
1. 收集相关日志
2. 记录问题现象和复现步骤
3. 联系技术支持团队
