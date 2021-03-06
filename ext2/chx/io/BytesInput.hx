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
package chx.io;

import chx.lang.EofException;
import chx.lang.OutsideBoundsException;
import chx.lang.OverflowException;

class BytesInput extends chx.io.Input {

	var b : chx.io.BytesData;
	#if !flash9
	var pos : Int;
	var len : Int;
	#end

	public function new( b : Bytes, ?pos : Int, ?len : Int ) {
		if( pos == null ) pos = 0;
		if( len == null ) len = b.length - pos;
		if( pos < 0 || len < 0 || pos + len > b.length ) throw new OutsideBoundsException();
		#if flash9
		var ba = b.getData();
		ba.position = pos;
		if( len != ba.bytesAvailable ) {
			// truncate
			this.b = new flash.utils.ByteArray();
			ba.readBytes(this.b,0,len);
		} else
			this.b = ba;
		this.b.endian = flash.utils.Endian.LITTLE_ENDIAN;
		#else
		this.b = b.getData();
		this.pos = pos;
		this.len = len;
		#end
	}

	public override function readByte() : Int {
		#if flash9
			return try b.readUnsignedByte() catch( e : Dynamic ) throw new EofException();
		#else
			if( this.len == 0 )
				throw new EofException();
			len--;
			#if neko
			return untyped __dollar__sget(b,pos++);
			#elseif php
			return untyped __call__("ord", b[pos++]);
			#else
			return b[pos++];
			#end
		#end
	}

	override function getBytesAvailable() : Int {
		#if flash9
			return b.bytesAvailable;
		#else
			var r = len - pos;
			return r >= 0 ? r : 0;
		#end
	}

	public override function readBytes( buf : Bytes, pos, len ) : Int {
		#if php
			if( pos < 0 || len < 0 || pos + len > untyped __call__("strlen", b))
    throw new OutsideBoundsException();
		#elseif !neko
			if( pos < 0 || len < 0 || pos + len > b.length )
				throw new OutsideBoundsException();
		#end
		#if flash9
			if( len > b.bytesAvailable && b.bytesAvailable > 0 ) len = b.bytesAvailable;
			try b.readBytes(buf.getData(),pos,len) catch( e : Dynamic ) throw new EofException();
		#else
			if( this.len == 0 && len > 0 )
				throw new EofException();
			if( this.len < len )
				len = this.len;
			#if neko
			try untyped __dollar__sblit(buf.getData(),pos,b,this.pos,len) catch( e : Dynamic ) throw new OutsideBoundsException();
			#elseif php
			// TODO: test me
			untyped __php__("$buf->b = substr($buf->b, 0, $pos) . substr($this->b, $this->pos, $len) . substr($buf->b, $pos+$len)"); //__call__("substr", b, 0, pos)+__call__("substr", src.b, srcpos, len)+__call__("substr", b, pos+len);
//			var b2 = untyped __php__("& $buf->b");
//			b2 = untyped __call__("substr", b2, 0, pos)+__call__("substr", b, 0, len)+__call__("substr", b2, pos+len);
			#else
			var b1 = b;
			var b2 = buf.getData();
			for( i in 0...len )
				b2[pos+i] = b1[this.pos+i];
			#end
			this.pos += len;
			this.len -= len;
		#end
		return len;
	}

	#if flash9
	override function setEndian(e) {
		bigEndian = e;
		b.endian = e ? flash.utils.Endian.BIG_ENDIAN : flash.utils.Endian.LITTLE_ENDIAN;
		return e;
	}

	public override function readFloat() {
		return try b.readFloat() catch( e : Dynamic ) throw new EofException();
	}

	public override function readDouble() {
		return try b.readDouble() catch( e : Dynamic ) throw new EofException();
	}

	public override function readInt8() {
		return try b.readByte() catch( e : Dynamic ) throw new EofException();
	}

	public override function readInt16() {
		return try b.readShort() catch( e : Dynamic ) throw new EofException();
	}

	public override function readUInt16() : Int {
		return try b.readUnsignedShort() catch( e : Dynamic ) throw new EofException();
	}

	public override function readInt31() {
		var n;
		try n = b.readInt() catch( e : Dynamic ) throw new EofException();
		if( (n >>> 30) & 1 != (n >>> 31) ) throw new OverflowException();
		return n;
	}

	public override function readUInt30() {
		var n;
		try n = b.readInt() catch( e : Dynamic ) throw new EofException();
		if( (n >>> 30) != 0 ) throw new OverflowException();
		return n;
	}

	public override function readInt32() : haxe.Int32 {
		return try cast b.readInt() catch( e : Dynamic ) throw new EofException();
	}

	public override function readString( len : Int ) {
		return try b.readUTFBytes(len) catch( e : Dynamic ) throw new EofException();
	}

	#end

}
