Connection = require "ssh2"

class Strategy
	payload_name: "default"
	app: "default"

	constructor: (@server, @argv) ->
		@payload = @server.payloads[@payload_name]

		if !@payload
			console.error "Cannot find payload #{@payload_name} for #{@server.name} (#{@server.host})".red
			process.exit 1

		@app = @argv[0]

		if !@payload[@app]
			console.error "Cannot find app #{@app} for #{@server.name} (#{@server.host})."
			process.exit 1

		@connection = new Connection()

		@connection.on "ready", =>
			@onSSHConnected()
			@execute()

		@connection.on "error", (err) =>
			@onSSHError err

		@connection.on "end", =>
			@onSSHEnded()

		@connection.on "close", =>
			@onSSHClosed()

	@help: () =>
		return "<app_name>"

	connect: =>
		auth =
			host: @server.host
			port: @server.port or 22
			username: @server.username or "root"

		if @server.key_file
			auth.privateKey = require("fs").readFileSync(@server.key_file)
		else
			auth.password = @server.password

		@connection.connect auth

	onSSHConnected: =>
		console.log "connected to #{@server.name} (#{@server.host})".cyan

	onSSHError: (err) =>
		console.trace err

	onSSHEnded: =>
		#console.log "connection ended."

	onSSHClosed: =>
		console.log "connection to #{@server.name} (#{@server.host}) closed.".cyan

	execute: =>
		@connection.exec "uptime", (err, stream) =>
			stream.on "data", (data, extended) =>
				if extended isnt "stderr"
					extended = "stdout"
				console.log "#{extended}: #{data}".cyan

			stream.on "end", () =>
				console.log "[exec:end]".cyan

			stream.on "close", () =>
				console.log "[exec:close]".cyan

			stream.on "exit", (code, signal) =>
				console.log "[exec:exit] #{code} - #{signal}".cyan
				@connection.end()

	shell: () =>
		@connection.shell (err, stream) =>
			output = {}
			@_attachDefaultCallbackToStream stream, output, (stderr, stdout) =>
				if stdout
					process.stdout.write stdout
				else if stderr
					process.stderr.write stderr

			stream.on "end", () =>
				console.log "[shell:end]".cyan

			stream.on "close", () =>
				console.log "[shell:close]".cyan

			stream.on "exit", (code, signal) =>
				console.log "[shell:exit] #{code} - #{signal}".cyan

			process.stdin.on 'readable', (chunk) =>
				chunk = process.stdin.read()
				if chunk isnt null
					stream.write chunk

	# opt_callback(stderr, stdout)
	_attachDefaultCallbackToStream: (stream, output, opt_callback) =>
		output.stdout = ""
		output.stderr = ""

		stream.on "data", (data, extended) =>
			if !extended
				if data
					output.stdout += data.toString()
					if opt_callback then opt_callback null, data.toString()
			else
				if data
					output.stderr += data.toString()
					if opt_callback then opt_callback data.toString(), null

		#stream.on "end", () =>
		#	console.log "[exec:end]"

		#stream.on "close", () =>
		#	console.log "[exec:close]"

		#stream.on "exit", (code, signal) =>
		#	console.log "[exec:exit] #{code} - #{signal}"

module.exports = Strategy