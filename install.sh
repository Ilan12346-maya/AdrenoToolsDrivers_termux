#!/data/data/com.termux/files/usr/bin/bash
SD="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$HOME/.driver"
EXTRACT_DIR="$BASE_DIR/driver_files"
LAYER_DIR="$BASE_DIR/layer"
WSI_SRC="$SD/vulkan-wsi-layer"
IMPLICIT_DIR="$HOME/.local/share/vulkan/implicit_layer.d"

# Clean
if [[ "$1" == "-c" ]]; then
    echo "cleaning"
    rm -rf "$BASE_DIR"
    rm -f "$IMPLICIT_DIR/VkLayer_window_system_integration.json"
    rm -rf "$WSI_SRC/build/"*
    echo "yeah"
    exit 0
fi

if [[ -z "$1" ]]; then
    echo "nope"
    exit 1
fi

mkdir -p "$LAYER_DIR"
mkdir -p "$IMPLICIT_DIR"
rm -rf "$EXTRACT_DIR"
ZIP_FILE=$(realpath "$1")

echo "Extracting"
unzip -q "$ZIP_FILE" -d "$EXTRACT_DIR"

echo "building layer"
cd "$WSI_SRC/build" && ninja > /dev/null 2>&1
cp libVkLayer_window_system_integration.so VkLayer_window_system_integration.json "$LAYER_DIR/"
sed -i "s|\"./libVkLayer_window_system_integration.so\"|\"$LAYER_DIR/libVkLayer_window_system_integration.so\"|g" "$LAYER_DIR/VkLayer_window_system_integration.json"
sed -i "s|\"api_version\": \"1.3.216\"|\"api_version\": \"1.4.303\"|g" "$LAYER_DIR/VkLayer_window_system_integration.json"
ln -sf "$LAYER_DIR/VkLayer_window_system_integration.json" "$IMPLICIT_DIR/"
cd "$SD"

DRIVER_SO=$(find "$EXTRACT_DIR" -name "vulkan.*.so" | head -n 1)
if [[ -z "$DRIVER_SO" ]]; then
    echo "err"
    exit 1
fi
echo "Driver: $DRIVER_SO"

echo "analyzing symbols"
M_CREATE=$(nm -D "$DRIVER_SO" | grep -oP "_ZN11qglinternal\d+vkCreateInstance\w+")
M_GET_INST=$(nm -D "$DRIVER_SO" | grep -oP "_ZN11qglinternal\d+vkGetInstanceProcAddr\w+")
M_GET_DEV=$(nm -D "$DRIVER_SO" | grep -oP "_ZN11qglinternal\d+vkGetDeviceProcAddr\w+")
M_ENUM_INST=$(nm -D "$DRIVER_SO" | grep -oP "_ZN11qglinternal\d+vkEnumerateInstanceExtensionProperties\w+")
M_ENUM_DEV=$(nm -D "$DRIVER_SO" | grep -oP "_ZN11qglinternal\d+vkEnumerateDeviceExtensionProperties\w+")

echo "make wrapper"
cat <<EOF > "$BASE_DIR/wrapper.c"
#include <stdio.h>
#include <stdlib.h>
#include <dlfcn.h>
#include <stdint.h>

#define REAL_DRIVER "$DRIVER_SO"
#define M_GET_INSTANCE_PROC "$M_GET_INST"
#define M_GET_DEVICE_PROC   "$M_GET_DEV"
#define M_ENUM_INST_EXT     "$M_ENUM_INST"
#define M_ENUM_DEV_EXT      "$M_ENUM_DEV"
#define M_CREATE_INST       "$M_CREATE"

static void *handle = NULL;

void load_driver() {
    if (handle) return;
    handle = dlopen(REAL_DRIVER, RTLD_NOW | RTLD_GLOBAL);
}

void* vkGetInstanceProcAddr(void* instance, const char* name) {
    load_driver();
    if (!handle) return NULL;
    void* (*f)(void*, const char*) = (void* (*)(void*, const char*))dlsym(handle, M_GET_INSTANCE_PROC);
    return f ? f(instance, name) : NULL;
}

void* vk_icdGetInstanceProcAddr(void* instance, const char* name) {
    return vkGetInstanceProcAddr(instance, name);
}

void* vkGetDeviceProcAddr(void* device, const char* name) {
    load_driver();
    if (!handle) return NULL;
    void* (*f)(void*, const char*) = (void* (*)(void*, const char*))dlsym(handle, M_GET_DEVICE_PROC);
    return f ? f(device, name) : NULL;
}

void* vk_icdGetPhysicalDeviceProcAddr(void* instance, const char* name) {
    return vkGetInstanceProcAddr(instance, name);
}

int vkEnumerateInstanceExtensionProperties(const char* pLayerName, uint32_t* pPropertyCount, void* pProperties) {
    load_driver();
    if (!handle) return -1;
    int (*f)(const char*, uint32_t*, void*) = (int (*)(const char*, uint32_t*, void*))dlsym(handle, M_ENUM_INST_EXT);
    return f ? f(pLayerName, pPropertyCount, pProperties) : -1;
}

int vkEnumerateDeviceExtensionProperties(void* physicalDevice, const char* pLayerName, uint32_t* pPropertyCount, void* pProperties) {
    load_driver();
    if (!handle) return -1;
    int (*f)(void*, const char*, uint32_t*, void*) = (int (*)(void*, const char*, uint32_t*, void*))dlsym(handle, M_ENUM_DEV_EXT);
    return f ? f(physicalDevice, pLayerName, pPropertyCount, pProperties) : -1;
}

int vkCreateInstance(const void* pCreateInfo, const void* pAllocator, void* pInstance) {
    load_driver();
    if (!handle) return -1;
    int (*f)(const void*, const void*, void*) = (int (*)(const void*, const void*, void*))dlsym(handle, M_CREATE_INST);
    return f ? f(pCreateInfo, pAllocator, pInstance) : -1;
}
EOF

clang -shared -fPIC "$BASE_DIR/wrapper.c" -o "$BASE_DIR/libvulkan_wrapper.so" -ldl

echo "make ICD JSON..."
cat <<EOF > "$BASE_DIR/driver_icd.json"
{
    "file_format_version": "1.0.0",
    "ICD": {
        "library_path": "$BASE_DIR/libvulkan_wrapper.so",
        "api_version": "1.4.303"
    }
}
EOF

echo "Vulkan Info"
env VK_ICD_FILENAMES="$BASE_DIR/driver_icd.json" \
    VK_LAYER_PATH="$LAYER_DIR" \
    VK_INSTANCE_LAYERS="VK_LAYER_window_system_integration" \
    LD_LIBRARY_PATH="$EXTRACT_DIR:/vendor/lib64:/system/lib64:$LD_LIBRARY_PATH" \
    vulkaninfo 2>/dev/null | grep -A 40 "Device Properties" | grep -iE "deviceName|driverVersion" | sed 's/^[[:space:]]*//'

echo "yeah"
