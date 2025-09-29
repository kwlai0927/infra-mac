#!/bin/bash
set -euo pipefail

# 獲取腳本所在目錄
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🚀 安裝 K3s Lima 環境..."

# 1. 創建 Lima K3s 配置目錄
echo "📁 創建配置目錄..."
sudo mkdir -p /etc/lima/k3s

# 2. 複製 lima.yaml 配置文件
echo "📋 複製 K3s 配置文件..."
sudo cp "${SCRIPT_DIR}/lima.yaml" /etc/lima/k3s/lima.yaml

# 3. 設置適當的權限
echo "🔐 設置文件權限..."
sudo chmod 644 /etc/lima/k3s/lima.yaml

# 4. 創建系統層級掛載目錄
echo "💾 創建系統層級掛載目錄..."
MOUNT_BASE="/opt/lima-k3s"

# 創建建議的掛載點
sudo mkdir -p "${MOUNT_BASE}/data"
sudo mkdir -p "${MOUNT_BASE}/logs"
sudo mkdir -p "${MOUNT_BASE}/configs"

# 設置目錄權限（允許所有用戶讀寫）
sudo chmod 755 "${MOUNT_BASE}"
sudo chmod 755 "${MOUNT_BASE}/data"
sudo chmod 755 "${MOUNT_BASE}/logs"
sudo chmod 755 "${MOUNT_BASE}/configs"

echo "✅ K3s Lima 環境安裝完成！"
echo ""
echo "📁 掛載目錄："
echo "  - 數據目錄: ${MOUNT_BASE}/data"
echo "  - 日誌目錄: ${MOUNT_BASE}/logs"
echo "  - 配置目錄: ${MOUNT_BASE}/configs"
echo ""
echo "🔧 K3s 配置："
echo "  - 配置文件: /etc/lima/k3s/lima.yaml"
echo "  - 實例名稱: k3s"
echo ""
echo "💡 下一步："
echo "  - 啟動 K3s: make k3s-start"
echo "  - 更新 kubeconfig: make k3s-config"
