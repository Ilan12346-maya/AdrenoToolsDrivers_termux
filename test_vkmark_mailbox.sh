#!/data/data/com.termux/files/usr/bin/bash
BASE_DIR="$HOME/.driver"
EXTRACT_DIR="$BASE_DIR/driver_files"
LAYER_DIR="$BASE_DIR/layer"

if [[ ! -f "$BASE_DIR/driver_icd.json" ]]; then
    echo "err"
    exit 1
fi

export DISPLAY=:0
export VK_ICD_FILENAMES="$BASE_DIR/driver_icd.json"
export VK_LAYER_PATH="$LAYER_DIR"
export VK_INSTANCE_LAYERS="VK_LAYER_window_system_integration"
export LD_LIBRARY_PATH="$EXTRACT_DIR:/vendor/lib64:/system/lib64:$LD_LIBRARY_PATH"
export MESA_VK_WSI_PRESENT_MODE=mailbox

echo "vkmark (MAILBOX mode)"
vkmark --present-mode mailbox "$@"
