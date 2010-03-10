SWMiniHiveConfig{

	var <configLib;
	var <hiveConfigMap;
	var <hiveIdMap;
	var <hiveConfed;
	var <configLabels; // to derive configIDs from

	var idAllocator;

	*new{
		^super.new.init;
	}

	makeGui{
		^SWMiniHiveConfigGui.new( this );
	}

	init{
		configLib = IdentityDictionary.new;     // labels -> SWMiniBeeConfigs
		hiveConfigMap = IdentityDictionary.new; // serial IDs -> config label
		hiveIdMap = IdentityDictionary.new;     // serial IDs -> node IDs
		configLabels = List.new; // empty list with config labels
		hiveConfed = IdentityDictionary.new;    // serial IDs -> configured?
		
		idAllocator = LRUNumberAllocator.new(1,255);
	}

	getNodeID{ |serial|
		var id;
		id = hiveIdMap.at( serial );
		if ( id.isNil ){
			id = idAllocator.alloc;
			hiveIdMap.put( serial, id );
		};
		^id;
	}

	getConfigID{ |serial|
		var config,cid;
		config = hiveConfigMap.at( serial );
		if ( config.isNil ){
			("no config known for this device!" + serial).postln;
		}{
			cid = configLabels.indexOf( config ) + 1; // offset of one
		}
		^cid;
	}

	getConfigMsg{ |cid|
		var label,config;
		label = configLabels.at( cid - 1 );
		config = configLib.at( label );
		^config.getConfigMsg;
	}

	getConfig{ |cid|
		var label,config;
		label = configLabels.at( cid - 1 );
		config = configLib.at( label );
		^config;
	}

	getConfigIDLabel{ |label|
		var cid;
		cid = configLabels.indexOf( label ) + 1; // offset of one
		^cid;
	}

	isConfigured{ |serial|
		// three states : 
		// - send new config(1), 
		// - do not send config(0),
		// - must define config(2)
		var config = hiveConfed.at( serial );
		if ( config.isNil ){
			^2;
		};
		^config;
	}

	addConfig{ |config|
		if ( configLabels.select{ |it| it == config.label.asSymbol }.size == 0 ){
			configLabels.add( config.label.asSymbol );
		};
		configLib.put( config.label.asSymbol, config );
	}

	save{
		// save configuration to disk
	}

	load{
		// load configuration from disk
	}
}

SWMiniBeeConfig{

	classvar <pinTypes;

	var <>hive;
	var <label;
	var <>pinConfig;
	var <>samplesPerMsg;
	var <>msgInterval;
	

	*initClass{
		pinTypes = [
			\unconfigured,
			\digitalIn, \digitalOut, 
			\analogIn, \analogOut, \analogIn10bit,
			\SHTClock, \SHTData,
			\TWIClock, \TWIData,
			\Ping
		];
	}

	*getPinCID{ |name|
		^pinTypes.indexOf( name );
	}

	*getPinCaps{ |label|
		var caps;
		caps = switch( label,
			\SDA_A4, { this.filterPinTypes( [\TWIClock, \analogOut ]); },
			\SCL_A5, { this.filterPinTypes( [\TWIData, \analogOut ]); },
			\A0, { this.filterPinTypes( [\TWIData, \TWIClock, \analogOut ]); },
			\A1, { this.filterPinTypes( [\TWIData, \TWIClock, \analogOut ]); },
			\A2, { this.filterPinTypes( [\TWIData, \TWIClock, \analogOut ]); },
			\A3, { this.filterPinTypes( [\TWIData, \TWIClock, \analogOut ]); },
			\A6, { this.filterPinTypes( [\TWIData, \TWIClock, \analogOut ]); },
			\A7, { this.filterPinTypes( [\TWIData, \TWIClock, \analogOut ]); },
			\D3, { this.filterPinTypes( [\TWIData, \TWIClock, \analogIn, \analogIn10bit ]); },
			\D4, { this.filterPinTypes( [\TWIData, \TWIClock, \analogIn, \analogIn10bit, \analogOut ]); },
			\D5, { this.filterPinTypes( [\TWIData, \TWIClock, \analogIn, \analogIn10bit ]); },
			\D6, { this.filterPinTypes( [\TWIData, \TWIClock, \analogIn, \analogIn10bit ]); },
			\D7, { this.filterPinTypes( [\TWIData, \TWIClock, \analogIn, \analogIn10bit, \analogOut ]); },
			\D8, { this.filterPinTypes( [\TWIData, \TWIClock, \analogIn, \analogIn10bit, \analogOut ]); },
			\D9, { this.filterPinTypes( [\TWIData, \TWIClock, \analogIn, \analogIn10bit ]); },
			\D10, { this.filterPinTypes( [\TWIData, \TWIClock, \analogIn, \analogIn10bit ]); },
			\D11, { this.filterPinTypes( [\TWIData, \TWIClock, \analogIn, \analogIn10bit ]); },
			\D12, { this.filterPinTypes( [\TWIData, \TWIClock, \analogIn, \analogIn10bit, \analogOut ]); },
			\D13, { this.filterPinTypes( [\TWIData, \TWIClock, \analogIn, \analogIn10bit, \analogOut ]); }
			);
		^caps;
	}

	*filterPinTypes{ |filters|
		var caps = pinTypes;
		filters.do{ |it|
			caps = caps.reject{ |jt| jt == it };
		};
		//	caps.postln;
		^caps;
	}
	
	*new{
		^super.new.init;
	}

	init{
		pinConfig = Array.fill( 19, { \unconfigured } );
	}

	label_{ |lb|
		label = lb.asSymbol;
		if ( hive.notNil){
			hive.addConfig( this.deepCopy; );
		};
	}

	getConfigMsg{
		var pins,mint;
		// config has things like:
		// noInputs
		// samplesPerMsg
		// msgInterval
		// scale
		// pins
		pins = pinConfig.collect{ |it| SWMiniBeeConfig.getPinCID( it ) };
		mint = [ (msgInterval / 256).floor, msgInterval%256 ];
		^( mint ++ samplesPerMsg ++ pins );
	}

	makeGui{
		^SWMiniBeeConfigGui.new( this );
	}

	checkConfig{
		// check if SHTData is matched by SHTClock, and vice versa
		// check if TWIData is matched by TWIClock, and vice versa
		var hasSHTData, hasSHTClock, shtOk = true;
		var hasTWIData, hasTWIClock, twiOk = true;
		var configStatus = "";

		hasSHTClock = pinConfig.select{ |it| it == \SHTClock };
		if ( hasSHTClock.size == 1 ){
			shtOk = false;
			hasSHTData = pinConfig.select{ |it| it == \SHTData };
			if ( hasSHTData.size == 1 ){
				shtOk = true;
			}{
				if ( hasSHTData.size > 1 ){
					configStatus = configStatus ++ "Err: More than one SHTData pin defined!"

				}{
					configStatus = configStatus ++ "Err: No SHTData pin defined!"
				}
			}
		}{
			if ( hasSHTClock.size == 0 ){
				// check for data pin
				hasSHTData = pinConfig.select{ |it| it == \SHTData };
				if ( hasSHTData.size > 0 ){
					shtOk = false;
					configStatus = configStatus ++ "Err: No SHTClock pin defined!"
				}
			}{
				// more than one!
				shtOk = false;
				configStatus = configStatus ++ "Err: more than one SHTClock pin defined!"
			};
		};


		hasTWIClock = pinConfig.select{ |it| it == \TWIClock };
		if ( hasTWIClock.size == 1 ){
			twiOk = false;
			hasTWIData = pinConfig.select{ |it| it == \TWIData };
			if ( hasTWIData.size == 1 ){
				twiOk = true;
			}{
				if ( hasTWIData.size > 1 ){
					configStatus = configStatus ++ "Err: More than one TWIData pin defined!"

				}{
					configStatus = configStatus ++ "Err: No TWIData pin defined!"
				}
			}
		}{
			if ( hasTWIClock.size == 0 ){
				// check for data pin
				hasTWIData = pinConfig.select{ |it| it == \TWIData };
				if ( hasTWIData.size > 0 ){
					twiOk = false;
					configStatus = configStatus ++ "Err: No TWIClock pin defined!"
				}
			}{
				// more than one!
				twiOk = false;
				configStatus = configStatus ++ "Err: more than one TWIClock pin defined!"
			};
		};
		configStatus.postln;
		^[ twiOk, shtOk, configStatus ];
	}


}

SWMiniBeeConfigGui{

	var <config;

	var w;
	var left,right,top,bottom;
	var label,store,send;
	var <leftpins, <rightpins;
	var <status,<check;
	var noInputs;

	var msgInt, smpMsg;

	*new{ |config|
		^super.new.init( config );
	}

	init{ |conf|
		w = Window.new("MiniBee Configuration", Rect( 0, 0, 430, 350 ));
		
		top = CompositeView.new( w, Rect( 0,0, 430, 60 ));
		top.addFlowLayout;

		label = TextField.new( top, 300@25 );
		store = Button.new( top, 50@25 ).states_( [[ "store"]]).action_({ this.storeConfig; });
		send = Button.new( top, 50@25 ).states_( [[ "send"]]).action_({ "sending config".postln; });

		msgInt = EZNumber.new( top, 160@20, "delta T (ms)", [5,100000,\exponential,1].asSpec, {}, 50, labelWidth: 80 );
		smpMsg = EZNumber.new( top, 130@20, "samples/msg", [1,20,\linear,1].asSpec, {}, 1, labelWidth: 90 );
		//		noInputs = EZNumber.new( top, 80@20, "#in", labelWidth:40 );
		
		left = CompositeView( w,  Rect(0,  60, 215, 260) );
		right = CompositeView( w, Rect(215,60, 215, 260) );

		bottom = CompositeView( w, Rect( 0, 320, 430, 30 ) );

		left.addFlowLayout(2@2,2@2);
		right.addFlowLayout(2@2,2@2);
		bottom.addFlowLayout(2@2,2@2);

		StaticText.new( left, 180@20 ); // spacer

		leftpins = [ \SDA_A4, \SCL_A5, \A0, \A1, \A2, \A3, \A6, \A7 ].collect{ |it|
			this.createPin( it, left );
		};

		leftpins[0][1].action = { |b| if ( b.items.at( b.value ) == \TWIData ) { 
			leftpins[1][1].value = SWMiniBeeConfig.getPinCaps( \SCL_A5 ).indexOf( \TWIClock );
		} };
		leftpins[1][1].action = { |b| if ( b.items.at( b.value ) == \TWIClock ) { 
			leftpins[0][1].value = SWMiniBeeConfig.getPinCaps( \SDA_A4 ).indexOf( \TWIData );
		} };

		rightpins = (13..3).collect{ |it|
			this.createPin( ("D"++it).asSymbol, right );
		};

		check = Button.new( bottom, 50@25 ).states_( [[ "check"]]).action_({ this.checkConfig; });
		status = StaticText.new( bottom, 370@25 );

		w.front;

		if ( conf.notNil ){
			this.config = conf;
		}{
			this.config = SWMiniBeeConfig.new;
		};

	}

	config_{ |conf,hconf|
		// set all values to given config
		config = conf;
		if ( hconf.notNil ){
			config.hive = hconf;
		};
		this.updateGui;
	}

	updateGui{
		var rpins,lpins;
		label.string_( config.label.asString );

		rpins = config.pinConfig.copyRange( 0, 10 ).reverse;
		lpins = config.pinConfig.copyRange( 11, 18 ).at( [4,5, 0,1,2,3, 6,7]);
		rightpins.do{ |it,i|
			it[1].value_( it[1].items.indexOf( rpins[i] ) );
		};
		leftpins.do{ |it,i|
			it[1].value_( it[1].items.indexOf( lpins[i] ) );
		};
	}

	checkConfig{
		var res;
		// checks validity of config and indicates errors if any
		this.getConfig;
		res = config.checkConfig;
		res.postln;
		status.string_( res[2] );
		w.refresh;
		// make wrong ones red
		if ( res[0] && res[1] ){
			status.string_( "configuration valid" );
		}
	}

	storeConfig{
		// check the label, and put config under label in hiveconfig
		config.label = label.string;
		this.getConfig;
	}

	getConfig{
		// reads the gui status for the config
		config.msgInterval = msgInt.value;
		config.samplesPerMsg = smpMsg.value;
		config.pinConfig = this.getPinVals;
	}

	createPin{ |label,parent|
		^[
			StaticText.new( parent, 50@20 ).string_( label ).align_( \right ),
			PopUpMenu.new( parent, 150@20 ).items_( 
				SWMiniBeeConfig.getPinCaps( label );
			)
		]
	}

	getPinVals{
		^(
			rightpins.collect{ |it| it[1].items.at( it[1].value) }.reverse ++
			leftpins.collect{ |it| it[1].items.at( it[1].value) }.at( [2,3,4,5, 0,1, 6,7])
		)
	}

}

SWMiniHiveConfigGui{

	var w,view,hview;
	var <confs;
	var <header;
	var <hiveConf;

	var <configEdit;

	*new{ |hc|
		^super.new.init(hc);
	}

	init{ |hc|
		hiveConf = hc;
		
		w = Window.new("MiniHive Configuration", Rect( 0, 400, 440, 350 ));
		//	
		
		hview = CompositeView.new(w, Rect( 0,0, 440, 30));
		hview.addFlowLayout(2@2);
		header = [
			StaticText.new( hview, 130@20 ).string_("serial number"), // serial number
			StaticText.new( hview, 60@20 ).string_( "node ID" ), // node ID
			StaticText.new( hview, 100@20 ).string_( "config" ), // choice of configs
			StaticText.new( hview, 40@20 ).string_( "active" ), // active/not active
			StaticText.new( hview, 80@20 ).string_( "send config"), // send config
		];

		view = CompositeView.new( w, Rect( 0,30, 440, 310 ));
		view.addFlowLayout(2@2);

		confs = List.new;

		configEdit = SWMiniBeeConfigGui.new;
		configEdit.config.hive = hiveConf;

		this.updateGui;
		w.front;
	}

	addLine{
		confs.add([
			StaticText.new( view, 130@20 ), // serial number
			StaticText.new( view, 60@20 ).align_('right'), // node ID
			PopUpMenu.new( view, 100@20 ).items_(  [ "*new*" ] ++ hiveConf.configLabels).action_({ |men|
				men.value.postln;
				if ( men.value > 0 ){
					configEdit.config_( 
						hiveConf.getConfig( men.value ).deepCopy,
						hiveConf );
				}
			}), // choice of configs
			Button.new( view, 40@20 ).states_( [['o',Color.black, Color.green], ['x', Color.black, Color.red ]]), // active/not active
			Button.new( view, 80@20 ).states_( [['known'],['send'],['define']]), // send config
		]);
	}

	updateLine{ |key|
		confs.last[0].string_( key );
		confs.last[1].string_( hiveConf.hiveIdMap.at( key ) );
		if ( hiveConf.hiveConfigMap.at( key ).notNil ){
			confs.last[2].value_( 
				hiveConf.getConfigIDLabel(
					hiveConf.hiveConfigMap.at( key )
				) );
		}{
			confs.last[2].value_( 0 );
		};
		// set active
		confs.last[4].value_( hiveConf.isConfigured( key ));
	}

	updateGui{
		hiveConf.hiveIdMap.keys.do{ |key|
			this.addLine;
			this.updateLine( key );
		}
	}
}