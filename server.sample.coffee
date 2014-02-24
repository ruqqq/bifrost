Server = 
	name: "My Server"
	host: "test.test.com"
	port: 22
	username: "root"
	password: null
	key_file: "servers/id_rsa"

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

module.exports = Server