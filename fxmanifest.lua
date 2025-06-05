fx_version 'cerulean'
game 'gta5'

author 'PerfQ'
description 'Delivery system for esx_economyreworked'
version '1.0.0'

shared_scripts {
    '@es_extended/imports.lua',
    '@es_extended/locale.lua',
    'locales/*.lua',
    'config.lua'
}

server_scripts {
    'server/main.lua'
}

escrow_ignore {
    'config.lua',
    'locales/*.lua'
}

client_scripts {
    'client/main.lua'
}

dependencies {
    'es_extended',
    'esx_economyreworked'
}

lua54 'yes'