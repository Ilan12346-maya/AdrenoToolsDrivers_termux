import subprocess
import re
import sys
import os
import xml.etree.ElementTree as ET

def get_driver_symbols(driver_path):
    try:
        output = subprocess.check_output(['nm', '-D', driver_path]).decode('utf-8')
        return output.splitlines()
    except subprocess.CalledProcessError:
        return []
        
        

def parse_vk_xml(xml_path):
    tree = ET.parse(xml_path)
    root = tree.getroot()
    commands = {}
    for command in root.findall(".//command"):
        name_elem = command.find("proto/name")
        if name_elem is None: continue
        func_name = name_elem.text
        proto = command.find("proto")
        ret_type = "".join(proto.itertext()).replace(func_name, "").strip()
        params = []
        for param in command.findall("param"):
            pname_elem = param.find("name")
            if pname_elem is None: continue
            pname = pname_elem.text
            ptype = "".join(param.itertext()).replace(pname, "").strip()
            suffix = ""
            if ptype.endswith(']'):
                last_bracket = ptype.rfind('[')
                if last_bracket != -1:
                    suffix = ptype[last_bracket:]
                    ptype = ptype[:last_bracket].strip()
            params.append({'type': ptype, 'name': pname, 'suffix': suffix})
        commands[func_name] = {'ret': ret_type, 'params': params}
    return commands

def generate_proxy(driver_path, xml_path, template_path, output_path):
    raw_symbols = get_driver_symbols(driver_path)
    vk_commands = parse_vk_xml(xml_path)
    proxy_map = {}
    
    for vk_name in vk_commands.keys():
        pattern = f"_ZN11qglinternal{len(vk_name)}{vk_name}"
        for line in raw_symbols:
            if pattern in line:
                proxy_map[vk_name] = line.split()[2]
                break

    forward_decls = []
    typedefs = []
    compares = []
    impls = []

    for vk_name in sorted(proxy_map.keys()):
        cmd = vk_commands[vk_name]
        p_decl = ", ".join([f"{p['type']} {p['name']}{p['suffix']}" for p in cmd['params']])
        p_names = ", ".join([p['name'] for p in cmd['params']])
        
        forward_decls.append(f"VKAPI_ATTR {cmd['ret']} VKAPI_CALL {vk_name}({p_decl});")
        typedefs.append(f"typedef {cmd['ret']} (VKAPI_PTR *PFN_{vk_name}_REAL)({p_decl});")

        if len(vk_name) > 2:
            char_at_2 = vk_name[2]
            compares.append(f"    if (pName[2] == '{char_at_2}' && strcmp(pName, \"{vk_name}\") == 0) return (PFN_vkVoidFunction){vk_name};")
        else:
            compares.append(f"    if (strcmp(pName, \"{vk_name}\") == 0) return (PFN_vkVoidFunction){vk_name};")
        
        if vk_name not in ["vkGetInstanceProcAddr", "vkGetDeviceProcAddr"]:
            impl = [
                f"VKAPI_ATTR {cmd['ret']} VKAPI_CALL {vk_name}({p_decl}) {{",
                f"    static PFN_{vk_name}_REAL real_func = NULL;",
                f"    if (!real_func) {{ load_driver(); real_func = (PFN_{vk_name}_REAL)dlsym(handle, \"{proxy_map[vk_name]}\"); }}",
                f"    {'return ' if cmd['ret'] != 'void' else ''}real_func({p_names});",
                "}\n"
            ]
            impls.append("\n".join(impl))

    with open(template_path, 'r') as f:
        content = f.read()

    replacements = {
        "%%REAL_DRIVER_PATH%%": os.path.abspath(driver_path),
        "%%FORWARD_DECLARATIONS%%": "\n".join(forward_decls),
        "%%TYPEDEFS%%": "\n".join(typedefs),
        "%%PROC_ADDR_COMPARES%%": "\n".join(compares),
        "%%PROXY_IMPLEMENTATIONS%%": "\n".join(impls),
        "%%GIPA_SYMBOL%%": proxy_map.get("vkGetInstanceProcAddr", ""),
        "%%GDPA_SYMBOL%%": proxy_map.get("vkGetDeviceProcAddr", "")
    }

    for tag, val in replacements.items():
        content = content.replace(tag, val)

    with open(output_path, 'w') as f:
        f.write(content)


if __name__ == "__main__":
    generate_proxy(sys.argv[1], sys.argv[2], "vkproxy.c.template", sys.argv[3])
