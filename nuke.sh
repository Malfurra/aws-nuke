cat << 'EOF' > full-reset.sh
#!/bin/bash

echo "=========================================================="
echo "   AUTO RESET SELURUH RESOURCE AWS (DENGAN AWS-NUKE)"
echo "=========================================================="

ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
CALLER_ARN=$(aws sts get-caller-identity --query "Arn" --output text)
CURRENT_REGION=${AWS_REGION:-${AWS_DEFAULT_REGION:-ap-southeast-3}}

echo "Account ID     : $ACCOUNT_ID"
echo "Active Identity: $CALLER_ARN"
echo "Target Region  : $CURRENT_REGION, us-east-1, & global"
echo "=========================================================="

# 1. Unduh binary aws-nuke langsung (Direct Link tanpa GitHub API)
if [ ! -f "./aws-nuke-bin" ]; then
    echo "[*] Mengunduh aws-nuke v3.62.2 secara langsung..."
    ARCH=$(uname -m)
    if [ "$ARCH" = "x86_64" ]; then N_ARCH="amd64"; else N_ARCH="arm64"; fi
    
    DIRECT_URL="https://github.com/ekristen/aws-nuke/releases/download/v3.62.2/aws-nuke-v3.62.2-linux-${N_ARCH}.tar.gz"
    
    curl -fL "$DIRECT_URL" -o aws-nuke.tar.gz
    if [ ! -f "aws-nuke.tar.gz" ]; then
        echo "[!] Gagal mengunduh aws-nuke. Periksa koneksi CloudShell."
        exit 1
    fi

    tar -xzf aws-nuke.tar.gz aws-nuke
    mv aws-nuke aws-nuke-bin
    chmod +x aws-nuke-bin
    rm -f aws-nuke.tar.gz
    echo "[+] aws-nuke berhasil diinstal!"
fi

# 2. Pastikan Account Alias tersedia
ALIASES=$(aws iam list-account-aliases --query "AccountAliases[]" --output text 2>/dev/null)
if [ -z "$ALIASES" ]; then
    TEMP_ALIAS="reset-aws-${ACCOUNT_ID}"
    echo "[*] Membuat alias akun sementara: $TEMP_ALIAS"
    aws iam create-account-alias --account-alias "$TEMP_ALIAS" 2>/dev/null || true
fi

# 3. Buat file konfigurasi nuke-config.yaml
cat << YAML > nuke-config.yaml
regions:
  - global
  - $CURRENT_REGION
  - us-east-1

blocklist:
  - "999999999999"

resource-types:
  excludes:
    - IAMUser
    - IAMUserPolicyAttachment
    - IAMUserAccessKey
    - IAMLoginProfile

accounts:
  "$ACCOUNT_ID":
    presets:
      - common

presets:
  common:
    filters:
      IAMRole:
        - property: Name
          type: glob
          value: "AWSServiceRole*"
      IAMRolePolicyAttachment:
        - property: RoleName
          type: glob
          value: "AWSServiceRole*"
YAML

echo ""
echo "Pilih Mode Eksekusi:"
echo "1) Simulasi / Dry-Run (Hanya melihat daftar seluruh resource yang akan dihapus)"
echo "2) EKSEKUSI HAPUS PERMANEN (Menghapus semua resource sekarang)"
read -p "Masukkan pilihan [1/2]: " MODE

if [ "$MODE" == "2" ]; then
    echo -e "\n[!] MEMULAI PENGHAPUSAN SELURUH RESOURCE..."
    ./aws-nuke-bin run -c nuke-config.yaml --no-dry-run --no-prompt --no-alias-check
    echo -e "\n[+] Selesai! Silakan refresh halaman dashboard AWS kamu."
else
    echo -e "\n[*] Menjalankan Simulasi (Dry-Run)..."
    ./aws-nuke-bin run -c nuke-config.yaml --no-prompt --no-alias-check
    echo -e "\n[i] Ini hanya simulasi. Jalankan './full-reset.sh' lagi dan pilih '2' untuk benar-benar menghapus."
fi
EOF

chmod +x full-reset.sh
./full-reset.sh
