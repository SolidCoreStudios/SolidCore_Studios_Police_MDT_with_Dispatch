fx_version 'cerulean'
game 'gta5'

shared_script '@ox_lib/init.lua'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/assets/*',
}

author      'FlipperZeus'
description 'Police MDT'
version     '1.1'