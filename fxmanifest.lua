fx_version 'cerulean'
game 'gta5'
author 'TroyScripts'
description 'Losse reparatiepunten met ESX dienstcontrole'
version '1.1.2'
shared_scripts { '@ox_lib/init.lua', 'config/config.lua' }
server_scripts { 'config/server.lua', 'server/webhooks.lua', 'server/pricing.lua', 'server/settlements.lua', 'server/payment.lua', 'server/compensation.lua', 'server/main.lua', 'server/peds.lua', 'server/updates.lua' }
client_scripts { 'client/main.lua', 'client/peds.lua' }
dependencies { 'es_extended', 'ox_lib', 'ts_bridge', '/onesync' }
