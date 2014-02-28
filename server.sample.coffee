Server = 
	name: "My Server"
	host: "test.test.com"
	port: 22
	username: "root"
	password: null
	key_file: "servers/id_rsa"

	# specify if server is running only one app and you can remove the key "app-server" in configs below
	# e.g.
	# payloads:
	# 	gitdeploy:
	# 		repo: "git@github.com:hello/world.git"
	# 		branch: "master"
	# 		path: "/opt/"
	#
	#app_name: "app-server"

	payloads:
		gitdeploy:
			"app-server":
				repo: "git@github.com:hello/world.git"
				branch: "master"
				path: "/opt/"
		npminstall:
			"app-server":
				path: "/opt/app-server"
		upstart:
			"app-server":
				service_name: "app-server"
		viewlog:
			"app-server":
				file: "/var/logs/app-server.log"
		ps:
			"app-server":
				name: "app-server" # optional, if not specified, will use the key "app-server" or @app_name

module.exports = Server