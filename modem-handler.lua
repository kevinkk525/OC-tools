------------------------------
local version="1.1b"
------------------------------
local serialization=require("serialization")
local component=require("component")
local modem=component.modem
local computer=require("computer")
local m={} --functions
local lifetime_msg=50
local rec={}
local parts={} --temporary storage for splitted messages
local exceptions={}
local blacklist={}
modem.open(801)
if modem.isWireless() then
    modem.setStrength(400)
end --add whitelist possibility
local function checkParts(data)
    if not data[13] then
        addTask(data)
    else
        if parts[data[7]]==nil then
            parts[data[7]]={}
        end
        if data[13]==0 then --add check of parts/ if parts missing-->error
            if not parts[data[7]][data[13]] then
                parts[data[7]][data[13]]=data[6]
                local msgtmp=""
                for i=1,#parts[data[7]] do
                    if parts[data[7]][i]~=nil then
                        msgtmp=msgtmp..parts[data[7]][i]
                    end
                end
                msgtmp=msgtmp..data[6]
                data[6]=msgtmp
                msgtmp=nil
                addTask(data)
            end
        else
            parts[data[7]][data[13]]=data[6]
        end
        return true
    end
end
function m.initialize(handler)
    rec={} --received_list, --format: rec_index="from" ,[from]:[messages]:[mid=uptime]][message=uptime] ,[note]
    exceptions={} --address_list for exceptions of blacklist check and message saving
    blacklist={} --[from]:[uptime],[blacklist-time]
    local file=io.open("blacklist","r")
    if file==nil then
        file=io.open("/lib/blacklist","w")
        file:close()
        file=io.open("/lib/blacklist","r")
    end
    local tmp=file:read("*all")
    if tmp~=nil then
        blacklist=serialization.unserialize(tmp) --maybe warn on corrupted saves
    end
    if blacklist==nil then
        blacklist={}
    end
    file:close()
    f=handler
    if f~=nil then
        f.addEvent("modem_message",m.receive)
    end
end
function free_cached_msg(data)
    local tmp={}
    local up=computer.uptime()-lifetime_msg
    for i=1,#rec[data],1 do
        if rec[data]["messages"][rec[data][i]]<up then
            if parts[rec[data][i]] then
                parts[rec[data][i]]=nil
            end
            rec[data]["messages"][rec[data][i]]=nil
            tmp[#tmp+1]=i
        end
    end
    for i=1,#tmp do
        table.remove(rec[data],tmp[i]-i+1)
    end
    tmp={}
end
function addTask(data) --f.addTask:command,data,id,source,status,add_Data,add_Data_position,priority
    data[6]=data[6] or ""
    local tmp=serialization.unserialize(data[6])
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
    f.addTask(com,data,id,"external") --data: 3:from,4:port,5:arg5,6:data
    return true
end
function m.send(data,answer) --[1]to,[2]port,[3]message,[4]com,[5]task-id (of request),[6]arg10,[7]source,[8]task-id of sending system(automatically added),[9]split message?
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
        end
        if type(data[i])~="nil" then
            length=length+tmp2[i]:len()
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
            os.sleep(0)
        end
    else
        modem.send(data[1],data[2],tmp2[3],tmp,tmp2[4],tmp2[5],tmp2[6],tmp2[7],data[8],data[9])
        modem.send(data[1],data[2],tmp2[3],tmp,tmp2[4],tmp2[5],tmp2[6],tmp2[7],data[8],data[9])
    end
    tmp=nil
    tmp2=nil
    return true 
end
function m.receive(a,b,c,d,e,f,g,h,i,j,k,l,n) --[1]event_name,[2]recieving_card-addr,[3]from,[4]port,arg5,[6]message,[7]mid,[8]com,[9]task-id,[10]arg10,[11]task-id of request,[12]task-id of sending system,[13]split
    local data={a,b,c,d,e,f,g,h,i,j,k,l,n}
    if exceptions[data[3]]==nil then
        if blacklist[data[3]]~=nil then
            if blacklist[data[3]][1]+blacklist[data[3]][2]>computer.uptime() or blacklist[data[3]][1]<computer.uptime() then
                blacklist[data[3]]=nil
                for i=1,#blacklist,1 do
                    if blacklist[i]==data[3] then
                        table.remove(blacklist,i)
                        break
                    end
                end
                m.receive(a,b,c,d,e,f,g,h,i,j,k,l,n)
            end
        else
            if data[7]~=nil then
                if rec[data[3]]~=nil then
                    free_cached_msg(data[3])
                    if checkParts(data) then
                        return true
                    end
                    if rec[data[3]]["messages"][data[7]]==nil then
                        rec[data[3]]["messages"][data[7]]=computer.uptime()
                        rec[data[3]][#rec[data[3]]+1]=data[7] 
                    end
                else
                    rec[data[3]]={}
                    rec[data[3]]["messages"]={}
                    rec[data[3]]["messages"][data[7]]=computer.uptime()
                    rec[#rec+1]=data[3]
                    rec[data[3]][#rec[data[3]]+1]=data[7]  
                    checkParts(data)              
                end
            else
                if rec[data[3]]~=nil then
                    free_cached_msg(data[3])
                    if rec[data[3]]["messages"][data[6]]==nil then
                        rec[data[3]][#rec[data[3]]+1]=data[6]
                        rec[data[3]]["messages"][data[6]]=computer.uptime()
                        checkParts(data)
                    end
                else 
                    rec[data[3]]={}
                    rec[data[3]]["messages"]={}
                    rec[data[3]]["messages"][data[6]]=computer.uptime()
                    rec[#rec+1]=data[3]
                    rec[data[3]][#rec[data[3]]+1]=data[6]
                    checkParts(data)
                end
            end
        end
    else
        if rec[data[3]]~=nil then
            free_cached_msg(data[3])
            if data[7]~=nil then
                if checkParts(data) then
                    return true
                end
                if rec[data[3]]["messages"][data[7]]~=nil then
                    rec[data[3]]["messages"][data[7]]=computer.uptime()
                end
            else
                m.send({data[3],data[4],"Please add MID!","warn"})
            end
        else
            if data[7]~=nil then
                rec[data[3]]={}
                rec[data[3]]["messages"]={}
                rec[data[3]]["messages"][data[7]]=computer.uptime()
                rec[#rec+1]=data[3]
                rec[data[3]][#rec[data[3]]+1]=data[7]
                checkParts(data)
            else
                m.send({data[3],data[4],"Please add MID!","warn"})
            end
        end
    end
end
function m.open(port)
    if port~=nil and type(port)=="number" then
        modem.open(port)
    else 
        f.error("Wrong port") --should be a warning
    end
end
function m.note(from)
    if rec[from].note==nil then
        rec[from].note=0
    end
    rec[from].note=rec[from].note+1
    if rec[from].note>10 then
        rec[from].note=nil
        blacklist[from]={}
        blacklist[from][1]=computer.uptime()
        blacklist[from][2]=20
        blacklist[#blacklist+1]=from
end end
function randID(x) local id=tostring(math.random(1,100)) if x==nil then if rec[id]~=nil then id=f.randID() end end return id end
function m.showBlacklist() return blacklist end
function m.showExceptions() return exceptions end
function m.setException(address) exceptions[address]=computer.uptime() end
function m.delException(address) exceptions[address]=nil end
function m.setBlacklist(address,t) blacklist[address]={} blacklist[address][1]=computer.uptime() blacklist[address][2]=t or 20 end
function m.delBlacklist(address) blacklist[address]=nil end
function m.stop() local file=io.open("/lib/blacklist","w") file:write(serialization.serialize(blacklist)) file:close() end
function m.listReceived() return rec end
return m