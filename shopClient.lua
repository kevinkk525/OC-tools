---
local version="0.3b"
local author="kevinkk525"
local port=801
local shopmaster=""
---

local f=require"req_handler"
f.initialize()
local gui=f.addHook("gui","GUI")
local modem=hooks.modem
local computer=require("computer")
local w,h=gui.getResolution()
local s={} --shop client functions

local selectedItem
local items={}
local itemNames={}
local confirmed=false
--add updating of itemlist
--test splitting of messages

local username
local password
local auth
local exit_b=gui.label(w-4,h,3,0,101,0x00AAFF,nil,function() gui.stop() os.exit() end,nil,"Exit")

local function username_set(x,y,button,user,text) username=text end
local function password_set(x,y,button,user,text) password=text end
local function login_process(mode)
    if f.getStatus()=="added" then
        modem.send(shopmaster,port,"authenticate",mode)
        f.pause(login_process)
    else
        if f.getData()=="authenticated" then
            auth={username,password}
        else
            t.info_l.setText(f.getData())
            t.setFCol(0xFF0000)
            os.sleep(3) --temporary solution
            gui.stop()
            os.exit()
        end
    end
end
local function login_add() f.addTask(login_process,"address") t.confirm_login.removeClickEvent() t.login_auth.removeClickEvent() end
local function login() f.addTask(login_process,{username,password}) t.confirm_login.removeClickEvent() t.login_auth.removeClickEvent() end 

local timeout=60+computer.uptime()
local t={}
t.username_l=gui.labelbox(math.floor(w/2-10),5,9,0,101,0xAAFF00,nil,nil,nil,"Username: ")
t.headline_l=gui.label(math.floor(w/2-10),1,19,0,101,0x00FFAA,nil,nil,nil,"Login to KK's SHOP")
t.info_l=gui.label(math.floor(w/3),3,math.floor(w/3),0,101,nil,nil,nil,nil,"Either use your username & password or login by modem address")
t.password_l=gui.labelbox(math.floor(w/2-10),6,9,0,101,0x00AAFF,nil,nil,nil,"Password: ")
t.userinp=gui.textbox(t.username_l.getX()+t.username_l.getRX()+1,5,19,0,101,0xAAFF00,nil,username_set,nil,"Insert username")
t.passinp=gui.textbox(t.password_l.getX()+t.password_l.getRX()+1,6,19,0,101,0xAAFF00,nil,password_set,nil,"Insert password")
t.confirm_login=gui.labelbox(math.floor(w/3*2),8,6,2,101,0xAFAFAF,nil,login,nil,"Login")
t.confirm_login.moveText(1,1)
t.login_auth=gui.labelbox(math.floor(w/3),8,25,2,101,0xFAFAFA,nil,login_add,nil,"Login with modem address")
t.login_auth.moveText(1,1)
while not auth do
    f.execute()
    if computer.uptime()>=timeout then
        info_l.setText("Timeout, exiting program!")
        info_l.setFCol(0xFF0000)
        os.sleep(3)
        gui.stop()
        os.exit()
    end
end
for a,b in pairs(t) do
    t[a].remove()
end
t=nil timeout=nil 

--init GUI
local headline=gui.labelbox(math.floor(w/2-10),1,19,0,101,0xAAFF00,0x00AAFF,nil,nil,"SHOP CLIENT by %s",author)
local info=gui.labelbox(2,3,w-5,2,101,0x000000,0xFFFFFF,nil,nil,"You can .... do here..")
local itemlist=gui.listing(2,6,w-21,h-8,101,nil,nil,s.select,nil,{"receiving items"})
local balance_label=gui.label(w-20,26,18,0,101,nil,nil,function() f.addTask(getBalance) end,"Balance: ")
local itemamount_box=gui.textbox(w-19,10,9,2,101,nil,nil,s.calcPrices,nil,"Amount")
local buy_label=gui.label(w-17,14,14,0,101)
local sell_label=gui.label(w-17,21,14,0,101)
local buy_button=gui.labelbox(w-15,16,4,2,101,0x00AAFF,nil,s.buy_item,nil,"Buy")
local sell_button=gui.labelbox(w-15,23,5,2,101,0x00FFAA,nil,s.sell_item,nil,"Sell")
local instruction_label=gui.labelbox(w-18,25,w-2,h-3,101,nil,0xFF0000)

local function getItemNames()
    if f.getStatus()=="added" then
        modem.send(shopmaster,port,getItemNames)
        f.pause(getItemNames)
    else
        itemlist.setText(f.getData()) --call different function for showing items 
        itemNames=f.getData()
    end
end

local function getItemList()
    if f.getStatus()=="added" then
        modem.send(shopmaster,port,getItemList)
        f.pause(getItemList)
    else
        items=f.getData()
        f.addTask(getItemNames)
    end
end
getItemList()
    
local function calc(am,it,mode)
    local i=1
    local amount=0
    it=items[it]
    if it[mode]==nil then
        return "NA"
    end
    while am>0 do
        local g,k=math.modf(am/it[mode][i][1])
        amount=amount+g*it[mode][i][2]
        am=am-g*it[mode][i][1]
        if g==0 then 
            i=i+1
        end
    end
    return amount
end

local function confirmInstructions() confirmed=true end

function s.select(x,y,button,user)
    local i=itemlist.getY()+itemlist.getTextLine()
    local item=itemlist.getText(i)
    if selectedItem==item then
        selectedItem=nil
        itemlist.setBCol(itemlist.getBCol(0),i)
    else
        selectedItem=item
        itemlist.setBCol(0x4444FF,i)
    end
end

function s.buy_item(x,y,button,user) --add possibility to pay with account money: extra button?
    if not confirmed then
        instruction_label.setText("Please insert "..buy_label.getText().."$ in your sending chest!\nAfter that, click on this instructions")
        buy_button.removeClickEvent()
        sell_button.removeClickEvent()
        itemamount_box.removeClickEvent()
        itemlist.removeClickEvent()
    else
        instruction_label.setText("Confirmed, sending items and buy-request to shop")
        f.addTask(s.sendToShop,"buy",tonumber(itemamount_box.getText()),auth)
        confirmed=false
    end 
end

function s.sell_item(x,y,button,user)
    if not confirmed then   
        instruction_label.setText("Please insert "..sell_label.getText().." "..itemNames[selectedItem].." in your sending chest!\nAfter that, click on this instructions")
        sell_button.removeClickEvent()
        buy_button.removeClickEvent()
        itemamount_box.removeClickEvent()
        itemlist.removeClickEvent()
    else
        instruction_label.setText("Confirmed, sending items and sell-request to shop")
        f.addTask(s.sendToShop,"sell",tonumber(itemamount_box.getText()),auth)
        confirmed=true
    end
end

function s.sendToShop(mode,itemamount,auth)
    local error=false
    if type(itemamount)=="string" then
        print("itemamount not working with number")
        itemamount=tonumber(itemamount)
    end
    if f.getStatus()=="added" then
        modem.send(shopmaster,port,mode,selectedItem,itemamount,auth) --add authentication method (temporary with login,permanent with registered address)
        f.pause(s.sendToShop)
        timeout=computer.uptime()
        f.setRemove(s.restore)
        f.addData("timeout","Timeout, transaction either finished or canceled")
    else    
        if f.getData()=="confirmed" then
            instruction_label.setText("Request confirmed, wait for items. If transaction complete, click this text to continue or wait 30 secs.")
            instruction_label.setClickEvent(s.restore("Transaction complete and confirmed by user"))
            f.pause(s.sendToShop)
        else
            if not error then
                instruction_label.setText(f.getData())
                error=true
            end
        end
    end
end

function s.restore(text)
    if type(text)=="string" or text==nil then
        text=text or f.getData("timeout")
        instruction_label.setText(text.."\n Click this text to continue")
        f.remove()
    else
        instruction_label.removeClickEvent()
        sell_button.setClickEvent(s.buy_item)
        buy_button.setClickEvent(s.sell_item) --add option to disable clickEvent in objects: object.disable()
        itememount_box.setClickEvent(s.calcPrices)
        itemlist.setClickEvent(s.select)
    end
end    

function s.calcPrices(x,y,button,user,text)
    if selectedItem then
        if math.floor(tonumber(text))~=text then
            itemamount_box.setText(math.floor(tonumber(text)))
        end
        text=math.floor(tonumber(text))
        buy_label.setText(tostring("buy: "..calc(text,selectedItem,"b")))
        sell_label.setText(tostring("sell: "..calc(text,selectedItem,"s")))
    end
end

function s.getBalance()
    if f.getStatus()=="added" then
        modem.send(shopmaster,port,"getBalance",auth)
        f.pause(s.getBalance())
    else
        balance_label.setText("Balance "..f.getData())
    end
end

while true do f.execute() end