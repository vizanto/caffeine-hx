/*
 * Copyright (c) 2005, The haXe Project Contributors
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

/**
	The Std class provides standard methods for manipulating basic types.
**/
class Std {

	/**
		Tells if a value v is of the type t.
	**/
	public static function is( v : Dynamic, t : Dynamic ) : Bool {
		return untyped
		#if flash
		flash.Boot.__instanceof(v,t);
		#else neko
		neko.Boot.__instanceof(v,t);
		#else js
		js.Boot.__instanceof(v,t);
		#else true
		false;
		#end
	}

	/**
		Convert any value to a String
	**/
	public static function string( s : Dynamic ) : String {
		return untyped
		#if flash
		flash.Boot.__string_rec(s,"");
		#else neko
		new String(__dollar__string(s));
		#else js
		js.Boot.__string_rec(s,"");
		#else true
		"";
		#end
	}

	/**
		Convert a Float to an Int, rounded down.
	**/
	public #if flash9 inline #end static function int( x : Float ) : Int {
		#if flash9
		return untyped __int__(x);
		#else true
		if( x < 0 ) return Math.ceil(x);
		return Math.floor(x);
		#end
	}

	/**
		Convert any value to a Bool. Only 0, null and false are false, other values are true.
	**/
	public static function bool( x : Dynamic ) : Bool {
		return (x !== 0 && x != null && x !== false);
	}

//BEGINPR/rw01/2008-02-28//Russell Weir/Changed docs and base handling for flash 8,9 and neko. This is to make parseInt actually work the same on all 3 platforms.
	/**
		Convert a String to an Int, parsing different possible representations.
		Strings beginning with 0x will be interpreted as hex, those starting with
		0 will be interpreted as octal. Returns [null] if could not be parsed.
	**/
	public static function parseInt( x : String ) : Null<Int> {
		untyped {
		#if flash9
		var n : Int = 0;
		var octal : Bool = false;
		var s = StringTools.ltrim(x);
		var neg = false;
		var pos : Int = 0;
		while(n < s.length) {
			var c = s.charAt(n);
			if(c == "+")
				pos = n+1;
			else if(c == "-") {
				pos = n+1;
				neg = true;
			}
			else if(c >= "0" || c <= "9" ) {
				if(c == 0 && n < s.length-1 && s.charAt(n+1) != "x")
					octal = true;
				else
					octal = false;
				break;
			}
			n++;
		}
		var v =
			if(octal)
				__global__["parseInt"](s.substr(pos), 8);
			else
				__global__["parseInt"](s.substr(pos));
		if( __global__["isNaN"](v) )
			return null;
		if(neg)
			return 0-v;
		return v;
		#else flash
		var s = StringTools.ltrim(x);
		var neg = false;
		if(StringTools.startsWith(s,"-0x")) {
			s = s.substr(1);
			neg = true;
		}
		var v = _global["parseInt"](s);
		if( Math.isNaN(v) )
			return null;
		if(neg)
			return 0-v;
		return v;
		#else neko
		var t = __dollar__typeof(x);
		if( t == __dollar__tint )
			return x;
		if( t == __dollar__tfloat )
			return __dollar__int(x);
		if( t != __dollar__tobject )
			return null;
		// octal processing
		var neg = false;
		var n : Int = 0;
		var octal = false;
		var s = StringTools.ltrim(x);
		var accum : Int = 0;
		while(n < s.length) {
			if(s.charAt(n) == "-") {
				if(octal)
					break;
				neg = true;
				if(s.charAt(n+1) == "0") {
					if(s.charAt(n+2) == "x") {
						n++;
						break;
					}
				}
				else {
					n++;
					break;
				}
				octal = true;
			}
			else if(s.charAt(n) == "+") {
				if(s.charAt(n+1) != "0" || octal) break;
				octal = true;
			}
			else if(octal && s.charAt(n) >= "0" && s.charAt(n) < "8") {
				accum <<= 3;
				accum += (s.charCodeAt(n) - Std.ord("0"));
			}
			else if(!octal && s.charAt(n) == "0") {
				if(s.charAt(n+1) != "x")
					octal = true;
				else break;
			}
			else break;
			n++;
		}
		if(octal) {
			if(neg)
				return 0-accum;
			return accum;
		}
		s = s.substr(n);
		var v = __dollar__int(s.__s);
		if(neg)
			return 0-v;
		return v;
		#else js
		var v = __js__("parseInt")(x);
		if( Math.isNaN(v) )
			return null;
		return v;
		#else true
		return 0;
		#end
		}
	}
//ENDPR/rw01///

	/**
		Convert a String to a Float, parsing different possible reprensations.
	**/
	public static function parseFloat( x : String ) : Float {
		return untyped
		#if flash9
		__global__["parseFloat"](x);
		#else flash
		_global["parseFloat"](x);
		#else neko
		__dollar__float(x.__s);
		#else js
		__js__("parseFloat")(x);
		#else true
		0;
		#end
	}

	/**
		Convert a character code into the corresponding single-char String.
	**/
	public static function chr( x : Int ) : String {
		return String.fromCharCode(x);
	}

	/**
		Return the character code of the first character of the String, or null if the String is empty.
	**/
	public static function ord( x : String ) : Null<Int> {
		#if flash
		if( x == "" )
			return null;
		else
			return x.charCodeAt(0);
		#else neko
		untyped {
			var s = __dollar__ssize(x.__s);
			if( s == 0 )
				return null;
			else
				return __dollar__sget(x.__s,0);
		}
		#else js
		if( x == "" )
			return null;
		else
			return x.charCodeAt(0);
		#else true
		return null;
		#end
	}

	/**
		Return a random integer between 0 included and x excluded.
	**/
	public static function random( x : Int ) : Int {
		return untyped
		#if flash9
		Math.floor(Math.random()*x);
		#else flash
		__random__(x);
		#else neko
		Math._rand_int(Math.__rnd,x);
		#else js
		Math.floor(Math.random()*x);
		#else true
		0;
		#end
	}

	/**
		Return the given resource stored using -res, or null if not defined.
	**/
	public static function resource( name : String ) : String {
		return untyped
		#if as3gen
		throw "Not supported in AS3";
		#else flash9
		flash.Boot.__res[name];
		#else flash
		flash.Boot.__res[name];
		#else neko
		__dollar__objget(neko.Boot.__res,__dollar__hash(name.__s));
		#else js
		js.Boot.__res[name];
		#else true
		null;
		#end
	}

}