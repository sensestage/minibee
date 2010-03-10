// =====================================================================
// SimpleMessageSystem interface

XBeeSMS2 : Arduino
{
	*initClass{
		crtscts = true;
	}

	*parserClass {
		^XBeeParserSMS2
	}

	start{
		port.put( $r.ascii );
	}

	stop{
		port.put( $x.ascii );
	}

	send{ |data|
		port.putAll( data );
	}

	light{ |id,vals|
		port.putAll( 
			[ 92, $l.ascii ] ++
			([ id ] ++ vals).collect{ |it| it.asInteger }
			.replaceAllSuchThat( { |it| it == 10 }, [92,10])
			.replaceAllSuchThat( { |it| it == 92 }, [92,92])
			.flatten
			++ [ 10 ] );
	}

	motor{ |val|
		port.putAll( [ $m.ascii, val.max(0).min(9).asInteger.asDigit ] );
	}

	// PRIVATE
	prDispatchMessage { | msg |
		action.value(msg);
	}
}

XBeeParserSMS2 : ArduinoParser
{
	var msg, msgArgStream, state;

	var <>verbose = 0;

	var <logfile;
	var record = false;

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
			if ( verbose > 1, { msg.postln; } );
		}
	}

	parseByte { | byte |
		[ Process.elapsedTime ].post; " ".post;
		byte.asAscii.postln;
	}
}

// EOF