class Strategy extends require("./strategy.coffee")
	payload_name: "bowerinstall"

	constructor: (@server, @argv) ->
		super @server, @argv

	execute: =>
		@_bower_install @app.path, (std, output) =>
			if !std.code
				console.log "bower install for #{@app_name} succeeded on #{@server.name} (#{@server.host}).".green
			else
				console.warn std.stderr.red
			@connection.end()
		, (stderr, stdout) =>
			if stdout
				process.stdout.write stdout.toString().grey
			#else if stderr
				#process.stderr.write stderr.toString().red

	# callback(std, output)
	_bower_install: (path, callback, opt_callback) =>
		cmd = "cd #{path} && bower install"
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