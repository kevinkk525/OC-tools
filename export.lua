---config section
local version="0.9a"
local database_entries=81
local stack_exp_side=0
local half_exp_side=3
local single_exp_side=4
local chest_side=4
local shopHost
local redstone_side=5
------

--sides: down:0,up:1,south:3,east:5,

local serialization=require("serialization")
local component=require("component")
local exchange=require("money_exchange")
local s={} --functions
local b={} --backup
local ex_single={}
local ex_stack={}
local ex_half={}
local d={} --Itemlist! database structure: index={hash};hash={index,address,slot}
local database={} --reminder: table equality on pointer
local trade_table={} --structure {index=ident,ident={s/b{{amount,price},...},a:boolean}} --a=active trade
local trade_tavailable={} --available/activated trades --> use only during trade requests
local trans=component.dimensional_transceiver
local switch=""
local inv=component.inventory_controller
local chest_size=inv.getInventorySize(chest_side)

local registrationServer

local function regServer()
    local file=io.open("/lib/registrationServer","r")
    if file then
        registrationServer=file:read()
        file:close()
    else
        print("Please enter registrationServer address or quit")
        local inp=io.read()
        if inp=="quit" then os.exit()
        else 
            registrationServer=inp
            file=io.open("/lib/registrationServer","w")
            file:write(registrationServer)
            file:close()
        end
    end
end

local function initShopHost()
    if f.getStatus()=="added" then
        hooks.m.send({registrationServer,801,{"H398FKri0NieoZ094nI","ShopHost"},"getRegistration"})
        f.pause(initShopHost)
    elseif f.getStatus()=="standard" then
        shopHost=f.getData()[6][1]
    end
end

local function initSwitch()
    if f.getStatus()=="added" then
        hooks.m.send({registrationServer,801,{"H398FKri0NieoZ094nI","Switch"},"getRegistration"})
        f.pause(initSwitch)
    elseif f.getStatus()=="standard" then 
        switch=f.getData()[6][1]
    end
end

--local function changeSwitch2(data)
--    hooks.m.send({switch,801,data[1],data[2]})
--end

local function remote(target,func,data,timeout)
    timeout=timeout or 20
    local id=f.addTask(hooks.m.send,{target,func,data})
    f.moveTo(nil,id)
    f.execute()
    while true do
        os.sleep(0.1)
        timeout=timeout-0.1
        if f.listTasks()[id] then
            local ret=f.getData(6,id)
            f.remove(id)
            return ret
        end
        if timout<=0 then
            f.remove(id)
            return false,"timed out"
        end
    end
end