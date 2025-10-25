fx_version 'cerulean'
game 'gta5'

author 'Moayed'
description 'Hunting System'
version '1.0.0'

server_script 'server/events.js'

shared_scripts {
    'Shared/Shared.lua'
}

client_scripts {
    'client/cl_main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/sv_main.lua',
}


ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style/style.css',
    'html/js/script.js'
}

lua54 'yes'

-- Create In 10/18/2025