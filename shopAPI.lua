---config section
local version="0.9a"
local database_entries=81
local stack_exp_side=0
local half_exp_side=1
local single_exp_side=4
local chest_side=2
local registrationServer="5ab38756-65fc-426a-a6f8-60100b3b9d34"
local shopHost
local transmitting_timeout=20
local redstone_side=5
--- 
--sides: down:0,up:1,south:3,east:5

local serialization=require("serialization")
local component=require("component")
local fs=require("filesystem")
local exchange=require("money_exchange")
local s={} --functions
local b={}
local ex_single={}
local ex_stack={}
local ex_half={}
local d={} --Itemlist! database structure: index={ident};ident={index,address,slot}
local database={} --reminder: table equality on pointer
local trade_table={} --structure {index=ident,ident={s/b{{amount,price},...},a:boolean}} --a=active trade
local trade_tavailable={} --available/activated trades --> use only during trade requests
local trans=component.dimensional_transceiver
local switch=""
local inv=component.inventory_controller
local chest_size=inv.getInventorySize(chest_side)

--add price-calculation --> if no single price is given ensure 0.1 is the lowest
--database.indexOf? hash-table useful?
--compare to price table
--check available amount (acc to table?)
--maybe add maximum sale/buy size? per player? per day?
--move file-path to config-section & use functions to save/load
--use dynamic additional events on buy/sell functions like signals

local function getIdent(t)
    ret=""
    for a,b in pairs(t) do 
        if a~="size" then
            ret=ret..a.."="..tostring(b)..","
        end
    end
    ret=ret:sub(1,ret:len()-1)
    return ret
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

local function changeSwitch(user,mode) --rewrite this function to use normal API calls
    hooks.m.send({switch,801,user,mode})
    f.getTasks()[f.getID()]={"temp"}
    local wait=true
    local tid=0
    local timeout=0
    while wait do
        os.sleep(0.1)
        for i=1,#f.getTasks() do
            if f.getTasks()[i].id==f.getID() and f.getTasks()[i].status=="ready" then
                tid=i
                wait=false
                break
            end
        end
        timeout=timeout+1
        if timeout==transmitting_timeout then
            return false
        end
    end
    local ret=f.getTasks()[tid].data[6]
    if ret=="sending" or ret=="receiving" or ret=="closed" then --quick and dirty
        timeout=true
    else
        timeout=false
    end
    f.remove(tid)
    f.getTasks()[tid]=nil
    return timeout
end

local function addBalance(user,balance) --rewrite API calls
    hooks.m.send({ShopHost,801,{user,balance},"addBalance"})
    f.getTasks()[f.getID()]={"temp"} --what is that??
    local wait=true
    local tid=0
    local timeout=0
    while wait do
        os.sleep(0.1)
        for i=1,#f.getTasks() do
            if f.getTasks()[i].id==f.getID() and f.getTasks()[i].status=="ready" then
                tid=i
                wait=false
                break
            end
        end
        timeout=timeout+1
        if timeout==transmitting_timeout then
            return false
        end
    end
    f.remove(tid)
    f.getTasks()[tid]=nil
    return f.getTasks()[tid].data[6] --what's that?
end

local function initTradeTable() --structure index,"label,name,hasTag,damage"={s/b{{amount,prize},...},a:boolean}
    local file=io.open("/trade_table","r")
    local tmp={}
    if file~=nil then
        tmp=file:read("*all")
        file:close()
        tmp=serialization.unserialize(tmp)
        if tmp==nil then
            tmp={}
        end
    end
    trade_table=tmp
    tmp=nil
    for i=1,#d do
        local tmp=getIdent(d)
        if trade_table[tmp]==nil then
            trade_table[tmp]={}
            trade_table[#trade_table+1]=tmp
        else 
            if trade_table[tmp].s~=nil or trade_table[tmp].b~=nil then
                if trade_table[tmp].a~=nil then
                    if trade_table[tmp].a==true then
                        trade_tavailable[tmp]=trade_table[tmp]
                        trade_tavailable[#trade_tavailable+1]=tmp
                    end
                end
            end
        end
        tmp=nil
    end
    local file=io.open("/trade_table","w")
    file:write(serialization.serialize(trade_table))
    file:close()
end

local function registerShopMaster()
    if f.getStatus()=="added" then --[1]to,[2]port,[3]message,[4]com
        hooks.m.send({registrationServer,801,{"H398FKri0NieoZ094nI","ShopProcessor"},"registerDevice"})
        f.pause(registerShopMaster)
    elseif f.getStatus()=="standard" then 
        s.error(f.getData()[6]) --change this...
    end
end

local function initDatabase() --index={ident};ident={index,address,slot}
    local tmp={} 
    for a,b in component.list("database") do tmp[#tmp+1]=a end
    s.error("found "..#tmp.." databases") --info
    for i=1,#tmp do 
        database[i]=component.proxy(tmp[i]) 
        database[tmp[i]]=i 
    end
    for i=1,#database do 
        for j=1,database_entries do
            local get=database[i].get(j)
            if get~=nil then
                d[#d+1]=getIdent(get)
                d[getIdent(d[#d])]={["index"]=#d,["address"]=database[i].address,["slot"]=j}
            end
            get=nil
        end
    end
    tmp=nil
end

local function initExport()
    local tmp={}
    s.error(serialization.serialize(d)) --debug info
    for a,b in component.list("me_exportbus") do tmp[#tmp+1]=a end
    if #d>0 then
        for i=1,#tmp do
            local item=d[getIdent(d[1])]
            if component.proxy(tmp[i]).setConfiguration(single_exp_side,item.address,item.slot)==true then
                ex_single=component.proxy(tmp[i])
            elseif component.proxy(tmp[i]).setConfiguration(half_exp_side,item.address,item.slot)==true then
                ex_half=component.proxy(tmp[i])
            elseif component.proxy(tmp[i]).setConfiguration(stack_exp_side,item.address,item.slot)==true then
                ex_stack=component.proxy(tmp[i])
            end
            item=nil
        end
    else
        s.error("no database entry")
    end
    tmp=nil
end

-----------------------------------
function s.initialize(handler)
    f=handler
    b={}
    ex_single={}
    ex_stack={}
    ex_half={}
    --add clear in_use?
    d={}
    database={}
    trade_table={}
    trade_tavailable={}
    if hooks["backup"]==nil then
        b=f.addHook("backup","backup")
    end
    --add component-check
    f.addTask(registerShopMaster)
    f.addTask(initSwitch)
    f.addTask(initShopHost)
    initDatabase()
    initExport()
    initTradeTable()
    f.registerFunction(s.activateItem,"activateItem")
    f.registerFunction(s.deactivateItem,"deactivateItem")
    f.registerFunction(s.searchItem,"searchItem")
    f.registerFunction(s.listAvailableTrades,"listAvailableTrades")
    f.registerFunction(s.listItems,"listItems")
    f.registerFunction(s.listTradeTable,"listTradeTable")
    f.registerFunction(s.exportTo,"exportTo")
    f.registerFunction(s.importFrom,"importFrom")
    f.registerFunction(s.addItem,"addItem") --structure: {ident="label,name",s/b{{amount,price},...},a:boolean}
end

--use the same chest for both operations 
function s.export(amount,itemid,user) --check if item used correctly
    if type(amount)~="table" then
        amount={amount}
    end
    if type(itemid)~="table" then
        itemid={itemid}
    end
    --check for empty chest/not in use, before calling this function?
    if not trans.setSendChannel("item",user,true) then
        return "wrong user, channel not available"
    end
    for it=1,#itemid do --export for every item in list
        local item=d[itemid[it]]
        local am,tm=math.modf(amount[it]/d[item.index].maxSize)
        tm=amount[it]-am*d[item.index].maxSize
        local hm,bm=math.modf(tm/(d[item.index].maxSize/2))
        local split=false --split export into more tasks
        bm=tm-hm*(d[item.index].maxSize/2)
        local cm=ex_single.setConfiguration(single_exp_side,item.address,item.slot)
        local dm=ex_stack.setConfiguration(stack_exp_side,item.address,item.slot)
        local em=ex_stack.setConfiguration(half_exp_side,item.address,item.slot)
        if cm==false or dm==false or em==false then
            s.error("Configuration of Exportbus failed!")
        else --sum this up
            for i=1,am do
                if i>chest_size then
                    split=true
                    amount[it]=amount[it]-am*d[item.index].maxSize
                    break
                end
                if not ex_stack.exportIntoSlot(stack_exp_side,i) then
                    s.error("Error during stack-export")
                    return false,"Error during stack-export",it
                end
            end
            local j=0
            local offseth=1
            for i=1,hm do
                j=j+1
                if j>2 then
                    j=1
                    offseth=offseth+1
                end
                if offseth+am+1>chest_size then
                    split=true
                    amount[it]=amount[it]-am*d[item.index].maxSize-i*d[item.index].maxSize/2
                    break
                end
                if not ex_half.exportIntoSlot(half_exp_side,am+offseth) then
                    s.error("Error during half-export")
                    return false,"Error during half-export",it
                end
            end
            
            local j=0
            local offset=1

            for i=1,bm do 
                j=j+1
                if j>d[item.index].maxSize then
                    j=1
                    offset=offset+1
                end
                if offset+am+offseth>chest_size then
                    split=true
                    amount[it]=amount[it]-am*d[item.index].maxSize-i+1
                    break
                end
                if not ex_single.exportIntoSlot(single_exp_side,am+offset+offseth) then
                    s.error("Error during single-export")
                    return false,"Error during single-export",it
                end
            end
            j=nil offset=nil offseth=nil
        end
        if split==true then
            --add split method
            --send items
            --add task sending remaining amount
            print("splitting export") --debug
        end
        local exportedItems=0
        for ch=1,inv.getInventorySize(chest_side) do
            exportedItems=exportedItems+inv.getStackInSlot(chest_side,ch).size
        end
        if exportedItems~=amount[it] then
            return false,"Error during export of "..itemid[it],it
        end
        --actually here we would need a real process pause to let req_handler work --> temporary workaround/quick and dirty
        if not ChangeSwitch(user,"send") then
            return false,"Error activating the switch",it
        end
        trans.setIOMode(5,"push")
        local exporting=true
        local timeout=0
        while exporting do
            if timeout=transmitting_timeout then
                return false,"Error during transmission",it
            end
            os.sleep(1)
            for chi=1,inv.getInventorySize(chest_side) do
                if inv.getStackInSlot(chest_side,chi) then
                    break
                end
                exporting=false
            end
            timeout=timeout+1
        end
        if not ChangeSwitch(user,"close") then
            return false,"Error closing switch",it+1
        end
        trans.setIOMode(5,"disabled")
    end
    item=nil am=nil bm=nil cm=nil dm=nil em=nil hm=nil tm=nil amount=nil itemid=nil
    trans.setSendChannel("item",user,false)
    return true,"Done"
end

function s.exportTo(amount,itemid,user,prices) --add timestamp in errorlog
    local bool,err,it=s.export(amount,itemid,user)
    if bool then 
        return "Done"
    else
        local balance=0
        --if err=="Error during transmission" then
            --calculate remaining items left --> for now remaining items are lost..
        --end 
        local file=io.open("/export.log","a")
        file:write(err.."\n")
        file:close()
        for i=it+1,#itemid do
            balance=balance+prices[i]
        end
        local bal=addBalance(user,balance)
        if not bal then
            local file=io.open("/export.log","a")
            file:write(user..": addBalance failed, balance="..balance.."\n")
            file:close()
            return "Error during transmission! "..balance.." for not transferred items could not be added to your accout. This has been logged. Please contact kevinkk525!"
        end
        return "Error during transmission! "..balance.." has been added to your account."
    end
end

function s.importFrom(user,amount,itemid,prices) --prices/itemid should have general "money" section naming money to import
    local money=false
    local bool,amounti,itemidi=s.import(user)
    if not bool then
        --send all items back, if any in there
        print("should send items back")
        return amounti
    end
    local money_table=exchange.getMoney()
    for i=1,#itemid do  --check amount
        if itemidi[itemid[i]] then --also check for money_table
            ---
        elseif itemidi[i]=="money" then
            --empty: is done after item check
            money=i
        elseif money_table[itemidi[i]]
        else
            print("should send items back")
            --send everything back or add items to balance? --> send items back, no storage for damaged hoes...
            --send back --> local function
        end
    end
    if not money then
        local file=io.open("/import.log","a")
        file:write("no price from ShopHost, bug\n")
        file:close()
        return "Error during import, ShopHost failed to send price to importEnginge. Error has been logged"
    else
        local i=money
        local money=exchange.count(itemid)
        if money~=prices[i] then
            if money>prices[i] then
                addBalance(user,money-prices[i])
            else
                --send back --> local function
                print("should send back")
                return "Error during import, not enough money!"
            end
            --everything should be ok here
            --activate redstone
            local importing=true
            while importing do
                os.sleep(1)
                for j=1,chest_size do
                    local tmp=inv.getStackInSlot(chest_side,j)
                    if tmp then
                        break
                    end
                    if j==chest_size then
                        importing=false
                    end
                end
            end
            return "Done"
        end
    end
    return "Should ever end here.."
end

function s.import(user) --ident calculation has to be done here already, .size to amounti[i]
    if not ChangeSwitch(user,"receive") then
        return false,"Error activating the switch",it
    end
    trans.setIOMode(5,"pull")
    local amount={}
    local itemid={}
    for i=1,chest_size do
        local it=inv.getStackInSlot(chest_side,i)
        if it then
            local ident=getIdent(it)
            if itemid[ident]==nil then
                itemid[ident]=#itemid+1
                itemid[#itemid+1]=ident
                amount[#amount+1]=it.size
            else
                amount[itemid[ident]]=amount[itemid[ident]]+it.size
            end
        end
    end
    if not ChangeSwitch(user,"close") then
        return false,"Error activating the switch",it
    end
    trans.setIOMode(5,"disabled")
    return true,amount,itemid
end
    
            
function s.resetTradeTable()
    local file=io.open("/trade_table","w")
    file:write("")
    file:close()
    local trade_table={} 
    local trade_tavailable={} 
    initTradeTable()
end

function s.addItem(tab) --structure: {ident="label,name",s/b{{amount,price},...},a:boolean}
    --will override existing entry, wrong data can cause problems.. --> add data check
    if trade_table[tab.ident]==nil then
        trade_table[#trade_table+1]=tab.ident
    end
    trade_table[tab.ident]={}
    trade_table[tab.ident].s=tab.s
    trade_table[tab.ident].b=tab.b
    trade_table[tab.ident].a=tab.a
    if tab.a==true then
        if d[tab.ident]~=nil then
            trade_tavailable[tab.ident]=trade_table[tab.ident]
            trade_tavailable[#trade_tavailable+1]=tab.ident
        else
            trade_table[tab.ident].a=false
            s.error("Could not activate Item "..tmp.ident.label.." because not in database!")
        end
    end
    tab=nil
    local file=io.open("/trade_table","w")
    file:write(serialization.serialize(trade_table))
    file:close()
end

function s.searchItem(item)
    local tmp={}
    local tmp2={}
    for i=1,#d do
        if d[i].name==item then
            tmp[#tmp+1]=i
        end
        if d[i].label==item then
            tmp[#tmp+1]=i
        end
    end
    if #tmp==1 then
        return d[tmp[1]]
    elseif #tmp2==1 then
        return d[tmp2[1]]
    elseif #tmp==0 and #tmp2==0 then
        return "No entry"
    else 
        return "No exclusive Entry"
    end
end

function s.removeItem(tab)
    --add check for ongoing trades --> would screw this up
    if in_use[tab.ident]~=true then
        trade_table[tab.ident]=nil
        for i=1,#trade_table do
            if trade_table[i]==tab.ident then
                table.remove(trade_table,i)
                break
            end
        end
    else
        f.addTask(s.removeItem,tab)
    end
    trade_tavailable[tab.ident]=nil
    for i=1,#trade_tavailable do
        if trade_tavailable[i]==tab.ident then
            table.remove(trade_tavailable,i)
            break
        end
    end
end

function s.activateItem(ident,activate)
    if activate==nil then
        activate=true
    end
    if trade_table[ident]==nil then
        s.error("No entry found in trade table")
    else
        if trade_table[ident].a==activate then
            if trade_tavailable[ident]~=nil and activate==true then
                s.error("Already activated")
            elseif trade_tavailable[ident]==nil and activate==false then
                s.error("Already deactivated")
            end
        elseif trade_table[ident].b==nil and trade_table[ident].s==nil and activate==true then
            s.error("No sell price and no buy price")
        else
            trade_table[ident].a=activate
            if activate==true then
                trade_tavailable[ident]=trade_table[ident]
                trade_tavailable[#trade_tavailable+1]=ident
            else
                trade_tavailable[ident]=nil
                for i=1,#trade_tavailable do
                    if trade_tavailable[i]==ident then
                        table.remove(trade_tavailable,i)
                        break
                    end
                end
            end
            local file=io.open("/trade_table","w")
            file:write(serialization.serialize(trade_table))
            file:close()
        end
    end
end

function s.deactivateItem(ident)
    s.activateItem(ident,false)
end

function s.listItems()
    return d
end

function s.listDatabase()
    return database
end

function s.listTradeTable()
    return trade_table
end

function s.listAvailableTrades()
    return trade_tavailable
end

function s.singleExport() --only debug
    return ex_single
end

function s.stackExport() --only debug
    return ex_stack
end

function s.error(output)
    print(output)
end

return s