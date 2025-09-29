#!/bin/bash
set -euo pipefail

# 獲取當前用戶
USER=$(whoami)
USER_HOME="${HOME}"

echo "🔧 更新 K3s Kubeconfig 配置..."
echo ""
echo "💡 使用說明："
echo "  - 本機使用: ./update-kubeconfig.sh"
echo "  - 遠端使用: 在 Tailscale 環境中執行"
echo "  - 強制指定: K3S_SERVER_OVERRIDE=https://your-server:6443 ./update-kubeconfig.sh"
echo ""

# 檢查 Lima K3s 實例是否運行
if ! limactl list | grep -q "k3s.*Running"; then
    echo "❌ Lima K3s 實例未運行，請先執行: sudo limactl start /etc/lima/k3s/lima.yaml --name=k3s"
    exit 1
fi

# 檢查 Lima K3s 實例是否運行
echo "🔍 檢查 K3s 實例狀態..."
if ! limactl list | grep -q "k3s.*Running"; then
    echo "❌ K3s 實例未運行，請先執行: make k3s-start"
    exit 1
fi

# 判斷是本機還是遠端呼叫
echo "🔍 判斷連線方式..."

# 檢查是否有強制指定的 server 地址
if [[ -n "${K3S_SERVER_OVERRIDE:-}" ]]; then
    echo "🔧 使用指定的 server 地址: ${K3S_SERVER_OVERRIDE}"
    K3S_SERVER="${K3S_SERVER_OVERRIDE}"
elif [[ -n "${TAILSCALE_HOSTNAME:-}" ]] || command -v tailscale >/dev/null 2>&1; then
    # 檢查是否在 Tailscale 網路中
    if tailscale status >/dev/null 2>&1; then
        TAILSCALE_IP=$(tailscale ip -4 2>/dev/null)
        TAILSCALE_HOSTNAME=$(tailscale status --json 2>/dev/null | grep -o '"HostName":"[^"]*"' | cut -d'"' -f4 | head -n1)
        
        if [[ -n "${TAILSCALE_IP}" ]]; then
            echo "🌐 檢測到 Tailscale 環境"
            echo "📍 使用 Tailscale IP: ${TAILSCALE_IP}:6443"
            K3S_SERVER="https://${TAILSCALE_IP}:6443"
        elif [[ -n "${TAILSCALE_HOSTNAME}" ]]; then
            echo "🌐 檢測到 Tailscale 環境"
            echo "📍 使用 Tailscale 主機名: ${TAILSCALE_HOSTNAME}.ts.net:6443"
            K3S_SERVER="https://${TAILSCALE_HOSTNAME}.ts.net:6443"
        else
            echo "📍 使用本機地址: 127.0.0.1:6443"
            K3S_SERVER="https://127.0.0.1:6443"
        fi
    else
        echo "📍 使用本機地址: 127.0.0.1:6443"
        K3S_SERVER="https://127.0.0.1:6443"
    fi
else
    echo "📍 使用本機地址: 127.0.0.1:6443"
    K3S_SERVER="https://127.0.0.1:6443"
fi

# 從 Lima 實例複製 kubeconfig
echo "📋 複製 K3s kubeconfig..."
lima k3s sudo cat /etc/rancher/k3s/k3s.yaml > /tmp/k3s-kubeconfig.yaml

# 更新 kubeconfig 中的 server 地址
echo "🔧 更新 kubeconfig server 地址為: ${K3S_SERVER}"
sed -i.bak "s|server: https://127.0.0.1:6443|server: ${K3S_SERVER}|g" /tmp/k3s-kubeconfig.yaml

# 確保 .kube 目錄存在
mkdir -p "${USER_HOME}/.kube"

# 創建專用的 K3s kubeconfig 文件
K3S_CONFIG="${USER_HOME}/.kube/k3s-config"
echo "📝 創建專用 K3s kubeconfig..."
cp /tmp/k3s-kubeconfig.yaml "${K3S_CONFIG}"

# 設置正確的權限
chmod 600 "${K3S_CONFIG}"

# 設定/重命名 context 為 mbpk3s，並設為預設
CURRENT_CTX=$(kubectl config get-contexts --kubeconfig "${K3S_CONFIG}" -o name | head -n1 || true)
if [[ -n "${CURRENT_CTX}" && "${CURRENT_CTX}" != "mbpk3s" ]]; then
  kubectl config rename-context "${CURRENT_CTX}" "mbpk3s" --kubeconfig "${K3S_CONFIG}" || true
fi
kubectl config use-context "mbpk3s" --kubeconfig "${K3S_CONFIG}" || true

# 如果存在主 kubeconfig，則合併配置
if [[ -f "${USER_HOME}/.kube/config" ]]; then
    echo "🔗 合併到主 kubeconfig..."
    
    # 備份現有的 kubeconfig
    cp "${USER_HOME}/.kube/config" "${USER_HOME}/.kube/config.backup.$(date +%Y%m%d_%H%M%S)"
    
    # 使用 kubectl 合併配置
    KUBECONFIG="${USER_HOME}/.kube/config:${K3S_CONFIG}" kubectl config view --flatten > /tmp/merged-config.yaml
    mv /tmp/merged-config.yaml "${USER_HOME}/.kube/config"
    
    echo "✅ 已將 K3s 配置合併到主 kubeconfig"
else
    echo "📝 創建新的主 kubeconfig..."
    cp "${K3S_CONFIG}" "${USER_HOME}/.kube/config"
fi

# 清理臨時文件
rm -f /tmp/k3s-kubeconfig.yaml /tmp/k3s-kubeconfig.yaml.bak

echo "✅ Kubeconfig 更新完成！"
echo ""
echo "📋 使用說明："
echo "  - 檢查集群狀態: kubectl get nodes"
echo "  - 查看 pods: kubectl get pods -A"
echo "  - 連接到 VM: lima k3s"
echo ""
echo "🔧 配置信息："
echo "  - K3s API Server: ${K3S_SERVER}"
echo "  - 主 kubeconfig: ${USER_HOME}/.kube/config"
echo "  - K3s 專用配置: ${USER_HOME}/.kube/k3s-config"
echo "  - 用戶: ${USER}"
echo "  - Context 名稱: mbpk3s"
echo ""
if [[ "${K3S_SERVER}" == "https://127.0.0.1:6443" ]]; then
    echo "🏠 本機存取模式"
    echo "  - 如需遠端存取，請在 Tailscale 環境中重新執行此腳本"
else
    echo "🌐 遠端存取模式 (Tailscale)"
    echo "  - 此 kubeconfig 已配置為遠端存取"
    echo "  - 可在任何 Tailscale 網路中的機器上使用"
fi

echo ""
echo "💡 指定 kubeconfig 使用："
echo "  - 使用 K3s 配置: kubectl --kubeconfig=${USER_HOME}/.kube/k3s-config get nodes"
echo "  - 使用環境變量: KUBECONFIG=${USER_HOME}/.kube/k3s-config kubectl get nodes"
echo "  - 切換上下文: kubectl config use-context mbpk3s"
