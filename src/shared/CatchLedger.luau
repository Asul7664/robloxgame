-- Pure transaction logic. A won fish is reserved during Landing; the SERVER commits it.
-- A saved reservation can be recovered on load. No client completion event is trusted.
local Ledger={}
local function normalized(config,record)
    if type(record)~='table' then return nil end
    local fish=config.ById[record.Species]
    if not fish or type(record.Kg)~='number' or record.Kg~=record.Kg then return nil end
    local kg=math.max(fish.MinKg,math.min(fish.MaxKg,record.Kg))
    local mutation=(record.Mutation=='gold' or record.Mutation=='glow')and record.Mutation or 'normal'
    return {Species=fish.Id,Kg=kg,Mutation=mutation,Value=config.Value(fish,kg,mutation)}
end
function Ledger.Reserve(data,config,record,token)
    if type(token)~='string' or #token==0 or #token>128 then return false end
    if data.PendingCatch or data.LastCatchToken==token or #data.Bag>=config.BagCapacity then return false end
    local safe=normalized(config,record);if not safe then return false end
    data.PendingCatch={Token=token,Record=safe};return true
end
function Ledger.Commit(data,config,expectedToken)
    local pending=data.PendingCatch
    if type(pending)~='table' then return nil end
    if expectedToken and pending.Token~=expectedToken then return nil end
    if type(pending.Token)~='string' or pending.Token==data.LastCatchToken then data.PendingCatch=nil;return nil end
    local r=normalized(config,pending.Record)
    if not r then data.PendingCatch=nil;return nil end
    if #data.Bag>=config.BagCapacity then return nil end -- retain, don't destroy an earned catch
    local fish=config.ById[r.Species]
    local before=config.Level(data.XP)
    local fresh=not data.Bestiary[r.Species]
    -- This block contains no yield; only a validated reservation can be committed once.
    data.PendingCatch=nil;data.LastCatchToken=pending.Token
    table.insert(data.Bag,r);data.Bestiary[r.Species]=true
    data.XP=math.min(100000000,data.XP+fish.XP)
    data.TotalCaught=math.min(100000000,data.TotalCaught+1)
    return {Record=r,New=fresh,XP=fish.XP,LevelUp=not data.TestMode and config.Level(data.XP)>before,Token=pending.Token}
end
function Ledger.Recover(data,config,raw)
    data.LastCatchToken=type(raw.LastCatchToken)=='string'and raw.LastCatchToken or nil
    local p=raw.PendingCatch
    if type(p)=='table'and type(p.Token)=='string'and #p.Token<=128 then
        local r=normalized(config,p.Record)
        if r then data.PendingCatch={Token=p.Token,Record=r};return Ledger.Commit(data,config) end
    end
end
return Ledger
