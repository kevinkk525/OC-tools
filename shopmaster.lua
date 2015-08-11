host atrributes
auth={addresses=username,username=password}
user_frequency={username=clientnumber}
balance={username={ident/money=value}}
export_available=boolean

host functions:

authenticate(mode:sring/table):string
{ mode:"address"/{username,password},return "authenticated"/error
}

getItemNames():table {return ItemNames}
getItemList():table {return trade_tavailable}
buy(selectedItem:ident,amount:number,auth:string/table):confirmed
{check for received money/receive money, return "confirmed"/error,send bought items}
sell(selectedItem:ident,amount:number,auth:string/table):confirmed
{check for received items/recieve items,return "confirmed"/error", send money}
getBalance(auth:string/table):number {return balance[username].money}
addBalance(user:string,balance:number):?? {add balance to user account, security!}

extensions:
registerUser(username:string,password:string):string
{register user, connect to tesseract}



available external shop-master functions:
addItem(tab:table)--format:?
removeItem(iden
activateItem
deactivateItem
searchItem(item:ident?)
listAvailableTrades
listTradeTable
exportTo(amount:number/table,itemid:string/table,user:string,prices:table)
importFrom(...)
