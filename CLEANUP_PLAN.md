# 项目清理分析报告

生成时间: 2026-01-06

## 当前文件清单

### 文档文件
1. ✅ README.md - 项目主文档（保留）
2. ⚠️ NEW_STRUCTURE.md - 临时结构方案1（待删除）
3. ⚠️ MULTI_VERSION_STRUCTURE.md - 临时结构方案2（待删除）
4. ❌ docs/guides/bigdata-deployment.md - 旧的大数据部署指南（需迁移）
5. ❌ docs/guides/cluster-deployment.md - 旧的集群部署指南（需迁移）
6. ❌ docs/guides/database-deployment.md - 旧的数据库部署指南（需迁移）
7. ❌ docs/troubleshooting/common-issues.md - 通用问题汇总（需整合）
8. ✅ inventory/production.md - 生产环境资产清单（保留）
9. ✅ inventory/testing.md - 测试环境资产清单（保留）
10. ✅ inventory/development.md - 开发环境资产清单（保留）
11. ❌ scales/small/deployment-guide.md - 旧的小规模部署指南（已过时）
12. ⚠️ services/cluster/elasticsearch/v7.4.1/pseudo-distributed-deployment.md - ES部署文档（待迁移）
13. ✅ templates/issue-record-template.md - 问题记录模板（保留）
14. ✅ templates/service-config-template.md - 服务配置模板（保留）

### 空目录（需要清理）
- services/bigdata/hadoop/ (空)
- services/bigdata/hbase/ (空)
- services/bigdata/hive/ (空)
- services/cluster/zookeeper/ (空)
- services/database/mysql-pxc/ (空)
- services/database/dameng/ (空)
- services/database/oracle-rac/ (空)
- services/database/golden-db/ (空)
- issues/resolved/ (空)
- issues/unresolved/ (空)
- scales/large/ (空)
- scales/medium/ (空)
- scripts/ (空)

---

## 清理方案

### 阶段1：备份重要内容
先备份需要迁移的文档内容

### 阶段2：删除冗余和临时文件
- NEW_STRUCTURE.md
- MULTI_VERSION_STRUCTURE.md
- scales/small/deployment-guide.md (内容已过时)

### 阶段3：删除空目录
旧的按类型分类的空目录：
- services/bigdata/
- services/database/
- services/cluster/ (保留elasticsearch直到迁移完成)
- scales/
- issues/

### 阶段4：迁移有用内容
将旧文档中的有用内容迁移到新结构：
- docs/guides/* → 各服务的对应目录
- docs/troubleshooting/common-issues.md → 各服务的issues/目录
- services/cluster/elasticsearch/v7.4.1/* → services/elasticsearch/versions/v7.4.1/

### 阶段5：创建新结构
按照新的三维组织结构创建目录

---

## 清理优先级

### 高优先级（立即执行）
1. ✅ 删除临时文档（NEW_STRUCTURE.md, MULTI_VERSION_STRUCTURE.md）
2. ✅ 删除空目录
3. ✅ 删除过时文档（scales/small/deployment-guide.md）

### 中优先级（迁移后执行）
4. 迁移 services/cluster/elasticsearch/ 内容到新结构
5. 迁移 docs/guides/ 内容到各服务目录
6. 删除旧的 services/bigdata/, services/database/ 等目录

### 低优先级（整理）
7. 整合 docs/troubleshooting/common-issues.md
8. 更新主 README.md
