class Strategy extends require("./strategy.coffee")
	payload_name: "gitdeploy"

	constructor: (@server, @argv) ->
		super @server, @argv

		@gitfolder = @app.repo.split "/"
		@gitfolder = @gitfolder[if @gitfolder.length > 0 then @gitfolder.length-1 else 0]
		@gitfolder = @gitfolder.replace ".git", ""

		if !@gitfolder
			console.error "Cannot parse #{@app.repo} to get gitfolder."
			process.exit 1

		if @argv[1]
			@app.branch = @argv[1]

	@help: () =>
		return "<server> [app_name] [branch]"

	execute: =>
		@_check_if_deployed_previously (std, first_deployment) =>
			if !std.code
				if first_deployment
					@_git_clone (std, output) =>
						if !std.code
							console.log "git cloned successfully.".green
							@_git_checkout (std, output) =>
								if !std.code
									@_npm_install "#{@app.path}/#{@gitfolder}", (std, output) =>
										if !std.code
											console.log "#{@app_name} installed on #{@server.name} (#{@server.host}).".green
											console.log "Please configure config.coffee before starting app.".green
										else
											console.warn std.stderr.red
										@connection.end()
									, (stderr, stdout) =>
										if stdout
											process.stdout.write stdout.toString().grey
										#else if stderr
											#process.stderr.write stderr.toString().red
								else
									console.warn "Failed to checkout branch #{@app.branch}.".red
									@connection.end()
							, (stderr, stdout) =>
								if stdout
									process.stdout.write stdout.toString().grey
								#else if stderr
									#process.stderr.write stderr.toString().red
						else
							console.warn "Failed to clone git: #{@app.repo}.".red
							@connection.end()
					, (stderr, stdout) =>
						if stdout
							#process.stdout.write stdout
						else if stderr
							process.stderr.write stderr.toString().red
				else
					@_git_pull (std, output) =>
						if !std.code
							@_git_checkout (std, output) =>
								if !std.code
									console.log "#{@app_name} updated on #{@server.name} (#{@server.host}).".green
								else
									console.warn "Failed to checkout branch #{@app.branch}.".red
								@connection.end()
							, (stderr, stdout) =>
								if stdout
									process.stdout.write stdout.toString().grey
								#else if stderr
								#	process.stderr.write stderr.toString().red
						else
							console.warn "Failed to git pull: #{@app.repo}.".red
							@connection.end()
					, (stderr, stdout) =>
						if stdout
							process.stdout.write stdout.toString().grey
						#else if stderr
						#	process.stderr.write stderr.toString().red
			else
				console.warn std

	# callback(std, first_deployment)
	_check_if_deployed_previously: (callback, opt_callback) =>
		cmd = "cd #{@app.path} && ls -al"
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


	# callback(std, output)
	_git_clone: (callback, opt_callback) =>
		cmd = "cd #{@app.path} && git clone #{@app.repo}"
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
	_git_pull: (callback, opt_callback) =>
		cmd = "cd #{@app.path}/#{@gitfolder} && git pull"
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
	_git_checkout: (callback, opt_callback) =>
		cmd = "cd #{@app.path}/#{@gitfolder} && git checkout #{@app.branch}"
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