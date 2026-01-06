#!/bin/bash
# Elasticsearch 7.0.1 用户修复脚本
# 解决不能以 root 用户运行的问题

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 配置变量
ES_VERSION="7.0.1"
ES_HOME="/data3/elasticsearch"
ES_USER="elastic"

echo -e "${GREEN}"
echo "=========================================="
echo "  Elasticsearch 7.0.1 用户配置修复"
echo "=========================================="
echo -e "${NC}"

# 步骤1: 停止可能运行的进程
echo -e "${YELLOW}[1/6]${NC} 停止现有进程..."
PIDS=$(ps aux | grep '[e]lasticsearch' | grep 'data3' | awk '{print $2}')
if [ -n "$PIDS" ]; then
    echo "找到进程: $PIDS"
    kill -9 $PIDS 2>/dev/null || true
    sleep 2
    echo -e "${GREEN}✅ 进程已停止${NC}"
else
    echo -e "${GREEN}✅ 没有运行中的进程${NC}"
fi

# 步骤2: 创建 elasticsearch 用户
echo -e "${YELLOW}[2/6]${NC} 检查专用用户..."
if id "$ES_USER" &>/dev/null; then
    echo -e "${GREEN}✅ 用户 $ES_USER 已存在${NC}"
else
    useradd -M -s /bin/bash $ES_USER
    echo -e "${GREEN}✅ 用户 $ES_USER 创建成功${NC}"
fi

# 步骤3: 设置目录权限
echo -e "${YELLOW}[3/6]${NC} 设置目录权限..."
chown -R $ES_USER:$ES_USER $ES_HOME
echo -e "${GREEN}✅ 目录权限设置完成${NC}"

# 步骤4: 修改启动脚本
echo -e "${YELLOW}[4/6]${NC} 更新启动脚本..."
cat > /data3/start-es-701.sh << 'EOF'
#!/bin/bash
export ES_HOME=/data3/elasticsearch
ES_USER=elastic

# 检查是否以 root 运行
if [ "$(whoami)" != "root" ]; then
    echo "错误: 必须以 root 用户运行此脚本"
    exit 1
fi

cd $ES_HOME
echo "以 $ES_USER 用户启动 Elasticsearch 7.0.1..."
su - $ES_USER -c "cd $ES_HOME && nohup $ES_HOME/bin/elasticsearch > $ES_HOME/logs/console.log 2>&1 &"
echo "Elasticsearch 7.0.1 启动中..."
sleep 3
tail -30 $ES_HOME/logs/console.log
EOF

chmod +x /data3/start-es-701.sh

cat > /data3/stop-es-701.sh << 'EOF'
#!/bin/bash
ES_USER=elastic
echo "停止 Elasticsearch 7.0.1..."
PIDS=$(ps aux | grep '[e]lasticsearch' | grep 'data3' | awk '{print $2}')
if [ -z "$PIDS" ]; then
    echo "没有运行的 Elasticsearch 7.0.1 进程"
else
    echo "找到进程: $PIDS"
    kill $PIDS
    sleep 5
    REMAINING=$(ps aux | grep '[e]lasticsearch' | grep 'data3' | awk '{print $2}')
    if [ -n "$REMAINING" ]; then
        echo "强制停止进程..."
        kill -9 $REMAINING
    fi
    echo "✅ Elasticsearch 7.0.1 已停止"
fi
EOF

chmod +x /data3/stop-es-701.sh

echo -e "${GREEN}✅ 启动脚本更新完成${NC}"

# 步骤5: 配置系统参数
echo -e "${YELLOW}[5/6]${NC} 配置系统参数..."
if ! grep -q "elastic soft nofile" /etc/security/limits.conf; then
cat >> /etc/security/limits.conf << 'EOF'

# Elasticsearch 用户 limits
elastic soft nofile 65536
elastic hard nofile 65536
elastic soft memlock unlimited
elastic hard memlock unlimited
EOF
    echo -e "${GREEN}✅ 系统参数配置完成${NC}"
else
    echo -e "${GREEN}✅ 系统参数已配置${NC}"
fi

echo ""
echo -e "${YELLOW}注意：${NC}如果 limits.conf 生效需要重新登录，或者运行:"
echo "  su - elastic -c 'ulimit -n'"
echo ""

# 步骤6: 启动 ES
echo -e "${YELLOW}[6/6]${NC} 启动 Elasticsearch 7.0.1..."
/data3/start-es-701.sh

# 等待启动
echo ""
echo "等待 Elasticsearch 启动..."
for i in {1..60}; do
    if curl -s http://localhost:9210 >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Elasticsearch 启动成功！${NC}"
        break
    fi
    if [ $i -eq 60 ]; then
        echo -e "${RED}❌ 启动超时，请检查日志${NC}"
        exit 1
    fi
    sleep 2
    echo -n "."
done
echo ""

# 验证
echo ""
echo "=== 验证部署 ==="
echo ""
echo "集群信息:"
curl -s http://localhost:9210
echo ""
echo ""
echo "节点信息:"
curl -s http://localhost:9210/_cat/nodes?v
echo ""
echo ""
echo "健康状态:"
curl -s http://localhost:9210/_cluster/health?pretty
echo ""

echo -e "${GREEN}"
echo "=========================================="
echo "  ✅ 修复完成！"
echo "=========================================="
echo -e "${NC}"
echo ""
echo "服务信息："
echo "  版本: Elasticsearch 7.0.1"
echo "  访问地址: http://172.16.47.57:9210"
echo "  运行用户: $ES_USER"
echo ""
echo "管理命令："
echo "  启动: /data3/start-es-701.sh"
echo "  停止: /data3/stop-es-701.sh"
echo "  查看日志: tail -f $ES_HOME/logs/console.log"
echo ""
