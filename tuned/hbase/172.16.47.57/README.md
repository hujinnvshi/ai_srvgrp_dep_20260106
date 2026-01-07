# HBase 2.5.10 单机版快速部署指南

## 🎯 快速开始 (5分钟部署)

```bash
# 1. 上传部署包
scp -r tuned/hbase/172.16.47.57 root@172.16.47.57:/opt/deployment/

# 2. 登录服务器
ssh root@172.16.47.57

# 3. 进入部署目录
cd /opt/deployment/scripts

# 4. 添加执行权限
chmod +x *.sh

# 5. 一键部署 (按顺序执行)
./01-check-env.sh && \
./02-install-jdk.sh && \
source ~/.bashrc && \
./03-install-zookeeper.sh && \
./04-install-hadoop.sh && \
./05-install-hbase.sh && \
source ~/.bashrc && \
./06-start-all.sh start
```

## 📊 部署架构

```
服务器: 172.16.47.57
├── JDK 1.8.0_412
├── ZooKeeper 3.8.4 (端口: 2181)
├── Hadoop 3.3.6 (端口: 9000, 9870, 9866)
└── HBase 2.5.10 (端口: 16010, 16030)
```

## 🔧 关键端口

| 服务 | 端口 | 用途 |
|-----|------|------|
| ZooKeeper | 2181 | 客户端连接 |
| Hadoop | 9000 | NameNode RPC |
| Hadoop | 9870 | NameNode Web UI |
| HBase | 16010 | Master Web UI |
| HBase | 16030 | RegionServer Web UI |

## ✅ 验证部署

```bash
# 1. 检查服务状态
bash 06-start-all.sh status

# 2. 测试服务
bash 06-start-all.sh test

# 3. 访问Web界面
# Hadoop: http://172.16.47.57:9870
# HBase:  http://172.16.47.57:16010

# 4. HBase命令行测试
hbase shell
> version
> create 'test', 'cf'
> put 'test', 'row1', 'cf:a', 'value1'
> scan 'test'
> exit
```

## 📋 常用命令

```bash
# 服务管理
bash 06-start-all.sh start    # 启动所有服务
bash 06-start-all.sh stop     # 停止所有服务
bash 06-start-all.sh restart  # 重启所有服务
bash 06-start-all.sh status   # 查看状态

# 查看日志
bash 06-start-all.sh logs hbase    # HBase日志
bash 06-start-all.sh logs hadoop   # Hadoop日志
bash 06-start-all.sh logs zk       # ZooKeeper日志

# HBase Shell
hbase shell
> list                           # 列出所有表
> create 'table', 'cf'           # 创建表
> put 'table', 'row', 'cf:col', 'value'  # 插入数据
> scan 'table'                   # 扫描表
> get 'table', 'row'             # 获取行
> disable 'table'                # 禁用表
> drop 'table'                   # 删除表
```

## ⚠️ 端口冲突解决

```bash
# 检查端口占用
sudo netstat -tulnp | grep -E "2181|9000|16010"

# 查找占用进程
sudo lsof -i :<端口号>

# 停止占用进程
sudo kill -9 <PID>

# 临时关闭防火墙
sudo systemctl stop firewalld
```

## 🔥 故障排查

| 问题 | 解决方法 |
|-----|---------|
| 端口被占用 | `sudo netstat -tulnp \| grep 端口` |
| Java版本错误 | `java -version` 确保是Java 8 |
| HDFS格式化失败 | 删除 `/data/hadoop/hdfs/*` 重新格式化 |
| ZooKeeper启动失败 | 检查 `/data/zookeeper/myid` 文件 |
| HBase连接失败 | 先确保 ZooKeeper 和 Hadoop 正常运行 |

## 📖 详细文档

查看完整部署手册: [DEPLOYMENT.md](docs/DEPLOYMENT.md)

包含内容:
- 详细部署步骤
- 性能优化建议
- 数据备份恢复
- 常见问题解决

## 🗂️ 目录结构

```
/opt/deployment/
├── metadata.json          # 元数据
├── scripts/               # 部署脚本
│   ├── 01-check-env.sh    # 环境检查
│   ├── 02-install-jdk.sh  # 安装JDK
│   ├── 03-install-zookeeper.sh  # 安装ZK
│   ├── 04-install-hadoop.sh     # 安装Hadoop
│   ├── 05-install-hbase.sh      # 安装HBase
│   └── 06-start-all.sh          # 服务管理
└── docs/                  # 文档
    └── DEPLOYMENT.md      # 详细部署手册
```

## 💡 环境要求

- CPU: 4核+
- 内存: 8GB+ (推荐32GB)
- 磁盘: 100GB+
- 系统: CentOS 7+ / Ubuntu 18.04+
- 网络: 端口2181,9000,9870,16010,16030可用

## 🔄 卸载方法

```bash
# 停止服务
bash 06-start-all.sh stop

# 删除目录
sudo rm -rf /opt/{java,zookeeper,hadoop,hbase}
sudo rm -rf /data/{zookeeper,hadoop,hbase}

# 清理环境变量
vim ~/.bashrc  # 删除Java/ZK/Hadoop/HBase配置
```

---

**版本**: 1.0 | **日期**: 2026-01-07 | **维护**: AI服务组
