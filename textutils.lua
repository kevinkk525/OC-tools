--ported from CC
t={}
function t.formatTime( nTime, bTwentyFourHour )
    local sTOD = nil
    if not bTwentyFourHour then
        if nTime >= 12 then
            sTOD = "PM"
        else
            sTOD = "AM"
        end
        if nTime >= 13 then
            nTime = nTime - 12
        end
    end
 
    local nHour = math.floor(nTime)
    local nMinute = math.floor((nTime - nHour)*60)
    if sTOD then
        return string.format( "%d:%02d %s", nHour, nMinute, sTOD )
    else
        return string.format( "%d:%02d", nHour, nMinute )
    end
end
 
local function makePagedScroll( _term, _nFreeLines )
    local nativeScroll = _term.scroll
    local nFreeLines = _nFreeLines or 0
    return function( _n )
        for n=1,_n do
            nativeScroll( 1 )
           
            if nFreeLines <= 0 then
                local w,h = _term.getSize()
                _term.setCursorPos( 1, h )
                _term.write( "Press any key to continue" )
                os.pullEvent( "key" )
                _term.clearLine()
                _term.setCursorPos( 1, h )
            else
                nFreeLines = nFreeLines - 1
            end
        end
    end
end
 
function t.pagedPrint( _sText, _nFreeLines )
    -- Setup a redirector
    local oldTerm = term.current()
    local newTerm = {}
    for k,v in pairs( oldTerm ) do
        newTerm[k] = v
    end
    newTerm.scroll = makePagedScroll( oldTerm, _nFreeLines )
    term.redirect( newTerm )
 
    -- Print the text
    local result
    local ok, err = pcall( function()
        result = print( _sText )
    end )
 
    -- Removed the redirector
    term.redirect( oldTerm )
 
    -- Propogate errors
    if not ok then
        error( err, 0 )
    end
    return result
end
 
local function tabulateCommon( bPaged, ... )
    local tAll = { ... }
   
    local w,h = term.getSize()
    local nMaxLen = w / 8
    for n, t in ipairs( tAll ) do
        if type(t) == "table" then
            for n, sItem in pairs(t) do
                nMaxLen = math.max( string.len( sItem ) + 1, nMaxLen )
            end
        end
    end
    local nCols = math.floor( w / nMaxLen )
    local nLines = 0
    local function newLine()
        if bPaged and nLines >= (h-3) then
            pagedPrint()
        else
            print()
        end
        nLines = nLines + 1
    end
   
    local function drawCols( _t )
        local nCol = 1
        for n, s in ipairs( _t ) do
            if nCol > nCols then
                nCol = 1
                newLine()
            end
 
            local cx, cy = term.getCursorPos()
            cx = 1 + ((nCol - 1) * nMaxLen)
            term.setCursorPos( cx, cy )
            term.write( s )
 
            nCol = nCol + 1      
        end
        print()
    end
    for n, t in ipairs( tAll ) do
        if type(t) == "table" then
            if #t > 0 then
                drawCols( t )
            end
        elseif type(t) == "number" then
            term.setTextColor( t )
        end
    end    
end
 
function t.tabulate( ... )
    tabulateCommon( false, ... )
end
 
function t.pagedTabulate( ... )
    tabulateCommon( true, ... )
end
 
local g_tLuaKeywords = {
    [ "and" ] = true,
    [ "break" ] = true,
    [ "do" ] = true,
    [ "else" ] = true,
    [ "elseif" ] = true,
    [ "end" ] = true,
    [ "false" ] = true,
    [ "for" ] = true,
    [ "function" ] = true,
    [ "if" ] = true,
    [ "in" ] = true,
    [ "local" ] = true,
    [ "nil" ] = true,
    [ "not" ] = true,
    [ "or" ] = true,
    [ "repeat" ] = true,
    [ "return" ] = true,
    [ "then" ] = true,
    [ "true" ] = true,
    [ "until" ] = true,
    [ "while" ] = true,
}
 
local function serializeImpl( t, tTracking, sIndent )
    local sType = type(t)
    if sType == "table" then
        if tTracking[t] ~= nil then
            error( "Cannot serialize table with recursive entries", 0 )
        end
        tTracking[t] = true
 
        if next(t) == nil then
            -- Empty tables are simple
            return "{}"
        else
            -- Other tables take more work
            local sResult = "{\n"
            local sSubIndent = sIndent .. "  "
            local tSeen = {}
            for k,v in ipairs(t) do
                tSeen[k] = true
                sResult = sResult .. sSubIndent .. serializeImpl( v, tTracking, sSubIndent ) .. ",\n"
            end
            for k,v in pairs(t) do
                if not tSeen[k] then
                    local sEntry
                    if type(k) == "string" and not g_tLuaKeywords[k] and string.match( k, "^[%a_][%a%d_]*$" ) then
                        sEntry = k .. " = " .. serializeImpl( v, tTracking, sSubIndent ) .. ",\n"
                    else
                        sEntry = "[ " .. serializeImpl( k, tTracking, sSubIndent ) .. " ] = " .. serializeImpl( v, tTracking, sSubIndent ) .. ",\n"
                    end
                    sResult = sResult .. sSubIndent .. sEntry
                end
            end
            sResult = sResult .. sIndent .. "}"
            return sResult
        end
       
    elseif sType == "string" then
        return string.format( "%q", t )
   
    elseif sType == "number" or sType == "boolean" or sType == "nil" then
        return tostring(t)
       
    else
        error( "Cannot serialize type "..sType, 0 )
       
    end
end
 
local empty_json_array = {}
 
local function serializeJSONImpl( t, tTracking )
    local sType = type(t)
    if t == empty_json_array then
        return "[]"
 
    elseif sType == "table" then
        if tTracking[t] ~= nil then
            error( "Cannot serialize table with recursive entries", 0 )
        end
        tTracking[t] = true
 
        if next(t) == nil then
            -- Empty tables are simple
            return "{}"
        else
            -- Other tables take more work
            local sObjectResult = "{"
            local sArrayResult = "["
            local nObjectSize = 0
            local nArraySize = 0
            for k,v in pairs(t) do
                if type(k) == "string" then
                    local sEntry = serializeJSONImpl( k, tTracking ) .. ":" .. serializeJSONImpl( v, tTracking )
                    if nObjectSize == 0 then
                        sObjectResult = sObjectResult .. sEntry
                    else
                        sObjectResult = sObjectResult .. "," .. sEntry
                    end
                    nObjectSize = nObjectSize + 1
                end
            end
            for n,v in ipairs(t) do
                local sEntry = serializeJSONImpl( v, tTracking )
                if nArraySize == 0 then
                    sArrayResult = sArrayResult .. sEntry
                else
                    sArrayResult = sArrayResult .. "," .. sEntry
                end
                nArraySize = nArraySize + 1
            end
            sObjectResult = sObjectResult .. "}"
            sArrayResult = sArrayResult .. "]"
            if nObjectSize > 0 or nArraySize == 0 then
                return sObjectResult
            else
                return sArrayResult
            end
        end
 
    elseif sType == "string" then
        return string.format( "%q", t )
 
    elseif sType == "number" or sType == "boolean" then
        return tostring(t)
 
    else
        error( "Cannot serialize type "..sType, 0 )
 
    end
end
 
function t.serialize( t )
    local tTracking = {}
    return serializeImpl( t, tTracking, "" )
end
 
function t.unserialize( s )
    local func = load( "return "..s, "unserialize", "t", {} )
    if func then
        local ok, result = pcall( func )
        if ok then
            return result
        end
    end
    return nil
end
 
function t.serializeJSON( t )
    local tTracking = {}
    return serializeJSONImpl( t, tTracking )
end
 
function t.urlEncode( str )
    if str then
        str = string.gsub(str, "\n", "\r\n")
        str = string.gsub(str, "([^%w ])", function(c)
            return string.format("%%%02X", string.byte(c))
        end )
        str = string.gsub(str, " ", "+")
    end
    return str    
end
 
local tEmpty = {}
function t.complete( sSearchText, tSearchTable )
    local nStart = 1
    local nDot = string.find( sSearchText, ".", nStart, true )
    local tTable = tSearchTable or _ENV
    while nDot do
        local sPart = string.sub( sSearchText, nStart, nDot - 1 )
        local value = tTable[ sPart ]
        if type( value ) == "table" then
            tTable = value
            nStart = nDot + 1
            nDot = string.find( sSearchText, ".", nStart, true )
        else
            return tEmpty
        end
    end
 
    local sPart = string.sub( sSearchText, nStart, nDot )
    local nPartLength = string.len( sPart )
 
    local tResults = {}
    local tSeen = {}
    while tTable do
        for k,v in pairs( tTable ) do
            if not tSeen[k] and type(k) == "string" then
                if string.find( k, sPart, 1, true ) == 1 then
                    if not g_tLuaKeywords[k] and string.match( k, "^[%a_][%a%d_]*$" ) then
                        local sResult = string.sub( k, nPartLength + 1 )
                        if type(v) == "function" then
                            sResult = sResult .. "("
                        elseif type(v) == "table" and next(v) ~= nil then
                            sResult = sResult .. "."
                        end
                        table.insert( tResults, sResult )
                    end
                end
            end
            tSeen[k] = true
        end
        local tMetatable = getmetatable( tTable )
        if tMetatable and type( tMetatable.__index ) == "table" then
            tTable = tMetatable.__index
        else
            tTable = nil
        end
    end
 
    table.sort( tResults )
    return tResults
end

return t