#!/usr/bin/env bash
set -euo pipefail

# Lima 官方倉庫
REPO="lima-vm/lima"

# ---------- 檢查平台 ----------
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "此腳本僅支援 macOS。"; exit 1
fi

OS_NAME="Darwin"
ARCH="$(uname -m)"
case "$ARCH" in
  arm64)   ARCH="arm64"   ;;
  x86_64)  ARCH="x86_64"  ;;
  *) echo "未知架構：$ARCH"; exit 1 ;;
esac

# ---------- 取得最新版本 tag ----------
echo "偵測 Lima 最新版本..."
LATEST_TAG="$(curl -fsSL https://api.github.com/repos/${REPO}/releases/latest | \
  grep -Eo '"tag_name":\s*"v[0-9]+\.[0-9]+\.[0-9]+"' | head -n1 | sed -E 's/.*"([^"]+)".*/\1/')"

if [[ -z "${LATEST_TAG}" ]]; then
  echo "無法從 GitHub 取得最新版本。"; exit 1
fi
echo "最新版本：${LATEST_TAG}"

# ---------- 準備下載 ----------
VERSION="${LATEST_TAG#v}"  # 移除 'v' 前綴
ASSET="lima-${VERSION}-${OS_NAME}-${ARCH}.tar.gz"
BASE_URL="https://github.com/${REPO}/releases/download/${LATEST_TAG}"
URL="${BASE_URL}/${ASSET}"

TMPDIR="$(mktemp -d)"
TAR_PATH="${TMPDIR}/${ASSET}"

echo "下載：${URL}"
curl -fL --retry 3 -o "${TAR_PATH}" "${URL}"

# （可選）校驗檔案：若存在 SHA256SUMS，則驗證
SUMS_URL="${BASE_URL}/SHA256SUMS"
if curl -fI -s "${SUMS_URL}" >/dev/null; then
  echo "下載 SHA256SUMS 以驗證檔案..."
  curl -fsSL -o "${TMPDIR}/SHA256SUMS" "${SUMS_URL}"
  pushd "${TMPDIR}" >/dev/null
  # 擷取對應檔案的校驗行，並比對
  EXPECTED="$(grep "  ${ASSET}$" SHA256SUMS | awk '{print $1}')"
  if [[ -n "${EXPECTED}" ]]; then
    ACTUAL="$(shasum -a 256 "${ASSET}" | awk '{print $1}')"
    if [[ "${EXPECTED}" != "${ACTUAL}" ]]; then
      echo "SHA256 驗證失敗！"; exit 1
    else
      echo "SHA256 驗證通過。"
    fi
  else
    echo "SHA256SUMS 中未找到 ${ASSET}，略過驗證。"
  fi
  popd >/dev/null
else
  echo "找不到 SHA256SUMS，略過校驗（可接受但安全性較低）。"
fi

# ---------- 解壓並安裝 ----------
echo "解壓檔案..."
tar -xzf "${TAR_PATH}" -C "${TMPDIR}"
EXTRACT_DIR="${TMPDIR}"
BIN_DIR="${EXTRACT_DIR}/bin"
if [[ ! -d "${BIN_DIR}" ]]; then
  echo "bin 目錄不存在。"; exit 1
fi

echo "以系統層級安裝到 /usr/local/bin（需 sudo）..."
sudo install -m 0755 "${BIN_DIR}/limactl" /usr/local/bin/limactl
sudo install -m 0755 "${BIN_DIR}/lima"    /usr/local/bin/lima

# （可選）安裝 shell 自動補全與範例（若存在）
if [[ -d "${EXTRACT_DIR}/share" ]]; then
  echo "安裝 share 資源到 /usr/local/share（需 sudo）..."
  sudo mkdir -p /usr/local/share/lima
  sudo cp -R "${EXTRACT_DIR}/share/." /usr/local/share/lima/ || true
fi

# ---------- 驗證 ----------
echo
echo "驗證安裝版本："
limactl --version || { echo "limactl 無法執行；請檢查 /usr/local/bin 是否在 PATH。"; exit 1; }

echo
echo "✅ Lima 安裝完成。"
echo "  - 指令：limactl、lima"
echo "  - 範例啟動：sudo limactl start /etc/lima/k3s/lima.yaml --name=k3s"
echo "  - 提醒：/usr/local/bin 已對所有使用者可執行；請確認他們的 PATH 包含此目錄。"