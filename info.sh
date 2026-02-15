#!/bin/bash

echo "Vulkan:"
 vulkaninfo 2>/dev/null | grep -m 1 "deviceName" | cut -d "=" -f2 | xargs

vulkaninfo 2>/dev/null | grep -m 1 "driverVersion" | cut -d "=" -f2 | xargs
