---
local version="0.1"
local author="kevinkk525"
---

local component=require"component"
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

print("downloading content")
local only=false
for i=1,#args do
    local path="/lib/"
    if args[i]=="git.lua" then
        path="/"
    end
    local url="https://github.com/kevinkk525/OC-tools/raw/master/"..args[i]
    if args[i]=="-o" then
        only=true
    else
        local command="wget -f "..url.." "..path..args[i]
        os.execute(command)
    end    
end
if not only then
    print("\ndownloading GUI-API")
    os.execute("wget -f https://github.com/kevinkk525/OC-GUI-API/raw/master/shapes_default.lua /lib/shapes_default.lua")
    os.execute("wget -f https://github.com/kevinkk525/OC-GUI-API/raw/master/GUI.lua /lib/GUI.lua")
    os.execute("wget -f https://github.com/kevinkk525/OC-GUI-API/raw/master/term_mod.lua /lib/term_mod.lua")
    os.execute("wget -f https://github.com/kevinkk525/OC-GUI-API/raw/master/tech_demo.lua /tech_demo.lua")

    print("\ndownloading request-handler and modem-handler")
    os.execute("wget -f https://github.com/kevinkk525/OC-tools/raw/master/modem-handler.lua /lib/modem_handler.lua")
    os.execute("wget -f https://github.com/kevinkk525/OC-tools/raw/master/request-handler.lua /lib/req_handler.lua")
end

print("download finished")