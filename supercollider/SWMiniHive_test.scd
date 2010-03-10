// =====================================================================
// SuperCollider Workspace
// =====================================================================

(
(
x = SWDataNetwork.new;
x.addOSCInterface;
q = SWMiniHive.new( x );
x.makeBasicGui;
q.makeGui;
TdefAllGui.new;
);

( // configuration of various nodes:
// Aaron
q.addConfig( 110, 8, 1, 0.05, 1/255 );
q.addConfig( 111, 8, 1, 0.05, 1/255 );
q.addConfig( 112, 8, 1, 0.05, 1/255 );
// Nick
q.addConfig( 113, 4, 10, 0.05, 1/255 );
q.addConfig( 114, 4, 10, 0.05, 1/255 );
// Ariadne
q.addConfig( 115, 7, 10, 0.05, 1/255 );
q.addConfig( 116, 8, 1, 0.05, 1/255 );
// Justin C.
q.addConfig( 117, 3, 10, 0.05, 1/255 );
q.addConfig( 118, 4, 1, 0.05, 1/255 );
// Justin L.
q.addConfig( 119, 3, 1, 0.05, 1/255 );

// DMX
x.addExpected( 10, \dmxOut, 12 );
);
);


~dmxFromPat = SWCombineNode.new( 10, x, 12 );
[130,131].do{ |it,i|
    x.nodes[it].action_( { |data|
        // reorder data and set in combine node
        ~dmxFromPat.set( i*6, data ); 
    }; );
};



//x.osc.clients.copy.do{ |it| if ( it.key == \justin ){ x.osc.removeClient( it.addr, it.key ) } };


q.swarm.do{ |it| [it.id,it.dt].postln; }

q.detectedNodes



q.swarm.at( 114 ).msgInterval = 0.5;

x.removeNode( 996 )
x.removeNode( 117 );

q.removeBee( 117 )

a = ( noInputs: 8, samplePerMessage: 1 )

a.keysValuesDo{ |key,val| [key,val].postln; }

x.addExpected( 10, \dmxOut, 12 );

x.setData( 10, Array.fill(12, {0} ));

Tdef( \dmxTest, {
	loop{ 
		x.setData( 10, Array.fill(12, {255.rand} ));
		0.5.wait;
	}
});

x.verbose

q.startSend;

q.stopSend;

q.setPWM( 110, [255,255,255, 255,255,255]);

q.setPWM( 109,  Array.fill( 6, 0 )) ;

q.setDigital( 110, Array.fill( 11, 1 ));
q.setDigital( 109, Array.fill( 11, 0 ));

q.swarm.at( 109 ).dt
q.swarm.at( 110 ).scale = 1/255;

q.swarm.at( 109 ).samplesPerMsg = 10;

[q.swarm.at( 117 ).msgInterval, q.swarm.at( 117 ).dt ]

q.swarm.at( 117 ).verbose = 0;
q.swarm.at(117).pwmData
q.swarm.at(117).digData

1/ 255

Tdef( \minibee110data ).isPlaying
Tdef( \minibee110data ).resume
Tdef( \minibee110timeOut ).isPlaying
Tdef( \minibee110timeOut ).reset.play

q.swarm.at( 110 )

x.removeNode( 420 )
x.removeNode( 423 )

q.verbose = 0

TdefAllGui.new;

b.status.string
b.w.refresh

q.xbee.light( 110, Array.fill( 6, 127 ) );


a = SWMiniHiveConfig.new;

a.getNodeID( "".catList([23,24,5,5 ,6,1,23,145].collect{ |it| it.asHexString(2)}).asSymbol );

b = SWMiniHiveConfigGui.new( a )

a.configLib.do{ |it| it.dump}
a.configLabels.at(0)
a.configLib.at( 'test' ).label

a.getConfig(2).label
a.configLabels

b.confs[0][2].value
items.postcs

b.configEdit.config.dump


b.updateGui;

a = SWMiniBeeConfig.new;
b = SWMiniBeeConfigGui.new(a);

b.getPinVals

b.checkConfig;

b.getConfig;

a.pinConfig;

b.updateGui;

a.pinConfig

a.getConfigMsg;


"".catList([23,24,5,5 ,6,1,23,145].collect{ |it| it.asHexString(2)}).postcs;

240.asHexString(2)