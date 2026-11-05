local threads, events, commands, registered, notices = {}, {}, {}, {}, {}
local loaded, targetState, dead, inVehicle, distance = false, 'started', false, false, 0
local registrations, repairs, removals = 0, 0, 0
local position=setmetatable({}, {__sub=function() return setmetatable({}, {__len=function() return distance end}) end})
Config={Ped={TargetDistance=2.5,ArrivalDistance=1.5}}
RepairPoints={points={garage={coords={x=0,y=0,z=0},pedNetId=7}},peds={},locked=false,active=nil,
    mode=function() return 'ped' end,position=function() return position end,
    notify=function(msg) notices[#notices+1]=msg end,repair=function() repairs=repairs+1 end}
CreateThread=function(fn) threads[#threads+1]=coroutine.create(fn) end
Wait=function() coroutine.yield() end
AddEventHandler=function(name,fn) events[name]=fn end
RegisterCommand=function(name,fn) commands[name]=fn end
GetCurrentResourceName=function() return 'ts_repairpoints' end
GetResourceMetadata=function() return '1.1.3' end
GetResourceState=function() return targetState end
NetworkDoesEntityExistWithNetworkId=function() return loaded end
NetToPed=function() return loaded and 42 or 0 end
DoesEntityExist=function() return loaded end
NetworkHasControlOfEntity=function() return false end
IsEntityDead=function() return dead end
IsPedInAnyVehicle=function() return inVehicle end
PlayerPedId=function() return 1 end
GetEntityCoords=function() return position end
exports={ox_target={
    addEntity=function(_,netId,options)
        -- Het echte ox_target negeert de aanmelding als de netwerkped nog niet bestaat.
        if loaded then registrations=registrations+1; registered[netId]=options[1] end
    end,
    removeEntity=function(_,netId) removals=removals+1; registered[netId]=nil end
}}
dofile('client/peds.lua')
local function tick() local ok,err=coroutine.resume(threads[1]); assert(ok,err) end
tick(); assert(registrations==0, 'no registration before streaming')
loaded=true; tick(); assert(registrations==1 and registered[7], 'retry initial ignored registration')
tick(); assert(registrations==1, 'do not re-register every frame')
local option=registered[7]
assert(option.canInteract(42)); option.onSelect({entity=42}); assert(repairs==1)
distance=2.0; assert(option.canInteract(42)); option.onSelect({entity=42}); assert(repairs==2, 'same tolerance as server')
distance=3.0; option.onSelect({entity=42}); assert(repairs==2 and notices[#notices]:find('terug'))
distance=0; RepairPoints.locked=true; assert(option.canInteract(42)); option.onSelect({entity=42})
assert(repairs==2 and notices[#notices]:find('dienst'), 'explain duty block without starting repair')
RepairPoints.locked=false; RepairPoints.points.garage.repairJob={}; option.onSelect({entity=42})
assert(repairs==2 and notices[#notices]:find('iemand anders'))
RepairPoints.points.garage.repairJob=nil; RepairPoints.active={}; option.onSelect({entity=42}); assert(repairs==2)
RepairPoints.active=nil; dead=true; assert(not option.canInteract(42)); dead=false
inVehicle=true; assert(not option.canInteract(42)); inVehicle=false
loaded=false; tick(); assert(not RepairPoints.peds.garage.targetRegistered)
loaded=true; tick(); assert(registrations==2, 're-register after re-streaming')
targetState='stopped'; events.onResourceStop('ox_target'); assert(not RepairPoints.peds.garage.targetRegistered)
loaded=false; targetState='started'; events.onClientResourceStart('ox_target')
assert(registrations==2, 'restart outside streaming range waits')
loaded=true; tick(); assert(registrations==3)
commands.reparatietargetcheck(); assert(notices[#notices]:find('F8'))
RepairPoints.points.garage=nil; tick(); assert(removals==1 and not RepairPoints.peds.garage)
print('Target streaming, restart, visibility and availability scenarios passed')
