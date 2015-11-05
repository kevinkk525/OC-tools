debug=require("component").debug
local serialization=require"serialization"
data=loadfile("DataCenter.lua")()
local file=io.open("screens","r")
local screens
if file then
    screens=serialization.unserialize(file:read("*all"))
    file:close()
end

X,Y,Z=718,90,2070 -- Corner coords
Y=Y-42
w = debug.getWorld()
for i=1,#data do
  local x1,y1,z1,x2,y2,z2,id,meta = table.unpack(data[i])
  z1,z2 = -z1,-z2 -- Rotating
  meta = meta or 0

    w.setBlocks(x1+X,y1+Y,z1+Z,x2+X,y2+Y,z2+Z,id,meta)
    if screens then
        if screens[i] then
            local tmp=screens[i]
            local xk,yk,zk=1,1,1
            if x1~=math.abs(x1) then
                xk=-1
            end
            if y1~=math.abs(y1) then
                yk=-1
            end
            if z1~=math.abs(z1) then
                zk=-1
            end
            for x=math.abs(x1),math.abs(x2) do
                for y=math.abs(y1),math.abs(y2) do
                    for z=math.abs(z1),math.abs(z2) do
                        tmp.value.x={["type"]=3,["value"]=x*xk+X}
                        tmp.value.y={["type"]=3,["value"]=y*yk+Y}
                        tmp.value.z={["type"]=3,["value"]=z*zk+Z}
                        w.setTileNBT(x*xk+X,y*yk+Y,z*zk+Z,tmp)
                    end
                end
                os.sleep(0)
            end
        end
    end
end

--possible bug: if x1 and x2 are not both > or < 0, same for y1,y2 and z1,z2