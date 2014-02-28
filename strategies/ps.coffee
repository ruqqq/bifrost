class Strategy extends require("./strategy.coffee")
	payload_name: "ps"

	constructor: (@server, @argv) ->
		super @server, @argv

	@help: () =>
		return ""

	execute: =>
		@_ps (std, output) =>
			@connection.end()
		, (stderr, stdout) =>
			if stdout
				process.stdout.write stdout.toString().grey
			else if stderr
				process.stderr.write stderr.toString().red 

	_ps: (callback, opt_callback) =>
		cmd = "ps ax -o %cpu,%mem,cmd | sort -r -k 1,2 | grep #{@app.name or @app_name}"
		console.log ">> #{cmd}".cyan

		@connection.exec cmd, (err, stream) =>
			output = {}
			@_attachDefaultCallbackToStream stream, output, opt_callback

			stream.on "exit", (code, signal) =>
				if code is 0
					if callback then return callback {code: code, signal: signal, stderr: output.stderr}, true
				else
					if callback then return callback {code: code, signal: signal, stderr: output.stderr}, false

module.exports = Strategy