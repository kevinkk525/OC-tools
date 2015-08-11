local serialization=require"serialization"
--deprecated...

local c={}
local d={} 

function c.loadDB(path)
    local file=io.open(path,"r")
    if file==nil then 
        print("wrong path")
    else
        d=file:read("*all")
        file:close()
        d=serialization.unserialize(d)
        print("DB loaded")
    end
end

function c.convert(db)
    db=db or d
    for i=1,#db do 
        local ident=db[i]
        local nident=serialization.serialize({db[db[i]].label,db[db[i]].name,db[db[i]].hasTag,db[db[i]].damage})
        db[i]=nident
        db[nident]=db[ident]
        db[ident]=nil
        ident=nil
        nident=nil
    end
    print("conversion done")
end

function c.saveDB(path,db)
    db=db or d
    local db=serialization.serialize(db)
    local file=io.open(path,"w")
    if file==nil then
        print("wrong path")
    else
        file:write(db)
        file:close()
        print("file saved")
    end
end

function c.autoConvert(path,db,exists)
    if exists~=true and path~=nil and db~=nil then
        c.convert(db)
        c.saveDB(path,db)
    elseif path~=nil and db==nil then
        c.loadDB(path)
        c.convert()
        c.saveDB(path)
    elseif db~=nil then
        c.convert(db)
    end
end

function c.getDB()
    return d
end

return c