---config section
local version="0.9a"
local database_entries=81
local stack_exp_side=0
local half_exp_side=3
local single_exp_side=4
local chest_side=4
local shopHost
local redstone_side=5
local chest_dim_side=2
local transmission_timeout=20
local receiving_timeout=20
local hard_currency=true
------

--sides: down:0,up:1,south:3,east:5,
--items need to be in ME-network
--slot 1 of each database has to be empty for temporary operations
--no safety if database gets full

local serialization=require("serialization")
local component=require("component")
local exchange=require("money_exchange")
local s={} --functions
local b={} --backup
local me=component.me_controller
local ex_single={}
local ex_stack={}
local ex_half={}
local database={}  --fake database
local databases={} --components
local trade_table={} --structure: index=hash,hash={s/b={{amount,prize},...},name=label?} 
local trans=component.dimensional_transceiver
local switch=""
local inv=component.inventory_controller
local chest_size=inv.getInventorySize(chest_side)
local redstone=component.redstone
local deactivated={} --deactivated because missing in database

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

local function initDatabase()
    local tmp={}
    databases={}
    for a,b in component.list("database") do
        tmp[#tmp+1]=a
    end
    for i=1,#tmp do
        databases[i]=component.proxy(tmp[i])
    end  
    database.address=databases[1].address
end

local function log(str)
    print(str) --expand to real logging of errors
end

local function addBalance(user,balance)
    --depending on server use bank-API or own accounts...
    return f.remoteRequest(ShopHost,"addBalance",{user,balance})
end

local function initTradeTable() --structure: size=int,hash={s/b={{amount,prize},...},name=label?}
    --trade_table=f.remoteRequest(shopHost,"getTradeTable")  --deactivated for debugging
    deactivated={}
    deactivated.size=0
    for item in pairs(trade_table) do 
        if database.indexOf(item)<1 then
            trade_table[item]=nil
            deactivated[item]=1
            trade_table.size=trade_table.size-1
            deactivated.size=deactivated.size+1
            log("item not found in d:"..item)
        end
    end
    print("#"..trade_table.size.." entries in the trade_table") 
end

local function initExport()
    local tmp={}
    local item=me.getItemsInNetwork()[1]
    if not me.store(item,database.address,1) then
        log("error, could not store in database")
        os.exit()
    end
    for a,b in component.list("me_exportbus") do tmp[#tmp+1]=a end
    for i=1,#tmp do
        if component.proxy(tmp[i]).setConfiguration(single_exp_side,database.address,1) then
            ex_single=component.proxy(tmp[i])
        elseif component.proxy(tmp[i]).setConfiguration(half_exp_side,item.address,1) then
            ex_half=component.proxy(tmp[i])
        elseif component.proxy(tmp[i]).setConfiguration(stack_exp_side,item.address,1) then
            ex_stack=component.proxy(tmp[i])
        end
    end
    if not ex_single or not ex_half or not ex_stack then
        log("error, could not proxy export buses")
        os.exit()
    end
end

local function export_log(str)
    print(str) --fully implement
end
   
local function getItems()
    local ret={}
    trans.setIOMode(chest_dim_side,"push")
    os.sleep(1)
    trans.setIOMode(chest_dim_side,"disabled")
    for i=1,chest_size do
        local item=inv.getStackInSlot(chest_side,i)
        if item then
            local size=item.size
            local me_item=me.getItemsInNetwork(item)
            if me_item["n"]>1 then
                log("item not unique, label: "..item.label)
            elseif me_item["n"]==0 then
                log("item not in network, label: "..item.label)
            else
                me.store(item,database.address,1)
                local hash=database.computeHash(1)
                if not ret[hash] then
                    ret[hash]=item
                    ret[hash].size=size
                else
                    ret[hash].size=ret[hash].size+size
                end
            end 
        end
    end
    return ret
end

local function calculateBalance(items,price)
    local balance=0
    for item in pairs(items) do
        if not price(item) then
            log("item not found in price table, not possible for export")
        else
            balance=balance+(price[item][2]*(item.size/price[item][1]))
        end
    end
    return balance
end

local function sendItems()
    while true do
        if timeout==transmission_timeout then
            return false,"Error during transmission of items"
        end
        os.sleep(1)
        local exporting=false
        for chi=1,inv.getInventorySize(chest_side) do
            if inv.getStackInSlot(chest_side,chi) then
                exporting=true
                break
            end
        end
        if not exporting then
            break
        end
        timeout=timeout+1
    end
    return true
end

local function me_import()
    redstone.setOutput(redstone_side,15)
    while true do
        os.sleep(0.5)
        local running=false
        for i=1,chest_size do
            if inv.getStackInSlot(chest_side,i) then
                running=true
                break
            end
        end
        if not running then
            break
        end
    end
    redstone.setOutput(redstone_side,0)
end
    
------------------------------

function database.indexOf(ind)
    for i=1,#databases do
        if databases[i].indexOf(ind)>0 then
            database.address=databases[i].address
            return databases[i].indexOf(ind)
        end
    end
    return -1
end

function database.computeHash(slot)
    for i=1,#databases do
        if databases[i].address==database.address then
            return databases[i].computeHash(slot)
        end
    end
end

function database.setAdress(add)
    database.addres=add
end

function database.nextAddress()
    for i=1,#databases do
        if databases[i].address==database.address then
            i=i+1 
            if i>#databases then
                i=i-#databases
            end
            database.address=databases[i].address
            break
        end
    end
end

function database.get(slot)
    for i=1,#databases do
        if databases[i].address==database.address then
            return databases[i].get(slot)
        end
    end
end 

function database.clear(slot,address)
    address=addess or database.address
    for i=1,#databases do
        if databases[i].address==address then
            return databases[i].clear(slot)
        end
    end
end

------------------------------

   

function s.import(user,items)
    if not trans.setReceiveChannel("item",user,true) then
        return "wrong user, channel not available"
    end
    trans.setIOMode(chest_dim_side,"push")
    if not s.changeSwitch(user,"receive") then
        log("error during activating switch")
        trans.setIOMode(chest_dim_side,"disabled")
        trans.setReceiveChannel("item",user,false)
        return false,"switch error"
    end
    local slots=0
    local timeout=0
    local try=0
    while true do
        os.sleep(1)
        local slotn
        for i=1,chest_size do
            if not inv.getStackInSlot(chest_side,i) then
                slotn=i
                break
            end
        end
        if slotn~=slots then
            slots=slotn
            try=0
        else
            try=try+1
            if try==3 then
                break
            end
        end
        timeout=timeout+1
        if timeout>=receiving_timeout then
            break
        end
    end
    trans.setIOMode(chest_dim_side,"disabled")
    trans.setReceiveChannel("item",user,false)
    if not s.changeSwitch(user,"close") then
        log("error closing the switch")
        return false,"switch error"
    end
    local imported=getItems()
    for item in pairs(imported) do
        if not items[item] or not exhange.getMoney()[imported[item].label] or imported[item].size~=items[item].size then
            return false,"different items/amounts"
        end
    end
    if items.price and hard_currency then
        local imported_money=exchange.count(imported)
        if items.price>imported_money then
            return false,"not correct money amount"
        elseif items.price<imported_money then
            addBalance(user,imported_money-items.price)
        end
    end
    return true,imported
end

function s.importFrom(user,items) --items: hash={amount},price
    local money=false
    local success,imported=s.import(user,items)
    if not success then
        if not s.changeSwitch(user,"send") then
            log("error during try of sending back imported items")
        end
        trans.setIOMode(chest_dim_side,"pull")
        trans.setSendChannel(item,user,true)
        if not sendItems() then
            local balance=0
            for item in pairs(imported) do
                if items[item] then
                    balance=balance+(items[item][2]*(item.size/items[item][1]))
                end
            end
            if not addBalance(user,balance) then
                log("Error adding balance after faild import and sending back")
                me_import()
                trans.setIOMode(chest_dim_side,"disabled")
                trans.setSendChannel(item,user,false)
                return "error adding balance after failed import and sending back"
            end
        end
        trans.setIOMode(chest_dim_side,"disabled")
        trans.setSendChannel(item,user,false)
        return "sent back, wrong items"
    else
        return true,"imported successfully"
    end
end  
    

function s.changeSwitch(user,mode)
    if not f.remoteRequest(switch,mode,user) then
        log("error, could not change the switch")
        return false
    end
    return true
end

function s.exportTo(user,items) --add time in errorlog; items structure: hash={amount,price}
    local success,err=s.export(user,items)
    if success then
        return true,"sent"
    else
        local balance=calculateBalance(getItems(),items)
        if addBalance(user,amount) then
            export_log("Error during transmission, refunded "..balance)
            return "Error during transmission, refunded "..balance
        else
            export_log("Error during transmission and refunding of "..balance)
            return "Error during transmission and refunding, contact your shop owner immediately!"
        end
    end
end

function s.export(user,items) --currently host has to take care of stack amounts<chest_size
    if not trans.setSendChannel("item",user,true) then
            me_import()
        return "wrong user, channel not available"
    end
    for i in pairs(items) do
        local item=database.get(database.indexOf(i))
        local am,tm=math.modf(items[i][1]/item.maxSize)
        tm=items[i][1]-am*item.maxSize
        local hm,bm=math.modf(tm/(item.maxSize/2))
        local split=false --split export into more tasks, currently not supported
        bm=tm-hm*(item.maxSize/2)
        local slot=database.indexOf(i)
        local cm=ex_single.setConfiguration(single_exp_side,database.address,slot)
        local dm=ex_stack.setConfiguration(stack_exp_side,database.address,slot)
        local em=ex_stack.setConfiguration(half_exp_side,database.address,slot)        
        if not cm or not dm or not em then
            log("Configuration of exportbus failed!")
            return false,"configuration failed"
        else
            for j=1,am do
                if not ex_stack.exportIntoSlot(stack_exp_side,j) then
                    log("Error during stack-export")
                    return false,"Error during stack-export"
                end   
            end
            local j=0
            local offseth=1
            for i=1,hm do
                j=j+1
                if j>2 then --because 2 half-stacks have to be exported to fill one stack
                    j=1
                    offseth=offseth+1
                end
                if not ex_half.exportIntoSlot(half_exp_side,am+offseth) then
                    log("Error during half-export")
                    return false,"Error during half-export"
                end
            end            
            local j=0
            local offset=1
            for i=1,bm do 
                j=j+1
                if j>item.maxSize then
                    j=1
                    offset=offset+1
                end
                if not ex_single.exportIntoSlot(single_exp_side,am+offset+offseth) then
                    log("Error during single-export")
                    return false,"Error during single-export"
                end
            end
        end
    end
    --recheck exported amount
    local exported=0
    for ch=1,chest_size do
        if inv.getStackInSlot(chest_side,ch) then
            exported=exported+inv.getStackInSlot(chest_side,ch).size
        end
    end
    for item in pairs(items) do
        exported=exported-item[1]
    end
    if exported~=0 then
        log("Not every item was exported, exported-target="..exported)
        return false,"error during recheck"
    end
    if not s.changeSwitch(user,"send") then
        return false,"error activating switch"
    end
    trans.setIOMode(chest_dim_side,"pull")
    local timeout=0
    if not sendItems() then
        trans.setSendChannel("item",user,false)
        trans.setIOMode(chest_dim_side,"disabled")
        me_import()
        return false,"error during transmission"
    end
    if not s.changeSwitch(user,"close") then
        trans.setSendChannel("item",user,false)
        trans.setIOMode(chest_dim_side,"disabled")
        me_import()
        return false,"Error closing the switch"
    end
    trans.setSendChannel("item",user,false)
    trans.setIOMode(chest_dim_side,"disabled")
    return true,"items exported"
end

function s.addItem(items) --structure: hash={nbt,{s/b={{amount,prize},...},name=label?}}
    local rej={} --rejected because not in database and me
    for item in pairs(items) do
        if trade_table[item] then
            trade_table[item]=items[item][2]
        else
            items[item][1].size=nil
            local me_item=me.getItemsInNetwork(items[item][1])
            if me_item and me_item["n"]==1 then
                while database.get(database_entries) do
                    database.nextAddress()
                end
                if not database.get(1) then
                    me.store(me_item,database.address)
                end
                me.store(me_item,database.address)
                if database.indexOf(item)>0 then
                    trade_table[item]=items[item][2]
                    trade_table.size=trade_table.size+1
                else
                    rej[#rej+1]=item
                end
            end
        end
    end
    deactivated=rej
    return true
end

function s.removeItem(items)
    for item in pairs(items) do
        if trade_table[item] then
            trade_table[item]=nil
            trade_table.size=trade_table.size-1
            database.clear(database.indexOf(item))
        end
    end
    return true
end

function s.updateTradeTable(tab)
    local rej={}
    for item in pairs(tab) do
        if trade_table[item] then
            trade_table[item]=tab[item]
        else
            rej[#rej+1]=item
        end
    end
    return true
end

function s.initialize(handler)
    regServer()
    f=handler
    b={}
    ex_single={}
    ex_stack={}
    ex_half={}
    d={}
    if hooks["backup"]==nil then
        b=f.addHook("backup","backup")
    end
    switch=f.remoteRequest(registrationServer,"getRegistration",{"H398FKri0NieoZ094nI","Switch"})[1]
    if not switch then print("error, could not get a switch") end
    shopHost=f.remoteRequest(registrationServer,"getRegistration",{"H398FKri0NieoZ094nI","ShopHost"})[1]
    if not shopHost then print("error, could not get a shopHost") end
    print(f.remoteRequest(registrationServer,"registerDevice",{"H398FKri0NieoZ094nI","ShopExport"}))
    initDatabase()
    initExport()
    initTradeTable()
    f.registerFunction(s.updateTradeTable,"updateTradeTable")
    f.registerFunction(s.exportTo,"exportTo")
    f.registerFunction(s.importFrom,"importFrom")
    f.registerFunction(s.addItem,"addItem") 
    f.registerFunction(s.removeItem,"removeItem")
    f.registerFunction(s.getDeactivated,"getDeactivated")
    f.registerFunction(s.resetDeactivated,"resetDeactivated")
    f.registerFunction(s.getTradeTable,"getTradeTable")
end

function getDeactivated() return deactivated end

function resetDeactivated() deactivated={} end

function getTradeTable() return trade_table end

function s.singleExport() return ex_single end  --only debug
function s.halfExport() return ex_half end
function s.stackExport() return ex_stack end

return s