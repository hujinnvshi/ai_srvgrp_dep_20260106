#!/bin/bash
# ============================================================================
# JDK 8 安装脚本
# ============================================================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 配置变量
JAVA_VERSION="8u412-b08"
JAVA_BUILD="b08"
JDK_VERSION="1.8.0_412"
INSTALL_DIR="/opt/java"

# 检查是否已安装Java
check_java_installed() {
    log_info "检查Java安装状态..."

    if [[ -d $INSTALL_DIR/jdk$JDK_VERSION ]]; then
        log_info "✓ JDK已安装在: $INSTALL_DIR/jdk$JDK_VERSION"

        # 检查是否已配置环境变量
        if grep -q "java" ~/.bashrc; then
            log_info "✓ 环境变量已配置"
        else
            configure_env_vars
        fi

        java -version
        return 0
    fi

    return 1
}

# 下载JDK
download_jdk() {
    log_info "下载JDK ${JDK_VERSION}..."

    local jdk_url="https://download.java.net/java/GA/jdk8u412/b08/jdk-${JAVA_VERSION}-linux-x64.tar.gz"
    local jdk_file="/tmp/jdk-${JAVA_VERSION}-linux-x64.tar.gz"

    if [[ -f $jdk_file ]]; then
        log_info "JDK安装包已存在: $jdk_file"
        read -p "是否重新下载? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -f $jdk_file
        else
            return 0
        fi
    fi

    log_info "开始下载..."
    wget -O $jdk_url $jdk_file || {
        log_error "下载失败，请手动下载"
        log_info "下载链接: $jdk_url"
        log_info "保存到: $jdk_file"
        exit 1
    }

    log_info "✓ JDK下载完成"
}

# 安装JDK
install_jdk() {
    log_info "安装JDK..."

    local jdk_file="/tmp/jdk-${JAVA_VERSION}-linux-x64.tar.gz"

    if [[ ! -f $jdk_file ]]; then
        log_error "JDK安装包不存在: $jdk_file"
        exit 1
    fi

    # 创建安装目录
    sudo mkdir -p $INSTALL_DIR

    # 解压JDK
    log_info "解压JDK到 $INSTALL_DIR..."
    sudo tar -xzf $jdk_file -C $INSTALL_DIR

    log_info "✓ JDK安装完成"
}

# 配置环境变量
configure_env_vars() {
    log_info "配置Java环境变量..."

    local env_file="$HOME/.bashrc"
    local java_env="
# Java Environment
export JAVA_HOME=$INSTALL_DIR/jdk$JDK_VERSION
export JRE_HOME=\$JAVA_HOME/jre
export CLASSPATH=\$JAVA_HOME/lib:\$JRE_HOME/lib:\$CLASSPATH
export PATH=\$JAVA_HOME/bin:\$JRE_HOME/bin:\$PATH
"

    # 检查是否已配置
    if grep -q "JAVA_HOME=$INSTALL_DIR/jdk$JDK_VERSION" $env_file; then
        log_info "环境变量已配置"
        return 0
    fi

    # 添加环境变量
    echo "$java_env" >> $env_file

    log_info "✓ 环境变量配置完成"
    log_warn "请执行以下命令使环境变量生效:"
    log_info "  source ~/.bashrc"
}

# 验证安装
verify_installation() {
    log_info "验证Java安装..."

    # 加载环境变量
    source ~/.bashrc

    if ! command -v java &> /dev/null; then
        log_error "Java命令不可用，请手动执行: source ~/.bashrc"
        return 1
    fi

    log_info "Java版本信息:"
    java -version

    local java_version=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}')
    log_info "检测到的Java版本: $java_version"

    if [[ $java_version == "1.8."* ]]; then
        log_info "✓ Java版本验证通过"
        return 0
    else
        log_error "Java版本不正确，期望: 1.8.x"
        return 1
    fi
}

# 清理临时文件
cleanup() {
    log_info "清理临时文件..."
    local jdk_file="/tmp/jdk-${JAVA_VERSION}-linux-x64.tar.gz"
    if [[ -f $jdk_file ]]; then
        rm -f $jdk_file
        log_info "✓ 临时文件已清理"
    fi
}

# 主函数
main() {
    log_info "=========================================="
    log_info "JDK 8 安装脚本"
    log_info "=========================================="
    log_info ""

    # 检查是否已安装
    if check_java_installed; then
        log_info "JDK已安装，无需重复安装"
        exit 0
    fi

    # 询问是否继续
    log_info "准备安装 JDK $JDK_VERSION"
    log_info "安装目录: $INSTALL_DIR"
    read -p "是否继续? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "安装已取消"
        exit 0
    fi

    # 下载
    download_jdk

    # 安装
    install_jdk

    # 配置环境变量
    configure_env_vars

    # 清理
    cleanup

    log_info ""
    log_info "=========================================="
    log_info "JDK安装完成"
    log_info "=========================================="
    log_info ""
    log_info "请执行以下命令使环境变量生效:"
    log_info "  source ~/.bashrc"
    log_info ""
    log_info "然后运行以下命令验证:"
    log_info "  java -version"
    log_info ""
    log_info "下一步："
    log_info "  安装ZooKeeper: ./03-install-zookeeper.sh"
}

# 运行主函数
main "$@"
