fx_version 'cerulean'
game 'gta5'

author 'PerfQ'
description 'System dostaw dla esx_economyreworked'
version '1.0.0'

shared_scripts {
    '@es_extended/imports.lua',
    '@es_extended/locale.lua',
    'locales/*.lua',
    'config.lua'
}

escrow_ignore {
	'config.lua',
	'locales/*lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}
dependencies {
    'es_extended',
    'esx_economyreworked'
}

lua54 'yes'