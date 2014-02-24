class Strategy extends require("./strategy.coffee")
	payload_name: "npminstall"

	constructor: (@server, @argv) ->
		super @server, @argv

	execute: =>
		@_npm_cache_clear (std, output) =>
			if !std.code
				@_npm_install @app.path, (std, output) =>
					if !std.code
						console.log "npm install for #{@app_name} succeeded on #{@server.name} (#{@server.host}).".green
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

	# callback(std, output)
	_npm_cache_clear: (callback, opt_callback) =>
		cmd = "npm cache clear"
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
	_npm_install: (path, callback, opt_callback) =>
		cmd = "cd #{path} && npm install"
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