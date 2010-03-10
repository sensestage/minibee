XBeeAT : Arduino
{
	*parserClass {
		^ArduinoParserSMS
	}
	send { | ... args |
		args.do { |obj,i|
			port.putAll(obj.asString);
		};
		port.put(13);
	}
}


XBeeATParser : ArduinoParser
{
	var msg, msgArgStream, state;

	parse {
		msg = Array[];
		msgArgStream = CollStream();
		state = nil;
		loop { this.parseByte(port.read) };
	}

	finishArg {
		var msgArg = msgArgStream.contents; msgArgStream.reset;
		if (msgArg.notEmpty) {
			if (msgArg.first.isDecDigit) {
				msgArg = msgArg.asInteger;
			};
			msg = msg.add(msgArg);
		}
	}
	parseByte { | byte |
		if (byte === 13) {
			// finish last arg
			this.finishArg;
			state = nil;
			if (msg.notEmpty) {
				this.dispatch(msg);
				msg = Array[];
			};
		} {
			// add to current arg
			msgArgStream << byte.asAscii;
		}
	}
}

// EOF