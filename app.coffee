require "colors"
fs = require "fs"
YAML = require "yamljs"

class App
	strategies: {}

	constructor: ->
		process.argv = process.argv.slice 2, process.argv.length

		# load strategies
		_strategies = fs.readdirSync "#{__dirname}/strategies"
		for file in _strategies
			if file.indexOf(".coffee") > -1 and file.indexOf("strategy.coffee") < 0
				@strategies[file.split(".")[0]] = require "#{__dirname}/strategies/#{file}"

		if !process.argv[0] or process.argv[0] is "--help"
			if process.argv[0] isnt "--help"
				console.warn "Invalid command. Showing help:\n".red

			@help()
			process.exit 1

		if !@strategies[process.argv[0]]
			console.error "Strategy #{process.argv[0]} not found.".red
			process.exit 1

		@strategyName = process.argv[0]

		# if user just want to see help, output it and exit
		if process.argv[1] is "--help"
			@bifrost_info()
			@strategy_usage()
			@list_servers()
			process.exit 1

		process.argv = process.argv.slice 1, process.argv.length

		# load the server file based on env or argv
		serverPath = if process.env.BIFROST_SERVERS then process.env.BIFROST_SERVERS else "servers"
		if serverPath is ""
			console.error "Env variable BIFROST_SERVERS is empty.".red
			process.exit 1

		serverName = process.env.BIFROST_HOST
		for ind,val of process.argv
			if val is "--host"
				serverName = process.argv[parseInt(ind)+1]
				process.argv.splice ind, 2
				break
		@server = "#{serverPath}/#{serverName}.yml"

		if !serverName or serverName is ""
			console.error "Specify --host option or BIFROST_HOST env.".red
			process.exit 1

		if !fs.existsSync(@server)
			console.error "Host #{serverName} not found.".red
			process.exit 1

		try
			@server = YAML.load @server
		catch e
			console.error "Please specify a valid server yml."
			process.exit 1

		# resolve the path of key_file if needed
		if @server.key_file
			@server.key_file = "#{serverPath}/#{@server.key_file}"

		# output help if user is requesting it and exit
		if process.argv[0] is "--help"
			@bifrost_info()
			@strategy_usage()
			process.exit 1

	start: =>
		@strategy = new @strategies[@strategyName] @, @server, process.argv
		@strategy.connect()

	bifrost_info: =>
		console.info "bifrost v0.2.4: The Docker \"Catapult\"".bold.blue
		console.info "(c)2014 Faruq Rasid <me@ruqqq.sg>\n".italic.white
		console.info "Run the command in the directory which contains bifrost.yml:".italic.white
		console.info "bifrost <strategy> [--host BIFROST_HOST] [args...]".green
		
		console.info ""

	strategy_usage: =>
		console.info "#{@strategyName} usage: ".bold.yellow
		console.info "   - #{@strategyName} #{@strategies[@strategyName].help()}".cyan
		console.info ""

	list_servers: =>
		console.info "Available Hosts: ".bold.yellow
		serverPath = if process.env.BIFROST_SERVERS then process.env.BIFROST_SERVERS else "servers"
		_servers = fs.readdirSync serverPath
		for file in _servers
			if file.indexOf(".yml") > -1
				console.info "   - #{file.split(".")[0]}".cyan

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