XBeeSMSGui {

	var <>network;
	var <xbee;

	var <w, dev, baud;
	var verb,openBut,startBut;
	var detect,add;

	var <detectedNodes;

	*new{ |network|
		^super.new.network_( network ).init;
	}

	init {

		detectedNodes = Set.new;

		w = Window.new("XBee", Rect( 0, 280, 200, 150 ));
		w.view.decorator = FlowLayout.new(w.bounds,2@2,2@2);
		
		StaticText.new( w, 200@22).string_(
			"XBee Network").align_( \center).font_( GUI.font.new( "Helvetica Bold", 18) );

		dev = EZPopUpMenu.new(w, 164@22, "Device: ", 
			SerialPort.devices.reverse.collect{ |it| Association.new( it.asSymbol, {} )},
			labelWidth: 50
		);

		Button.new( w, 30@22).states_([["Upd"]]).action_( { this.refreshDev; });

		baud = EZPopUpMenu.new(w, 200@22, "Baudrate: ", 
			[9600,19200,115200].collect{ |it| Association.new( it.asSymbol, {} ) },
			initVal: 1, labelWidth: 70
		);

		openBut = Button.new(w, 81@22)
		.states_( [["OPEN",Color.red,Color.white],
			["CLOSE",Color.black,Color.red]])
		.action_( { |but| 
			if ( but.value == 1 ) 
			{ xbee = XBeeSMS.new( dev.menu.item.asString, baud.menu.item.asInteger ); startBut.enabled_( true ); }
			{ xbee.close; startBut.enabled_( false ); }
		});
		
		startBut = Button.new(w, 81@22)
		.states_( 
			[["START",Color.red,Color.white],
				["STOP",Color.black,Color.red]])
		.action_( { |but| 
			if ( but.value == 1 ) { 
				xbee.action = { |msg| 
					detectedNodes.add( msg[0] );
					fork{ 
						network.setData( msg[0], msg.copyToEnd(1) );
					}
				}
			}{ 
				xbee.action_( {} ); 
			}
		});
		startBut.enabled_( false );

		verb = GUI.button.new( w, 30@22 )
		.states_(
			(0..3).collect{ |it| [ "V"++it, Color.red ] } )
		.action_( { |but| xbee.parser.verbose = but.value } );


		Button.new( w, 96@22).states_([["Update nodes"]]).action_( { this.refreshDetected; });

		add = GUI.button.new( w, 96@22 )
		.states_( [[ "add to network", Color.red ]] )
		.action_( { |but| detectedNodes.do{ |it| network.addExpected( it ); } } );

		detect = StaticText.new( w, 200@22).align_( \center);
		
		w.front;
	}
	
	xbee_{ |xb|
	
	}

	refreshDetected{
		detect.string_( detectedNodes.asArray.sort.asString );
	}
	
	refreshDev{
		dev.items_( SerialPort.devices.reverse.collect{ |it| Association.new( it.asSymbol, {} )} );
	}


}

SWMiniHiveGui {

	var <>minibee;

	var <w, dev, baud;
	var verb,openBut,startBut;
	var detect,add,reset;
	var sendStart, sendStop;

	*new{ |minibee|
		^super.new.minibee_(minibee).init;
	}

	init {
		w = Window.new("SWMiniHive", Rect( 0, 280, 200, 180 ));
		w.view.decorator = FlowLayout.new(w.bounds,2@2,2@2);
		
		StaticText.new( w, 200@22).string_(
			"SWMiniBee Hive").align_( \center).font_( GUI.font.new( "Helvetica Bold", 18) );

		dev = EZPopUpMenu.new(w, 164@22, "Device: ", 
			SerialPort.devices.reverse.collect{ |it| Association.new( it.asSymbol, {} )},
			labelWidth: 50
		);

		Button.new( w, 30@22).states_([["Upd"]]).action_( { this.refreshDev; });

		baud = EZPopUpMenu.new(w, 200@22, "Baudrate: ", 
			[9600,19200,115200].collect{ |it| Association.new( it.asSymbol, {} ) },
			initVal: 1, labelWidth: 70
		);

		openBut = Button.new(w, 81@22)
		.states_( [["OPEN",Color.red,Color.white],
			["CLOSE",Color.black,Color.red]])
		.action_( { |but| 
			if ( but.value == 1 ) 
			{ 
				minibee.xbee = XBeeSMS.new( dev.menu.item.asString, baud.menu.item.asInteger ); 
				startBut.enabled_( true );
				sendStart.enabled_( true );
			}{
				minibee.xbee.close;
				startBut.enabled_( false );
				sendStart.enabled_( false );
			}
		});
		
		startBut = Button.new(w, 81@22)
		.states_( 
			[["START",Color.red,Color.white],
				["STOP",Color.black,Color.red]])
		.action_( { |but| 
			if ( but.value == 1 ) { 
				minibee.start;
			}{ 
				minibee.stop; 
			}
		});
		startBut.enabled_( false );

		verb = GUI.button.new( w, 30@22 )
		.states_(
			(0..3).collect{ |it| [ "V"++it, Color.red ] } )
		.action_( { |but| minibee.xbee.parser.verbose = but.value } );


		sendStart = Button.new(w, 81@22)
		.states_( 
			[["START",Color.red,Color.white],
				["STOP",Color.black,Color.red]])
		.action_( { |but| 
			if ( but.value == 1 ) { 
				minibee.startSend;
			}{ 
				minibee.stopSend; 
			}
		});
		sendStart.enabled_( false );

		w.view.decorator.nextLine;

		Button.new( w, 96@22).states_([["Update nodes"]]).action_( { this.refreshDetected; });

		add = GUI.button.new( w, 46@22 )
		.states_( [[ "add", Color.red ]] )
		.action_( { |but| minibee.addDetected; } );

		reset = GUI.button.new( w, 47@22 )
		.states_( [[ "reset", Color.red ]] )
		.action_( { |but| minibee.resetDetected; this.refreshDetected; } );

		detect = StaticText.new( w, 200@22).align_( \center);
		
		w.front;
	}

	refreshDetected{
		detect.string_( minibee.detectedNodes.asArray.sort.asString );
	}
	
	refreshDev{
		dev.items_( SerialPort.devices.reverse.collect{ |it| Association.new( it.asSymbol, {} )} );
	}


}