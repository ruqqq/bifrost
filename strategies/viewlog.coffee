class Strategy extends require("./strategy.coffee")
	payload_name: "viewlog"

	constructor: (@server, @argv) ->
		super @server, @argv

		if !@payload[@app].file
			console.error "No log file specified for #{@app} for #{@server.name} (#{@server.host})."
			process.exit 1

	execute: =>
		@_viewlog (std, output) =>
			@connection.end()
		, (stderr, stdout) =>
			if stdout
				process.stdout.write stdout.toString().grey
			else if stderr
				process.stderr.write stderr.toString().red 

	_viewlog: (callback, opt_callback) =>
		cmd = "tail -n 100 -f #{@payload[@app].file}"
		console.log ">> #{cmd}".cyan

		@connection.exec cmd, (err, stream) =>
			output = {}
			@_attachDefaultCallbackToStream stream, output, opt_callback

			stream.on "exit", (code, signal) =>
				if code is 0
					if output.stdout.indexOf(@gitfolder) > -1
						if callback then return callback {code: code, signal: signal, stderr: output.stderr}, false
					else
						if callback then return callback {code: code, signal: signal, stderr: output.stderr}, true
				else
					if callback then return callback {code: code, signal: signal, stderr: output.stderr}, false

module.exports = Strategy