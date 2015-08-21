---config section
local version="0.9a"
local database_entries=81
local stack_exp_side=0
local half_exp_side=3
local single_exp_side=4
local eighth_exp_side=1
local chest_side=4
local shopHost
local redstone_side=5
local chest_dim_side=2
local transmission_timeout=4
local receiving_timeout=4
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
    trade_table={}
    trade_table.size=0
    --trade_table=f.remoteRequest(shopHost,"getTradeTable")  --deactivated for debugging
    deactivated={}
    deactivated.size=0
    for item in pairs(trade_table) do 
        if item~="size" and database.indexOf(item)<1 then
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
    for a,b in component.list("me_exportbus") do tmp[#tmp+1]=a end
    for i=1,#tmp do
        if component.proxy(tmp[i]).setConfiguration(single_exp_side,database.address,2) then
            ex_single=component.proxy(tmp[i])
        elseif component.proxy(tmp[i]).setConfiguration(half_exp_side,database.address,2) then
            ex_half=component.proxy(tmp[i])
        elseif component.proxy(tmp[i]).setConfiguration(stack_exp_side,database.address,2) then
            ex_stack=component.proxy(tmp[i])
        elseif component.proxy(tmp[i]).setConfiguration(eighth_exp_side,database.address,2) then
            ex_eighth=component.proxy(tmp[i])
        end
    end
    if not ex_single or not ex_half or not ex_stack then
        log("error, could not proxy export buses")
        os.exit()
    end
end

local function initStoreFunction()
    local me_store=me.store
    me.store=function(item,slot,address)
        slot=slot or -1
        if slot>1 and not address then 
            while true do 
                if database.get(database_entries) then
                    database.nextAddress()
                else
                    break
                end
            end
        elseif slot==1 and not address then
            database.clear(1)
        end
        if not database.get(1) and not address then
            me_store(item,database.address,1)
        end
        if not address and slot~=1 and slot~=-1 then
            me_store(item,database.address,slot)
            database.clear(1)
        elseif address then
            database.setAddress(address)
            database.clear(slot)
            me_store(item,database.address,slot)
        end
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
    local items=me.getItemsInNetwork()
    ret.size=items.n
    for i=1,#items do
        me.store(items[i],1)
        local hash=database.computeHash(1)
        database.clear(1)
        if database.indexOf(hash)<1 then
            local add=database.address
            me.store(items[i],1)
            me.store(items[i])
            database.clear(1,add)
        end
        ret[hash]=items[i]
    end
    items=nil
    return ret
end

local function calculateBalance(items,price)
    local balance=0
    for item in pairs(items) do
        if item~="size" and not price[item] then
            log("item not found in price table, not possible for export")
        elseif item~="size" then
            local percent=items[item].size/price[item].size
            if percent>1 then percent=1 end
            balance=balance+(price[item][1]*percent)
        end
    end
    balance=math.floor(balance*100+0.5)/100
    return balance
end

local function receiveItems(timeout,size)
    size=size or 0
    timeout=timeout or transmission_timeout
    local sleep=0.1
    local count=0
    local change=0
    while true do
        if count>=timeout then
            return false,"Error during transmission of items"
        end
        os.sleep(sleep)
        local new=0
        local items=me.getItemsInNetwork()
        for i=1,items["n"] do
            new=new+items[i].size
        end
        if new==size then
            break
        elseif change==new then
            count=count+sleep+0.1 --calculation offset
        else
            change=new
            count=0
        end
    end
    return true
end

local function sendItems(timeout)
    receiveItems(timeout,0)
end

local function me_import(timeout)
    timeout=timeout or 4
    trans.setSendChannel("item","AE_Import",true)
    redstone.setOutput(redstone_side,15)
    local ret=false
    if sendItems(timeout) then
        ret=true
    end
    redstone.setOutput(redstone_side,0)
    trans.setSendChannel("item","AE_Import",false)
    return ret
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

function database.setAddress(add)
    database.address=add
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

function s.changeSwitch(user,mode)
    if not f.remoteRequest(switch,mode,user) then
        log("error, could not change the switch for user "..user)
        return false
    end
    return true
end

function s.import(user,items)
    if not trans.setReceiveChannel("item",user,true) then
        return false,"wrong user, channel not available"
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
    local part=1
    local amount=0
    for i in pairs(items) do
        if i~="size" then
            amount=amount+items[i].size
        end
    end
    local err=receiveItems(7,amount)
    trans.setIOMode(chest_dim_side,"disabled")
    trans.setReceiveChannel("item",user,false)
    if not err then
        log("timeout during import")
    end
    if not s.changeSwitch(user,"close") then
        log("error closing the switch")
        return false,"switch error"
    end
    local imported=getItems()
    for item in pairs(imported) do
        if item~="size" then
            if not (items[item] or exchange.getMoney()[imported[item].label]) or imported[item].size~=items[item].size then
                return false,"different items/amounts"
            end
        end
    end
    if items[1] and hard_currency then
        local imported_money=exchange.count(imported)
        if items.price>imported_money then
            return false,"not correct money amount"
        elseif items.price<imported_money then
            if not addBalance(user,imported_money-items.price) then
                log("error during refunding of overpaid export")
            end
        end
    end
    return true,imported
end

function s.importFrom(user,items) --items: hash={[size]=amount,[1]=price}
    local money=false
    local success,imported=s.import(user,items)
    if not success then
        if not s.changeSwitch(user,"send") then
            log("error during try of sending back imported items")
        end
        trans.setIOMode(chest_dim_side,"push")
        trans.setReceiveChannel("item",user,true)
        if not receiveItems() then
            local balance=calculateBalance(getItems(),items)
            if not addBalance(user,balance) then
                log("Error adding balance after faild import and failed sending back")
                me_import()
                trans.setIOMode(chest_dim_side,"disabled")
                trans.setReceiveChannel("item",user,false)
                return "error adding balance after failed import and failed sending back"
            end
        end
        trans.setIOMode(chest_dim_side,"disabled")
        trans.setSendChannel("item",user,false)
        return "sent back, wrong items"
    else
        return true,"imported successfully"
    end
end

function s.exportTo(user,items) --add time in errorlog; items structure: hash={size=amount,[1]=price}
    local success,err=s.export(user,items),
    print(err)
    if success then
        return true,"sent"
    else
        local balance=calculateBalance(getItems(),items)
        if addBalance(user,amount) then
            trans.setSendChannel("item",user,false)
            trans.setIOMode(chest_dim_side,"disabled")
            me_import()
            export_log("Error during transmission, refunded "..balance)
            return "Error during transmission, refunded "..balance
        else
            trans.setSendChannel("item",user,false)
            trans.setIOMode(chest_dim_side,"disabled")
            me_import()
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
        local item=database.indexOf(i)
        if item<1 then
            return "item not found in database"
        else
            item=database.get(item)
        end        
        local am,tm=math.modf(items[i].size/item.maxSize)
        tm=items[i].size-am*item.maxSize
        local hm,bm=math.modf(tm/(item.maxSize/2))
        bm=tm-hm*(item.maxSize/2)
        local gm,jm=math.modf(bm/(item.maxSize/8))
        bm=bm-gm*(item.maxSize/8)
        local slot=database.indexOf(i)
        local cm=ex_single.setConfiguration(single_exp_side,database.address,slot)
        local dm=ex_stack.setConfiguration(stack_exp_side,database.address,slot)
        local em=ex_half.setConfiguration(half_exp_side,database.address,slot)  
        local fm=ex_eighth.setConfiguration(eighth_exp_side,database.address,slot)
        if not cm or not dm or not em or not fm then
            log("Configuration of exportbus failed!"..tostring(cm)..tostring(dm)..tostring(em))
            return false,"configuration failed"
        else
            for j=1,am do
                if not ex_stack.exportIntoSlot(stack_exp_side,1) then
                    log("Error during stack-export")
                    return false,"Error during stack-export"
                end   
            end
            for i=1,hm do
                if not ex_half.exportIntoSlot(half_exp_side,1) then
                    log("Error during half-export")
                    return false,"Error during half-export"
                end
            end   
            for i=1,gm do
                if not ex_eighth.exportIntoSlot(eighth_exp_side,1) then
                    log("Error during eighth-export")
                    return false,"Error during eighth-export"
                end
            end
            for i=1,bm do
                if not ex_single.exportIntoSlot(single_exp_side,1) then
                    log("Error during single-export")
                    return false,"Error during single-export"
                end
            end
        end
    end
    local exported=0
    local exported_i=me.getItemsInNetwork()
    for i=1,exported_i["n"] do
        exported=exported+exported_i[i].size
    end
    for item in pairs(items) do
        exported=exported-items[item].size
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

function s.addItem(items) --structure: hash={[1]=nbt,{s/b={{amount,prize},...},name=label?}}  --how to add items? into database? 2nd ME?
    local rej={} --rejected because not in database --and me
    for item in pairs(items) do
        if trade_table[item] and item~="size" then
            trade_table[item]=items[item]
        elseif item~="size" then
            if database.indexOf(item)>0 then
                trade_table[item]=items[item]
                trade_table.size=trade_table.size+1
            else
                rej[#rej+1]=item
            end
        end
    end
    deactivated=rej
    return rej
end

function s.removeItem(items)
    for item in pairs(items) do
        if trade_table[item] then
            trade_table[item]=nil
            trade_table.size=trade_table.size-1
            --database.clear(database.indexOf(item)) --leave all items in database
        end
    end
    return true
end

function s.updateTradeTable(tab)
    local rej={}
    for item in pairs(tab) do
        if trade_table[item] and item~="size" then
            trade_table[item]=tab[item]
        elseif item~="size" then
            rej[#rej+1]=item
        end
    end
    return rej
end

function s.initialize(handler)
    regServer()
    f=handler
    b={}
    ex_single={}
    ex_stack={}
    ex_half={}
    ex_eighth={}
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
    initTradeTable()
    initExport()
    initStoreFunction()
    trans.setIOMode(chest_dim_side,"disabled")
    trans.setSendChannel("item","AE_Import",false)
    f.registerFunction(s.updateTradeTable,"updateTradeTable")
    f.registerFunction(s.exportTo,"exportTo")
    f.registerFunction(s.importFrom,"importFrom")
    f.registerFunction(s.addItem,"addItem") 
    f.registerFunction(s.removeItem,"removeItem")
    f.registerFunction(s.getDeactivated,"getDeactivated")
    f.registerFunction(s.resetDeactivated,"resetDeactivated")
    f.registerFunction(s.getTradeTable,"getTradeTable")
end

function s.getDeactivated() return deactivated end

function s.resetDeactivated() deactivated={} end

function s.getTradeTable() return trade_table end

function s.getDatabase() return database end

function s.singleExport() return ex_single end  --only debug
function s.halfExport() return ex_half end
function s.stackExport() return ex_stack end
function s.eighthExport() return ex_eighth end

return s