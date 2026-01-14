fx_version 'cerulean'
game 'gta5'
author 'MatkezZz'
description 'Ownable car washes'
lua54 'yes'
version '1.0.5'

client_scripts {
    'client/main.lua',
    'client/creator.lua',
    'bridge/client/*.lua',
    '@qbx_core/modules/playerdata.lua' -- you can remove this if you don't use qbox
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
	'server/main.lua',
    'config/server.lua',
    'bridge/server/*.lua'
}

shared_scripts {
    '@ox_lib/init.lua',
    'config/shared.lua',
    'bridge/shared.lua'
}