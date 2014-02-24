class Strategy extends require("./strategy.coffee")
	payload_name: "upstart"

	constructor: (@server, @argv) ->
		super @server, @argv

		if @argv[1] isnt "stop" and @argv[1] isnt "start" and @argv[1] isnt "restart" and @argv[1] isnt "status"
			console.error "Upstart: Invalid command. Only stop, start or restart, status is accepted.".red
			process.exit 1

	@help: () =>
		return "<app_name> <stop/start/restart/status>"

	execute: =>
		if @argv[1] is "stop" 
			@_sudo_stop (std, output) =>
				if !std.code
					console.log "#{@app} stopped on #{@server.name} (#{@server.host}).".green
				else
					console.warn std.stderr.red
				@connection.end()
			, (stderr, stdout) =>
				if stdout
					process.stdout.write stdout.toString().grey
				#else if stderr
					#process.stderr.write stderr.toString().red
		else if @argv[1] is "start" 
			@_sudo_start (std, output) =>
				if !std.code
					console.log "#{@app} started on #{@server.name} (#{@server.host}).".green
				else
					console.warn std.stderr.red
				@connection.end()
			, (stderr, stdout) =>
				if stdout
					process.stdout.write stdout.toString().grey
				#else if stderr
					#process.stderr.write stderr.toString().red
		else if @argv[1] is "restart" 
			@_sudo_stop (std, output) =>
				if !std.code
					@_sudo_start (std, output) =>
						if !std.code
							console.log "#{@app} restarted on #{@server.name} (#{@server.host}).".green
						else
							console.warn std.stderr.red
						@connection.end()
					, (stderr, stdout) =>
						if stdout
							process.stdout.write stdout.toString().grey
						#else if stderr
							#process.stderr.write stderr.toString().red
				else
					console.warn std.stderr.red
					@connection.end()
			, (stderr, stdout) =>
				if stdout
					process.stdout.write stdout.toString().grey
				#else if stderr
					#process.stderr.write stderr.toString().red
		else
			@_sudo_status (std, output) =>
				if !std.code
					console.log "#{@app} started on #{@server.name} (#{@server.host}).".green
				else
					console.warn std.stderr.red
				@connection.end()
			, (stderr, stdout) =>
				if stdout
					process.stdout.write stdout.toString().grey
				#else if stderr
					#process.stderr.write stderr.toString().red

	# callback(std, output)
	_sudo_stop: (callback, opt_callback) =>
		cmd = "sudo stop #{@payload[@app].service_name}"
		console.log ">> #{cmd}".cyan

		@connection.exec cmd, (err, stream) =>
			output = {}
			@_attachDefaultCallbackToStream stream, output, opt_callback

			stream.on "exit", (code, signal) =>
				if code is 0
					if callback then return callback {code: code, signal: signal, stderr: output.stderr}, output.stdout
				else
					if callback then return callback {code: code, signal: signal, stderr: output.stderr}, output.stdout

	# callback(std, output)
	_sudo_start: (callback, opt_callback) =>
		cmd = "sudo start #{@payload[@app].service_name}"
		console.log ">> #{cmd}".cyan

		@connection.exec cmd, (err, stream) =>
			output = {}
			@_attachDefaultCallbackToStream stream, output, opt_callback

			stream.on "exit", (code, signal) =>
				if code is 0
					if callback then return callback {code: code, signal: signal, stderr: output.stderr}, output.stdout
				else
					if callback then return callback {code: code, signal: signal, stderr: output.stderr}, output.stdout

	# callback(std, output)
	_sudo_restart: (callback, opt_callback) =>
		cmd = "sudo restart #{@payload[@app].service_name}"
		console.log ">> #{cmd}".cyan

		@connection.exec cmd, (err, stream) =>
			output = {}
			@_attachDefaultCallbackToStream stream, output, opt_callback

			stream.on "exit", (code, signal) =>
				if code is 0
					if callback then return callback {code: code, signal: signal, stderr: output.stderr}, output.stdout
				else
					if callback then return callback {code: code, signal: signal, stderr: output.stderr}, output.stdout

	# callback(std, output)
	_sudo_status: (callback, opt_callback) =>
		cmd = "sudo status #{@payload[@app].service_name}"
		console.log ">> #{cmd}".cyan

		@connection.exec cmd, (err, stream) =>
			output = {}
			@_attachDefaultCallbackToStream stream, output, opt_callback

			stream.on "exit", (code, signal) =>
				if code is 0
					if callback then return callback {code: code, signal: signal, stderr: output.stderr}, output.stdout
				else
					if callback then return callback {code: code, signal: signal, stderr: output.stderr}, output.stdout

module.exports = Strategy