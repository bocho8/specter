# Tricky Store paths
TRICKY_DIR="/data/adb/tricky_store"
TARGET_FILE="$TRICKY_DIR/keybox.xml"
BACKUP_FILE="$TRICKY_DIR/keybox.xml.bak"
TARGET_TXT="$TRICKY_DIR/target.txt"
SECURITY_PATCH_FILE="$TRICKY_DIR/security_patch.txt"
TEE_STATUS="$TRICKY_DIR/tee_status"

# Other system paths
BOOT_HASH_FILE="/data/adb/boot_hash"
BBIN="/data/adb/Yurikey/bin"
HMA_DIR="/data/user/0/org.frknkrc44.hma_oss/files"
HMA_FILE="$HMA_DIR/config.json"
IDFILE="/data/local/tmp/yurid"

# Config persistence (flat-file fallback when ksud unavailable)
YURIKEY_CONFIG_DIR="/data/adb/Yurikey/config"
MIGRATION_MARKER="/data/adb/Yurikey/.migrated"
