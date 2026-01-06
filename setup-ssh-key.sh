#!/bin/bash
# SSH免密登录配置脚本
# 目标服务器: 172.16.47.57
# 用户: root

set -e

SERVER="172.16.47.57"
USER="root"
SSH_KEY="${HOME}/.ssh/id_rsa.pub"

echo "=========================================="
echo "  SSH免密登录配置脚本"
echo "=========================================="
echo ""
echo "目标服务器: $USER@$SERVER"
echo "本地公钥: $SSH_KEY"
echo ""

# 检查公钥是否存在
if [ ! -f "$SSH_KEY" ]; then
    echo "❌ 错误：公钥文件不存在: $SSH_KEY"
    echo "请先生成SSH密钥对："
    echo "  ssh-keygen -t rsa -b 4096"
    exit 1
fi

echo "✅ 找到本地公钥"
echo ""

# 方法1: 使用 ssh-copy-id（推荐）
if command -v ssh-copy-id &> /dev/null; then
    echo "方法1: 使用 ssh-copy-id (推荐)"
    echo "----------------------------------------"
    echo "请输入服务器密码完成配置："
    echo ""

    ssh-copy-id -i "$SSH_KEY" "$USER@$SERVER"

    if [ $? -eq 0 ]; then
        echo ""
        echo "✅ SSH公钥复制成功！"
    else
        echo ""
        echo "❌ SSH公钥复制失败，请手动配置"
        exit 1
    fi
else
    # 方法2: 手动复制
    echo "方法2: 手动复制公钥"
    echo "----------------------------------------"
    echo "请在目标服务器上执行以下命令："
    echo ""
    echo "  mkdir -p ~/.ssh"
    echo "  chmod 700 ~/.ssh"
    echo "  echo '$(cat $SSH_KEY)' >> ~/.ssh/authorized_keys"
    echo "  chmod 600 ~/.ssh/authorized_keys"
    echo ""
    echo "或者直接运行："
    echo ""
    cat "$SSH_KEY" | while read key; do
        echo "  echo \"$key\" >> ~/.ssh/authorized_keys"
    done
fi

echo ""
echo "=========================================="
echo "  测试SSH连接"
echo "=========================================="
echo ""

# 测试连接
echo "正在测试连接到 $SERVER ..."
ssh -o ConnectTimeout=5 -o BatchMode=yes "$USER@$SERVER" "echo '✅ SSH免密登录配置成功！' && hostname && whoami" 2>&1

if [ $? -eq 0 ]; then
    echo ""
    echo "=========================================="
    echo "  ✅ 配置完成！"
    echo "=========================================="
    echo ""
    echo "现在你可以直接执行："
    echo "  ssh $USER@$SERVER"
    echo ""
    echo "无需输入密码！"
else
    echo ""
    echo "❌ 免密登录测试失败"
    echo "请检查："
    echo "1. 服务器SSH配置是否允许密钥登录"
    echo "2. .ssh/authorized_keys文件权限是否正确(600)"
    echo "3. .ssh目录权限是否正确(700)"
fi
