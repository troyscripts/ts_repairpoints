local callbacks, commands, persisted = {}, {}, nil
local writing, player, health, entity, now = true, 'char:A', 500, 42, 1000
local debitCount, creditCount, refundCount = 0, 0, 0
local creditResult, debitResult, refundResult = {ok=true}, {ok=true}, {ok=true}
local afterCredit
local function clone(t)
    if type(t) ~= 'table' then return t end
    local out = {}; for k,v in pairs(t) do out[k] = clone(v) end; return out
end
local jsonValues, jsonIndex = {}, 0
json = {
    encode = function(t) jsonIndex=jsonIndex+1; jsonValues[tostring(jsonIndex)]=clone(t); return tostring(jsonIndex) end,
    decode = function(s) return clone(jsonValues[s]) end
}
Config = {Account='bank', Society='mechanic', Price=1000, DamageTolerance=5}
local bridge = {
    GetMoney=function() return 10000 end, GetSocietyBalance=function() return 0 end,
    RemoveMoney=function() debitCount=debitCount+1; return debitResult end,
    AddSocietyMoney=function() creditCount=creditCount+1; if afterCredit then afterCredit() end; return creditResult end,
    AddMoney=function() refundCount=refundCount+1; return refundResult end
}
exports = { es_extended = {getSharedObject=function() return {GetPlayerFromId=function() return player and {identifier=player} end} end}, ts_bridge=bridge }
GetCurrentResourceName=function() return 'ts_repairpoints' end
GetResourceState=function() return 'started' end
LoadResourceFile=function() return persisted end
SaveResourceFile=function(_,_,data) if writing then persisted=data; return true end; return false end
RegisterCommand=function(n,fn) commands[n]=fn end
lib={callback={register=function(n,fn) callbacks[n]=fn end}}
GetPlayerPed=function() return 1 end
NetworkGetEntityFromNetworkId=function() return entity end
DoesEntityExist=function() return entity~=0 end
GetEntityModel=function() return 123 end
GetVehicleNumberPlateText=function() return 'A 123 BC' end
GetEntityRoutingBucket=function() return 0 end
GetPlayerRoutingBucket=function() return 0 end
local coords=setmetatable({}, {__sub=function() return setmetatable({}, {__len=function() return 0 end}) end})
GetEntityCoords=function() return coords end
RepairVehicleQuote=function() return {engine=health,body=health} end
os.time=function() return now end
local function reload() dofile('server/settlements.lua'); dofile('server/payment.lua') end
local function reset()
    persisted=nil; writing=true; player='char:A'; health=500; entity=42; now=1000
    debitCount=0; creditCount=0; refundCount=0; afterCredit=nil
    creditResult={ok=true}; debitResult={ok=true}; refundResult={ok=true}
    reload()
end
local session={price=100,vehicle=42,netId=7,model=123,plate='A 123 BC',engine=500,body=500}
local function pay()
    local r=assert(RepairSettlementCreate(1, session))
    local paid,reason,uncertain=RepairPayment(1,100,r)
    local saved=RepairSettlementResult(r,paid,reason,uncertain)
    return r,paid,saved
end
local function recover() return callbacks['ts_repairpoints:recover'](1) end
local function confirm(id) return callbacks['ts_repairpoints:confirmed'](1,id) end
reset()
assert(not recover(), 'unpaid player cannot repair')
local r,paid,saved=pay(); assert(paid and saved)
assert(RepairSettlementPending(1) and RepairSettlementVehiclePending(42))
assert(not RepairSettlementCreate(1,session), 'prevent second payment')
local ok,data=recover(); assert(ok and data.dossier==r.id)
assert(not confirm(r.id), 'must wait for server damage replication')
assert(recover(), 'lost control can retry without money mutation')
assert(debitCount==1 and creditCount==1)
health=1000; assert(confirm(r.id)); assert(confirm(r.id), 'acknowledgment is idempotent')
assert(not RepairSettlementPending(1) and not RepairSettlementVehiclePending(42))
player='char:B'; assert(not confirm(r.id), 'another player cannot acknowledge')

reset(); r=pay(); player='char:B'; assert(not recover()); player='char:A'; assert(recover(), 'reconnect same character')
entity=99; assert(not recover(), 'network ID reused for another entity'); entity=42
health=300; assert(not recover(), 'new damage is not a free repair'); health=500
now=1121; assert(not recover(), 'bounded recovery window')

reset(); writing=false; assert(not RepairSettlementCreate(1,session)); assert(debitCount==0)
reset(); r=pay(); writing=false; health=1000; assert(not recover()); assert(RepairSettlementPending(1))
reset(); r=pay(); reload(); assert(RepairSettlementPending(1).status=='review'); assert(not recover(), 'restart cannot reuse entity IDs')
commands.reparatiedossier(1,{'sluiten',tostring(r.id),'checked'}); assert(RepairSettlementPending(1), 'console only')
commands.reparatiedossier(0,{'sluiten',tostring(r.id),'handmatig gecontroleerd'}); assert(not RepairSettlementPending(1))

reset(); creditResult={ok=false,uncertain=false}; r,paid=pay(); assert(not paid and refundCount==1 and not RepairSettlementPending(1))
reset(); creditResult={ok=false,uncertain=true}; r,paid=pay(); assert(not paid and refundCount==0 and RepairSettlementPending(1).status=='review')
reload(); assert(RepairSettlementPending(1).status=='review', 'uncertain payment survives restart')
reset(); creditResult={ok=false,uncertain=false}; afterCredit=function() player='char:B' end
r,paid=pay(); assert(not paid and refundCount==0, 'never refund a reused player ID')
player='char:A'; assert(RepairSettlementPending(1).status=='review')
reset(); debitResult={ok=false,uncertain=false}; r,paid=pay(); assert(not paid and creditCount==0 and not RepairSettlementPending(1))
reset(); r=assert(RepairSettlementCreate(1,session)); player='char:B'; assert(not RepairPayment(1,100,r)); assert(debitCount==0)
reset(); r=assert(RepairSettlementCreate(1,session)); writing=false
assert(not RepairSettlementResult(r,true)); assert(RepairSettlementPending(1).status=='review')
print('Settlement/payment scenarios passed')
