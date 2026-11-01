fx_version 'cerulean'
game 'gta5'
author 'TroyScripts'
description 'Losse reparatiepunten met ESX dienstcontrole'
version '1.0.0'
shared_scripts { '@ox_lib/init.lua', 'config/config.lua' }
server_scripts { 'config/server.lua', 'server/payment.lua', 'server/main.lua' }
client_script 'client/main.lua'
dependencies { 'es_extended', 'ox_lib', 'ts_bridge', '/onesync' }
