---config section
local version="0.9.9.9.9b"
---
----- rewrite this more object oriented!!

local math=require("math")
local table=require("table")
local serialization=require("serialization")
local event=require("event")
local f={} --functions
local r={}
local events={}
local state={}
local priority_tasks={}
local del_after_exec={}
hooks={}
local ext={}
local task_timeout=30

--add coroutine possibility to pause() & continue()
--add f.warning()
--add return true/false to functions
--dynamic form of error/warning depending on hook-system
--"list"-functions may be unsafe with return table
--on false usage return correct one
--add automatic_update
--add private network function through registration system (internal execution)

local function added()
    r[#r].com(r[#r].data)
end

local function waiting()
    increment("timeout")
    if r[r[#r].id]==nil then
        f.remove()
    else 
        table.insert(r,1,r[#r])
        table.remove(r,#r)
    end
end

local function standard()
    added()
end


function f.error(x) --should be optimized
    print(x)
    f.stop()
end

function f.stop()
    for i=1,#hooks,1 do
        if hooks[hooks[i]].stop~=nil then
            hooks[hooks[i]].stop()
        end
    end
    for i=1,#events do
        if events[events[i]]~=nil and events[events[i]][0]~=nil then
            for j=1,#events[events[i]] do
                event.ignore(events[i],events[events[i]][j])
            end
        end
    end
    running=false
end

function f.initialize(req,modem) --Initialize task-table
    r={} --requests/task-table
    events={} --event_list
    state={} --status_list
    del_after_exec={}
    r=req or r
    priority_tasks={}
    ext={} --external commands: safe to be executed my clients
    state["added"]={}
    state["added"][1]=added
    state["waiting"]={}
    state["waiting"][1]=waiting
    state["ready"]={}
    state["ready"][1]=standard
    state["standard"]={}
    state["standard"][1]=standard
    del_after_exec["added"]=true
    del_after_exec["standard"]=true
    del_after_exec["ready"]=true
    if modem~=false then
        hooks["m"]=require("modem_handler")
        hooks.m.initialize(f)
        f.remoteRequest=hooks.m.remoteRequest
        f.sendCommand=hooks.m.sendCommand
    end
end

function f.addHook(name, handler_filename)
    if type(name)~="string" or type(handler_filename)~="string" then
        f.error("Must be strings")
    else
        hooks[name]=require(handler_filename)
        if hooks[name].initialize~=nil then
            hooks[name].initialize(f)
        end
        hooks[#hooks+1]=name
        return hooks[name]
    end
end

function f.removeHook(name)
    hooks[name]=nil
    for i=1,#hooks,1 do
        if hooks[i]==name then
            table.remove(hooks,i)
            break
        end
    end
end

function f.randID()
    local id=tostring(math.random(1,1000))
    if r[id]~=nil then
        id=f.randID()
    end
    return id
end

function f.addTask(command,data,id,source,status,add_Data_position,add_Data,priority,override_id)
    local adding=true
    source=source or "internal"
    if command==nil and id==nil and status==nil and source=="external" and data==nil then
        f.error("task with no command or id")
    end
    command=command or nil
    data=data or ""
    add_Data=add_Data or nil
    add_Data_position=add_Data_position or 1
    status=status or "added"
    if id~=nil then
        status="ready"
        if r[id]==nil then
            adding=false
        end
    end
    if override_id==nil then
        id=id or f.randID()
    else
        id=override_id
    end
    local tmp={}
    ------------- task structure
    tmp.source=source
    tmp.com=command
    tmp.data=data
    tmp.status=status
    tmp.timeout=0
    tmp.lifetime=0
    tmp.id=id
    tmp[add_Data_position]=add_Data
    -------------
    if adding==true then
        if status=="ready" then
            if r[id] then 
                r[id].status="ready"
                tmp=r[id]
                tmp.data=data
            end
        end
        if priority==nil then
            table.insert(r,1,tmp)
        elseif priority=="permanent" then
            table.insert(priority_tasks,#priority_tasks+1,tmp)
        end
    else 
        id="wrong ID"
        if source=="external" and hooks.m~=nil then
            hooks.m.note(data[3])
        end
    end
    tmp=nil
    return id
end

function f.remove(x)
    f.delete(x)
end

function f.delete(x)
    x=x or #r
    if r[x] then
        if r[x].delete~=nil then
            r[x].delete()
        elseif r[x].remove~=nil then
            r[x].remove()
        end 
        r[x].id="remove"
    end
    if type(x)=="number" then
        if r[r[x].id] then
            r[r[x].id]=nil
        end
        table.remove(r,x)
    else
        r[x]=nil
        for i=1,#r do
            if r[i] and r[i].id==x then
                table.remove(r,i)
            end
        end
    end
end

function f.setRemove(com,x)
    x=x or #r
    if type(com)=="function" then
        r[x].delete=com
    else
        return false,"not a function"
    end
end

function f.setDelete(com,x) f.setRemove(com,x) end
    
function f.addEvent(event_name,function_pointer) --function_pointer must be a function!
    if events[event_name]==nil then   
        events[event_name]={}           
    else 
        for i=1,#events[event_name],1 do
            if events[event_name][i]==function_pointer then
                f.error("Event already added") --should be a warning
                break
            end
        end
    end
    events[event_name][#events[event_name]+1]=function_pointer
    event.listen(event_name,function_pointer)
end

function f.removeEvent(event_name,function_pointer)
    if function_pointer=="*" then
        events[event_name]=nil
    else
        if events[event_name]~=nil then
            if #events[event_name]<2 then
                events[event_name]=nil
            else
                for i=1,#events[event_name],1 do
                    if events[event_name][i]==function_pointer then
                        table.remove(events[event_name],i)
                        event.ignore(event_name,function_pointer)
                        break
                    end
                end
            end
        end
    end
end

function f.removeVipTask(id)
    for i=1,#priority_tasks,1 do
        if priority_tasks[i].id==id then
            if priority_tasks[i].delete~=nil then
                priority_tasks[i].delete()
            else
                table.remove(priority_tasks,i)
            end
            break
        end
    end
end

function f.pause(com) --pause and save next command
    r[#r].com=com 
    r[r[#r].id]=r[#r] --reminder: no duplicate saving because of shallow copy
    r[#r].status="waiting"
    table.insert(r,1,r[#r])
    table.remove(r,#r)
end

function f.execute(short) --short: execution without dynamic sleep time
    if r[#r]~=nil then
        if r[#r].id=="remove" then
            f.remove()
        end
    end
    if not short then
        local rc=#r
        for i=1,rc do
            if r[i].getStatus=="waiting" then
                rc=rc-1
            end
        end
        if rc==0 then
            os.sleep(1)
        else
            os.sleep(0.1)
        end
    end
    local exec=true
    if #r==0 then
        exec=false
    end
    if exec==true then
        local exec=true
        increment("lifetime")
        if r[#r].timeout==task_timeout then
            r[r[#r].id]=nil
            f.remove()
            exec=false
        end
        if exec then
            if state[r[#r].status]~=nil then
                local tmp=#r
                local tmp_id=r[#r].id
                if r[#r].source~="external" then
                    for i=1,#state[r[#r].status],1 do
                        state[r[#r].status][i](r[#r].data)
                    end
                else 
                    if ext[r[#r].com]~=nil then
                        local tmp_return
                        if r[#r].data[10]~=1 then
                            tmp_return=ext[r[#r].com](r[#r].data[6])
                        else
                            tmp_return=ext[r[#r].com](r[#r].data)
                        end
                        if tmp_return~=nil then
                            hooks.m.send({r[#r].data[3],r[#r].data[4],tmp_return,nil,r[#r].data[9] or r[#r].data[11]},true)
                        end
                    else 
                        if hooks.m~=nil then
                            if hooks.m.note~=nil then
                                hooks.m.note(r[#r].data[3])
                                hooks.m.send({r[#r].data[3],r[#r].data[4],false,nil,r[#r].data[9] or r[#r].data[11]},true)
                            end
                        end
                    end
                end
                if r[#r]~=nil and r[#r].id==tmp_id and del_after_exec[r[#r].status] then
                    f.remove()
                elseif r[#r]~=nil and r[#r].id==tmp_id and del_after_exec[r[#r].status]==false then
                    f.moveTo(1)
                end
            elseif state[r[#r].status]==nil then
                f.error("Task with wrong status or status not added")
            end
        end
    end
    if #priority_tasks>0 then
        for i=1,#priority_tasks,1 do
            --for j=1,#state[priority_tasks[i].status],1 do
                priority_tasks[i].com(priority_tasks[i].data) --priority tasks currently only support internal execution without state support and wait
            --end
        end
    end
end

function f.addStatus(status_name,function_pointer,del_after_execution)
    del_after_execution=del_after_execution or true
    if state[status_name]==nil then
        state[status_name]={}
        state[status_name][1]=function_pointer
        del_after_exec[status_name]=del_after_execution
    else 
        state[status_name][#state[status_name]+1]=function_pointer
    end
end

function f.removeStatus(status_name,function_pointer)
    if function_pointer=="*" then
        state[status_name]=nil
    else
        if #state[status_name]>1 then
            for i=1,#state[status_name],1 do
                if state[status_name][i]==function_pointer then
                    table.remove(state[status_name],i)
                    break
                end
            end
        else
            state[status_name]=nil
        end
    end
end

function increment(x,i)
    i=i or 1
    r[#r][x]=r[#r][x]+i
end

function f.listEvents()
    return events
end

function f.listStates()
    return state
end

function f.listTasks()
    return r
end

function f.listVipTasks()
    return priority_tasks
end

function f.listTaskElem(x)
    x=x or #r
    return r[x]
end

function f.addData(x,i)
    i=i or "data"
    r[#r][i]=x
end
    
function f.getData(i,p)
    i=i or "data"
    p=p or #r
    return r[p][i]
end

function f.getTimeout()
    return r[#r].timeout
end

function f.getLifetime()
    return r[#r].lifetime
end

function f.getStatus(id)
    id=id or #r
    if r[id] then
        return r[id].status
    end
end

function f.getID()
    return r[#r].id
end

function f.getSource()
    return r[#r].source
end

function f.setCom(x)
    if type(x)=="function" then
        r[#r].com=x
    else 
        f.error("Command has to be a function")
    end
end
 
function f.moveTo(x,id)
    x=x or #r
    if not id then
        table.insert(r,x,r[#r])
        table.remove(r,#r)
    else
        for i=1,#r do
            if r[i].id==id then
                local tmp=r[i]
                table.remove(r,i)
                table.insert(r,x,tmp)
                break
            end
        end
    end
end

function f.registerFunction(function_pointer,name,overwrite) --pointer or table; because of simplicity and resource saving all functions will
    if overwrite~=true then                               --be called directly, not through an external table like f["g.print"]
        overwrite=nil
    end
    if type(function_pointer)=="function" then             
        if f[function_pointer]~=nil and overwrite~=true then
            f.error("function exists already!") --should be a warning
        else 
            f[name]=function_pointer
            ext[name]=f[name]
        end
    elseif type(function_pointer)=="table" then --table have to have an index of their functions like [1]="function_name"
        for i=1,#function_pointer,1 do
            if f[function_pointer[i]]~=nil then
                f.error("Function "..function_pointer[i].." already exists!")
            else
                f[function_pointer[i]]=function_pointer[function_pointer[i]]
                ext[function_pointer[i]]=f[function_pointer[i]]
            end
        end
    end --maybe add return at success
end
 
function f.unregisterFunction(function_pointer,name)
    if type(function_pointer)=="function" then
        if f[name]~=nil then
            f[name]=nil
            ext[name]=nil
        else
            f.error("Function does not exist") --should be a warning (with gui pop-up?)
        end
    elseif type(function_pointer)=="table" then
        for i=1,#function_pointer,1 do
            if f[function_pointer[i]]~=nil then
                f[function_pointer[i]]=nil
                ext[function_pointer[i]]=nil
            else
                f.error("Function "..function_pointer[i].." does not exist!") --should be a warning
            end
        end
    end
end

function f.listExtFunctions()
    return ext
end
 
return f