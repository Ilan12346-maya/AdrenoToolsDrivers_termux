#!/data/data/com.termux/files/usr/bin/bash
SD="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$HOME/.driver"
EXTRACT_DIR="$BASE_DIR/driver_files"
LAYER_SRC="$(realpath "$SD/../vulkan-805/layer")"

if [[ "$1" == "-c" ]]; then
    rm -rf "$BASE_DIR"
    echo "clean"
    exit 0
fi

if [[ -z "$1" ]]; then
    echo "nope"
    exit 1
fi

mkdir -p "$BASE_DIR"
rm -rf "$BASE_DIR"/*
ZIP_FILE=$(realpath "$1")

echo "unpacking"
unzip -q "$ZIP_FILE" -d "$EXTRACT_DIR"

DRIVER_SO=$(find "$EXTRACT_DIR" -name "vulkan.*.so" | head -n 1)
if [[ -z "$DRIVER_SO" ]]; then
    echo "err"
    exit 1
fi

cat <<EOF > "$BASE_DIR/wrapper.c"
#include <stdio.h>
#include <stdlib.h>
#include <dlfcn.h>
#include <stdint.h>
#define REAL_DRIVER "$DRIVER_SO"
#define M_GET_INSTANCE_PROC "_ZN11qglinternal21vkGetInstanceProcAddrEP12VkInstance_TPKc"
#define M_GET_DEVICE_PROC   "_ZN11qglinternal19vkGetDeviceProcAddrEP10VkDevice_TPKc"
#define M_ENUM_INST_EXT     "_ZN11qglinternal38vkEnumerateInstanceExtensionPropertiesEPKcPjP21VkExtensionProperties"
#define M_ENUM_DEV_EXT      "_ZN11qglinternal36vkEnumerateDeviceExtensionPropertiesEP18VkPhysicalDevice_TPKcPjP21VkExtensionProperties"
#define M_CREATE_INST       "_ZN11qglinternal16vkCreateInstanceEPK20VkInstanceCreateInfoPK21VkAllocationCallbacksPP12VkInstance_T"
static void *handle = NULL;
void load_driver() { if (!handle) handle = dlopen(REAL_DRIVER, RTLD_NOW | RTLD_GLOBAL); }
void* vkGetInstanceProcAddr(void* instance, const char* name) { load_driver(); if (!handle) return NULL; void* (*f)(void*, const char*) = (void* (*)(void*, const char*))dlsym(handle, M_GET_INSTANCE_PROC); return f ? f(instance, name) : NULL; }
void* vk_icdGetInstanceProcAddr(void* instance, const char* name) { return vkGetInstanceProcAddr(instance, name); }
void* vkGetDeviceProcAddr(void* device, const char* name) { load_driver(); if (!handle) return NULL; void* (*f)(void*, const char*) = (void* (*)(void*, const char*))dlsym(handle, M_GET_DEVICE_PROC); return f ? f(device, name) : NULL; }
void* vk_icdGetPhysicalDeviceProcAddr(void* instance, const char* name) { return vkGetInstanceProcAddr(instance, name); }
int vkEnumerateInstanceExtensionProperties(const char* pLayerName, uint32_t* pPropertyCount, void* pProperties) { load_driver(); if (!handle) return -1; int (*f)(const char*, uint32_t*, void*) = (int (*)(const char*, uint32_t*, void*))dlsym(handle, M_ENUM_INST_EXT); return f ? f(pLayerName, pPropertyCount, pProperties) : -1; }
int vkEnumerateDeviceExtensionProperties(void* physicalDevice, const char* pLayerName, uint32_t* pPropertyCount, void* pProperties) { load_driver(); if (!handle) return -1; int (*f)(void*, const char*, uint32_t*, void*) = (int (*)(void*, const char*, uint32_t*, void*))dlsym(handle, M_ENUM_DEV_EXT); return f ? f(physicalDevice, pLayerName, pPropertyCount, pProperties) : -1; }
int vkCreateInstance(const void* pCreateInfo, const void* pAllocator, void* pInstance) { load_driver(); if (!handle) return -1; int (*f)(const void*, const void*, void*) = (int (*)(const void*, const void*, void*))dlsym(handle, M_CREATE_INST); return f ? f(pCreateInfo, pAllocator, pInstance) : -1; }
EOF

echo "compile"
clang -shared -fPIC "$BASE_DIR/wrapper.c" -o "$BASE_DIR/libvulkan_wrapper.so" -ldl

cat <<EOF > "$BASE_DIR/driver_icd.json"
{"file_format_version": "1.0.0", "ICD": {"library_path": "$BASE_DIR/libvulkan_wrapper.so", "api_version": "1.4.303"}}
EOF

echo "Vulkan Info"
env VK_ICD_FILENAMES="$BASE_DIR/driver_icd.json" \
    VK_LAYER_PATH="$LAYER_SRC" \
    VK_INSTANCE_LAYERS="VK_LAYER_window_system_integration" \
    LD_LIBRARY_PATH="$EXTRACT_DIR:/vendor/lib64:/system/lib64:$LD_LIBRARY_PATH" \
    vulkaninfo 2>/dev/null | grep -A 40 "Device Properties" | grep -iE "deviceName|driverVersion" | sed 's/^[[:space:]]*//'

echo "yeah"
