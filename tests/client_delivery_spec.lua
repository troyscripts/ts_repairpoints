local commands, callbacks, fixed, notices = {}, {}, 0, {}
local clock, available, owned, attempt, confirmed = 0, true, false, 0, false
Config={}
CreateThread=function() end
RegisterNetEvent=function() end
AddEventHandler=function() end
RegisterCommand=function(n,fn) commands[n]=fn end
lib={callback={await=function(name)
    if name=='ts_repairpoints:recover' then return true,{netId=7,model=123,plate='A 123 BC',price=100,dossier=1} end
    if name=='ts_repairpoints:confirmed' then confirmed=true; return true end
    error(name)
end},notify=function(data) notices[#notices+1]=data.description end}
NetworkDoesEntityExistWithNetworkId=function() return available end
NetToVeh=function() return 42 end
DoesEntityExist=function() return available end
GetGameTimer=function() return clock end
Wait=function(ms) clock=clock+ms end
NetworkHasControlOfEntity=function() return owned end
NetworkRequestControlOfEntity=function() attempt=attempt+1; if attempt==2 then owned=true end end
GetEntityModel=function() return 123 end
GetVehicleNumberPlateText=function() return 'A 123 BC' end
SetVehicleFixed=function() fixed=fixed+1 end
for _,n in ipairs({'FreezeEntityPosition','SetVehicleDeformationFixed','SetVehicleEngineHealth','SetVehicleBodyHealth','SetVehiclePetrolTankHealth','SetVehicleUndriveable','SetVehicleTyreFixed'}) do _G[n]=function() end end
dofile('client/main.lua')
commands.reparatieherstel(); assert(fixed==1 and confirmed and attempt==2, 'reacquire control before repair')
available=false; confirmed=false
commands.reparatieherstel(); assert(fixed==1 and not confirmed, 'missing vehicle must not be confirmed')
available=true; owned=false; attempt=100
commands.reparatieherstel(); assert(fixed==1 and not confirmed and clock>=2000, 'bounded control retry')
print('Client delivery scenarios passed')
