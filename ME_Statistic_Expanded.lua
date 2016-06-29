---
local version="0.8b"
---

local component=require("component")
local event = require("event")
local fs = require("filesystem")
local keyboard = require("keyboard")
local shell = require("shell")
local term = require("term")
local text = require("text")
local unicode = require("unicode")
local sides = require("sides")
local colors=require("colors")
local serialization=require("serialization")
local modem=component.modem
if modem.isWireless() then 
    modem.setStrength(400)
end
gpu=component.gpu
local running=true
local stats_now=false
local hours=0
local mins=0
local tickCnt=0
local ME=component.me_controller
local items_tmp=ME.getItemsInNetwork()
local fluids_tmp=ME.getFluidsInNetwork()
local fluids={}
local items={}
local difference={}
local w,h = gpu.getResolution()
local per_row=h-12
local rows=math.floor(w/53)
local table=require("table")
local dict={}
local input={}
local output={}
local differ={}

i=1
while i<(#items_tmp+1) do
    items[items_tmp[i].label]=items_tmp[i].size
    dict[i]=items_tmp[i].label
    dict[items_tmp[i].label]=i
    i=i+1
end
items_tmp={}
i=1
while i<(#fluids_tmp+1) do
    items[fluids_tmp[i].name.."_fluid"]=fluids_tmp[i].amount
    dict[#dict+1]=fluids_tmp[i].name.."_fluid"
    dict[fluids_tmp[i].name.."_fluid"]=#dict
    i=i+1
end
fluids_tmp={}


term.clear()
term.setCursorBlink(false)
-------------------------------------------------------------------------------
function getKey()
    return (select(4, event.pull("key_down")))
end
local function printXY(row, col, s, ...)
    term.setCursor(col, row)
    print(s:format(...))
end
local function gotoXY(row, col)
    term.setCursor(col,row)
end
local function center(row, msg)
    local mLen = string.len(msg)
    term.setCursor((w - mLen)/2,row)
    print(msg)
end
local function centerF(row, msg, ...)
    local mLen = string.len(msg)
    term.setCursor((w - mLen)/2,row)
    print(msg:format(...))
end
local function warning(row, msg)
    local mLen = string.len(msg)
    term.setCursor((w - mLen)/2,row)
    print(msg)
end

local controlKeyCombos = {[keyboard.keys.s]=true,[keyboard.keys.w]=true,
                        [keyboard.keys.c]=true,[keyboard.keys.x]=true}
                        
local function onKeyDown(opt)
    if opt == keyboard.keys.left then

    elseif opt == keyboard.keys.right then

    elseif opt == keyboard.keys.up then

    elseif opt == keyboard.keys.down then
    
    elseif opt == keyboard.keys.pageDown then
    
    elseif opt== keyboard.keys.n then
        input={}
        output={}
        differ={}
        difference={}
        term.clear()
    
    elseif opt == keyboard.keys.q then
        running = false
    end
end

local function SI(number)
    if number>=1000000 then
        return tostring(math.floor(number/100000)/10).."M"
    elseif number >=1000 then
        return tostring(math.floor(number/100)/10).."K"
    end
    return tostring(number)
end


-------------------------------------------------------------------------------

while running do
    tickCnt = tickCnt + 1
    if tickCnt == 60 then
        mins = mins + 1
        tickCnt = 0
    end
    if mins == 60 then
        hours = hours + 1
        mins = 0
    end

    term.setCursor(1,1)
    print("ME_Stats_Expanded")
    
    if running==true then
        items_tmpp=ME.getItemsInNetwork()
        fluids_tmpp=ME.getFluidsInNetwork()
        i=1
        while i<(#items_tmpp+1) do
            items_tmp[items_tmpp[i].label]=items_tmpp[i].size
            if dict[items_tmpp[i].label]==nil then
                dict[#dict+1]=items_tmpp[i].label
                dict[items_tmpp[i].label]=#dict
            end
            i=i+1
        end
        items_tmpp={}
        i=1
        while i<(#fluids_tmpp+1) do
            items_tmp[fluids_tmpp[i].name.."_fluid"]=fluids_tmpp[i].amount
            if dict[fluids_tmpp[i].name.."_fluid"]==nil then
                dict[#dict+1]=fluids_tmpp[i].name.."_fluid"
                dict[fluids_tmpp[i].name.."_fluid"]=#dict
            end
            i=i+1
        end
        fluids_tmpp={}
        items_tmp[1]="do it"
    end
    if items_tmp[1]~=nil then
        i=1
        j=1
        while i<#dict+1 do
            if items[dict[i]]==nil then
                items[dict[i]]=0
            end
            if items_tmp[dict[i]]==nil then
                items_tmp[dict[i]]=0
            end
            if items[dict[i]]~= items_tmp[dict[i]] then
                difference[j]={}
                difference[j][1]=dict[i]
                difference[j][2]=items_tmp[dict[i]]-items[dict[i]]
                if input[dict[i]]==nil then
                    input[dict[i]]=0
                    output[dict[i]]=0
                end
                if difference[j][2]>0 then
                    input[dict[i]]=input[dict[i]]+difference[j][2]
                elseif difference[j][2]<0 then
                    output[dict[i]]=output[dict[i]]+difference[j][2]
                end
                j=j+1
            end
            if input[dict[i]]~=nil then
                if differ[dict[i]]==nil then
                    differ[#differ+1]=dict[i]
                    differ[dict[i]]=1
                end
            end
            i=i+1
        end
        -------
        k=1
        m=0
        --term.clear()
        while k<rows*per_row+1 and differ[k]~=nil do
            l=1
            n=m*w/rows
            while l~=per_row+1 and differ[k]~=nil do
                printXY(l+4,n+3, "+%s", SI(input[differ[k]]))
                printXY(l+4,n+10, "%s", SI(output[differ[k]]))
                printXY(l+4,n+17, "%s", differ[k])
                l=l+1
                k=k+1
            end
            m=m+1
        end
        if #differ>rows*per_row then
            printXY(l+4,((m-1)*w/rows)+10, "+%d Elemente",#differ-rows*per_row)
        end
        centerF(h-6, "Differences: %d",#differ)
        ------
        items=items_tmp
        items_tmp={}
        difference={}
    end
    
    
    
    
    
    centerF(h-4, "Data updates every second Tick Count: %2d", tickCnt)
    centerF(h-3, "Current up time: %2d hours %2d min", hours, mins)
    center(h-2, "n - Reset Stats    Q - Quit ")
    
    
    
    term.clearLine()
    print()
    
    local event, address, arg1, arg2, arg3 = event.pull(1)
    if type(address) == "string" and component.isPrimary(address) then
        if event == "key_down" then
            onKeyDown(arg2)
        end
    end
end
term.clear()
term.setCursorBlink(false)