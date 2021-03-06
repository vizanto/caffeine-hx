import crypt.Aes;
import haxe.remoting.EncRemotingAdaptor;

enum Status {
	Connecting;
	Online;
	Offline;
}

class ImplClientApi extends haxe.remoting.AsyncProxy<IClientApi> {
}

class ClientData {
	public var api : ImplClientApi;
	public var name : String;
	public var serverapi(default,null) 	: IServerApi;
	public var remotingserver(default,null) : neko.net.RemotingServer;
	public var aes : crypt.Aes;

	public var adaptor(default,null) : EncRemotingAdaptor;
	public var status(default,null) : Status;

	public function new( scnx : haxe.remoting.SocketConnection, rserver : neko.net.RemotingServer ) {
		serverapi = new PreAuthApi(this);
		api = new ImplClientApi(scnx.inst);
		(cast scnx).__private = this;
		adaptor = new EncRemotingAdaptor(scnx);
		this.remotingserver = rserver;
		this.remotingserver.addObject("api",serverapi);
		this.status = Connecting;
	}

	public function leave() {
		this.status = Offline;
		if( !CryptServer.clients.remove(this) )
			return;
		for( c in CryptServer.clients ) {
			c.api.userLeave(name);
		}
	}

	// authorize user
	public static function doAuth(client : ClientData, name : String, hPassword : String) : Bool {
		var validPasswords : Array<String> = [
			"mypass",
			"passw0rd",
			"mango23"
		];
		if(name == null)
			throw "Error. Null username";

		var valid = false;
		var textpswd = "";
		for(p in validPasswords) {
			if(hPassword == hash.Sha1.encode(p)) {
				valid = true;
				textpswd = p;
				break;
			}
		}
		if(!valid) {
			client.api.loginFailed();
			return false;
		}
		client.name = name;
		trace("Client "+name+" authed with pass "+hPassword );
		CryptServer.clients.add(client);

		// instruct client that any further message, after this one itself
		// will be encrypted.
		client.api.startEncSession();
		client.adaptor.startCrypt(new crypt.ModeCBC(new Aes(128,textpswd)));
		client.serverapi = new PostAuthApi(client);
		client.remotingserver.addObject("api",client.serverapi);
		return true;
	}

	public function join() : Void {
		trace(here.methodName);
		status = Online;
		for( c in CryptServer.clients ) {
			c.api.userJoin(name);
		}
	}

	public static function ofConnection( scnx : haxe.remoting.SocketConnection ) : ClientData {
		return (cast scnx).__private;
	}
}
