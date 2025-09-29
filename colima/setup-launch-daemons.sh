#!/usr/bin/env bash
set -euo pipefail

PLIST_SRC="./com.colima.k3s.plist"
PLIST_DST="/Library/LaunchDaemons/com.colima.k3s.plist"
LOG_OUT="/var/log/colima-k3s.out.log"
LOG_ERR="/var/log/colima-k3s.err.log"

if [[ ! -f "${PLIST_SRC}" ]]; then
  echo "❌ 找不到 ${PLIST_SRC}，請先準備好 plist 檔案"
  exit 1
fi

echo "➡️ 複製 LaunchDaemon plist 到 ${PLIST_DST}"
sudo cp "${PLIST_SRC}" "${PLIST_DST}"
sudo chown root:wheel "${PLIST_DST}"
sudo chmod 644 "${PLIST_DST}"

echo "➡️ 建立日誌檔"
sudo touch "${LOG_OUT}" "${LOG_ERR}"
sudo chown kwlai0927:wheel "${LOG_OUT}" "${LOG_ERR}" || true

echo "➡️ 載入 LaunchDaemon"
sudo launchctl unload -w "${PLIST_DST}" >/dev/null 2>&1 || true
sudo launchctl load -w "${PLIST_DST}"

echo "✅ 完成，檢查狀態："
echo "  sudo launchctl list | grep com.colima.k3s"
echo "  tail -f ${LOG_OUT}"