/*
 * Copyright (c) 2008, The Caffeine-hx project contributors
 * Original author : Russell Weir
 * Contributors:
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
 * THIS SOFTWARE IS PROVIDED BY THE CAFFEINE-HX PROJECT CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE CAFFEINE-HX PROJECT CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
 * THE POSSIBILITY OF SUCH DAMAGE.
 */


package system.log;

import system.log.LogLevel;

/**
	Log to a text file. The class is started with a logging level
**/

#if neko

class File extends EventLog, implements IEventLog {
	var STDOUT 		: neko.io.FileOutput;

	/**
		Logs to the provided file handle. If the handle is null, logging will go
		to STDOUT
	**/
	public function new(service: String,  level:LogLevel, ?hndFile : neko.io.FileOutput ) {
		super(service, level);
		if(hndFile == null)
			STDOUT = neko.io.File.stdout();
		else
			STDOUT = hndFile;
	}

	override public function _log(s : String, ?lvl : LogLevel) {
		if(lvl == null)
			lvl = INFO;
		if(Type.enumIndex(lvl) >= Type.enumIndex(level)) {
			STDOUT.write(serviceName + ": "+Std.string(lvl)+" : "+ s + "\n");
			STDOUT.flush();
		}
	}
}

#end
