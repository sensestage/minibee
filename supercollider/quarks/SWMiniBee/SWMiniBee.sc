// =====================================================================
// SimpleMessageSystem interface

SWMiniHive {

	var <network;

	var <detectedNodes;
	var <>xbee;

	var <>swarm;

	var <>redundancy = 5;
	var <>serialDT = 0.020;
	var <outTask;

	var <>verbose = 0;

	//	var <>configs;

	var <hiveConfig;

	var <outMessages;
	var <outMsgID = 0;

	/*
	*new { | network, portName, baudrate |
		^super.new( portName, baudrate ).myInit( network )
	}
	*/

	*new { | network |
		^super.new.network_( network ).init;
	}

	makeGui{
		^SWMiniHiveGui.new( this );
	}

	setXBee{ |xb|
		xbee = xb;
	}

	init{
		hiveConfig = SWMiniHiveConfig.new;

		detectedNodes = Set.new;
		swarm = IdentityDictionary.new;
		//	configs = IdentityDictionary.new;

		outMessages = List.new;
	}

	network_{ |nw|
		network = nw;
		network.hive = this;		
	}

	/*
		addConfig{ |id, noInputs, smpPmsg = 1, msgInt = 50, scale|
		scale = scale ? (1/255);
		configs.put( id, ( noInputs: noInputs, samplesPerMsg: smpPmsg, msgInterval: msgInt, scale: scale ) );
		}
	*/

	addBee{ |id,bee|
		swarm.put( id, bee );
		bee.network = network;
	}

	removeBee{ |id|
		swarm.removeAt( id );
	}

	resetDetected{
		detectedNodes = Set.new;		
	}

	addDetected{
		detectedNodes.do{ |it|
			network.addExpected( it, ("minibee"++it).asSymbol );
			if ( swarm.at( it ).isNil, {
				this.createBee( it );
			} );
		};
	}

	createBee{ |id|
		var newbee;
		newbee = SWMiniBee.new( id, ("minibee"++id).asSymbol );

		/*
		if ( configs.at( id ).notNil ){
			configs.at( id ).keysValuesDo{ |key,val|
				if ( key == \noInputs ){
					newbee.noInputs_( val );
				};
				if ( key == \samplesPerMsg ){
					newbee.samplesPerMsg_( val );
				};
				if ( key == \msgInterval ){
					newbee.msgInterval_( val );
				};
				if ( key == \scale ){
					newbee.scale_( val );
				};
			};
		};
		*/
		this.addBee( id, newbee );	
	}

	start{
		xbee.action = { |type,msg|
			//	type.postcs;
			switch( type.asSymbol,
				'd',{
					detectedNodes.add( msg[1] );
					try{ 
						swarm.at( msg[1] ).parseData( msg[2], msg.copyToEnd( 3 ) );
					}
				},
				's',{ // 8 byte serial number
					this.parseSerialNumber( msg );
				}
			);
			//	fork{
			//	network.setData( msg[0], msg.copyToEnd( 1 ) ); 
			//	}
		}
	}

	parseSerialNumber{ |msg|
		var id;
		var serial = "".catList(msg.copyRange(0,7).collect{ |it| it.asHexString(2) }).asSymbol;
		id = hiveConfig.getNodeID( serial );
		switch( hiveConfig.isConfigured( serial ),
			0, { outMessages.add( [ $I ] ++ msg ++ id ); };
			1, { outMessages.add( [ $I ] ++ msg ++ id ++ hiveConfig.getConfigID( serial ) ) },
			2, { "Please define configuration".postln; }
		);
	}

	sendConfig{ |cid|
		outMessages.add( [$C] ++ hiveConfig.getConfigMsg( cid ) );
	}

	stop{
		xbee.action = {};
	}

	startSend{
		if ( outTask.isNil ){ this.createOutputTask };
		outTask.play;
	}

	stopSend{
		outTask.stop;
	}

	createOutputTask{ 
		outTask = Tdef( \miniHiveOut, {
			var msg;
			loop{
				outMessages.copy.do{ |it,i|
					xbee.sendMsgNoID( it[0], it.copyToEnd( 1 ) );
					outMessages.remove( it );
					serialDT.wait;
				};
				swarm.do{ |it|
					if ( verbose > 1 ){ it.dump };
					if ( it.repeatsPWM < this.redundancy ){
						msg = it.getPWMMsg;
						xbee.sendMsgNoID( $P, msg  );
						if ( verbose > 0 ){ [ $P, msg ].postln; };
						serialDT.wait;
					};
				};
				swarm.do{ |it|
					if ( verbose > 1 ){ it.dump };
					if ( it.repeatsDig < this.redundancy ){
						msg = it.getDigMsg;
						xbee.sendMsgNoID( $D, msg );
						if ( verbose > 0 ){ [ $D, msg ].postln; };
						serialDT.wait;
					};
				};
				// wait always between iterations to prevent endless loop
				serialDT.wait;
			}
		});
	}

	setPWM{ |id,data|
		var bee = swarm.at(id);
		if ( bee.notNil ){
			bee.setPWM( data );
		}
	}

	setDigital{ |id,data|
		var bee = swarm.at(id);
		if ( bee.notNil ){
			bee.setDigital( data );
		}
	}
}

SWMiniBee{

	var <>id; // node ID of the MiniBee itself
	var <>label;
	var <>dataNodeIn; // data node in network that receives data from this minibee
	//	var <>dataNodeOutPWM; // data node in network from which we are sending data to this minibee, PWM
	//	var <>dataNodeOutDig; // data node in network from which we are sending data to this minibee, digital

	var <network;
	
	var <>config;


	/// ------- input --------
	//	var <>dataIn;

	var <>scale = 1;
	var <>noInputs = 1;
	var <samplesPerMsg = 1;
	var <msgInterval = 0.050;
	var <dt; // dt for task. Calculated when either of the above are set
	var <lastTime;

	var <timeOutTask;
	var <>timeOutTime = 0.1;

	var <dataInBuffer;
	var <dataTask;
	//	var <dataStream;
	var <dataFunc;

	var <msgRecvID = 0;

	/// ------- output --------

	var <msgSendID = 0;

	//	var <msgIDpwm = 0;
	//	var <msgIDdig = 0;
	var <repeatsPWM = 0;
	var <repeatsDig = 0;
	var <pwmData;
	var <digData;

	var <>verbose = 0;


	*new { | id, label |
		^super.new.id_(id).label_( label ).init;
	}


	network_{ |nw|
		network = nw;
		dataFunc = { |data| 
			network.setData( this.dataNodeIn, data*scale );
			if ( verbose > 1 ){ [id, this.dataNodeIn, data].postln; };
		};
	}

	init{ 
		config = SWMiniBeeConfig.new;
		// dataNodeIn can be configured to something else, but by default it is equal to the MiniBee node ID
		dataNodeIn = id;
		// dummy func until network is set:
		dataFunc = { |data| data.postln; };

		dataInBuffer = RingList.fill( 100, 0 );
		//		dataStream = Pseq( dataInBuffer, inf ).asStream;
		dt = msgInterval / samplesPerMsg;
		dataTask = Tdef( (label++"data").asSymbol, {
			loop{
				dataFunc.value( dataInBuffer.read );
				this.dt.max(0.002).wait;
			}
		});
		// timeOutTask stops the task when we don't get a new message for longer than the msgInterval.
		timeOutTask = Tdef( (label++"timeOut").asSymbol, {
			loop{
				if ( (Process.elapsedTime - lastTime) > timeOutTime ){
					dataTask.stop;
				};
				msgInterval.wait; // maybe add some extra leeway?
			}
		});
		//		lastTime = Process.elapsedTime;
	}

	msgInterval_{ |mi|
		msgInterval = mi;
		dt = msgInterval / samplesPerMsg;
	}

	samplesPerMsg_{ |sm|
		samplesPerMsg = sm;
		dt = msgInterval / samplesPerMsg;
	}
	
	parseData{ |msgID, data|
		var diffTime;
		if ( msgID != msgRecvID ){ // parse only if we didn't haven't parsed this message yet
			msgRecvID = msgID;
			if ( samplesPerMsg == 1 ){
				// if only one sample per message, directly put it on the network
				dataFunc.value( data );
			}{// if multiple samples per message, we will play them onto the network accordingly
				// automatically adjust msgInterval according to last measured interval.
				diffTime = lastTime;
				lastTime = Process.elapsedTime;
				if ( diffTime.notNil ){
					diffTime = lastTime - diffTime;
					this.msgInterval = diffTime.max( 0.020 ); // at least 0.1ms
				};
				// clump data according to how many inputs we have, and flop it so that each element is a collection of current data values
				data = data.clump( noInputs );
				/*
					if ( noInputs == 1 ){
					data = data.unbubble;
					};
				*/
				if ( verbose > 0 ){ data.postln; };
				// add it to the ringbuffer:
				dataInBuffer.addData( data );
				// resume datatask if it is not still playing
				if ( dataTask.isPlaying.not ){
					dataTask.resume;
					if ( dataTask.isPlaying.not ){
						dataTask.play;
						//		timeOutTask.reset.play;
					};
				};
				// reset the time out task:
				//	timeOutTask.reset.play;
			}
		}
	}

	setPWM{ |data|
		if ( verbose > 0 ){ ("set pwm"+id+data).postln; };
 		pwmData = data;
		repeatsPWM = 0;
		msgSendID = msgSendID + 1;
		msgSendID = msgSendID.mod( 256 );
	}

	getPWMMsg{
		repeatsPWM = repeatsPWM + 1;
		^([ id, msgSendID ] ++ pwmData);
	}

	setDigital{ |data|
		if ( verbose > 0 ){ ("set dig"+id+data).postln; };
 		digData = data;
		repeatsDig = 0;
		msgSendID = msgSendID + 1;
		msgSendID = msgSendID.mod( 256 );
	}

	getDigMsg{
		repeatsDig = repeatsDig + 1;
		^([ id, msgSendID ] ++ digData);
	}



}

// EOF