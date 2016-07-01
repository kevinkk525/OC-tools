------
local version="0.4"
------

local component=require("component")


local x={} --exchange functions
--tables pointing from money to value and value to money
local money={["100 Craft Notes Pallet (s) (6400)"]=6400,
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
local money_i={[6400]="100 Craft Notes Pallet (s) (6400)",
[12800]="200 Craft Notes Pallet (s) (12800)",
[32000]="500 Craft Notes Pallet (s) (32000)",
[128]="2 Craft Notes Pallet (s) (128)",
[64]="1 Craft Notes Pallet (s) (64)",
[3200]="50 Craft Notes Pallet (s) (3200)",
[320]="5 Craft Notes Pallet (s) (320)",
[1280]="20 Craft Notes Pallet (s) (1280)",
[64000]="1000 Craft Notes Pallet (s) (64000)",
[640]="10 Craft Notes Pallet (s) (640)",
[20]="20 Craft Note (s)",
[4000]="500 Craft Notes Bundle (s)",
[400]="50 Craft Notes Bundle (s)",
[80]="10 Craft Notes Bundle (s)",
[200]="200 Craft Note (s)",
[100]="100 Craft Note (s)",
[1]="1 Craft Note (s)",
[2]="2 Craft Note (s)",
[500]="500 Craft Note (s)",
[8000]="1000 Craft Notes Bundle (s)",
[50]="50 Craft Note (s)",
[160]="20 Craft Notes Bundle (s)",
[5]="5 Craft Note (s)",
[0.2]="20 Craft Cent (s)",
[0.1]="10 Craft Cent (s)",
[800]="100 Craft Notes Bundle (s)",
[1600]="200 Craft Notes Bundle (s)",
[40]="5 Craft Notes Bundle (s)",
[1000]="1000 Craft Note (s)",
[0.5]="50 Craft Cent (s)",
[10]="10 Craft Note (s)",
[8]="1 Craft Notes Bundle (s)",
[16]="2 Craft Notes Bundle (s)"} 
local value={64000,32000,12800,8000,6400,4000,3200,1600,1280,1000,800,640,500,400,320,200,160,128,100,80,64,50,40,20,16,10,8,5,2,1,0.5,0.2,0.1} --simple value table

local function divide(a,b)
    local e=-1
    while a>=0 do
        a=a-b
        e=e+1
    end
    local r=a+b
    return e,r
end

function x.exchange(input,smaller) --exchanges every input in smaller amounts
    smaller=smaller or false
    local back={}
    if type(input)~="integer" and type(input)~="number" then
        return "wrong parameter"
    else
        local i=1
        if smaller==false then
            while value[i]>input do
                i=i+1
            end
        else
            while value[i]>=input do
                i=i+1
            end
        end
        local e=0
        for j=i,#value,1 do
            e,input=divide(input,value[j])
            if e~=0 then
                back[#back+1]={}
                back[#back][1]=money_i[value[j]]
                back[#back][2]=e
            end
        end
        back.rest=input
    end
    return back
end

function x.count(input) --count given money table
    if type(input)~="table" then
        return "Parameter must be table!"
    else
        local erg=0
        for i in pairs(input) do
            if tpye(input[i])~="number" then
                local mon=input[i]
                if type(mon)=="string" and input[mon]~=nil then
                    mon=input[mon]
                end
                if money[mon.label] then
                    erg=erg+money[mon.label]*mon.size
                end
            end
        end
        return erg
    end
end

function x.check() --check money_entries for integrity
    for i=1,#value,1 do 
        if money[money_i[value[i]]]==value[i] then
            print("passed value "..value[i])
        else
            print("not the same value at value "..value[i])
        end
    end
    print("equality test passed")
    local cr=component.me_controller.getItemsInNetwork()--getCraftables()
    local craft={}
    for i=1,#cr,1 do
        craft[i]=cr[i].label--getItemStack().label
    end
    print("done pulling craftables")
    for i=1,#value,1 do
        for j=1,#craft,1 do
            if craft[j]==money_i[value[i]] then
                print(craft[j].." found")
                break
            end
        end
    end
    print("test complete")
end

function x.getMoney()
    return money
end

return x
