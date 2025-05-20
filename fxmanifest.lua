fx_version 'cerulean'
game 'gta5'

author 'PerfQ'
description 'Tablet interface for esx_economyreworked'
version '1.0.0'

shared_scripts {
    '@es_extended/imports.lua',
    '@es_extended/locale.lua',
    'locales/*.lua',
    'config.lua'
}

escrow_ignore {
    'config.lua',
    'locales/*.lua'
}

client_scripts {
    'client.lua'
}

ui_page 'nui/index.html'

files {
    'nui/index.html',
    'nui/index.js',
    'nui/style.css',
    'nui/img/*.svg'
}

dependencies {
    'es_extended',
    'esx_economyreworked'
}

lua54 'yes'