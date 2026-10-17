cat << 'EOF' > full-reset.sh
#!/bin/bash
set -e

echo "=========================================================="
echo "   AUTO RESET SELURUH RESOURCE AWS (DENGAN AWS-NUKE)"
echo "=========================================================="

# 1. Mengambil ID Akun, ARN aktif, dan Region
ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
CALLER_ARN=$(aws sts get-caller-identity --query "Arn" --output text)
CURRENT_REGION=$(aws configure get region)
CURRENT_REGION=${CURRENT_REGION:-ap-southeast-3}

echo "Account ID   : $ACCOUNT_ID"
echo "Active Identity: $CALLER_ARN"
echo "Target Region: $CURRENT_REGION & global"
echo "=========================================================="

# 2. Mengunduh aws-nuke jika belum ada
if [ ! -f "./aws-nuke" ]; then
    echo "[*] Mengunduh aws-nuke versi terbaru..."
    ARCH=$(uname -m)
    if [ "$ARCH" = "x86_64" ]; then N_ARCH="amd64"; else N_ARCH="arm64"; fi
    
    LATEST_URL=$(curl -s https://api.github.com/repos/ekristen/aws-nuke/releases/latest \
        | grep "browser_download_url.*linux-${N_ARCH}.tar.gz" \
        | cut -d '"' -f 4)
        
    curl -sL "$LATEST_URL" -o aws-nuke.tar.gz
    tar -xzf aws-nuke.tar.gz aws-nuke
    chmod +x aws-nuke
    rm -f aws-nuke.tar.gz
    echo "[+] aws-nuke berhasil diinstal."
fi

# 3. Memastikan Account Alias tersedia (Syarat keamanan wajib dari aws-nuke)
ALIASES=$(aws iam list-account-aliases --query "AccountAliases[]" --output text)
if [ -z "$ALIASES" ]; then
    TEMP_ALIAS="reset-aws-${ACCOUNT_ID}"
    echo "[*] Membuat alias akun sementara: $TEMP_ALIAS"
    aws iam create-account-alias --account-alias "$TEMP_ALIAS" || true
fi

# 4. Mengekstrak nama User/Role saat ini agar TIDAK ikut terhapus
IAM_NAME=$(echo "$CALLER_ARN" | awk -F'/' '{print $2}')

# 5. Membuat file konfigurasi nuke-config.yaml
cat << YAML > nuke-config.yaml
regions:
  - global
  - $CURRENT_REGION
  # Tambahkan region lain di bawah ini jika Anda pernah membuat resource di luar Jakarta:
  # - ap-southeast-1
  # - us-east-1

blocklist:
  - "999999999999" # Dummy blocklist (wajib ada di config)

resource-types:
  excludes:
    # Mengamankan akun/akses login Anda saat ini agar tidak terkunci:
    - IAMUser
    - IAMUserPolicyAttachment
    - IAMUserAccessKey
    - IAMLoginProfile

accounts:
  "$ACCOUNT_ID":
    presets:
      - common
YAML

cat << PRESET >> nuke-config.yaml
presets:
  common:
    filters:
      IAMRole:
        - property: Name
          type: glob
          value: "AWSServiceRole*"
        - property: Name
          type: glob
          value: "*${IAM_NAME}*"
      IAMRolePolicyAttachment:
        - property: RoleName
          type: glob
          value: "AWSServiceRole*"
        - property: RoleName
          type: glob
          value: "*${IAM_NAME}*"
PRESET

echo ""
echo "Pilih Mode Eksekusi:"
echo "1) Simulasi / Dry-Run (Hanya melihat daftar seluruh resource yang akan dihapus)"
echo "2) EKSEKUSI HAPUS PERMANEN (Menghapus semua resource sekarang)"
read -p "Masukkan pilihan [1/2]: " MODE

if [ "$MODE" == "2" ]; then
    echo -e "\n[!] MEMULAI PENGHAPUSAN SELURUH RESOURCE..."
    ./aws-nuke run -c nuke-config.yaml --no-dry-run --no-prompt --no-alias-check
    echo -e "\n[+] Selesai! Akun telah dibersihkan."
else
    echo -e "\n[*] Menjalankan Simulasi (Dry-Run)..."
    ./aws-nuke run -c nuke-config.yaml --no-prompt --no-alias-check
    echo -e "\n[i] Ini hanya simulasi. Jalankan './full-reset.sh' lagi dan pilih '2' untuk benar-benar menghapus."
fi
EOF

chmod +x full-reset.sh
