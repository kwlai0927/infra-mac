#!/bin/bash
set -euo pipefail

echo "🚀 啟動 K3s Lima 實例..."

# 檢查配置文件是否存在
if [[ ! -f "/etc/lima/k3s/lima.yaml" ]]; then
    echo "❌ K3s 配置文件不存在，請先執行: make k3s-install"
    exit 1
fi

# 檢查實例是否已經運行
if limactl list | grep -q "k3s.*Running"; then
    echo "⚠️  K3s 實例已經在運行中"
    limactl list | grep k3s
    exit 0
fi

# 啟動 Lima K3s 實例
echo "🚀 啟動 Lima K3s 實例..."
limactl start /etc/lima/k3s/lima.yaml --name=k3s

echo "✅ K3s Lima 實例啟動完成！"
echo ""
echo "📋 使用說明："
echo "  - 連接到 VM: lima k3s"
echo "  - 查看狀態: limactl list"
echo "  - 停止實例: make k3s-stop"
echo "  - 更新 kubeconfig: make k3s-config"