------------------------------
local version="0.9.6b"
------------------------------
local serialization=require("serialization")
local component=require("component")
local computer=require("computer")
local io=require("io")
local s={} --functions
local files={}
local path={}
local f

--add browse backup, load backup & send backup, return backup_size, split backups
--add automatic raid detection

local function open(filename)
    for i=1,#path,1 do
        local insert=false
        files[i]=io.open(path[i].."/"..filename,"r")
        if files[i]==nil then
            insert=true
        else
            files[i]:close()
        end
        if insert==true then
            files[i]=io.open(path[i].."/"..filename,"a")
            files[i]:write("{")
        else
            files[i]=io.open(path[i].."/"..filename,"a")
        end
    end
end

local function close()
    for i=1,#path,1 do
        files[i]:close()
    end
end



function s.initialize(handler)
    local file=io.open("/backup_path","r") 
    if file==nil then
        file=io.open("/backup_path","w")
        while true do
            print("Enter storage location #"..tostring(#path+1)..", default for default, quit for quit")
            io.flush()
            local tmp2=io.read()
            if tmp2=="default" or "" then
                path[#path+1]="/"
            elseif tmp2=="quit" then
                break
            else 
                path[#path+1]=tmp2
            end
        end
        if #path>=1 then 
            file:write(serialization.serialize(path))
        end
        file:close()
    else
        path=serialization.unserialize(file:read())
        file:close()
    end
    
    f=handler
    f.registerFunction(s.backup,"backup")
end


function s.backup(filename,data)
    open(filename)
    for i=1,#files,1 do
        files[i]:write(data)
    end
    close()
end

function s.stop()
    for i=1,#files,1 do
        if files[i]~=nil then
            files[i]:close()
        end
    end
end


return s