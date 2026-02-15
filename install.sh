#!/data/data/com.termux/files/usr/bin/bash
SD="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$HOME/.driver"
EXTRACT_DIR="$BASE_DIR/driver_files"
WSI_WRAPPER_SO="/data/data/com.termux/files/usr/lib/libvulkan_wrapper.so"
PROXY_LINK="/data/data/com.termux/v.so"

# Clean
if [[ "$1" == "-c" ]]; then
    echo "cleaning"
    rm -rf "$BASE_DIR"
    rm -f "$PROXY_LINK"
    # Revert the patch in libvulkan_wrapper.so if possible
    if [[ -f "$WSI_WRAPPER_SO" ]]; then
        python3 -c "
path = '$WSI_WRAPPER_SO'
with open(path, 'rb') as f: content = f.read()
new_content = content.replace(b'/data/data/com.termux/v.so', b'/system/lib64/libvulkan.so')
with open(path, 'wb') as f: f.write(new_content)
"
    fi
    echo "yeah"
    exit 0
fi

if [[ -z "$1" ]]; then
    echo "nope ./install.sh <driver.zip>"
    exit 1
fi

rm -rf "$EXTRACT_DIR"
mkdir -p "$BASE_DIR"
ZIP_FILE=$(realpath "$1")

echo "Extracting"
unzip -q "$ZIP_FILE" -d "$EXTRACT_DIR"

DRIVER_SO=$(find "$EXTRACT_DIR" -name "vulkan.*.so" | head -n 1)
if [[ -z "$DRIVER_SO" ]]; then
    echo "err"
    exit 1
fi
echo "Driver: $DRIVER_SO"

echo "generating vkproxy.so"
python3 "$SD/gen_vkproxy.py" "$DRIVER_SO" "$SD/vk.xml" "$BASE_DIR/vkproxy.c"

clang -shared -fPIC "$BASE_DIR/vkproxy.c" -o "$BASE_DIR/vkproxy.so" -ldl

echo "patch libvulkan.so to use vkproxy.so"
ln -sf "$BASE_DIR/vkproxy.so" "$PROXY_LINK"

if [[ -f "$WSI_WRAPPER_SO" ]]; then
    python3 -c "
path = '$WSI_WRAPPER_SO'
with open(path, 'rb') as f: content = f.read()
new_content = content.replace(b'/system/lib64/libvulkan.so', b'/data/data/com.termux/v.so')
with open(path, 'wb') as f: f.write(new_content)
"
fi

echo "make ICD JSON..."
cat <<EOF > "$BASE_DIR/driver_icd.json"
{
    "file_format_version": "1.0.0",
    "ICD": {
        "library_path": "$BASE_DIR/vkproxy.so",
        "api_version": "1.4.303"
    }
}
EOF

echo "Vulkan Info:"
export VK_ICD_FILENAMES="/data/data/com.termux/files/usr/share/vulkan/icd.d/wrapper_icd.aarch64.json"
export LD_LIBRARY_PATH="$EXTRACT_DIR:/vendor/lib64:/system/lib64:$LD_LIBRARY_PATH"
export DISPLAY=:0
vulkaninfo 2>/dev/null | grep -iE "deviceName|driverVersion" | head -n 2 | sed 's/^[[:space:]]*//'

echo "yeah"
