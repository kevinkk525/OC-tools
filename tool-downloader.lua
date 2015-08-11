---
local version="0.1b"
local author="kevinkk525"
---
local filesystem=require"filesystem"
local component=require"component",
local args = { ... }

if not component.isAvailable("internet") then
    print("You need a internet card, quit with any key")
    local inp=io.read()
    os.exit()
end
if not component.internet.isHttpEnabled() then
    print("Http is not enabled, please ask your admin! quit with any key")
    local inp=io.read()
    os.exit()
end

print("downloading GUI-API")
wget -f https://github.com/kevinkk525/OC-GUI-API/raw/master/shapes_default.lua /lib/shapes_default.lua
wget -f https://github.com/kevinkk525/OC-GUI-API/raw/master/GUI.lua /lib/GUI.lua
wget -f https://github.com/kevinkk525/OC-GUI-API/raw/master/term_mod.lua /lib/term_mod.lua
wget -f https://github.com/kevinkk525/OC-GUI-API/raw/master/tech_demo.lua /tech_demo.lua

print("\ndownloading request-handler and modem-handler")
wget -f https://github.com/kevinkk525/OC-tools/raw/master/modem-handler.lua /lib/modem_handler.lua
wget -f https://github.com/kevinkk525/OC-tools/raw/master/request-handler.lua /lib/req_handler.lua

print("downloading additional content")
for i=1,#args do
    local url="https://github.com/kevinkk525/OC-tools/raw/master/"..args[i]
    wget -f url "lib"..args[i]
end

print("download finished")