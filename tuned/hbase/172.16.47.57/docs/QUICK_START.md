# HBase 2.5.10 单机部署 - 快速执行手册

## 说明
由于网络下载速度限制,本手册提供在服务器172.16.47.57上直接执行的命令,完成HBase单机版部署。

## 部署方案
使用HBase单机文件系统模式(standalone),不需要HDFS和ZooKeeper,适合快速测试和开发。

---

## 一键部署命令

登录到172.16.47.57后,直接执行以下命令:

```bash
# 创建目录
mkdir -p /data/hbase/tmp

# 下载HBase (使用archive源,更稳定)
cd /tmp
curl -L -o hbase-2.5.10-bin.tar.gz https://archive.apache.org/dist/hbase/2.5.10/hbase-2.5.10-bin.tar.gz

# 解压安装
tar -xzf hbase-2.5.10-bin.tar.gz -C /opt
mv /opt/hbase-2.5.10 /opt/hbase

# 配置HBase环境变量
cat >> ~/.bashrc <<'EOF'
export HBASE_HOME=/opt/hbase
export PATH=$PATH:$HBASE_HOME/bin
EOF

# 使环境变量生效
source ~/.bashrc

# 配置hbase-env.sh
cat > /opt/hbase/conf/hbase-env.sh <<'EOF'
export JAVA_HOME=/usr/lib/jvm/jdk1.8.0_341
export HBASE_MANAGES_ZK=true
export HBASE_HEAPSIZE=4096
EOF

# 配置hbase-site.xml (单机文件系统模式)
cat > /opt/hbase/conf/hbase-site.xml <<'EOF'
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
  <property>
    <name>hbase.rootdir</name>
    <value>file:///data/hbase</value>
  </property>
  <property>
    <name>hbase.zookeeper.property.dataDir</name>
    <value>/data/hbase/zookeeper</value>
  </property>
  <property>
    <name>hbase.cluster.distributed</name>
    <value>false</value>
  </property>
  <property>
    <name>hbase.master.info.port</name>
    <value>16010</value>
  </property>
</configuration>
EOF

# 启动HBase
/opt/hbase/bin/start-hbase.sh

# 等待启动
sleep 5

# 查看进程
jps | grep -E "(HMaster|HRegionServer|QuorumPeerMain)"

# 查看端口
netstat -tuln | grep -E ":(16010|16030|2181) "

echo ""
echo "=========================================="
echo "HBase部署完成!"
echo "=========================================="
echo "Web UI: http://172.16.47.57:16010"
echo ""
echo "测试命令:"
echo "  hbase shell"
echo ""
```

---

## 验证测试

### 1. 基本功能测试

```bash
# 进入HBase Shell
hbase shell
```

在HBase Shell中执行:

```ruby
# 查看版本
version

# 创建表
create 'test', 'cf'

# 插入数据
put 'test', 'row1', 'cf:a', 'value1'
put 'test', 'row2', 'cf:b', 'value2'

# 查看数据
scan 'test'

# 获取单行
get 'test', 'row1'

# 统计行数
count 'test'

# 删除表
disable 'test'
drop 'test'

# 退出
exit
```

### 2. 查看日志

```bash
# 查看HBase Master日志
tail -f /opt/hbase/logs/hbase-root-master-*.log

# 查看RegionServer日志
tail -f /opt/hbase/logs/hbase-root-regionserver-*.log
```

---

## 常用管理命令

### 启动/停止

```bash
# 启动HBase
/opt/hbase/bin/start-hbase.sh

# 停止HBase
/opt/hbase/bin/stop-hbase.sh

# 重启HBase
/opt/hbase/bin/stop-hbase.sh && sleep 3 && /opt/hbase/bin/start-hbase.sh
```

### 检查状态

```bash
# 查看Java进程
jps -ml

# 查看端口监听
netstat -tuln | grep -E ":(16010|16030|2181) "

# 查看HBase状态
echo "status" | hbase shell -n
```

---

## 目录结构

```
/opt/hbase/              # HBase安装目录
├── bin/                 # 可执行脚本
├── conf/                # 配置文件
│   ├── hbase-env.sh     # 环境变量配置
│   └── hbase-site.xml   # 核心配置
└── logs/                # 日志目录

/data/hbase/             # HBase数据目录
├── tmp/                 # 临时文件
└── zookeeper/           # ZooKeeper数据(内嵌)
```

---

## 故障排查

### 问题1: 端口被占用

```bash
# 查看占用端口的进程
netstat -tulnp | grep :16010

# 停止HBase
/opt/hbase/bin/stop-hbase.sh

# 检查是否还有残留进程
jps | grep HMaster
# 如有,使用 kill -9 <PID> 杀掉
```

### 问题2: Java版本不对

```bash
# 检查Java版本
java -version

# 应该显示: java version "1.8.0_xxx"

# 如果不是,设置正确的JAVA_HOME
export JAVA_HOME=/usr/lib/jvm/jdk1.8.0_341
```

### 问题3: 启动失败

```bash
# 查看详细日志
tail -100 /opt/hbase/logs/hbase-root-master-*.log

# 常见原因:
# 1. 目录权限问题: chown -R root:root /data/hbase
# 2. 配置文件错误: 重新执行上面的配置命令
# 3. 端口冲突: 停止其他服务或修改端口
```

---

## 性能调优(可选)

### 1. 增加堆内存

编辑 `/opt/hbase/conf/hbase-env.sh`:

```bash
export HBASE_HEAPSIZE=8192  # 单位MB,根据服务器内存调整
```

### 2. 调整RegionServer配置

编辑 `/opt/hbase/conf/hbase-site.xml`:

```xml
<property>
  <name>hbase.regionserver.handler.count</name>
  <value>50</value>
</property>
```

---

## 卸载清理

```bash
# 停止HBase
/opt/hbase/bin/stop-hbase.sh

# 删除安装目录
rm -rf /opt/hbase

# 删除数据目录
rm -rf /data/hbase

# 删除环境变量
vi ~/.bashrc  # 删除HBASE_HOME相关行
```

---

## 完整脚本下载

如需一键执行脚本,下载以下文件:

```bash
curl -o /tmp/install-hbase.sh https://your-server/hbase/install-hbase.sh
bash /tmp/install-hbase.sh
```

---

**文档版本**: 1.0
**创建日期**: 2026-01-07
**维护团队**: AI服务组
