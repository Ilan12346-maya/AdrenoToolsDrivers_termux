#!/data/data/com.termux/files/usr/bin/bash
BASE_DIR="$HOME/.driver"
EXTRACT_DIR="$BASE_DIR/driver_files"
LAYER_DIR="$BASE_DIR/layer"

if [[ ! -f "$BASE_DIR/driver_icd.json" ]]; then
    echo "err"
    exit 1
fi

echo "Vulkan Info"
env VK_ICD_FILENAMES="$BASE_DIR/driver_icd.json" \
    VK_LAYER_PATH="$LAYER_DIR" \
    VK_INSTANCE_LAYERS="VK_LAYER_window_system_integration" \
    LD_LIBRARY_PATH="$EXTRACT_DIR:/vendor/lib64:/system/lib64:$LD_LIBRARY_PATH" \
    vulkaninfo 2>/dev/null | grep -A 40 "Device Properties" | grep -iE "deviceName|driverVersion" | sed 's/^[[:space:]]*//'

echo "vkmark"
env DISPLAY=:0 \
    VK_ICD_FILENAMES="$BASE_DIR/driver_icd.json" \
    VK_LAYER_PATH="$LAYER_DIR" \
    VK_INSTANCE_LAYERS="VK_LAYER_window_system_integration" \
    LD_LIBRARY_PATH="$EXTRACT_DIR:/vendor/lib64:/system/lib64:$LD_LIBRARY_PATH" \
    vkmark "$@"
