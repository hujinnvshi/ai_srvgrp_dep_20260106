# 服务优化配置目录结构说明

## 目录组织原则

本目录用于存储各类服务的性能优化配置，按照**服务类型**、**IP地址**、**端口**进行组织。

---

## 目录结构

```
tuned/
├── README.md                        # 本文档
├── mysql/                           # MySQL 服务优化配置
│   ├── 172.16.47.63_9010/          # IP_端口 (服务器IP_服务端口)
│   │   ├── metadata.json           # 元数据（服务器信息、优化内容等）
│   │   ├── config/                 # 配置文件目录
│   │   │   ├── my.cnf.original     # 原始配置
│   │   │   └── my.cnf.optimized    # 优化后配置
│   │   ├── scripts/                # 部署和管理脚本
│   │   │   ├── deploy.sh          # 部署脚本
│   │   │   └── rollback.sh        # 回滚脚本
│   │   ├── systemd/               # systemd 服务文件
│   │   │   └── mysql.service      # 服务配置文件
│   │   └── docs/                   # 文档目录
│   │       ├── OPTIMIZATION.md    # 优化说明文档
│   │       ├── DEPLOYMENT.md      # 部署报告
│   │       └── README.md          # 本实例说明
│   └── 192.168.1.100_3306/        # 其他 MySQL 实例
│       └── ...
├── redis/                          # Redis 服务优化配置
│   └── 172.16.47.64_6379/
│       └── ...
├── elasticsearch/                  # Elasticsearch 服务优化配置
│   └── 172.16.47.57_9200/
│       └── ...
└── nginx/                          # Nginx 服务优化配置
    └── 172.16.47.65_80/
        └── ...
```

---

## 命名规范

### 1. 服务类型目录

使用小写服务名称：
- `mysql/` - MySQL 数据库
- `redis/` - Redis 缓存
- `elasticsearch/` - Elasticsearch 搜索引擎
- `nginx/` - Nginx Web 服务器
- `postgresql/` - PostgreSQL 数据库
- `mongodb/` - MongoDB 数据库

### 2. 实例目录

格式: `{IP}_{PORT}`

示例:
- `172.16.47.63_9010/` - IP: 172.16.47.63, 端口: 9010
- `192.168.1.100_3306/` - IP: 192.168.1.100, 端口: 3306

### 3. 配置文件

- `{filename}.original` - 原始配置文件
- `{filename}.optimized` - 优化后配置文件

### 4. 脚本文件

- `deploy.sh` - 部署脚本
- `rollback.sh` - 回滚脚本
- `backup.sh` - 备份脚本
- `health-check.sh` - 健康检查脚本

### 5. 服务文件

- `{service-name}.service` - systemd 服务文件

---

## 元数据文件 (metadata.json)

每个服务实例都应包含 `metadata.json` 文件，用于记录服务的基本信息和优化历史。

```json
{
  "service_type": "mysql",
  "instance_id": "172.16.47.63_9010",
  "server_info": {
    "ip": "172.16.47.63",
    "hostname": "oracle",
    "port": 9010,
    "os": "CentOS 7",
    "cpu_cores": 48,
    "total_memory_gb": 220
  },
  "service_info": {
    "name": "MySQL5739_ISAS_6003",
    "version": "5.7.39",
    "basedir": "/old-data/MySQL5739_ISAS_6003/base/5739",
    "datadir": "/old-data/MySQL5739_ISAS_6003/data",
    "config_file": "/old-data/MySQL5739_ISAS_6003/base/5739/my.cnf"
  },
  "optimization": {
    "date": "2026-01-06",
    "optimized_by": "AI服务组",
    "version": "1.0",
    "changes": [
      {
        "parameter": "innodb_buffer_pool_size",
        "before": "134G",
        "after": "100G",
        "reason": "降低内存占用，释放约30GB内存"
      }
    ],
    "results": {
      "memory_before_gb": 158,
      "memory_after_gb": 12.6,
      "improvement": "降低92%"
    }
  },
  "deployment": {
    "deployed": true,
    "deploy_date": "2026-01-06",
    "systemd_service": "mysql-6003",
    "backup_file": "/old-data/MySQL5739_ISAS_6003/base/5739/my.cnf.backup.20260106_173952"
  }
}
```

---

## 使用指南

### 1. 添加新的服务实例

```bash
# 1. 创建目录结构
mkdir -p tuned/{service_type}/{ip}_{port}/{config,scripts,systemd,docs}

# 2. 创建元数据文件
cat > tuned/{service_type}/{ip}_{port}/metadata.json << EOF
{...}
EOF

# 3. 保存原始配置
ssh root@{ip} "cat {config_path}" > tuned/{service_type}/{ip}_{port}/config/{filename}.original

# 4. 创建优化配置
cp tuned/{service_type}/{ip}_{port}/config/{filename}.original \
   tuned/{service_type}/{ip}_{port}/config/{filename}.optimized

# 5. 编辑优化配置
vi tuned/{service_type}/{ip}_{port}/config/{filename}.optimized

# 6. 提交到 Git
git add tuned/{service_type}/{ip}_{port}/
git commit -m "feat({service_type}): 添加 {ip}:{port} 优化配置"
```

### 2. 部署优化配置

```bash
cd tuned/{service_type}/{ip}_{port}/scripts/
bash deploy.sh
```

### 3. 回滚配置

```bash
cd tuned/{service_type}/{ip}_{port}/scripts/
bash rollback.sh
```

---

## 最佳实践

### 1. 配置管理

- ✅ 每次优化前先保存原始配置
- ✅ 使用 Git 追踪所有配置变更
- ✅ 在 metadata.json 中记录所有变更
- ✅ 配置文件命名清晰（.original, .optimized）

### 2. 文档编写

- ✅ 每个实例都有独立的 README.md
- ✅ 详细记录优化内容和原因
- ✅ 包含完整的部署和回滚步骤
- ✅ 记录优化前后的性能对比

### 3. 脚本编写

- ✅ 部署脚本应该自动化且幂等
- ✅ 回滚脚本必须可用
- ✅ 包含详细的日志输出
- ✅ 提供进度提示和错误处理

### 4. 安全考虑

- ⚠️ 不要在配置文件中存储明文密码
- ⚠️ 敏感信息使用环境变量或密钥管理工具
- ⚠️ Git 仓库中不要包含敏感信息
- ⚠️ 定期审查提交历史

---

## 示例：MySQL 实例

### 完整的目录结构

```
tuned/mysql/172.16.47.63_9010/
├── metadata.json              # 元数据
├── config/
│   ├── my.cnf.original       # 原始配置
│   └── my.cnf.optimized      # 优化配置
├── scripts/
│   ├── deploy.sh            # 部署脚本
│   └── rollback.sh          # 回滚脚本
├── systemd/
│   └── mysql-6003.service   # systemd 服务文件
└── docs/
    ├── README.md            # 实例说明
    ├── OPTIMIZATION.md     # 优化说明
    └── DEPLOYMENT.md       # 部署报告
```

### 查找实例

**按 IP 查找**:
```bash
find tuned/ -type d -name "*172.16.47.63*"
```

**按端口查找**:
```bash
find tuned/ -type d -name "*9010*"
```

**按服务类型查找**:
```bash
ls tuned/mysql/
```

---

## 迁移旧文件

从旧的目录结构迁移到新结构：

```bash
# 旧结构
tuned/172.16.47.63/
├── my.cnf.original
├── my.cnf.optimized
└── ...

# 新结构
tuned/mysql/172.16.47.63_9010/
├── config/
│   ├── my.cnf.original
│   └── my.cnf.optimized
└── ...
```

迁移命令：
```bash
# 创建新目录
mkdir -p tuned/mysql/172.16.47.63_9010/{config,scripts,systemd,docs}

# 移动配置文件
mv tuned/172.16.47.63/my.cnf.original tuned/mysql/172.16.47.63_9010/config/
mv tuned/172.16.47.63/my.cnf.optimized tuned/mysql/172.16.47.63_9010/config/

# 移动脚本
mv tuned/172.16.47.63/deploy-mysql-service.sh tuned/mysql/172.16.47.63_9010/scripts/deploy.sh

# 移动 systemd 文件
mv tuned/172.16.47.63/mysql-6003.service tuned/mysql/172.16.47.63_9010/systemd/

# 移动文档
mv tuned/172.16.47.63/*.md tuned/mysql/172.16.47.63_9010/docs/

# 删除旧目录
rm -rf tuned/172.16.47.63/
```

---

## 版本控制

### Git 提交规范

```
feat(service_type): 简短描述

详细描述优化内容、部署步骤和效果

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
```

示例：
```
feat(mysql): 优化 172.16.47.63:9010 内存配置

- innodb_buffer_pool_size: 134G -> 100G
- 移除废弃的 query_cache 配置
- 启用慢查询日志
- 创建 systemd 服务

优化效果:
- 内存占用: 158GB -> 12.6GB
- 可用内存: 15GB -> 161GB

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
```

---

## 常见问题

### Q1: 为什么要按 服务类型/IP_端口 组织？

**A**: 这种组织结构的优势：
- **清晰**: 一眼就能看出服务类型、服务器和端口
- **可扩展**: 易于添加新服务和新实例
- **避免冲突**: 同一服务器可以有多个相同服务的实例（不同端口）
- **便于查找**: 可以按服务类型、IP 或端口快速定位

### Q2: 如何处理同一服务器多个实例？

**A**: 为每个实例创建独立的目录：
```
tuned/mysql/
├── 172.16.47.63_9010/    # 实例 1
└── 172.16.47.63_9020/    # 实例 2
```

### Q3: metadata.json 是必需的吗？

**A**: 强烈推荐！它提供了：
- 快速了解服务实例信息
- 优化历史追踪
- 自动化脚本的数据源
- 团队协作时的信息共享

---

## 维护团队

- **维护**: AI服务组
- **更新日期**: 2026-01-06
- **版本**: 1.0

---

**注意**: 请遵循本文档的组织结构规范，确保配置管理的一致性和可维护性。
