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
	The StringTools class contains some extra functionalities for [String]
	manipulation. It's stored in a different class in order to prevent
	the standard [String] of being bloated and thus increasing the size of
	each application using it.
**/
class StringTools {

	/**
		Encode an URL by using the standard format.
	**/
	public static function urlEncode( s : String ) : String {
		#if flash9
		return untyped __global__["encodeURIComponent"](s);
		#else flash
		return untyped _global["escape"](s);
		#else neko
		return new String(_urlEncode(untyped s.__s));
		#else js
		return untyped encodeURIComponent(s);
		#else hllua
		return untyped __lua__("string.urlEncode(s)");
		#else error
		#end
	}

	/**
		Decode an URL using the standard format.
	**/
	public static function urlDecode( s : String ) : String {
		#if flash9
		return untyped __global__["decodeURIComponent"](s.split("+").join(" "));
		#else flash
		return untyped _global["unescape"](s);
		#else neko
		return new String(_urlDecode(untyped s.__s));
		#else js
		return untyped decodeURIComponent(s.split("+").join(" "));
		#else hllua
		return untyped __lua__("string.urlDecode(s)");
		#else error
		#end
	}

	/**
		Escape HTML special characters of the string.
	**/
	public static function htmlEscape( s : String ) : String {
		return s.split("&").join("&amp;").split("<").join("&lt;").split(">").join("&gt;");
	}

	/**
		Unescape HTML special characters of the string.
	**/
	public static function htmlUnescape( s : String ) : String {
		return s.split("&gt;").join(">").split("&lt;").join("<").split("&amp;").join("&");
	}

	/**
		Tells if the string [s] starts with the string [start].
	**/
	public static function startsWith( s : String, start : String ) {
		return( s.length >= start.length && s.substr(0,start.length) == start );
	}

	/**
		Tells if the string [s] ends with the string [end].
	**/
	public static function endsWith( s : String, end : String ) {
		var elen = end.length;
		var slen = s.length;
		return( slen >= elen && s.substr(slen-elen,elen) == end );
	}

	/**
		Tells if the character in the string [s] at position [pos] is a space.
	**/
	public static function isSpace( s : String, pos : Int ) : Bool {
		var c = s.charCodeAt( pos );
		return (c >= 9 && c <= 13) || c == 32;
	}

//BEGINPR/rw03/2008-03-02//Russell Weir/Additional convenience methods
	/**
		Tells if the character in the string [s] at position [pos] is a decimal number (0-9).
	**/
	public static function isNum( s : String, pos : Int ) : Bool {
		var c = s.charCodeAt( pos );
		return (c >= 48 && c <= 57);
	}

	/**
		Tells if the character in the string [s] at position [pos] is a alpha char (A-Z a-z).
	**/
	public static function isAlpha(s : String, pos : Int ) : Bool {
		var c = s.charCodeAt( pos );
		return (c >= 65 && c <= 90) || (c >= 97 && c <= 122);
	}

	/**
		Returns the decimal number from string [s] at position [pos] or null if it is not a decimal number (0-9)
	**/
	public static function num( s : String, pos : Int ) : Null<Int> {
		var c = s.charCodeAt( pos );
		if(c > 0) {
			c -= 48;
			if(c < 0 || c > 9)
				return null;
			return c;
		}
		return null;
	}
//ENDPR/rw03///

	/**
		Removes spaces at the left of the String [s].
	**/
	public static function ltrim( s : String ) : String {
		var l = s.length;
		var r = 0;
		while( r < l && isSpace(s,r) ){
			r++;
		}
		if( r > 0 )
			return s.substr(r, l-r);
		else
			return s;
	}

	/**
		Removes spaces at the right of the String [s].
	**/
	public static function rtrim( s : String ) : String {
		var l = s.length;
		var r = 0;
		while( r < l && isSpace(s,l-r-1) ){
			r++;
		}
		if( r > 0 ){
			return s.substr(0, l-r);
		}else{
			return s;
		}
	}

	/**
		Removes spaces at the beginning and the end of the String [s].
	**/
	public static function trim( s : String ) : String {
		return ltrim(rtrim(s));
	}

	/**
		Pad the string [s] by appending [c] at its right until it reach [l] characters.
	**/
	public static function rpad( s : String, c : String, l : Int ) : String {
		var sl = s.length;
		var cl = c.length;
		while( sl < l ){
			if( l - sl < cl ){
				s += c.substr(0,l-sl);
				sl = l;
			}else{
				s += c;
				sl += cl;
			}
		}
		return s;
	}

	/**
		Pad the string [s] by appending [c] at its left until it reach [l] characters.
	**/
	public static function lpad( s : String, c : String, l : Int ) : String {
		var ns = "";
		var sl = s.length;
		if( sl >= l ) return s;

		var cl = c.length;
		while( sl < l ){
			if( l - sl < cl ){
				ns += c.substr(0,l-sl);
				sl = l;
			}else{
				ns += c;
				sl += cl;
			}
		}
		return ns+s;
	}

	/**
		Replace all occurences of the string [sub] in the string [s] by the string [by].
	**/
	public static function replace( s : String, sub : String, by : String ) : String {
		return s.split(sub).join(by);
	}

//BEGINPR/rw01/2008-05-23//Russell Weir/Replace all chars
	/**
		Replace all characters that are in [sub] with the string [by]
	**/
	public static function replaceAll(s : String, sub : String, by : String) : String {

		var rv : String = "";
		var subs = new Hash<Bool>();
		var l = sub.length;
		for(i in 0...l) {
			subs.set(sub.charAt(i), true);
		}
		l = s.length;
		for(i in 0...l) {
			var c = s.charAt(i);
			if(subs.get(c) != null)
				rv += by;
			else
				rv += c;
		}
		return rv;
	}
//ENDPR/rw01///

//BEGINPR/rw01/2008-03-02//Russell Weir/Replace recursive
	/**
		Continues to replace [sub] with [by] until no more instances of [sub] exist.
	**/
	public static function replaceRecurse( s : String, sub : String, by : String ) : String {
		if(sub.length == 0)
			return replace(s, sub, by);
		if(by.indexOf(sub) >= 0)
			throw "Infinite recursion";
		var ns : String = s.toString();
		var olen = 0;
		var nlen = ns.length;
		while(olen != nlen) {
			olen = ns.length;
			replace( ns, sub, by );
			nlen = ns.length;
		}
		return ns;
	}
//ENDPR/rw01///

//BEGINPR/rw02/2008-03-02//Russell Weir/Strip all whitespace out of string, with no Ereg
	/**
		Strip whitespace out of a string
	**/
	public static function stripWhite( s : String ) : String {
		var l = s.length;
		var i = 0;
		var sb = new StringBuf();
		while( i < l ) {
			if(!isSpace(s, i))
				sb.add(s.charAt(i));
			i++;
		}
		return sb.toString();
	}
//ENDPR/rw02///

//BEGINPR/rw04/2008-03-02//Russell Weir/Found in mtwin.mail.Tools should be a StringTool
	public static function splitLines( str : String ) : Array<String> {
		var ret = str.split("\n");
		for( i in 0...ret.length ){
				var l = ret[i];
				if( l.substr(-1,1) == "\r" ){
						ret[i] = l.substr(0,-1);
				}
		}
		return ret;
	}
//ENDPR/rw04///

	/**
		Encode a string using the specified base. The base length must be a power of two.
	**/
	public static function baseEncode( s : String, base : String ) : String {
		#if neko
		return new String(_baseEncode(untyped s.__s,untyped base.__s));
		//#else hllua
		//return untyped __tostring__(__global__["tonumber"](s, base.length));
		#else true
		var len = base.length;
		var nbits = 1;
		while( len > 1 << nbits )
			nbits++;
		if( nbits > 8 || len != 1 << nbits )
			throw "baseEncode: base must be a power of two.";
		var size = Std.int((s.length * 8 + nbits - 1) / nbits);
		var out = new StringBuf();
		var buf = 0;
		var curbits = 0;
		var mask = ((1 << nbits) - 1);
		var pin = 0;
		while( size-- > 0 ){
			while( curbits < nbits ){
				curbits += 8;
				buf <<= 8;
				var t = s.charCodeAt(pin++);
				if( t > 255 )
					throw "baseEncode: bad chars";
				buf |= t;
			}
			curbits -= nbits;
			out.addChar(base.charCodeAt((buf >> curbits) & mask));
		}
		return out.toString();
		#end
	}

	/**
		Decode a string encoded in the specified base. The base length must be a power of two.
	**/
	public static function baseDecode( s : String, base : String ) : String {
		#if neko
		return new String(_baseDecode(untyped s.__s,untyped base.__s));
		#else true
		var len = base.length;
		var nbits = 1;
		while( len > 1 << nbits )
			nbits++;
		if( nbits > 8 || len != 1 << nbits )
			throw "baseDecode: base must be a power of two.";
		var size = (s.length * 8 + nbits - 1) / nbits;
		var tbl = new Array();
		for( i in 0...256 )
			tbl[i] = -1;
		for( i in 0...len )
			tbl[base.charCodeAt(i)] = i;
		var size = (s.length * nbits) / 8;
		var out = new StringBuf();
		var buf = 0;
		var curbits = 0;
		var pin = 0;
		while( size-- > 0 ){
			while( curbits < 8 ){
				curbits += nbits;
				buf <<= nbits;
				var i = tbl[s.charCodeAt(pin++)];
				if( i == -1 )
					throw "baseDecode: bad chars";
				buf |= i;
			}
			curbits -= 8;
			out.addChar((buf >> curbits) & 0xFF);
		}
		return out.toString();
		#end
	}

//BEGINPR/rw05/2008-03-05//Russell Weir/Documentation wording change
	/**
		Encode a number into a hexadecimal representation, optionally left zero padded to [digits] width.
	**/
//ENDPR/rw05////
	public static function hex( n : Int, ?digits : Int ) {
		var neg = false;
		if( n < 0 ) {
			neg = true;
			n = -n;
		}
		#if (flash || js)
		var s : String = untyped n.toString(16);
		s = s.toUpperCase();
		#else true
		var s = "";
		var hexChars = "0123456789ABCDEF";
		do {
			s = hexChars.charAt(n%16) + s;
			n = Std.int(n/16);
		} while( n > 0 );
		#end
		if( digits != null )
			while( s.length < digits )
				s = "0"+s;
		if( neg )
			s = "-"+s;
		return s;
	}

	#if neko
	private static var _urlEncode = neko.Lib.load("std","url_encode",1);
	private static var _urlDecode = neko.Lib.load("std","url_decode",1);
	private static var _baseEncode = neko.Lib.load("std","base_encode",2);
	private static var _baseDecode = neko.Lib.load("std","base_decode",2);
	#end

}
