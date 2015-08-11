---------------
local version="0.9.7b"
---------------

--sides: down:0,up:1,south:3,east:5
local component=require"component"
local s={} --functions
local f --handler
local trans={} --transceiver
local eBuffer={} --enderio capacitor
local eSource={} --creative capacitor
local user={} --username is just a channel name, shopAPI has to take care of username-->channel conversion

local trans_tmp={}
local eBuffer_tmp={}
local eSource_tmp={}

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

local function registerSwitch()
    if f.getStatus()=="added" then --[1]to,[2]port,[3]message,[4]com
        hooks.m.send({registrationServer,801,{"H398FKri0NieoZ094nI","Switch"},"registerDevice"})
        f.pause(registerSwitch)
    elseif f.getStatus()=="standard" then 
        print(f.getData()[6]) --change this...
    end
end

local function eBuff(side)
    for i=1,#trans do
        local energy={}
        for j=1,#eBuffer_tmp do
            energy[j]=component.proxy(eBuffer_tmp[j]).getEnergyStored()
        end
        trans[i].setIOMode(side,"pull")
        os.sleep(2)
        trans[i].setIOMode(side,"disabled")
        for j=1,#eBuffer_tmp do
            if component.proxy(eBuffer_tmp[j]).getEnergyStored()~=energy[j] then
                if eBuffer[i]==nil then
                    eBuffer[i]={}
                end
                eBuffer[i][side]=component.proxy(eBuffer_tmp[j])
                break
            end
        end
    end
end

local function trans_buffer()
    for i=1,#eSource_tmp do
        component.proxy(eSource_tmp[i]).setIOMode(1,"push")
        component.proxy(eSource_tmp[i]).setIOMode(0,"push")
    end
    while true do
        local percent=math.floor(component.proxy(eBuffer_tmp[1]).getEnergyStored()*100/component.proxy(eBuffer_tmp[1]).getMaxEnergyStored())
        print("charging "..percent)
        os.sleep(2)
        if percent>=50 then
            break
        end
    end
    for i=1,#eSource_tmp do
        component.proxy(eSource_tmp[i]).setIOMode(1,"disabled")
        component.proxy(eSource_tmp[i]).setIOMode(0,"disabled")
    end
    os.sleep(2)
    eBuff(0)
    eBuff(1)
end

local function creative_trans()
    for i=1,#eSource_tmp do
        local energy={}
        for j=1,#trans do
            energy[j]={}
            energy[j][1]=eBuffer[j][1].getEnergyStored()
            if energy[j][1]<100000 then
                print("warning, energy too low??")
            end
        end
        component.proxy(eSource_tmp[i]).setIOMode(1,"pull")
        os.sleep(5)
        component.proxy(eSource_tmp[i]).setIOMode(1,"disabled")
        for j=1,#trans do
            if energy[j][1]~=eBuffer[j][1].getEnergyStored() then
                eSource[j]=component.proxy(eSource_tmp[i])
                break
            end
        end
    end
    if #eSource_tmp~=#eSource then
        print("Error in creative_trans! "..#eSource_tmp..":"..#eSource)
    end
end

--------------------------------
function s.initTessIO()
    for a in component.list("dimensional_transceiver") do trans_tmp[#trans_tmp+1]=a end
    for a in component.list("capacitor_bank") do 
        if component.proxy(a).getMaxEnergyStored()==5000000 then
            eSource_tmp[#eSource_tmp+1]=a
        else
            eBuffer_tmp[#eBuffer_tmp+1]=a
        end
    end
    print("found #"..#eBuffer_tmp.." Capacitors and #"..#eSource_tmp.." Creative Capacitors")
    for i=1,#trans_tmp do
        trans[#trans+1]=component.proxy(trans_tmp[i])
        if trans[i].getSendChannels("item")[1] then
            user[i]=trans[i].getSendChannels("item")[1]
            user[user[i]]=i
        end
    end
    print("found #"..#trans.." transceiver")
        for i=1,#trans do
        trans[i].setReceiveChannel("power","Battery_Out",false)
        trans[i].setIOMode(0,"disabled")
        trans[i].setIOMode(1,"disabled")
        component.proxy(eSource_tmp[i]).setIOMode(0,"disabled")
        component.proxy(eSource_tmp[i]).setIOMode(1,"disabled")
    end
end

function s.test()
    print("creative -> buffer")
    for i=1,#eSource do
        local energy={}
        energy[1]=eBuffer[i][1].getEnergyStored()
        energy[0]=eBuffer[i][0].getEnergyStored()
        eSource[i].setIOMode(1,"pull")
        eSource[i].setIOMode(0,"push")
        os.sleep(1)
        eSource[i].setIOMode(1,"disabled")
        eSource[i].setIOMode(0,"disabled")
        if energy[1]==eBuffer[i][1].getEnergyStored() or energy[0]=eBuffer[i][0].getEnergyStored() then
            print("test failed at eSource #"..i)
        end
    end
    print("\ntesting trans->buffer")
    for i=1,#trans do
        local energy=eBuffer[i][1].getEnergyStored()
        trans[i].setIOMode(1,"pull")
        os.sleep(2)
        trans[i].setIOMode(1,"disabled")
        if energy==eBuffer[i][1].getEnergyStored() then
            print("test failed at trans #"..i)
        end
    end
    print("\n Test done")
end

function s.getUsers() return user end

function s.getTransNumber() return #trans end

function s.receive(username)
    if not user[username] then return false,"no such user" end
    trans[user[username]].setReceiveChannel("item",username,true)
    trans[user[username]].setIOMode(3,"pull")
    print(username.." activated pull")
    return "receiving"
end

function s.send(username)
    if not user[username] then return false,"no such user" end
    trans[user[username]].setIOMode(3,"push")
    print(username.." activated push")
    return "sending"
end

function s.close(username)
    if not user[username] then return false,"no such user" end
    trans[user[username]].setReceiveChannel("item",username,false)
    trans[user[username]].setIOMode(3,"disabled")
    print(username.." closed")
    return "closed"
end

function s.registerUser(username)
    if user[username] then return false,"user already registered" end
    if s.getUserNumber()==#trans then return false,"no available transceivers" end
    for i=1,#trans do
        if not user[i] then
            trans[i].setSendChannel("item",username,true)
            --trans[i].setReceiveChannel("item",username,true) --prevents item loss
            user[i]=username
            user[username]=i
            break
        end
    end
    return true,"user added"         
end

function s.removeUser(username)
    if not user[username] then return false,"user not registered" end
    trans[user[username]].setSendChannel("item",username,false)
    trans[user[username]].setReceiveChannel("item",username,false)
    user[i]=nil
    user[username]=nil
    return true,"user removed"
end

function s.getUserNumber()
    local j=0
    for i=1,#trans do
        if user[i] then
            j=j+1
        end
    end
    return j
end
    
function s.initialize(handler)
    trans={} --transceiver
    eBuffer={} --enderio capacitor
    eSource={}
    f=handler
    regServer()
    s.initTessIO()
    trans_buffer()
    creative_trans()
    trans_tmp=nil eBuffer_tmp=nil eSource_tmp=nil
    for i=1,#trans do
        trans[i].setReceiveChannel("power","Battery_Out",true)
        trans[i].setIOMode(3,"push") --to tesseract, reminder: push_pull
        eSource[i].setIOMode(0,"pull")
        eSource[i].setIOMode(1,"push")
    end
    for i=1,#eBuffer do for j=0,1 do eBuffer[i][j].setIOMode(0,"disabled") eBuffer[i][j].setIOMode(1,"disabled") end end
    f.registerFunction(s.send,"send")
    f.registerFunction(s.receive,"receive")
    f.registerFunction(s.close,"close")
    f.registerFunction(s.getTransNumber,"getTransNumber")
    f.registerFunction(s.registerUser,"registerUser")
    f.registerFnction(s.getUserNumber,"getUserNumber")
    f.addTask(registerSwitch)
end

function s.listTrans() return trans end
function s.listSource() return eSource end
function s.listBuffer() return eBuffer end
function s.listUser() return user end
return s