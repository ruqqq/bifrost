require "colors"
fs = require "fs"

# change working directory
process.chdir __dirname

class App
	strategies: {}

	constructor: ->
		# load strategies
		_strategies = fs.readdirSync "strategies"
		for file in _strategies
			if file.indexOf(".coffee") > -1 and file.indexOf("strategy.coffee") < 0
				@strategies[file.split(".")[0]] = require "./strategies/#{file}"

		if !process.argv[2] or process.argv[2] is "--help"
			if process.argv[2] isnt "--help"
				console.warn "Invalid command. Showing help:\n".red

			@help()
			process.exit 1

		if !@strategies[process.argv[2]]
			console.error "Strategy #{process.argv[2]} not found.".red
			process.exit 1

		if process.argv[3] is "--help" or !process.argv[3]
			@bifrost_info()
			@list_servers()
			process.exit 1

		@server = "./servers/#{process.argv[3]}.coffee"

		if !fs.existsSync(@server)
			console.error "Server #{process.argv[3]} not found.".red
			process.exit 1

		@server = require(@server)

		if process.argv[4] is "--help" or !process.argv[4]
			@bifrost_info()
			@list_server_apps()
			process.exit 1

	start: =>
		@strategy = new @strategies[process.argv[2]] @server, process.argv.slice 4, process.argv.length
		@strategy.connect()

	bifrost_info: =>
		console.info "bifrost v0.1".bold.blue
		console.info "(c)2014 Faruq Rasid <me@ruqqq.sg>\n".italic.white
		console.info "Usage: bifrost <strategy> <server> [extra arguments]".green

		console.info ""

	list_servers: =>
		console.info "Available Servers: ".bold.yellow
		_servers = fs.readdirSync "servers"
		for file in _servers
			if file.indexOf(".coffee") > -1
				console.info "   - #{file.split(".")[0]}".cyan

		console.info ""

	list_server_apps: =>
		console.info "Apps for #{@server.name} (#{@server.host}): ".bold.yellow

		for app in Object.keys(@server.payloads[process.argv[2]])
			console.info "   - #{app}".cyan

		console.info ""

	help: =>
		@bifrost_info()

		console.info "Available Strategies: ".bold.yellow
		for key in Object.keys(@strategies)
			console.info "   - #{key} #{@strategies[key].help()}".cyan

		console.info ""

		@list_servers()

# begin
new App().start()