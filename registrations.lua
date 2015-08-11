----------------------
local version="0.6b"
----------------------
local component=require("component")
local r={} --functions
local registrations={}
local fs=require("filesystem")
local serialization=require("serialization")
local computer=require("computer")
local password="H398FKri0NieoZ094nI"

--reminder: add update reference addresses on external call for all programs
--add multi-user system, password as table, registration list password dependand...

function r.initialize(handler)
    f=handler
    f.registerFunction(r.getRegistration,"getRegistration")
    f.registerFunction(r.unregisterDevice,"unregisterDevice")
    f.registerFunction(r.registerDevice,"registerDevice")
    f.registerFunction(r.listRegistrations,"listRegistrations")
    hooks.m.open(801)
    local file=io.open("/registrations","r")
    if file~=nil then
        registrations=serialization.unserialize(file:read("*all"))
        file:close()
    end
end
    
function r.registerDevice(stat_table)
    if stat_table[1]==password then
        if registrations[stat_table[2]]~=nil then
            for i=1,#registrations[stat_table[2]] do
                if registrations[stat_table[2]][i]==f.getData()[3] then
                    print("Registration as "..stat_table[2].." already added")
                    return "Already added"
                end
            end
            registrations[stat_table[2]][#registrations[stat_table[2]]+1]=f.getData()[3]
            r.save()
        else
            registrations[stat_table[2]]={}
            registrations[stat_table[2]][1]=f.getData()[3]
            registrations[#registrations+1]=stat_table[2]
            r.save()
            print(stat_table[2].." registered")
            return "Device added"
        end
    else
        hooks.m.note(f.getData()[3])
        print("wrong password")
        return "Wrong password"
    end
end

function r.unregisterDevice(stat_table) --add possibility to unregister different devices
    if stat_table[1]==password then
        if registrations[stat_table[2]]~=nil then
            for i=1,#registrations[stat_table[2]] do
                if registrations[stat_table[2]][i]==f.getData()[3] then
                    table.remove(registrations[stat_table[2]],i)
                    if #registrations[stat_table[2]]==0 then
                        registrations[stat_table[2]]=nil
                        for i=1,#registrations do
                            if registrations[i]==stat_table[2] then
                                table.remove(registrations,i)
                            end
                        end
                    end
                    r.save()
                    print("Removed registration for "..stat_table[2])
                    return "Device unregistered"
                end
            end
            print(stat_table[2].." not registered")
            return "Device not registered"
        else
            print(stat_table[2].." not registered")
            return "Device not registered"
        end
    else
        hooks.m.note(f.getData()[3])
        print("wrong password")
        return "Wrong password"
    end
end

function r.getRegistration(stat_table)
    if stat_table[1]==password then
        if registrations[stat_table[2]]==nil then
            return "No registration"
        else
            return registrations[stat_table[2]]
        end
    else
        hooks.m.note(f.getData()[3])
        return "Wrong password"
    end
end

function r.listRegistrations()
    return registrations
end

function r.save()
    r.stop()
end

function r.stop()
    local file=io.open("/registrations","w")
    file:write(serialization.serialize(registrations))
    file:close()
end

    
    
    
return r
