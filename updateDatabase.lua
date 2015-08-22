stupid idea...
--------------
local version="0.1b"
--------------
local database_entries=81

local component=require"component"
local me=component.me_controller
local f=require"req_handler"
f.initialize()
local database={}  --fake database
local databases={} --components


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

regServer()
--local shopHost=f.remoteRequest(registrationServer,"getRegistration",{"H398FKri0NieoZ094nI","ShopHost"})[1]
--print(f.remoteRequest(registrationServer,"registerDevice",{"H398FKri0NieoZ094nI","DatabaseUpdater"}))

function initDatabase()
    local tmp={}
    databases={}
    for a,b in component.list("database") do
        tmp[#tmp+1]=a
    end
    for i=1,#tmp do
        databases[i]=component.proxy(tmp[i])
    end  
    database.address=databases[1].address
end

------------------------------

function database.indexOf(ind)
    for i=1,#databases do
        if databases[i].indexOf(ind)>0 then
            database.address=databases[i].address
            return databases[i].indexOf(ind)
        end
    end
    return -1
end

function database.computeHash(slot)
    for i=1,#databases do
        if databases[i].address==database.address then
            return databases[i].computeHash(slot)
        end
    end
end

function database.setAddress(add)
    database.address=add
end

function database.nextAddress()
    for i=1,#databases do
        if databases[i].address==database.address then
            i=i+1 
            if i>#databases then
                i=i-#databases
            end
            database.address=databases[i].address
            break
        end
    end
end

function database.get(slot)
    for i=1,#databases do
        if databases[i].address==database.address then
            return databases[i].get(slot)
        end
    end
end 

function database.clear(slot,address)
    address=addess or database.address
    for i=1,#databases do
        if databases[i].address==address then
            return databases[i].clear(slot)
        end
    end
end

------------------------------

local function insert(items,i,hash)
    for j=2,database_entries do
        if not database.get(j) then
            me.store(items[i],database.address,j)
            print(hash.." "..database.address.." "..j)
            return true
        end
        os.sleep(0)
    end
    return false
end


function f.updateDatabase()
    initDatabase()
    local items=me.getItemsInNetwork()
    local item_table={}
    print("found #items: "..items.n)
    for i=1,items.n do
        items[i].size=nil
        database.clear(1)
        me.store(items[i],database.address,1)
        local hash=database.computeHash(1)
        local address=database.address
        database.clear(1)
        if database.indexOf(hash)>0 then
            database.setAddress(address)
        else
            while true do
                if not insert(items,i,hash) then
                    database.nextAddress()
                    os.sleep(0.1)
                else
                    item_table[hash]=items[i]
                    break
                end
            end
        end
        os.sleep(0.1)
    end
    return item_table
end

f.registerFunction(f.updateDatabase,"updateDatabase")
function f.getDatabase() return database end

return f