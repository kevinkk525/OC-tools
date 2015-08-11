---------------
local version="0.9.7b"
local registrationServer="5ab38756-65fc-426a-a6f8-60100b3b9d34"
---------------
--sides: down:0,up:1,south:3,east:5

local component=require("component")
local s={} --functions
local f={} --handler
local trans={} --transceiver
local eBuffer={} --enderio capacitor
local eBuffer_side={}
local eSource={} --enderio creative capacitor
local user={} --user of given transceiver and index
local SourceBufferPairs={}
local BufferDimPairs={}
--add possibility to rent energy
local function registerSwitch()
    if f.getStatus()=="added" then --[1]to,[2]port,[3]message,[4]com
        hooks.m.send({registrationServer,801,{"H398FKri0NieoZ094nI","Switch"},"registerDevice"})
        f.pause(registerSwitch)
    elseif f.getStatus()=="standard" then 
        print(f.getData()[6]) --change this...
    end
end


local function test3(side,mode,i)
    local tmp={}
    local mode=eSource[i].getIOMode(side)
    local modet=trans[i].getIOMode(side)
    tmp[1]=eBuffer[i][1].getEnergyStored()
    tmp[2]=eBuffer[i][2].getEnergyStored()
    for j=1,2 do
        if tmp[j]<5000 then
            print("charging")
            eSource[i].setIOMode(0,"push")
            eSource[i].setIOMode(1,"push")
            os.sleep(2)
            eSource[i].setIOMode(0,"disabled")
            eSource[i].setIOMode(1,"disabled")
            os.sleep(2)
        end
        tmp[j]=eBuffer[i][j].getEnergyStored()
    end print("tmp[1]="..tmp[1]..", tmp[2]="..tmp[2])
    eSource[i].setIOMode(side,"disabled")
    local modet2=trans[i].getIOMode(math.abs(side-1))
    trans[i].setIOMode(math.abs(side-1),"disabled")
    trans[i].setIOMode(side,mode)
    os.sleep(1.1)
    local tmp2={}
    tmp2[1]=eBuffer[i][1].getEnergyStored()
    tmp2[2]=eBuffer[i][2].getEnergyStored()
    print("tmp2[1]="..tmp2[1]..", tmp2[2]="..tmp2[2])
    for j=1,2 do
        if tmp[j]>tmp2[j] then
            bool[i]=true
        elseif bool[i]~=true then
            bool[i]=false
    end end
    trans[i].setIOMode(side,modet) trans[i].setIOMode(math.abs(side-1),modet2) eSource[i].setIOMode(side,mode)
end
local function test2(side,mode,i)  --fails at eSource[1] and eBuffer[1] for not found reason: manual check proved false test result
    local tmp={}
    local mode=eSource[i].getIOMode(side)
    tmp[1]=eBuffer[i][1].getEnergyStored()
    tmp[2]=eBuffer[i][2].getEnergyStored()
    eSource[i].setIOMode(side,mode)
    os.sleep(1.1)
    local tmp2={}
    tmp2[1]=eBuffer[i][1].getEnergyStored()
    tmp2[2]=eBuffer[i][2].getEnergyStored()
    for j=1,2 do
        if mode=="push" then
            if tmp[j]<tmp2[j] then
                bool[i]=true
            elseif bool[i]~=true then
                bool[i]=false
                print("bool false at i="..i..", side="..side..", mode="..mode..",tmp[1]="..tmp[1]..", tmp[2]="..tmp[2]..", tmp2[1]="..tmp2[1]..", tmp2[2]="..tmp2[2])
            end
        else
            if tmp[j]>tmp2[j] then
                bool[i]=true
    end end end
    eSource[i].setIOMode(side,mode)
end


local function dim(side,mode)
    for i=1,#trans do
        trans[i].setIOMode(side,mode)
        local tmp={}
        for j=1,#eBuffer_tmp do
            tmp[j]=component.proxy(eBuffer_tmp[j]).getEnergyStored()
            if tmp[j]<5000 then
                component.proxy(eSource_tmp[SourceBufferPairs[j]]).setIOMode(eBuffer_side[j],"push")
                os.sleep(5)
                component.proxy(eSource_tmp[SourceBufferPairs[j]]).setIOMode(eBuffer_side[j],"disabled")
                tmp[j]=component.proxy(eBuffer_tmp[j]).getEnergyStored()
            end
        end
        os.sleep(1.1)
        local tmp2={}
        for j=1,#eBuffer_tmp do
            tmp2[j]=component.proxy(eBuffer_tmp[j]).getEnergyStored()
        end
        for j=1,#tmp do
            --print("dim tmp["..j.."]="..tmp[j],"tmp2="..tmp2[j])
            if tmp[j]>tmp2[j] then
                BufferDimPairs[j]=i
                print("BufferDimPairs["..j.."]="..i)
                break
            end
        end
        trans[i].setIOMode(side,"disabled")
    end
end

local function eBuff(side,mode)
    for i=1,#eSource_tmp do
        local tmp={}
        for j=1,#eBuffer_tmp do
            tmp[j]=component.proxy(eBuffer_tmp[j]).getEnergyStored()
        end
        component.proxy(eSource_tmp[i]).setIOMode(side,mode)
        os.sleep(1.1)
        local tmp2={}
        for j=1,#eBuffer_tmp do
            tmp2[j]=component.proxy(eBuffer_tmp[j]).getEnergyStored()
        end
        component.proxy(eSource_tmp[i]).setIOMode(side,"disabled")
        for j=1,#tmp do
            --print("eBuff tmp["..j.."]="..tmp[j],"tmp2="..tmp2[j])
            if mode=="push" then
                if tmp[j]<tmp2[j] then
                    SourceBufferPairs[j]=i
                    eBuffer_side[j]=side
                    print("SourceBufferPairs["..j.."]="..i)
                    break
                end
            else
                if tmp[j]>tmp2[j] then
                    SourceBufferPairs[j]=i
                    eBuffer_side[j]=side
                    print("SourceBufferPairs["..j.."]="..i)
                    break
                end
            end
        end
    end
end
-------------------------------
function s.initialize(handler)
    s.initTessIO()
    f=handler
    for i=1,#trans do
        trans[i].setReceiveChannel("power","Battery_Out",true)
        trans[i].setIOMode(3,"push") --to tesseract, reminder: push_pull
        eSource[i].setIOMode(0,"push")
        eSource[i].setIOMode(1,"pull")
    end
    for i=1,#eBuffer do for j=1,2 do eBuffer[i][j].setIOMode(0,"disabled") eBuffer[i][j].setIOMode(1,"disabled") end end
    f.registerFunction(s.send,"send")
    f.registerFunction(s.receive,"receive")
    f.registerFunction(s.close,"close")
    f.registerFunction(s.getTransNumber,"getTransNumber")
    f.addTask(registerSwitch)
    print("switch started")
end
function s.getUsers() return user end
function s.getTransNumber() return #trans end
function s.receive(username)
    trans[user[username]].setIOMode(3,"pull")
    print(username.." activated pull")
    return "receiving"
end
function s.send(username)
    trans[user[username]].setIOMode(3,"push")
    print(username.." activated push")
    return "sending"
end
function s.close(username)
    trans[user[username]].setIOMode(3,"disabled")
    print(username.." closed")
    return "closed"
end
function s.initTessIO()
    trans_tmp={}
    eBuffer_tmp={}
    eSource_tmp={}
    for a in component.list("dimensional_transceiver") do
        trans_tmp[#trans_tmp+1]=a
    end
    for a in component.list("capacitor_bank") do
        eBuffer_tmp[#eBuffer_tmp+1]=a
        if component.proxy(eBuffer_tmp[#eBuffer_tmp]).getMaxEnergyStored()==5000000 then
            table.remove(eBuffer_tmp,#eBuffer_tmp)
            eSource_tmp[#eSource_tmp+1]=a
        end
    end
    print("found #"..#eBuffer_tmp.." Capacitors and #"..#eSource_tmp.." Creative Capacitors")
    for i=1,#trans_tmp do
        local tmp=component.proxy(trans_tmp[i]).getSendChannels("item")[1]
        if tmp~=nil then
            table.insert(trans,#user+1,component.proxy(trans_tmp[i]))
            user[#user+1]=tmp
            user[tmp]=#user
        else
            trans[#trans+1]=component.proxy(trans_tmp[i])
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
    eBuff(0,"push") eBuff(0,"pull") eBuff(1,"push") eBuff(1,"pull") dim(0,"pull") dim(1,"pull")
    for i=1,#BufferDimPairs do
        if eBuffer[BufferDimPairs[i]]==nil then
            eBuffer[BufferDimPairs[i]]={}
        end
        eBuffer[BufferDimPairs[i]][#eBuffer[BufferDimPairs[i]]+1]=component.proxy(eBuffer_tmp[i])
        eSource[BufferDimPairs[i]]=component.proxy(eSource_tmp[SourceBufferPairs[i]]) --getting an error sometimes
    end
    tmp=nil tmp2=nil trans_tmp=nil eBuffer_tmp=nil eSource_tmp=nil BufferDimPairs=nil SourceBufferPairs=nil
end
function s.test()
    for i=1,#eSource do
        bool={}
        test2(0,"push",i)
        test2(0,"pull",i)
        test2(1,"push",i)
        test2(1,"pull",i)
        for j=1,#bool do
            if bool[j]==false then
                print("Test failed at eSource #"..i.." and at Buffer #"..j)
            end
        end
    end
    for i=1,#trans do
        bool={}
        test3(0,"pull",i)
        test3(1,"pull",i)
        for j=1,#bool do
            if bool[j]==false then
                print("Test failed at Trans #"..i.." and at Buffer #"..j)
            end
        end
    end
    print("Test succesfull if no error until now!")
end
function s.listTrans() return trans end
function s.listSource() return eSource end
function s.listBuffer() return eBuffer end
function s.listUser() return user end
function s.listBufferSides() return eBuffer_side end
return s