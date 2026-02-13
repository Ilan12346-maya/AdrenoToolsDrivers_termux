# AdrenoToolsDrivers_termux

This project provides a workflow to use proprietary Adreno Vulkan driver blobs in termux

### convert.sh

```bash
pkg install unzip clang vulkan-tools
./convert.sh 805.zip
```

is creates an working directore ~/.driver 

1. Unpacks the provided driver ZIP file
2. Locates the primary Vulkan shared object
3. generates a wrapper to map standard Vulkan C symbols
4. Compile 
5. Generates the vulkan icd json
6. Print GPU Info hopefully with the selected Driver, haha

The driver blobs (like 805.zip) are from: https://github.com/K11MCH1/AdrenoToolsDrivers/releases/
The goal is to be able to use all drivers from there.

by now its hardcoded for 805.zip will make it Universal

Redmagic 8s pro, sd8gen2 adreno 740

![Comparison system driver vs newer 805 driver](screenshot.jpg)
*Comparison system driver vs newer 805 driver*
