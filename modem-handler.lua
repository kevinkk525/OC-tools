------------------------------
local version="1.7.1b"
------------------------------
local request_timeout=10
------------------------------
local serialization=require("serialization")
local component=require("component")
local modem=component.modem
local computer=require("computer")
local m={} --functions
local lifetime_msg=50
local rec={}
local recu={} --uptime table of received messages
local parts={} --temporary storage for splitted messages
local blacklist={}
local event=require"event"
modem.open(801)

local timer --temporary

--rec={size=int,from={[mid]=1,size=int}}
--recu={[uptime]={[from]={[mid]=1}},size=int}

if modem.isWireless() then
    modem.setStrength(400)
end 

local function addTask(data) --f.addTask:command,data,id,source,status,add_Data,add_Data_position,priority
    data[6]=data[6] or false
    local tmp=serialization.unserialize(tostring(data[6]))
    if tmp~=nil then
        data[6]=tmp
    end
    tmp=nil
    data[1]=nil
    data[2]=nil
    local id=nil
    id=id or data[12] --data[12] should only be an id in the answer!
    if type(data[9])~="table" then
        id=data[9]
    end
    local com=data[8]
    data[8]=nil
    data[7]=nil
    f.addTask(com,data,id,"external")
    return true
end

local function checkParts(data)
    if not data[13] then
        return false
    else
        if parts[data[7]]==nil then
            parts[data[7]]={}
        end
        if data[13]==0 then --add check of parts/ if parts missing-->error
            if not parts[data[7]][data[13]] then
                parts[data[7]][data[13]]=data[6]
                local msgtmp=""
                for i=#parts[data[7]],1,-1 do
                    if parts[data[7]][i]~=nil then
                        msgtmp=msgtmp..parts[data[7]][i]
                    end
                end
                msgtmp=msgtmp..data[6]
                data[6]=msgtmp
                msgtmp=nil
                addTask(data)
                parts[data[7]]=nil
            end
        else
            parts[data[7]][data[13]]=data[6]
        end
        return true
    end
end

local function free_cached_msg()
    local up=computer.uptime()-lifetime_msg
    for i in pairs(recu) do
        if i~="size" then
            if i<=up then
                for from in pairs(recu[i]) do
                    if from~="size" then
                        for mid in pairs(recu[i][from]) do 
                            rec[from][mid]=nil
                            rec[from].size=rec[from].size-1  --size nil for at least 1 entry, no idea how that bug happens
                            if parts[mid] then
                                parts[mid]=nil
                                local count=0
                                for a in pairs(parts) do count=count+1 end
                                if count==0 then parts={} end
                            end
                        end
                        if rec[from].size==0 then
                            rec[from]=nil
                            rec.size=rec.size-1
                            if rec.size==0 then
                                rec={}
                                rec.size=0
                            end
                        end
                    end
                end
                recu[i]=nil
                recu.size=recu.size-1
            end
        end
    end
    if recu.size==0 then
        recu={}
    end
    os.sleep(0)
end

local function randID(x) 
    local id=tostring(math.random(1,100)) 
    if not x then 
        if rec[id] then 
            id=f.randID() 
        end 
    end 
    return id 
end

--------------------------------------

function m.send(data,answer) --[1]to,[2]port,[3]message,[4]com,[5]task-id (of request),[6]arg10,[7]source,[8]task-id of sending system(automatically added),[9]split message
    if type(data[1])~="string" or type(data[2])~="number" then
        return "Wrong parameter"
    end
    local tmp2={}
    local length=0
    for i=3,9,1 do
        if type(data[i])=="table" then
            tmp2[i]=serialization.serialize(data[i])
        elseif type(data[i])=="string" or type(data[i])=="number" then
            tmp2[i]=tostring(data[i])
        else
            tmp2[i]=data[i]
        end
        if type(data[i])~="nil" then
            length=length+tostring(tmp2[i]):len()
        end
    end
    tmp2[7]=f.getID()
    if answer==true then
        data[8]=f.getData()[11]
    end
    local tmp=randID(1)
    if length>8000 then
        length=tmp2[3]:len()
        data[9]=0
        local part=""
        local count=1
        while length>0 do
            part=tmp2[3]:sub(count,count+8000-1)
            length=length-part:len()
            count=count+8000
            if length==0 then
                data[9]=0
            else 
                data[9]=data[9]+1
            end
            modem.send(data[1],data[2],part,tmp,tmp2[4],tmp2[5],tmp2[6],tmp2[7],data[8],data[9]) --parameter limit hit
            modem.send(data[1],data[2],part,tmp,tmp2[4],tmp2[5],tmp2[6],tmp2[7],data[8],data[9])
            os.sleep(0.1)
        end
    else
        modem.send(data[1],data[2],tmp2[3],tmp,tmp2[4],tmp2[5],tmp2[6],tmp2[7],data[8],data[9])
        modem.send(data[1],data[2],tmp2[3],tmp,tmp2[4],tmp2[5],tmp2[6],tmp2[7],data[8],data[9])
    end
    tmp=nil
    tmp2=nil
    return true 
end

function m.receive(_,_,from,port,_,message,mid,com,task_id,arg10,request_id,taskID_origin,split) --[1]event_name,[2]receiving_card-addr,[3]from,[4]port,arg5,[6]message,[7]mid,[8]com,[9]task-id,[10]arg10,[11]task-id of request,[12]task-id of sending system,[13]split
    if blacklist[from] then
        if blacklist[from]<computer.uptime() then
            blacklist[from]=nil
            m.receive(_,_,from,port,_,message,mid,com,task_id,arg10,request_id,taskID_origin,split)
        end
    else
        if mid then
            if not rec[from] then
                rec[from]={}
                rec[from].size=0
                if not rec.size then rec.size=0 end
                rec.size=rec.size+1
            end
            if not rec[from][mid] then
                rec[from][mid]=1
                if not rec[from].size then rec[from].size=0 end
                rec[from].size=rec[from].size+1
                local uptime=computer.uptime()
                if not recu[uptime] then recu[uptime]={} if not recu.size then recu.size=0 end recu.size=recu.size+1 end
                if not recu[uptime][from] then recu[uptime][from]={} end
                recu[uptime][from][mid]=1
                if not checkParts({_,_,from,port,_,message,mid,com,task_id,arg10,request_id,taskID_origin,split}) then
                    addTask({_,_,from,port,_,message,mid,com,task_id,arg10,request_id,taskID_origin,split})
                end
            else
                checkParts({_,_,from,port,_,message,mid,com,task_id,arg10,request_id,taskID_origin,split})
            end
        else
            modem.send(from,801,"message rejected, please use the modem_handler API to communicate with this PC")
        end
    end
end

function m.open(port)
    if type(port)=="number" then
        modem.open(port)
    else
        return false,"must be number"
    end
end

function m.note(from)
    if not rec[from].note then 
        rec[from].note=1
    else
        rec[from].note=rec[from].note+1
    end
    if rec[from].note>10 then
        rec[from].note=nil
        blacklist[from]=computer.uptime()+60
    end
end

function m.sendCommand(target,com,data,port)
    port=port or 801
    local id=f.addTask(function() hooks.m.send({target,port,data,com}) end)
    f.moveTo(nil,id)
    f.execute()
    return true
end

function m.remoteRequest(target,com,data,port,timeout,try)
    port=port or 801
    local id=f.addTask(function() hooks.m.send({target,port,data,com}) f.pause(function() end) end)
    f.moveTo(nil,id)
    f.execute()
    timeout=timeout or request_timeout
    while true do
        os.sleep(0.1)
        timeout=timeout-0.1
        if f.getStatus(id)=="ready" then
            local ret=f.getData(nil,id)[6]
            f.remove(id)
            return ret
        end
        if timeout<=0 then
            f.remove(id)
            if not try or try<4 then
                try=try or 2
                print("debug modem_handler: try "..try)
                return m.remoteRequest(target,com,data,port,timeout,try)
            end
            return false,"timed out"
        end
    end
end

function m.initialize(handler)
    rec={} --received_list
    rec.size=0
    recu={}
    f=handler
    if f~=nil then
        f.addEvent("modem_message",m.receive)
    end
    print("modem_handler started")
    timer=event.timer(30,free_cached_msg,math.huge) --temporary solution
end

function m.getBlacklist() return blacklist end
function m.blacklist(address,dt) blacklist[address]=computer.uptime()+dt return true end
function m.unlist(address) blacklist[address]=nil end
function m.stop() event.ignore("modem_message",m.receive) event.cancel(timer) rec=nil recu=nil end
function m.getReceived() return rec end
function m.getRecu() return recu end
function m.getParts() return parts end

return m