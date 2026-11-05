local callbacks, commands, jsonValues = {}, {}, {}
local identifier, clock, health, debitCount, saved, writeOK = 'char:A', 0, 500, 0, nil, true
local failCredit = false
local function clone(t) if type(t)~='table' then return t end; local o={}; for k,v in pairs(t) do o[k]=clone(v) end; return o end
json={encode=function(t) jsonValues[#jsonValues+1]=clone(t); return tostring(#jsonValues) end,decode=function(s) return clone(jsonValues[tonumber(s)]) end}
local vectorMT={__sub=function() return setmetatable({}, {__len=function() return 0 end}) end}
vector3=function() return setmetatable({},vectorMT) end
Config={Points={{id='test',coords={x=0,y=0,z=0}}},MechanicJobs={},DutyMode='job',
    Interaction='marker',Radius=5,VehicleRadius=8,Ped={TargetDistance=2},
    Price=1000,MinPrice=100,DamageWeights={engine=1,body=1},DamageTolerance=5,
    Duration=1000,StatusInterval=1000,QuoteLifetime=30,Cooldown=10,Account='bank',Society='mechanic'}
local xp={identifier=identifier,getJob=function() return {name='unemployed'} end}
local esx={GetPlayerFromId=function() xp.identifier=identifier; return identifier and xp end,GetExtendedPlayers=function() return {} end}
exports={es_extended={getSharedObject=function() return esx end},ts_bridge={
    GetMoney=function() return 10000 end,GetSocietyBalance=function() return 0 end,
    RemoveMoney=function() debitCount=debitCount+1; return {ok=true} end,
    AddSocietyMoney=function() return failCredit and {ok=false,uncertain=true} or {ok=true} end
}}
lib={callback={register=function(n,fn) callbacks[n]=fn end}}
GetCurrentResourceName=function() return 'ts_repairpoints' end
GetResourceState=function() return 'started' end
LoadResourceFile=function(_,p) if p=='data/repairs.json' then return saved end end
SaveResourceFile=function(_,_,s) if writeOK then saved=s; return true end; return false end
CreateThread=function() end
AddEventHandler=function() end
RegisterNetEvent=function() end
RegisterCommand=function(n,fn) commands[n]=fn end
TriggerClientEvent=function() end
GetPlayerPed=function() return 1 end
NetworkGetEntityFromNetworkId=function() return 42 end
DoesEntityExist=function() return true end
GetEntityType=function() return 2 end
GetEntityHealth=function() return 200 end
GetEntityRoutingBucket=function() return 0 end
GetPlayerRoutingBucket=function() return 0 end
GetVehiclePedIsIn=function() return 42 end
GetPedInVehicleSeat=function() return 1 end
GetEntityCoords=function() return vector3() end
GetEntitySpeed=function() return 0 end
GetEntityModel=function() return 123 end
GetVehicleNumberPlateText=function() return 'A 123 BC' end
GetVehicleEngineHealth=function() return health end
GetVehicleBodyHealth=function() return health end
GetGameTimer=function() return clock end
os.time=function() return 1000+math.floor(clock/1000) end
local function reset()
    saved=nil; clock=0; health=500; debitCount=0; writeOK=true; identifier='char:A'; failCredit=false
    dofile('server/pricing.lua'); dofile('server/settlements.lua'); dofile('server/payment.lua'); dofile('server/main.lua')
end
local function call(n,...) return callbacks['ts_repairpoints:'..n](1,...) end
local function begin()
    local ok,q=call('quote','test',7); assert(ok,q)
    assert(call('begin',q.token)); clock=1001; return q
end
reset(); local q=begin(); local ok,result=call('finish',q.token)
assert(ok and result.dossier and debitCount==1)
assert(not call('finish',q.token), 'finish replay cannot debit twice')
clock=4000; assert(not call('quote','test',7), 'open paid dossier blocks second payment')
assert(call('recover')); health=1000; assert(call('confirmed',result.dossier))
clock=20000; assert(call('quote','test',7), 'completed dossier allows later repair')
reset(); q=begin(); writeOK=false; assert(not call('finish',q.token)); assert(debitCount==0, 'persist before payment')
reset(); q=begin(); failCredit=true; assert(not call('finish',q.token)); assert(debitCount==1)
clock=4000; assert(not call('quote','test',7), 'unknown payment blocks retry')
reset(); q=begin(); identifier='char:B'; assert(not call('finish',q.token)); assert(debitCount==0, 'character identity pinned at quote')
print('Full payment flow scenarios passed')
