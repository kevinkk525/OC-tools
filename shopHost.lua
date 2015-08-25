---------------
local version="0.3b"
local author="kevinkk525"
---------------config section
local hard_currency=false
local offer_timeout=120
local chest_size=54
---------------

local serialization=require("serialization")
local component=require("component")
local exchange=require("money_exchange")
local computer=require("computer")
local fs=require("filesystem")
local sha256=require"sha256"
local event=require"event"
local redstone=component.redstone
local eco

local s={}
local b={} --backup
local export
local switch
local registrationServer
local f
local shopOwner
local ownerPassword
local trade_table={} --structure: size=int,hash={s/b={{amount,prize},...},name=label?}
local trans={} --structure: [user]={[uptime]=uptime,[status]=status,[trans-id]=randID}
local export_list={}
local user_list={} --structure: [user]=channel,[channel]=user
local nextInactiveScan=computer.uptime()+10
local marked_for_removal={}

--additems, removeitems, updateTradeTable... (move adding to different pc)
--shopHost needs a transceiver


local function loadTradeTable()
    local file=io.open("/trade_table","r")
    if file then
        trade_table=serialization.unserialize(file:read("*all"))
        file:close()
    end
end

local function saveTradeTable()
    local file=io.open("/trade_table","w")
    file:write(serialization.serialize(trade_table))
    file:close()
end

local function ownerCredentials()
    local file=io.open("/shopOwner","r")
    if file then
        shopOwner=file:read()
        ownerPassword=file:read()
        file:close()
    else
        print("Please enter shop owner credentials for eco-system or quit")
        print("Enter username")
        io.flush()
        local inp=io.read()
        if inp=="quit" or inp=="q" then
            os.exit()
        else
            shopOwner=inp
        end
        print("Enter password")
        io.flush()
        local inp=io.read()
        if inp=="quit" or inp=="q" then
            os.exit()
        else
            ownerPassword=sha256(inp)
        end
        local file=io.open("/shopOwner","w")
        file:write(shopOwner.."\n"..ownerPassword)
        file:close()
    end
end
 
local function regServer()
    local file=io.open("/lib/registrationServer","r")
    if file then
        registrationServer=file:read()
        file:close()
    else
        print("Please enter registrationServer address or quit")
        io.flush()
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

local function randID()
    local id=tostring(math.random(1,10000))
    local exists=false
    for i in pairs(trans) do
        if trans[i].id==id then
            exists=true
            break
        end
    end
    if exists then
        id=f.randID()
    end
    return id
end

local function log(text)
    print(text)
end

local function loadUser()
    local file=io.open("/user_channel","r")
    if file then
        user_list=serialization.unserialize(file:read("*all"))
        file:close()
        if type(user_list)~="table" then
            user_list={}
        end
    end
end

local function saveUser()
    local file=io.open("/user_channel","w")
    file:write(serialization.serialize(user_list))
    file:close()
end

local function authShopControl()
    local auth=f.remoteRequest(registrationServer,"getRegistration",{"H398FKri0NieoZ094nI","ShopControl"})
    for i=1,#auth do
        if auth[i]==f.getData()[3] then
            return true
        end
    end
    if auth~=true then
        return false
    end
end
 
local function checkItems(items)
    local amount=0
    for item in pairs(items) do
        if not trade_table[item] then
            return false
        end
        amount=amount+math.modf(items[item].size/trade_table[item][1].maxSize)+1
    end
    if amount>chest_size then
        return false
    end
    return true
end

local function saveMarked()
    local file=io.open("/marked_for_removal","w")
    file:write(serialization.serialize(marked_for_removal))
    file:close()
end

local function loadMarked()
    local file=io.open("/marked_for_removal","r")
    if file then
        marked_for_removal=serialization.unserialize(file:read("*all"))
        if type(marked_for_removal)~="table" then marked_for_removal={} end
        if #marked_for_removal>0 then redstone.setOutput(1,15) else redstone.setOutput(1,0) end
        file:close()
    end
end

local function calculatePrice(items,id,mode)
    local tab
    local price=0
    local file=io.open("/tmp/"..id,"r")
    if file then
        tab=serialization.unserialize(file:read("*all"))
        file:close()
        if type(tab)~="table" then tab=trade_table end
    end
    for item in pairs(items) do 
        if not tab[item][mode] then
            return 1000000000
        end
        price=price+tab[item][mode][1]*items[item].size
    end
    return price
end

---------------------------

function s.removeInactiveUser()
    local book=eco.book()
    for i=1,#book do
        book[book[i]]=1
    end
    for i in pairs(user_list) do
        if not i:sub(1,2)=="ch" and tonumber(i:sub(3)) then
            if not book[i] then
                local exists=false
                for i=1,#marked_for_removal do
                    if marked_for_removal[i]==user_lust[i] then 
                        exists=true
                        break
                    end
                end
                if not exists then
                    marked_for_removal[#marked_for_removal+1]=user_list[i]
                    redstone.setOutput(1,15)
                end
            end
        end
    end
end

function s.removeUser(channel)
    if not f.getSource()=="internal" and not authShopControl() then
        return "not authenticated to execute"
    end
    if user_list[channel] then
        for i=1,#marked_for_removal do
            if marked_for_removal[i]==channel then
                table.remove(marked_for_removal,i)
                user_list[user_list[channel]]=nil
                user_list[channel]=nil
                saveUser()
                saveMarked()
                if #marked_for_removal==0 then
                    redstone.setOutput(1,0)
                end
                return true
            end
        end
    end
    return false
end

function s.addBalance(user,balance,message) --only call this through req_handler,user has to be user of bank-system
    if type(user)=="table" then balance=user[2] message=user[3] user=user[1] end
    message=message or "payment/refund Kevrium"
    if f.getSource()=="internal" then
        return eco.pay(shopOwner,ownerPassword,user,message,balance)
    elseif f.getSource()=="external" and f.getData()[3]==export then
        return eco.pay(shopOwner,ownerPassword,user_list[user],message,balance)
    else
        return "not authorized to execute this command"
    end
end

function s.receivePayment(user,pass,message,balance)
    message=message or "payment in Kevrium"
    return eco.pay(user,pass,shopOwner,message,balance)
end

function s.initTrade(user)
    if not trans[user] then
        trans[user]={["uptime"]=computer.uptime(),["status"]="init",["id"]=randID(),["address"]=f.getData()[3]}
    else
        trans[user].address=f.getData()[3]
    end
    local file=io.open("/tmp/"..trans[user].id,"w")
    file:write(serialization.serialize(trade_table))
    file:close()
    return trade_table
end

function s.quitTransaction()
    for user in trans do
        if trans[user].address==f.getData()[3] then
            if not trans[user].status=="processing" then 
                fs.remove("/tmp"..trans[i].id)
                trans[user]=nil
            end
            break
        end
    end
end

function s.removeInactive()
    if nextInactiveScan<computer.uptime() then
        local up=computer.uptime()
        for i in pairs(trans) do
            if trans[i].uptime+offer_timeout<up and trans[i].status=="init" then
                fs.remove("/tmp/"..trans[i].id)
                trans[i]=nil
            end
        end
        nextInactiveScan=computer.uptime()+10
    end
end

function s.addUser(user)
    if not authShopControl() or not f.getSource()=="internal" then
        return "not authenticated"
    end
    if user_list[user] then
        return true
    else
        local num=f.remoteRequest(switch,"getUserNumber")
        if not num then return "Error with switch" end
        local channel
        for i=1,num do
            if not user_list["ch"..i] then
                channel="ch"..i
                break
            end
        end
        if not channel then return "No available channel" end
        user_list[channel]=user
        user_list[user]=channel
        saveUser()
        return true
    end
end

function s.buy(user,pass,items,price) --structure items: {[hash]={[size]=size,[1]=price}}
    if type(user)=="table" then pass=user[2] items=user[3] price=user[4] user=user[1] end
    local check=checkItems(items)
    if not user or not pass or not items or not price then
        return "Wrong input, you need a user, a password and items and precalculated price"
    end
    if check~=true then
        return check
    end
    local ret=eco.login(user,pass)
    if ret~=true then
        return ret
    end
    if not user_list(user) then
        return "We are sorry, but you are not registered. Talk to the Owner!"
    end
    if trans[user] and price and calculatePrice(items,trans[user].id,"s")==price then
        local ret=s.receivePayment(user,pass,"Kevrium: Buy #"..trans[user].id,price) --add check from owner side?
        if ret~=true then
            return ret
        end
        export_list[#export_list+1]={["user"]=user,["items"]=items,["mode"]="exportTo",["status"]="waiting",["address"]=f.getData()[3],["price"]=price}
        trans[user].status="processing"
        return true
    elseif not trans[user] and price then
        return "Price has changed, please try again"
    else
        return "Something else went wrong"
    end
end

function s.sell(user,pass,items,price) --add item amount check --> chest
    if type(user)=="table" then pass=user[2] items=user[3] price=user[4] user=user[1] end
    if not user or not pass or not items or not price then
        return "Wrong input, you need a user, a password and items and precalculated price"
    end
    local check=checkItems(items)
    if check~=true then
        return check
    end
    local ret=eco.login(user,pass)
    if ret~=true then
        return ret
    end
    if not user_list(user) then
        return "We are sorry, but you are not registered. Talk to the Owner!"
    end
    if trans[user] and price and calculatePrice(items,trans[user].id,"b")==price then
        export_list[#export_list+1]={["user"]=user,["items"]=items,["mode"]="importFrom",["status"]="waiting",["address"]=f.getData()[3],["price"]=price}
        trans[user].status="processing"
        return true
    elseif not trans[user] and price then
        return "Price has changed, please try again"
    else
        return "Something else went wrong"
    end
end

function s.startProcessing()
    hooks.m.send({export_list[1].address,801,{user_list[export_list[1].user],export_list[1].items},export_list[1].mode})
    f.pause(s.finishProcessing)
    for i=1,#export_control do
        f.sendCommand(export_list[i].address,"updateInfo","You are #"..i.."in queue, please have patience")
        os.sleep(0.1)
    end
end

function s.finishProcessing()
    if f.getData()[6]==true then
        if export_list[1].mode=="importFrom" then
            local ret=eco.pay(shopOwner,ownerPassword,export_list[1].user,"Kevrium: Sell #"..trans[export_list[1].user].id,export_list[1].price)
            if ret~=true then
                ret="Error paying you "..export_list[1].price..", please contact the ShopOwner immediately!"
                log("Error paying "..export_list[1].user.." "..export_list[1].price)
            end
            fs.remove("/tmp/"..trans[export_list[1].user].id)
            f.sendCommand(export_list[1].address,"updateInfo",ret)
            trans[export_list[1].user]=nil
            table.remove(export_list,1)
        else
            fs.remove("/tmp/"..trans[export_list[1].user].id)
            f.sendCommand(export_list[1].address,"updateInfo",true)
            trans[export_list[1].user]=nil
            table.remove(export_list,1)
        end
    else
        local ret
        if export_list[1].mode=="exportTo" then
            if f.getData()[6]:find("Error during transmission, refunded") then
                local a,b=f.getData():find("Error during transmission, refunded ")
                log("Error but refunded with "..f.getData()[6]:sub(b+1))
                ret="There was an error but you got refunded with "..f.getData()[6]:sub(b+1)
            else
                log(f.getData()[6])
                ret=f.getData()[6]
            end
        else
            if f.getData()[6]=="error adding balance after failed import and failed sending back" then
                local a,b=f.getData()[6]:find(",")
                log("Import failed and sending back too. Refund of "..f.getData()[6]:sub(a+1).." was not possible, Contact shop owner")
                ret="Import failed and sending back too. Refund of "..f.getData()[6]:sub(a+1).." was not possible, Contact shop owner"
            elseif f.getData()[6]:find("failed sending back, refunded ") then
                log("Could not send items back, refunded "..f.getData()[6]:sub(31))
                ret="Could not send items back, refunded "..f.getData()[6]:sub(31)
            elseif f.getData()[6]=="sent back, wrong items" then
                ret="You sent wrong items, try again"
            end
        end
        fs.remove("/tmp/"..trans[export_list[1].user].id)
        f.sendCommand(export_list[1].address,"updateInfo",ret)
        trans[export_list[1].user]=nil
        table.remove(export_list,1)
    end
end

function s.export_control()
    if #export_list>0 then
        if export_list[1].status=="waiting" then
            local task_id=f.addTask(s.startProcessing)
            export_list[1].status="processing"
        end
    end
end

function s.addItem(items) --structure: index={[1]=nbt,{s/b={{amount,prize},...},name=label?}} 
    if not authShopControl() or not f.getSource()=="internal" then
        return "Not authenticated to use this"
    end
    local result=f.remoteRequest(export,"addItem",items)
    for i=1,#result do
        if result[i]==false then
            print("Error adding "..items[i][1].label)
        else
            if not trade_table[result[i]] then
                if not trade_table.size then trade_table.size=0 end
                trade_table.size=trade_table.size+1
            end
            trade_table[result[i]]=items[i]
        end
    end
    saveTradeTable()
    return result
end

function s.removeItem(items)--structure: index=[hash]
    if not authShopControl() then
        return "Not authenticated to use this"
    end
    if f.remoteRequest(export,"removeItem",items) then
        for i=1,#items do
            if trade_table[items[i]] then
                trade_table[items[i]]=nil
                trade_table.size=trade_table.size-1
            end
        end
    else
        return false
    end
    return true  
        
end

function s.updateTradeTable(tab)
    if not authShopControl() then
        return "Not authenticated to use this"
    end
    return f.remoteRequest(export,"updateTradeTable",tab)
end
    
function s.initialize(handler)
	f=handler
    regServer()
    eco=f.addHook("eco","bankAPI")
    ownerCredentials()
    loadTradeTable()
    loadUser()
    loadMarked()
    b={}
    if hooks["backup"]==nil then
        b=f.addHook("backup","backup")
    else
        b=hooks["backup"]
    end
    export=f.remoteRequest(registrationServer,"getRegistration",{"H398FKri0NieoZ094nI","ShopExport"})[1]
    switch=f.remoteRequest(registrationServer,"getRegistration",{"H398FKri0NieoZ094nI","Switch"})[1]
    if not export or not switch then print("Error, no export or switch found") end
    print(f.remoteRequest(registrationServer,"registerDevice",{"H398FKri0NieoZ094nI","ShopHost"}))
    if not export then print("no ShopExport-processor found") end
    f.registerFunction(s.addBalance,"addBalance")
    f.registerFunction(s.getTradeTable,"getTradeTable")
    f.registerFunction(s.initTrade,"initTrade")
    f.registerFunction(s.buy,"buy")
    f.registerFunction(s.sell,"sell")
    f.registerFunction(s.addItem,"additem")
    f.registerFunction(s.removeItem,"removeItem")
    f.registerFunction(s.quitTransaction,"quitTransaction")
    f.registerFunction(s.removeUser,"removeUser")
    f.registerFunction(s.addUser,"addUser")
    f.registerFunction(eco.login,"login")
    f.addTask(s.removeInactive,nil,nil,nil,nil,nil,nil,"permanent")
    f.addTask(s.export_control,nil,nil,nil,nil,nil,nil,"permanent")
    s.removeInactiveUser()
    event.timer(86400,s.removeInactiveUser,math.huge)
end

function s.getTradeTable() return trade_table end
function s.getExportList() return export_list end
function s.getUserList() return user_list end

return s