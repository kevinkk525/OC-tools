---------------
local version="0.1b"
local author="kevinkk525"
---------------config section
local hard_currency=false
local offer_timeout=120
---------------

local serialization=require("serialization")
local component=require("component")
local exchange=require("money_exchange")
local computer=require("computer")
local fs=require("filesystem")
local eco

local s={}
local b={} --backup
local export
local switch
local registrationServer
local f
local shopOwner
local ownerPassword
local me=component.me_controller
local trade_table={} --structure: size=int,hash={s/b={{amount,prize},...},name=label?}
local trans={} --structure: [user]={[uptime]=uptime,[status]=status,[trans-id]=randID}
local export_list={}
local user_list={} --structure: [user]=channel,[channel]=user

--additems, removeitems, updateTradeTable... (move adding to different pc)
--shopHost needs a transceiver?
--add removeInactiveUsers


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
            ownerPassword=eco.sha256(inp)
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

local function checkTransceiver(user)
    if user_list[user] then
        return true
    else
        local channel
        local channels=trans.???? --abgleich mit chX
        for i=1,#channels do
            if not user_list[channels[i]] then
                channel=channels[i]
                break
            end
        end
        if not channel then
            return false
        end
        local ret=f.remoteRequest(switch,"registerUser",channel)
        if ret==true then
            user_list[channel]=user
            user_list[user]=channel
            saveUser()
        end
        return ret
    end
end

local function removeUser(user)
    if user_list[user] then
        local ret=f.remoteRequest(switch,"removeUser",user_list[user])
        if ret~=true then
            return "Could not remove user"
        end
        user_list[user_list[user]]=nil
        user_list[user]=nil
        saveUser()
    end
end
    
---------------------------

function s.addBalance(user,balance,message) --only call this through req_handler,user has to be user of bank-system
    if type(user)=="table" then balance=user[2] message=user[3] user=user[1] end
    message=message or "payment/refund Kevrium"
    if f.getSource()=="internal" or (f.getSource()=="external" and f.getData()[3]==export) then
        return eco.pay(shopOwner,ownerPassword,user,message,balance)
    else
        return "not authorized to execute this command"
    end
end

function s.receivePayment(user,pass,message,balance)
    message=message or "payment in Kevrium"
    return eco.pay(user,pass,shopOwner,message,balance)
end

function s.initTrade(user)
    trans[user]={["uptime"]=computer.uptime(),["status"]="init",["id"]=randID()}
    local file=io.open("/tmp/"..trans[user].id,"w")
    file:write(serialization.serialize(trade_table))
    file:close()
    return trade_table
end

function s.removeInactive()
    if f.getData("interval")<computer.uptime() then
        local up=computer.uptime()
        for i in pairs(trans) do
            if trans[i].uptime+offer_timeout<up and trans[i].status=="init" then
                fs.remove("/tmp/"..trans[i].id)
                trans[i]=nil
            end
        end
        f.addData(computer.uptime()+10,"interval")
    end
end

function s.buy(user,pass,items,price) --structure items: {[hash]={[size]=size,[1]=price}}
    if type(user)=="table" then pass=user[2] items=user[3] price=user[4] user=user[1] end
    if not user or not pass or not items or not price then
        return "Wrong input, you need a user, a password and items and precalculated price"
    end
    local ret=eco.login(user,pass)
    if ret~=true then
        return ret
    end
    if not checkTransceiver(user) then
        return "We are sorry, but we don't have enough capacity to register you. Talk to the Owner!"
    end
    if trans[user] and price and calculatePrice(items,trans[user].id)==price then
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
    local ret=eco.login(user,pass)
    if ret~=true then
        return ret
    end
    if not checkTransceiver(user) then
        return "We are sorry, but we don't have enough capacity to register you. Talk to the Owner!"
    end
    if trans[user] and price and calculatePrice(items,trans[user].id)==price then
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
        f.sendCommand(export_list[i].address,801,"You are #"..i.."in queue, please have patience","updateInfo")
        os.sleep(0.1)
    end
end

function s.finishProcessing()
    if f.getData()==true then
        if export_list[1].mode=="importFrom" then
            local ret=eco.pay(shopOwner,ownerPassword,export_list[1].user,"Kevrium: Sell #"..trans[export_list[1].user].id,export_list[1].price)
            if ret~=true then
                ret="Error paying you, please contact the ShopOwner immediately!"
                log("Error paying "..export_list[1].user.." "..export_list[1].price)
            end
            fs.remove("/tmp/"..trans[export_list[1].user].id)
            trans[export_list[1].user]=nil
            table.remove(export_list,1)
            return ret
        else
            return true
        end
    else
        --complex error handling
    end
end
            
function s.export_control()
    if #export_list>0 then
        if export_list[1].status=="waiting" then
            local task-id=f.addTask(s.startProcessing)
            export_list[1].status="processing"
        end
    end
end
    
function s.initialize(handler)
	regServer()
    ownerCredentials()
    loadTradeTable()
    loadUser()
	f=handler
    eco=f.addHook("eco","bankAPI")
	b={}
	if hooks["backup"]==nil then
		b=f.addHook("backup","backup")
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
    f.addTask(s.removeInactive,nil,nil,nil,nil,"interval",computer.uptime()+10,"permanent")
    f.addTask(s.export_control,nil,nil,nil,nil,nil,nil,"permanent")
end

function s.getTradeTable() return trade_table end

return s