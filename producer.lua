---config section
local version="0.9.9.5b"
local production_number=100
local overproduction=production_number/5
local cpus=25
local craft_update_time=300
local update_time=30
---

local component=require("component")
local serialization=require("serialization")
local computer=require("computer")
local p={} --functions
local me
local me_address
tmp={}
for a,b in component.list("me_controller") do tmp[#tmp+1]=a end
tmp2={}
for i=1,#tmp do tmp2[i]=component.proxy(tmp[i]) end
for i=1,#tmp2 do if #tmp2[i].getItemsInNetwork()>0 then me_address=tmp[i] end end
tmp=nil
tmp2=nil 
inProgress={}
index={} --remove local for debugging
craftables={}
items={}
local ctime=computer.uptime()
local chtime=ctime-180
local amount=1000
local last_i=1
local blacklist={["100 Craft Notes Pallet (s) (6400)"]=6400,
["200 Craft Notes Pallet (s) (12800)"]=12800,
["500 Craft Notes Pallet (s) (32000)"]=32000,
["2 Craft Notes Pallet (s) (128)"]=128,
["1 Craft Notes Pallet (s) (64)"]=64,
["50 Craft Notes Pallet (s) (3200)"]=3200,
["5 Craft Notes Pallet (s) (320)"]=320,
["20 Craft Notes Pallet (s) (1280)"]=1280,
["1000 Craft Notes Pallet (s) (64000)"]=64000,
["10 Craft Notes Pallet (s) (640)"]=640,
["20 Craft Note (s)"]=20,
["500 Craft Notes Bundle (s)"]=4000,
["50 Craft Notes Bundle (s)"]=400,
["10 Craft Notes Bundle (s)"]=80,
["200 Craft Note (s)"]=200,
["100 Craft Note (s)"]=100,
["1 Craft Note (s)"]=1,
["2 Craft Note (s)"]=2,
["500 Craft Note (s)"]=500,
["1000 Craft Notes Bundle (s)"]=8000,
["50 Craft Note (s)"]=50,
["20 Craft Notes Bundle (s)"]=160,
["5 Craft Note (s)"]=5,
["20 Craft Cent (s)"]=0.2,
["10 Craft Cent (s)"]=0.1,
["100 Craft Notes Bundle (s)"]=800,
["200 Craft Notes Bundle (s)"]=1600,
["5 Craft Notes Bundle (s)"]=40,
["1000 Craft Note (s)"]=1000,
["50 Craft Cent (s)"]=0.5,
["10 Craft Note (s)"]=10,
["1 Craft Notes Bundle (s)"]=8,
["2 Craft Notes Bundle (s)"]=16}

--add saving to file and starting from file --> not working because of task-object
--add function to add to blacklist or remove from it
--generally: return table is a security risk! (or debug possibility...)

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

function p.initialize(handler)
    f=handler
    f.addTask(p.produce)
end

function p.produce()
    me=component.proxy(me_address)
    if me==nil then
        print("no me, trying again")
    else
        if check_time()==true then
            p.craftables_pull()
            if check_production()==true then
                p.items_pull()
                local it=1
                for i=last_i,#craftables do
                    if #inProgress>=cpus then
                        break
                    else
                        local name=craftables[i].getItemStack()
                        local tmp=items[items.ident[getIdent(name)]]
                        if tmp then
                            if tmp.size<production_number then
                                local tmp2
                                tmp2=getIdent(tmp)
                                if index[tmp2]==nil and blacklist[tmp.label]==nil and blacklist[tmp2]==nil then
                                    inProgress[#inProgress+1]=craftables[i].request(20)--production_number+overproduction-tmp.size)
                                    if inProgress[#inProgress].isCanceled()==true then
                                        print(tmp2)
                                        table.remove(inProgress,#inProgress)
                                        --add second chance (lower production amount)
                                    else
                                        index[#index+1]=tmp2
                                        index[tmp2]=#index
                                    end
                                end
                                tmp2=nil
                            end
                            tmp=nil name=nil
                            it=i
                        end
                    end
                end
                last_i=it it=nil
                if last_i==#craftables then
                    last_i=1
                end
            end
        end
    end
    --f.addTask(p.produce)
    if not f then
        os.sleep(1)
    end
end

function p.listTasks()
    return inProgress
end

function check_time()
    if chtime<computer.uptime()-update_time then
        chtime=computer.uptime()
        return true
    else
        return false
    end
end

function check_production()
    if #inProgress==0 then
        return true
    else
        local tmp={}
        for i=1,#inProgress do
            if inProgress[i].isDone()==true or inProgress[i].isCanceled()==true then
                if inProgress[i].isCanceled()==true then
                    print(index[i])
                else

                end
                index[index[i]]=nil
                tmp[#tmp+1]=i
            end
        end
        for i=1,#tmp do
            table.remove(inProgress,tmp[i]-i+1)
            table.remove(index,tmp[i]-i+1)
        end
        tmp=nil
        if #inProgress<cpus then
            return true
        else
            return false
        end
    end
end

function p.craftables_pull()
    local ctime2=computer.uptime()
    if ctime2-ctime>craft_update_time or ctime2-ctime<0 or #craftables==0 then
        ctime=ctime2
        craftables=nil
        craftables=me.getCraftables()
    end
    ctime2=nil
end

function p.items_pull()
    items=nil
    items=me.getItemsInNetwork()
    items.ident={}
    for i=1,#items do
        local j=items[i]
        local name=getIdent(j)
        items.ident[name]=i
        name=nil j=nil
    end
end


return p