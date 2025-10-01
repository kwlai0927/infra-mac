#!/usr/bin/env bash
set -euo pipefail

PROFILE="nonprod"
TARGET_USER="kwlai0927"
USER_HOME="$(eval echo ~${TARGET_USER})"
PROFILE_ROOT="${USER_HOME}/.colima"
PROFILE_DIR="${PROFILE_ROOT}/${PROFILE}"
PROFILE_FILE="${PROFILE_DIR}/colima.yaml"

KUBE_DIR="${USER_HOME}/.kube"
OUT_KUBECONFIG="${KUBE_DIR}/tailscale.yaml"
TS_AUTHKEY="${TS_AUTHKEY:-}"
CF_TUNNEL_TOKEN="${CF_TUNNEL_TOKEN:-}"

# 準備 mount 與 kube 目錄（用使用者身分）
sudo -u "${TARGET_USER}" mkdir -p "${USER_HOME}/k3s" "${KUBE_DIR}"
sudo -u "${TARGET_USER}" chmod 700 "${KUBE_DIR}"

# 確保 ~/.colima 由使用者建立與持有
sudo -u "${TARGET_USER}" mkdir -p "${PROFILE_DIR}"

# 找 colima
COLIMA_BIN="$(command -v colima || true)"
if [[ -z "${COLIMA_BIN}" ]]; then
  if [[ -x /opt/homebrew/bin/colima ]]; then
    COLIMA_BIN="/opt/homebrew/bin/colima"
  elif [[ -x /usr/local/bin/colima ]]; then
    COLIMA_BIN="/usr/local/bin/colima"
  else
    echo "❌ 找不到 colima，請先安裝（brew install colima）"; exit 1
  fi
fi

# 放置 colima.yaml（用 install，不要 mv 成 root owner）
if [[ ! -f ./colima.yaml ]]; then
  echo "❌ 當前目錄沒有 colima.yaml"; exit 1
fi
echo "➡️ 複製 colima.yaml 到 ${PROFILE_FILE}"
install -m 0644 ./colima.yaml "${PROFILE_FILE}"
chown "${TARGET_USER}:staff" "${PROFILE_FILE}"

# 再次保險：整個 ~/.colima 都歸使用者
chown -R "${TARGET_USER}:staff" "${PROFILE_ROOT}"

echo "➡️ 啟動 Colima（以使用者身分）"
sudo -u "${TARGET_USER}" env PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
  "${COLIMA_BIN}" start --profile "${PROFILE}" || true

echo "➡️ 在 VM 內安裝 Tailscale"
"${COLIMA_BIN}" ssh --profile "${PROFILE}" -- sudo bash -lc 'curl -fsSL https://tailscale.com/install.sh | sh'
"${COLIMA_BIN}" ssh --profile "${PROFILE}" -- sudo systemctl enable tailscaled
"${COLIMA_BIN}" ssh --profile "${PROFILE}" -- sudo systemctl start tailscaled

if [[ -n "${TS_AUTHKEY}" ]]; then
  echo "➡️ tailscale up"
  "${COLIMA_BIN}" ssh --profile "${PROFILE}" -- sudo tailscale up \
    --authkey="${TS_AUTHKEY}" --ssh --accept-routes --advertise-tags=tag:k3s || true
else
  echo "ℹ️ 未提供 TS_AUTHKEY，稍後可在 VM 內執行：sudo tailscale up --authkey=... --ssh"
fi

echo "➡️ 取得 TS IP（可能為空，若尚未登入）"
TS_IP="$("${COLIMA_BIN}" ssh --profile "${PROFILE}" -- tailscale ip -4 2>/dev/null | head -n1 || true)"
if [[ -n "${TS_IP}" ]]; then echo "   TS IPv4: ${TS_IP}"; fi

echo "➡️ 匯出 kubeconfig 到 ${OUT_KUBECONFIG}"
"${COLIMA_BIN}" ssh --profile "${PROFILE}" -- sudo cat /etc/rancher/k3s/k3s.yaml > "${OUT_KUBECONFIG}"
chown "${TARGET_USER}:staff" "${OUT_KUBECONFIG}"
chmod 600 "${OUT_KUBECONFIG}"

if [[ -n "${TS_IP}" ]]; then
  /usr/bin/sed -i '' "s#server: https://127\.0\.0\.1:6443#server: https://${TS_IP}:6443#g" "${OUT_KUBECONFIG}" || true
  echo "✅ 用法：kubectl --kubeconfig ${OUT_KUBECONFIG} get nodes -o wide"
else
  echo "⚠️ 尚未登入 Tailscale：請在 VM 內 tailscale up 後，把 ${OUT_KUBECONFIG} 的 server 改為 TS IP"
fi