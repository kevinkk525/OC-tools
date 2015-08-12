---config section
local version="0.9a"
local database_entries=81
local stack_exp_side=0
local half_exp_side=3
local single_exp_side=4
local chest_side=4
local registrationServer
local shopHost
local redstone_side=5
------

--sides: down:0,up:1,south:3,east:5,

local serialization=require("serialization")
local component=require("component")
local exchange=require("money_exchange")
local s={} --functions
local b={} --backup
local ex_single={}
local ex_stack={}
local ex_half={}
local d={} --Itemlist! database structure: index={hash};hash={index,address,slot}
local database={} --reminder: table equality on pointer
local trade_table={} --structure {index=ident,ident={s/b{{amount,price},...},a:boolean}} --a=active trade
local trade_tavailable={} --available/activated trades --> use only during trade requests
local trans=component.dimensional_transceiver
local switch=""
local inv=component.inventory_controller
local chest_size=inv.getInventorySize(chest_side)