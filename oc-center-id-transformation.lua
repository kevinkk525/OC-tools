-- id transformation program
--usage: put in /lib and require, then generateIndex()

local serialization=require"serialization"
local c={}
print("Enter filename or enter for default")
local file=io.read()
if file=="" or file==nil then file="DataCenter.lua" end
local data=loadfile(file)()
local index={}
index.r={}

function c.generateIndex()
    for i=1,#data do
        if not index[tostring(data[i][7])] then
            index[tostring(data[i][7])]=#index.r+1
            index.r[#index.r+1]=data[i][7]
        end
        os.sleep(0)
    end
    print("Done, found "..tostring(#index.r).." unique IDs")
    local tmp=""
    for i=1,#index.r do tmp=tmp..tostring(index.r[i]).."," end
    print("IDs: "..tmp)
    return index
end

function c.getIndex()
    return index
end

function c.searchID(id,printing)
    local erg={}
    erg.r={}
    for i=1,#data do
        if data[i][7]==id then
            if printing then 
                local tmp=""
                for j=1,#data[i] do tmp=tmp..data[i][j].."," end
                print(tmp)
            end
            erg[#erg+1]=data[i]
            erg.r[#erg.r+1]=i
        end
    end
    return erg
end

function c.replaceID(oid,nid)
    for i=1,#data do
        if data[i][7]==oid then
            data[i][7]=nid
        end
    end
    index.r[index[tostring(oid)]]=nid
    index[tostring(nid)]=index[tostring(oid)]
    index[tostring(oid)]=nil
    print("Done, replaced "..oid.." with "..nid)
end

function c.replaceID_Meta(oid,ometa,nid,nmeta)
    for i=1,#data do
        if data[i][7]==oid and data[i][8]==ometa then
            data[i][7]=nid
            data[i][8]=nmeta
        end
    end
    print("Done, replaced "..oid..","..ometa.." with "..nid..","..nmeta)
end

function c.save(filename,backup)
    if type(filename)~="string" then
        filename="DataCenter.lua"
    end
    if filename:sub(filename:len()-3,filename:len())~=".lua" then
        filename=filename..".lua"
    end
    if backup and filename=="DataCenter" then
        print("not implemented..")
        return 0
    end
    local tmp="return {\n"
    for i=1,#data do
        tmp=tmp.."{"
        for j=1,#data[i] do
            tmp=tmp..data[i][j]
            if j~=#data[i] then
                tmp=tmp..","
            end
        end
        tmp=tmp.."},\n"
        os.sleep(0)
    end
    tmp=tmp.."}"
    local file=io.open(filename,"w")
    file:write(tmp)
    file:close()
    print("file saved")
end

function c.checkMetaEquality(id)
    local ind=c.searchID(id)
    local tmp=ind[1][8]
    print(tmp)
    for i=2,#ind do
        if ind[i][8]~=tmp then
            print(ind[i][8])
        end
    end
end

function c.findMetaDifferences()
    local diff={}
    diff.r={}
    for i=1,#index.r do
        local ind=c.searchID(index.r[i])
        local tmp=ind[1][8]
        for j=2,#ind do
            if ind[j][8]~=tmp then
                if not diff.r[index.r[i]] then
                    diff.r[index.r[i]]=#diff+1
                    diff[#diff+1]=index.r[i]
                end
            end
        end
    end
    print("There are "..#diff.." ids with no equal metadata")
    local tmp=""
    for i=1,#diff do 
        tmp=tmp..diff[i]..","
    end
    print("Those ids are: "..tmp)
end

function c.fixScreenOrientation(id,startx,starty,startz)
    local component=require"component"
    local debug=component.debug
    local w=debug.getWorld()
    print("building must be real..")
    if not id then print("need screen id") return 0 end
    if not startx or not starty or not startz then print("coords needed") return 0 end
    local screens={}
    local blocks=c.searchID(id)
    for i=1,#blocks.r do
        local tmp=w.getTileNBT(startx+blocks[i][1],starty+blocks[i][2],startz-blocks[i][3])
        screens[blocks.r[i]]={["type"]=10,["value"]={}}
        screens[blocks.r[i]].value["oc:yaw"]=tmp.value["oc:yaw"]
        screens[blocks.r[i]].value["oc:tier"]=tmp.value["oc:tier"]
        os.sleep(0)
    end
    file=io.open("screens","w")
    file:write(serialization.serialize(screens))
    file:close()
    print("done")
    return screens
end

return c