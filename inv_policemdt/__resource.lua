resource_manifest_version '44febabe-d386-4d18-afbe-5e627f4af937'

description 'ADRP Police MDT'

version '1.0.0'

ui_page 'html/mdt.html'

server_scripts {
	'@mysql-async/lib/MySQL.lua',
	'config.lua',
	'server.lua'
}

client_scripts {
	'config.lua',
	'client.lua'
}

files {
	'html/mdt.html',
	'html/style.css',
	'html/grid.css',
	'html/main.js'
}

dependency 'es_extended'