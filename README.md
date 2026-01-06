# AI 服务组部署规划项目

本项目用于管理各种服务的部署规划、配置管理及问题处理排查记录。

## 项目概述

本项目采用**以服务为核心**的文档组织方式，支持多版本、多部署模式、多规模的统一管理。

涵盖服务：
- **大数据组件**：Hadoop、Hive、HBase
- **数据库**：MySQL、达梦(Dameng)、Oracle、GoldenDB
- **集群服务**：Elasticsearch、Zookeeper

## 核心特性

✅ **三维组织**：服务 → 版本 → 部署模式
✅ **多版本支持**：同一服务支持多个版本并存
✅ **多部署模式**：支持单机、主备、集群、读写分离等多种模式
✅ **规模模板**：小型、中型、大型规模部署方案
✅ **问题追踪**：每个服务独立的问题记录和解决方案

## 目录结构

```
ai_srvgrp_dep_20260106/
├── README.md                          # 本文档
│
├── services/                          # 各服务目录（核心）
│   │
│   ├── elasticsearch/                 # Elasticsearch 服务
│   │   ├── README.md                  # ES概览和快速开始
│   │   ├── versions/                  # 不同版本
│   │   │   ├── v7.4.1/
│   │   │   │   ├── single-node/       # 单节点部署
│   │   │   │   ├── pseudo-distributed/# 伪分布式
│   │   │   │   ├── cluster/           # 真正的分布式集群
│   │   │   │   │   ├── deployment.md  # 部署文档
│   │   │   │   │   ├── config-templates/
│   │   │   │   │   ├── scripts/
│   │   │   │   │   ├── scales/        # 规模方案
│   │   │   │   │   └── issues/        # 问题记录
│   │   │   │   └── hot-warm/          # Hot-Warm架构
│   │   │   ├── v7.10.x/
│   │   │   └── v8.x/
│   │   └── common/                    # 通用内容
│   │       ├── monitoring/            # 监控方案
│   │       ├── backup/                # 备份方案
│   │       └── optimization/          # 性能优化
│   │
│   ├── mysql/                         # MySQL 服务
│   │   ├── README.md                  # MySQL概览、版本对比
│   │   ├── versions/
│   │   │   ├── v5.7/                  # MySQL 5.7
│   │   │   │   ├── master-slave/      # 主备模式
│   │   │   │   ├── mgr/               # MGR模式
│   │   │   │   ├── pxc/               # PXC模式
│   │   │   │   ├── read-write-split/  # 读写分离
│   │   │   │   └── standalone/        # 单机模式
│   │   │   ├── v8.0/                  # MySQL 8.0
│   │   │   └── v8.4/                  # MySQL 8.4 (LTS)
│   │   └── common/                    # 通用内容
│   │       ├── monitoring/
│   │       ├── backup/
│   │       ├── recovery/
│   │       ├── optimization/
│   │       └── security/
│   │
│   ├── hadoop/                        # Hadoop 服务
│   │   ├── versions/
│   │   │   ├── v2.10.x/
│   │   │   │   ├── standalone/        # 单机模式
│   │   │   │   ├── pseudo-distributed/# 伪分布式
│   │   │   │   ├── fully-distributed/ # 完全分布式
│   │   │   │   └── ha/                # 高可用模式
│   │   │   └── v3.3.x/
│   │   └── common/
│   │
│   ├── hive/                          # Hive 服务
│   │   ├── versions/
│   │   │   ├── v2.3.x/
│   │   │   │   ├── embedded/          # 内嵌模式
│   │   │   │   ├── remote/            # 远程模式
│   │   │   │   └── standalone/        # 单机模式
│   │   │   └── v3.1.x/
│   │   └── common/
│   │
│   ├── hbase/                         # HBase 服务
│   │   ├── versions/
│   │   │   ├── v1.4.x/
│   │   │   │   ├── standalone/
│   │   │   │   └── distributed/
│   │   │   └── v2.4.x/
│   │   └── common/
│   │
│   ├── zookeeper/                    # Zookeeper 服务
│   │   ├── versions/
│   │   │   ├── v3.5.x/
│   │   │   │   ├── standalone/
│   │   │   │   └── cluster/
│   │   │   └── v3.8.x/
│   │   └── common/
│   │
│   ├── dameng/                       # 达梦数据库
│   │   ├── versions/
│   │   │   ├── v7/
│   │   │   │   ├── standalone/
│   │   │   │   ├── primary-standby/
│   │   │   │   └── cluster/
│   │   │   └── v8/
│   │   └── common/
│   │
│   ├── oracle/                       # Oracle 数据库
│   │   ├── versions/
│   │   │   ├── 11g/
│   │   │   │   ├── single-instance/
│   │   │   │   └── rac/
│   │   │   ├── 19c/
│   │   │   └── 21c/
│   │   └── common/
│   │
│   └── goldendb/                     # GoldenDB
│       ├── versions/
│       └── common/
│
├── inventory/                         # 资产清单
│   ├── production.md                  # 生产环境
│   ├── testing.md                     # 测试环境
│   └── development.md                 # 开发环境
│
├── templates/                         # 通用模板
│   ├── service-config-template.md     # 服务配置模板
│   ├── issue-record-template.md       # 问题记录模板
│   └── common-issues.md               # 常见问题参考
│
└── docs_old/                          # 旧文档（参考）
    ├── guides_old/                    # 旧部署指南
    └── troubleshooting_old/           # 旧故障排查
```

## 快速开始

### 1. 选择服务

进入你想部署的服务目录：

```bash
# 例如：部署 Elasticsearch
cd services/elasticsearch/

# 例如：部署 MySQL
cd services/mysql/

# 例如：部署 Hadoop
cd services/hadoop/
```

### 2. 查看服务概览

每个服务都有 README.md，包含：
- 版本列表
- 部署模式对比
- 快速开始指南
- 选择建议

```bash
cat services/mysql/README.md
```

### 3. 选择版本和部署模式

```bash
# 示例1：部署 MySQL 8.0 + MGR 模式
cd services/mysql/versions/v8.0/mgr/
cat deployment.md

# 示例2：部署 ES 7.4.1 伪分布式（单机3节点）
cd services/elasticsearch/versions/v7.4.1/pseudo-distributed/
cat deployment.md

# 示例3：部署 Hadoop 3.3.x 完全分布式
cd services/hadoop/versions/v3.3.x/fully-distributed/
cat deployment.md
```

### 4. 选择部署规模

每个部署模式下的 scales/ 目录提供不同规模方案：

- **small**: 小型规模（测试/开发）
- **medium**: 中型规模（中小型生产）
- **large**: 大型规模（大型生产）

```bash
cat services/mysql/versions/v8.0/mgr/scales/medium.md
```

### 5. 使用配置模板

```bash
# 复制配置模板
cp services/mysql/versions/v8.0/mgr/config-templates/single-primary.cnf /etc/my.cnf

# 使用部署脚本
bash services/mysql/versions/v8.0/mgr/scripts/deploy.sh
```

## 使用场景示例

### 场景1：部署 MySQL 8.0 + MGR 集群

```bash
# 1. 查看概览
cat services/mysql/README.md

# 2. 进入具体部署目录
cd services/mysql/versions/v8.0/mgr/

# 3. 阅读部署文档
cat deployment.md

# 4. 选择规模
cat scales/medium.md

# 5. 使用配置和脚本
cp config-templates/single-primary.cnf /etc/my.cnf
bash scripts/deploy.sh

# 6. 遇到问题查看
ls issues/resolved/
```

### 场景2：对比不同版本的主备模式

```bash
# 查看 5.7 主备模式
cat services/mysql/versions/v5.7/master-slave/deployment.md

# 查看 8.0 主备模式
cat services/mysql/versions/v8.0/master-slave/deployment.md

# 对比配置差异
diff services/mysql/versions/v5.7/master-slave/config-templates/ \
     services/mysql/versions/v8.0/master-slave/config-templates/
```

### 场景3：查找问题解决方案

```bash
# 查找 MySQL PXC 相关问题
find services/mysql/versions/ -type d -name "pxc" -exec find {} -name "issues" \;

# 查看已解决的问题
ls services/mysql/versions/v8.0/mgr/issues/resolved/
```

## 服务详细信息

### MySQL

**版本支持**：5.7、8.0、8.4 (LTS)

**部署模式**：
- **主备模式**：传统异步/半同步复制
- **MGR**：MySQL Group Replication，支持单主/多主
- **PXC**：Percona XtraDB Cluster，基于Galera的同步复制
- **读写分离**：通过ProxySQL或MySQL Router实现
- **单机模式**：单实例部署

**快速链接**：
- [MySQL 8.0 + MGR](services/mysql/versions/v8.0/mgr/)
- [MySQL 8.0 + PXC](services/mysql/versions/v8.0/pxc/)
- [MySQL 8.0 主备](services/mysql/versions/v8.0/master-slave/)

### Elasticsearch

**版本支持**：7.4.1、7.10.x、8.x

**部署模式**：
- **单节点**：开发测试环境
- **伪分布式**：单机多节点
- **集群模式**：真正的分布式集群
- **Hot-Warm**：热温数据分离架构

**快速链接**：
- [ES 7.4.1 伪分布式](services/elasticsearch/versions/v7.4.1/pseudo-distributed/)
- [ES 7.4.1 集群](services/elasticsearch/versions/v7.4.1/cluster/)

### Hadoop

**版本支持**：2.10.x、3.3.x

**部署模式**：
- **单机模式**：开发调试
- **伪分布式**：单机模拟集群
- **完全分布式**：生产环境
- **高可用模式**：NameNode HA、YARN HA

**快速链接**：
- [Hadoop 3.3.x 完全分布式](services/hadoop/versions/v3.3.x/fully-distributed/)

### Hive

**版本支持**：2.3.x、3.1.x

**部署模式**：
- **内嵌模式**：元数据在内置Derby
- **远程模式**：独立Metastore服务
- **单机模式**：测试环境

### HBase

**版本支持**：1.4.x、2.4.x

**部署模式**：
- **单机模式**：开发测试
- **分布式模式**：生产环境

### Zookeeper

**版本支持**：3.5.x、3.8.x

**部署模式**：
- **单机模式**：开发测试
- **集群模式**：生产环境（3、5、7节点）

### 达梦数据库

**版本支持**：DM7、DM8

**部署模式**：
- **单机模式**
- **主备模式**
- **DMDSC集群**

### Oracle

**版本支持**：11g、19c、21c

**部署模式**：
- **单实例**
- **RAC集群**

### GoldenDB

**版本支持**：v1.x

**部署模式**：
- **单机模式**
- **集群模式**

## 部署流程

### 标准流程

1. **环境准备**
   - 检查系统要求（OS、CPU、内存、磁盘）
   - 配置网络和防火墙
   - 安装依赖包

2. **配置规划**
   - 选择版本和部署模式
   - 确定部署规模
   - 规划节点分配和端口

3. **服务部署**
   - 使用配置模板
   - 执行部署脚本
   - 启动验证

4. **监控配置**
   - 配置监控指标
   - 设置告警规则
   - 配置日志收集

## 问题处理流程

### 问题记录

遇到问题时，在对应服务和部署模式的 issues/ 目录下记录：

```bash
# 未解决的问题
cd services/mysql/versions/v8.0/mgr/issues/unresolved/
# 创建问题记录，格式：YYYY-MM-DD-问题简述.md

# 使用模板
cp ../../../../../../templates/issue-record-template.md ./
```

### 问题解决流程

1. 在 issues/unresolved/ 创建问题记录
2. 按照模板记录问题详情
3. 处理完成后移动到 issues/resolved/

## 模板使用

### 服务配置模板

```bash
# 使用服务配置模板
cat templates/service-config-template.md
```

包含：
- 基本信息
- 环境要求
- 部署架构
- 配置参数
- 部署步骤
- 验证测试

### 问题记录模板

```bash
# 使用问题记录模板
cat templates/issue-record-template.md
```

包含：
- 问题描述
- 问题分析
- 解决方案
- 处理过程
- 经验总结

## 资产管理

资产清单位于 inventory/ 目录：

- **production.md**：生产环境资产
- **testing.md**：测试环境资产
- **development.md**：开发环境资产

记录内容：
- 服务器资产
- 网络拓扑
- 存储资源
- 监控系统
- 变更记录

## 最佳实践

### 版本选择

- **生产环境**：选择 LTS 版本
- **测试环境**：跟随最新版本
- **开发环境**：可以使用新特性版本

### 模式选择

| 模式 | 适用场景 | 高可用 | 复杂度 |
|------|----------|--------|--------|
| 单机 | 开发测试 | 低 | 低 |
| 主备 | 简单读写分离 | 中 | 低 |
| 集群(MGR/PXC) | 高可用、自动故障转移 | 高 | 中 |
| 读写分离 | 读性能优化 | 中 | 中 |

### 规模选择

- **small**：3-5节点，测试/开发
- **medium**：5-15节点，中小型生产
- **large**：15+节点，大型生产

### 安全建议

1. 生产环境配置认证和加密
2. 限制网络访问（防火墙）
3. 定期备份数据和配置
4. 使用最小权限原则
5. 配置审计日志

## 维护建议

### 日常维护

- 每日：检查集群健康状态
- 每周：检查磁盘空间和日志
- 每月：检查配置更新和安全补丁
- 每季度：进行一次备份恢复演练
- 每年：进行一次架构评估

### 文档维护

1. 新增服务：使用模板创建文档
2. 问题记录：详细记录问题和解决方案
3. 配置变更：更新配置文件和文档
4. 版本升级：记录升级过程和注意事项

## 常见问题

**Q: 如何选择合适的部署模式？**

A: 参考 services/[服务名]/README.md 中的模式对比表

**Q: 不同版本可以同时部署吗？**

A: 可以，不同版本完全独立，互不影响

**Q: 如何升级版本？**

A: 查看具体版本的升级指南，通常包括备份、升级、验证步骤

**Q: 问题记录在哪里？**

A: 每个服务、版本、部署模式都有独立的 issues/ 目录

## 贡献指南

1. 新增服务时，参考现有服务的目录结构
2. 使用统一的模板（templates/）
3. 文档需要详细、准确
4. 问题记录要包含完整的解决过程
5. 配置文件需要详细注释

## 更新日志

### 2026-01-06 - v2.0 结构重组
- ✅ 重新设计目录结构（三维组织）
- ✅ 清理冗余文档和空目录
- ✅ 支持多版本、多部署模式、多规模
- ✅ 每个服务独立管理

### 2026-01-06 - v1.0 初始版本
- 创建项目基础结构
- 创建基础文档模板

## 联系方式

- **项目维护**：AI服务组
- **文档位置**：[项目路径]
- **问题反馈**：创建 Issue 或联系维护团队

---

**提示**：建议将本文档加入书签，方便快速查找服务。每个服务目录下都有详细的 README，请根据需要查看。
