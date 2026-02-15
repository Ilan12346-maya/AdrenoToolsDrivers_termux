#!/data/data/com.termux/files/usr/bin/bash
BASE_DIR="$HOME/.driver"
EXTRACT_DIR="$BASE_DIR/driver_files"
SYSTEM_ICD="/data/data/com.termux/files/usr/share/vulkan/icd.d/wrapper_icd.aarch64.json"

if [[ ! -f "$BASE_DIR/vkproxy.so" ]]; then
    echo "err: install driver first"
    exit 1
fi

export DISPLAY=:0
# Use the system wrapper ICD which we patched to load our proxy
export VK_ICD_FILENAMES="$SYSTEM_ICD"
export LD_LIBRARY_PATH="$EXTRACT_DIR:/vendor/lib64:/system/lib64:$LD_LIBRARY_PATH"
export GALLIUM_DRIVER=zink

echo "--- GPU Context ---"
vulkaninfo 2>/dev/null | grep -iE "deviceName|driverVersion" | head -n 2 | sed 's/^[[:space:]]*//'
echo "-------------------"

if [[ -z "$1" ]]; then
    echo "Usage: ./test_driver.sh <app_name>"
    exit 0
fi

echo "Start"
exec "$@"
