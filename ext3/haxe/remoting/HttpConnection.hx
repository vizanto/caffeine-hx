/*
 * Copyright (c) 2005-2008, The haXe Project Contributors
 * All rights reserved.
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 *   - Redistributions of source code must retain the above copyright
 *     notice, this list of conditions and the following disclaimer.
 *   - Redistributions in binary form must reproduce the above copyright
 *     notice, this list of conditions and the following disclaimer in the
 *     documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE HAXE PROJECT CONTRIBUTORS "AS IS" AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE HAXE PROJECT CONTRIBUTORS BE LIABLE FOR
 * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 * CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH
 * DAMAGE.
 */
package haxe.remoting;
import chx.sys.Web;
import chx.io.StringOutput;

/**
 * JS/Neko to Http server (syncronous)
 */
class HttpConnection implements Connection, implements Dynamic<Connection> {

	public static var TIMEOUT = 10;

	var __url : String;
	var __path : Array<String>;

	function new(url,path) {
		__url = url;
		__path = path;
	}

	public function resolve( name ) : Connection {
		var c = new HttpConnection(__url,__path.copy());
		c.__path.push(name);
		return c;
	}

	public function call( params : Array<Dynamic> ) : Dynamic {
		var data = null;
		var h = new haxe.Http(__url);
		#if js
			h.async = false;
		#end
		#if (neko && no_remoting_shutdown)
			h.noShutdown = true;
		#end
		#if (neko || php || cpp)
			h.cnxTimeout = TIMEOUT;
		#end
		var so : StringOutput = new StringOutput();
		var s = new chx.Serializer(so);
		s.serialize(__path);
		s.serialize(params);
		h.setHeader("X-Haxe-Remoting","1");
		h.setParameter("__x",so.toString());
		h.onData = function(d) { data = d; };
		h.onError = function(e) { throw e; };
		h.request(true);
		if( data.substr(0,3) != "hxr" )
			throw "Invalid response : '"+data+"'";
		data = data.substr(3);
		return new chx.Unserializer(data).unserialize();
	}

	#if (js || neko || php)

	/**
	 * Creates a new remoting connection to the specified URL. In neko, this
	 * will work like the asynchronous version but in synchronous mode.
	 * @param	url
	 */
	public static function urlConnect( url : String ) : HttpConnection {
		return new HttpConnection(url,[]);
	}

	#end

	//#if neko
	//public static function handleRequest( ctx : Context ) {
		//var v = neko.Web.getParams().get("__x");
		//if( neko.Web.getClientHeader("X-Haxe-Remoting") == null || v == null )
			//return false;
		//chx.Lib.print(processRequest(v,ctx));
		//return true;
	//}
	//#elseif php
	//public static function handleRequest( ctx : Context ) {
		//var v = php.Web.getParams().get("__x");
		//if( php.Web.getClientHeader("X-Haxe-Remoting") == null || v == null )
			//return false;
		//php.Lib.print(processRequest(v,ctx));
		//return true;
	//}
	//#end
	
	#if (neko || php || cpp)
	/**
	 * Handle an incoming http request.
	 * @param	ctx
	 */
	public static function handleRequest( ctx : Context ) : Bool {
		var v = Web.getParams().get("__x");
		if( Web.getClientHeader("X-Haxe-Remoting") == null || v == null )
			return false;
		chx.Lib.print(processRequest(v,ctx));
		return true;
	}
	
	/**
	 * Returns true if the current request is a remoting request
	 * @return true if http request is for remoting
	 */
	public static function isRemotingRequest() : Bool {
		var v = Web.getParams().get("__x");
		if( Web.getClientHeader("X-Haxe-Remoting") == null || v == null )
			return false;
		return true;
	}
	#end

	public static function processRequest( requestData : String, ctx : Context ) : String {
		try {
			var u = new chx.Unserializer(requestData);
			var path = u.unserialize();
			var args = u.unserialize();
			var data = ctx.call(path, args);
			var so = new StringOutput();
			var s = new chx.Serializer(so);
			s.serialize(data);
			return "hxr" + so.toString();
		} catch ( e : Dynamic ) {
			var so = new StringOutput();
			var s = new chx.Serializer(so);
			s.serializeException(e);
			return "hxr" + so.toString();
		}
	}

}
