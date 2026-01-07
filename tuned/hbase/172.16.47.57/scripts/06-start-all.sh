#!/bin/bash
# ============================================================================
# 服务启动和管理脚本
# ============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 检查服务状态
check_service() {
    local service_name=$1
    local ports=$2

    log_info "检查 ${service_name}..."

    local port_count=0
    for port in $ports; do
        if netstat -tuln 2>/dev/null | grep -q ":$port " || \
           ss -tuln 2>/dev/null | grep -q ":$port "; then
            ((port_count++))
        fi
    done

    if [[ $port_count -gt 0 ]]; then
        log_info "✓ ${service_name} 正在运行 (${port_count}/${#ports[@]} 端口可达)"
        return 0
    else
        log_error "${service_name} 未运行"
        return 1
    fi
}

# 启动 ZooKeeper
start_zookeeper() {
    log_info "=========================================="
    log_info "启动 ZooKeeper"
    log_info "=========================================="

    if check_service "ZooKeeper" "2181"; then
        log_warn "ZooKeeper 已在运行"
        return 0
    fi

    /opt/zookeeper/bin/zkServer.sh start

    sleep 3

    if check_service "ZooKeeper" "2181"; then
        log_info "✓ ZooKeeper 启动成功"
    else
        log_error "ZooKeeper 启动失败"
        return 1
    fi
}

# 启动 Hadoop
start_hadoop() {
    log_info "=========================================="
    log_info "启动 Hadoop"
    log_info "=========================================="

    # 检查NameNode是否已格式化
    if [[ ! -d /data/hadoop/hdfs/namenode/current ]]; then
        log_warn "HDFS 未格式化，正在格式化..."
        /opt/hadoop/bin/hdfs namenode -format -force
    fi

    # 启动 HDFS
    log_info "启动 HDFS..."
    /opt/hadoop/sbin/start-dfs.sh

    sleep 5

    if check_service "Hadoop" "9000 9870 9866"; then
        log_info "✓ Hadoop 启动成功"
    else
        log_error "Hadoop 启动失败"
        return 1
    fi
}

# 启动 HBase
start_hbase() {
    log_info "=========================================="
    log_info "启动 HBase"
    log_info "=========================================="

    if check_service "HBase" "16010 16030"; then
        log_warn "HBase 已在运行"
        return 0
    fi

    /opt/hbase/bin/start-hbase.sh

    sleep 5

    if check_service "HBase" "16010 16030"; then
        log_info "✓ HBase 启动成功"
    else
        log_error "HBase 启动失败"
        return 1
    fi
}

# 停止所有服务
stop_all() {
    log_info "=========================================="
    log_info "停止所有服务"
    log_info "=========================================="

    log_info "停止 HBase..."
    /opt/hbase/bin/stop-hbase.sh || true

    log_info "停止 Hadoop..."
    /opt/hadoop/sbin/stop-dfs.sh || true

    log_info "停止 ZooKeeper..."
    /opt/zookeeper/bin/zkServer.sh stop || true

    log_info "✓ 所有服务已停止"
}

# 查看服务状态
status_all() {
    log_info "=========================================="
    log_info "服务状态"
    log_info "=========================================="
    log_info ""

    check_service "ZooKeeper" "2181" || true
    check_service "Hadoop" "9000 9870 9866" || true
    check_service "HBase" "16010 16030" || true

    log_info ""
    log_info "详细进程信息:"
    ps aux | grep -E "(zookeeper|hadoop|hbase)" | grep -v grep || true
}

# 测试服务
test_services() {
    log_info "=========================================="
    log_info "测试服务"
    log_info "=========================================="
    log_info ""

    log_info "测试 ZooKeeper..."
    if echo "ruok" | nc localhost 2181 | grep -q "imok"; then
        log_info "✓ ZooKeeper 响应正常"
    else
        log_error "ZooKeeper 无响应"
    fi

    log_info "测试 Hadoop HDFS..."
    if /opt/hadoop/bin/hdfs dfsadmin -report &> /dev/null; then
        log_info "✓ HDFS 可用"
    else
        log_error "HDFS 不可用"
    fi

    log_info "测试 HBase..."
    if /opt/hbase/bin/hbase shell <<EOF
version
exit
EOF &> /dev/null; then
        log_info "✓ HBase 可用"
    else
        log_error "HBase 不可用"
    fi

    log_info ""
    log_info "Web UI 地址:"
    log_info "  Hadoop NameNode: http://172.16.47.57:9870"
    log_info "  HBase Master:   http://172.16.47.57:16010"
}

# 查看日志
view_logs() {
    local service=$1

    case $service in
        zk|zookeeper)
            log_info "查看 ZooKeeper 日志..."
            tail -f /opt/zookeeper/logs/zookeeper*.out || \
            tail -f /opt/zookeeper/logs/zookeeper-*.log
            ;;
        hadoop|hdfs)
            log_info "查看 Hadoop 日志..."
            tail -f /opt/hadoop/logs/hadoop-*-namenode-*.log || \
            tail -f /opt/hadoop/logs/hadoop-*-datanode-*.log
            ;;
        hbase)
            log_info "查看 HBase 日志..."
            tail -f /opt/hbase/logs/hbase-*-master-*.log || \
            tail -f /opt/hbase/logs/hbase-*-regionserver-*.log
            ;;
        *)
            log_error "未知服务: $service"
            log_info "可用服务: zk, hadoop, hbase"
            ;;
    esac
}

# 显示帮助
show_help() {
    cat << EOF
HBase 服务管理脚本

用法: $0 [命令] [选项]

命令:
  start       启动所有服务 (ZooKeeper -> Hadoop -> HBase)
  stop        停止所有服务
  restart     重启所有服务
  status      查看服务状态
  test        测试服务可用性
  logs [服务] 查看服务日志 (zk|hadoop|hbase)

示例:
  $0 start              # 启动所有服务
  $0 status             # 查看状态
  $0 logs hbase         # 查看 HBase 日志
  $0 test               # 测试服务

服务端口:
  ZooKeeper: 2181
  Hadoop:    9000, 9870, 9866
  HBase:     16010, 16030
EOF
}

# 主函数
main() {
    case "${1:-start}" in
        start)
            start_zookeeper
            start_hadoop
            start_hbase
            log_info ""
            log_info "=========================================="
            log_info "所有服务启动完成"
            log_info "=========================================="
            log_info ""
            status_all
            test_services
            ;;
        stop)
            stop_all
            ;;
        restart)
            stop_all
            sleep 3
            start_zookeeper
            start_hadoop
            start_hbase
            ;;
        status)
            status_all
            ;;
        test)
            test_services
            ;;
        logs)
            view_logs "$2"
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "未知命令: $1"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
