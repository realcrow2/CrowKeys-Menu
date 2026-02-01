fx_version 'cerulean'
game 'gta5'

author 'Crow'
description 'Discord ID Based Vehicle Keys System with Trust Functionality'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua'
}

server_scripts {
    'server/main.lua'
}

client_scripts {
    'client/main.lua'
}

ui_page 'html/index.html'

files {
    'config.json',
    'trusted.json',
    'html/index.html',
    'html/style.css',
    'html/script.js'
}

lua54 'yes'

