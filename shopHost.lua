---------------
local version="0.1b"
local author="kevinkk525"
---------------config section
local hard_currency=false
---------------

local serialization=require("serialization")
local component=require("component")
local exchange=require("money_exchange")
local eco=require("bankAPI")

local s={}
local b={} --backup
local export
local registrationServer
local f
local shopOwner
local ownerPassword
local me=component.me_controller
local trade_table={}

local function loadTradeTable()
    local file=io.open("/trade_table","r")
    if file then
        trade_table=serialization.unserialize(file:read("*all"))
        file:close()
    end
end

local function save()
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

---------------------------

function s.addBalance(user,balance,message) --only call this through req_handler,user has to be user of bank-system
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

function s.initialize(handler)
	regServer()
    ownerCredentials()
    loadTradeTable()
	f=handler
	b={}
	if hooks["backup"]==nil then
		b=f.addHook("backup","backup")
	end
	export=f.remoteRequest(registrationServer,"getRegistration",{"H398FKri0NieoZ094nI","ShopExport"})[1]
	print(f.remoteRequest(registrationServer,"registerDevice",{"H398FKri0NieoZ094nI","ShopHost"}))
	if not export then print("no ShopExport-processor found") end
    f.registerFunction(s.addBalance,"addBalance")
    f.registerFunction(s.getTradeTable,"getTradeTable")
end

function s.getTradeTable() return trade_table end

return s