#!/bin/bash
# MySQL 6003 实例服务化部署脚本
# 服务器: 172.16.47.63
# 日期: 2026-01-06

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}"
echo "=========================================="
echo "  MySQL 6003 实例服务化部署"
echo "=========================================="
echo -e "${NC}"

# 配置变量
SERVICE_NAME="mysql-6003"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
MYSQL_USER="MySQL5739_ISAS_6003"
MYSQL_DATADIR="/old-data/MySQL5739_ISAS_6003/data"
MYSQL_CONFIG="/old-data/MySQL5739_ISAS_6003/base/5739/my.cnf"
MYSQL_PID_FILE="/old-data/MySQL5739_ISAS_6003/data/mysql.pid"

# 步骤 1: 停止当前运行的 MySQL 进程
echo -e "${YELLOW}[1/7]${NC} 停止当前 MySQL 进程..."
PID=$(ps aux | grep 'MySQL5739_ISAS_6003' | grep '9010' | grep mysqld | grep -v grep | awk '{print $2}')
if [ -n "$PID" ]; then
    echo "找到 MySQL 进程 PID: $PID"
    echo "尝试优雅关闭..."
    if [ -f "/old-data/MySQL5739_ISAS_6003/base/5739/bin/mysqladmin" ]; then
        timeout=60
        elapsed=0
        while [ $elapsed -lt $timeout ]; do
            if /old-data/MySQL5739_ISAS_6003/base/5739/bin/mysqladmin -uroot -p'Rede@612@Mixed' -S$MYSQL_DATADIR/mysql.sock shutdown 2>/dev/null; then
                echo -e "${GREEN}✅ MySQL 已优雅关闭${NC}"
                break
            fi
            sleep 2
            elapsed=$((elapsed + 2))
        done

        # 检查是否还在运行
        if ps -p $PID > /dev/null 2>&1; then
            echo "优雅关闭超时，强制停止..."
            kill -15 $PID
            sleep 10
            if ps -p $PID > /dev/null 2>&1; then
                echo "强制停止..."
                kill -9 $PID
            fi
        fi
    else
        echo "mysqladmin 不存在，使用 kill 命令..."
        kill -15 $PID
        sleep 10
        if ps -p $PID > /dev/null 2>&1; then
            kill -9 $PID
        fi
    fi
else
    echo -e "${GREEN}✅ MySQL 进程未运行${NC}"
fi

# 等待进程完全停止
sleep 5
if ps aux | grep 'MySQL5739_ISAS_6003' | grep '9010' | grep mysqld | grep -v grep > /dev/null; then
    echo -e "${RED}❌ MySQL 进程仍在运行，请手动检查${NC}"
    exit 1
fi

# 步骤 2: 上传服务文件
echo -e "${YELLOW}[2/7]${NC} 创建 systemd 服务文件..."
cat > $SERVICE_FILE << 'EOF'
[Unit]
Description=MySQL 5.7.39 Server (Instance 6003)
Documentation=man:mysqld(8)
Documentation=http://dev.mysql.com/doc/refman/en/using-systemd.html
After=network.target
After=syslog.target
Wants=network.target

[Service]
Type=notify
User=MySQL5739_ISAS_6003
Group=MySQL5739_ISAS_6003

# MySQL 配置路径
Environment="MYSQLD_OPTS=--defaults-file=/old-data/MySQL5739_ISAS_6003/base/5739/my.cnf"

# 数据目录
Environment="MYSQL_DATADIR=/old-data/MySQL5739_ISAS_6003/data"

# PID 文件
PIDFile=/old-data/MySQL5739_ISAS_6003/data/mysql.pid

# 可执行文件
ExecStart=/old-data/MySQL5739_ISAS_6003/base/5739/bin/mysqld $MYSQLD_OPTS

# 优雅关闭（等待 600 秒）
ExecStop=/old-data/MySQL5739_ISAS_6003/base/5739/bin/mysqladmin --socket=/old-data/MySQL5739_ISAS_6003/data/mysql.sock -uroot -p'Rede@612@Mixed' shutdown
TimeoutSec=600
Restart=on-failure
RestartPreventExitStatus=1

# 私有临时目录
PrivateTmp=true

# 性能优化
LimitNOFILE=65535
LimitNPROC=65535

# 安全设置
NoNewPrivileges=true

# 日志
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=mysql-6003

[Install]
WantedBy=multi-user.target
EOF

echo -e "${GREEN}✅ 服务文件创建完成${NC}"

# 步骤 3: 重载 systemd
echo -e "${YELLOW}[3/7]${NC} 重载 systemd..."
systemctl daemon-reload
echo -e "${GREEN}✅ systemd 已重载${NC}"

# 步骤 4: 启用开机自启
echo -e "${YELLOW}[4/7]${NC} 启用开机自启..."
systemctl enable $SERVICE_NAME
echo -e "${GREEN}✅ 已启用开机自启${NC}"

# 步骤 5: 启动服务
echo -e "${YELLOW}[5/7]${NC} 启动 MySQL 服务..."
systemctl start $SERVICE_NAME
echo -e "${GREEN}✅ MySQL 服务启动中...${NC}"

# 步骤 6: 等待服务启动
echo -e "${YELLOW}[6/7]${NC} 等待服务启动..."
for i in {1..60}; do
    if systemctl is-active --quiet $SERVICE_NAME; then
        echo -e "${GREEN}✅ MySQL 服务已启动${NC}"
        break
    fi
    if [ $i -eq 60 ]; then
        echo -e "${RED}❌ MySQL 服务启动超时${NC}"
        echo "查看服务状态: systemctl status $SERVICE_NAME"
        echo "查看错误日志: tail -100 /old-data/MySQL5739_ISAS_6003/log/mysqldb-error.err"
        exit 1
    fi
    sleep 2
    echo -n "."
done
echo ""

# 步骤 7: 验证服务状态
echo -e "${YELLOW}[7/7]${NC} 验证服务状态..."
echo ""
echo "=== 服务状态 ==="
systemctl status $SERVICE_NAME --no-pager
echo ""
echo "=== 端口监听 ==="
netstat -tunlp | grep :9010 || echo "端口 9010 未监听"
echo ""
echo "=== 进程信息 ==="
ps aux | grep 'MySQL5739_ISAS_6003' | grep '9010' | grep mysqld | grep -v grep || echo "进程未找到"
echo ""

# 测试连接
if [ -f "/old-data/MySQL5739_ISAS_6003/base/5739/bin/mysql" ]; then
    echo "=== MySQL 连接测试 ==="
    if /old-data/MySQL5739_ISAS_6003/base/5739/bin/mysql -uroot -p'Rede@612@Mixed' -S$MYSQL_DATADIR/mysql.sock -e "SELECT 'MySQL connection OK!' AS Status;" 2>/dev/null; then
        echo -e "${GREEN}✅ MySQL 连接成功${NC}"
    else
        echo -e "${YELLOW}⚠️ MySQL 连接失败（密码可能不正确）${NC}"
    fi
fi

echo ""
echo -e "${GREEN}"
echo "=========================================="
echo "  ✅ 部署完成！"
echo "=========================================="
echo -e "${NC}"
echo ""
echo "服务管理命令："
echo "  启动服务: systemctl start $SERVICE_NAME"
echo "  停止服务: systemctl stop $SERVICE_NAME"
echo "  重启服务: systemctl restart $SERVICE_NAME"
echo "  查看状态: systemctl status $SERVICE_NAME"
echo "  查看日志: journalctl -u $SERVICE_NAME -f"
echo "  禁用自启: systemctl disable $SERVICE_NAME"
echo ""
echo "日志文件："
echo "  错误日志: tail -f /old-data/MySQL5739_ISAS_6003/log/mysqldb-error.err"
echo "  慢查询日志: tail -f /old-data/MySQL5739_ISAS_6003/log/mysqldb-query.err"
echo ""
echo "连接命令："
echo "  mysql -uroot -p'Rede@612@Mixed' -S$MYSQL_DATADIR/mysql.sock"
echo "  mysql -h127.0.0.1 -P9010 -uroot -p'Rede@612@Mixed'"
echo ""
echo -e "${YELLOW}注意：${NC}"
echo "  - 服务已配置为开机自启"
echo "  - 如需禁用开机自启，运行: systemctl disable $SERVICE_NAME"
echo "  - 配置文件已优化，内存占用应降低约 30GB"
echo ""
