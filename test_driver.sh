#!/data/data/com.termux/files/usr/bin/bash
BASE_DIR="$HOME/.driver"
EXTRACT_DIR="$BASE_DIR/driver_files"
LAYER_DIR="$BASE_DIR/layer"

if [[ ! -f "$BASE_DIR/driver_icd.json" ]]; then
    echo "err: convert driver first"
    exit 1
fi

export DISPLAY=:0
export VK_ICD_FILENAMES="$BASE_DIR/driver_icd.json"
export LD_LIBRARY_PATH="$EXTRACT_DIR:/vendor/lib64:/system/lib64:$LD_LIBRARY_PATH"
export GALLIUM_DRIVER=zink

echo "--- GPU Context ---"
vulkaninfo 2>/dev/null | grep -iE "deviceName|driverVersion" | head -n 2 | sed 's/^[[:space:]]*//'
echo "OpenGL Renderer: Zink (Vulkan-to-OpenGL)"
echo "-------------------"

if [[ -z "$1" ]]; then
    echo "Usage: ./test_gpu.sh <app_name>"
    exit 0
fi

echo "Start"
exec "$@"
