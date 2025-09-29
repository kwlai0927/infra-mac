#!/bin/bash
set -euo pipefail

echo "🛑 停止 K3s Lima 實例..."

# 檢查實例是否存在
if ! limactl list | grep -q "k3s"; then
    echo "⚠️  K3s 實例不存在"
    exit 0
fi

# 檢查實例是否正在運行
if limactl list | grep -q "k3s.*Running"; then
    echo "🛑 停止 K3s 實例..."
    sudo limactl stop k3s
    echo "✅ K3s 實例已停止"
else
    echo "⚠️  K3s 實例未在運行中"
    limactl list | grep k3s
fi

echo ""
echo "📋 其他操作："
echo "  - 重新啟動: make k3s-start"
echo "  - 刪除實例: sudo limactl delete k3s"
echo "  - 查看狀態: limactl list"
