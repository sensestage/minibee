XBeeLogAnalysis{

	var <>offsetCounter = 0;

	var <data;
	var <file;

	*new { |fn|
		^super.new.init(fn);
	}
	
	init { |fn|
		file = MultiFileReader.new( fn );
		data = IdentityDictionary.new;
	}

	readAll{
		var line;
		while({ line = file.nextInterpret; line.notNil }, {
			if ( data[ line[0] ].isNil )
			{ data.put( line[0], [line] ) }
			{ data[ line[0] ] = data[ line[0] ] ++ [ line ] };
		});
	}

	nodes{
		^data.keys
	}

	allTime{
		^data.asArray.flatten.flop[1];
	}

	nodeTime{ |id|
		^data[id].flop[1].drop(1)
	}

	nodeTimeFilter13{ |id|
		^this.nodeTime( id ).at( 
			this.nodeSeq( id ).selectIndex{ |it| 
				(( it[0][1] == 12) and: (it[1][1] == 14 )).not and: 
				(( it[0] == [12,255] ) and: ( it[1] == [14,0] )).not 
			}
		);
	}

	nodeTimeFilterMissed{ |id|
		^this.nodeTime( id ).at( 
			this.nodeSeq( id ).differentiate.selectIndex{ |it| 
				it < 2
			}
		);
	}

	nodeSequence{ |id|
		^data[id].flop[2].drop(1)
	}

	nodeSeq{ |id|
		^this.nodeSequence( id ).collect{ |it| (it.at( offsetCounter + [0,1] )*[256,1]).sum };
	}

	nodeSeqDiff{ |id|
		^this.nodeSeq( id ).differentiate.drop(1);
		//		^this.nodeSequence( id ).collect{ |it| (it.at( offsetCounter + [0,1] )*[256,1]).sum }.differentiate.drop(1);
	}

	outliers{ |data,threshold=1|
		^data.select{|it| it > threshold }.size / data.size;
	}

	nodeSequenceFilter13{ |id|
		^this.nodeSequence( id ).slide(2).clump(2).select{ |it| 
				(( it[0][offsetCounter + 1] == 12) and: (it[1][offsetCounter + 1] == 14 )).not and: 
				(( it[0].at( offsetCounter + [0,1]) == [12,255] ) and: ( it[1].at( offsetCounter + [0,1] ) == [14,0] )).not 
		}.collect{ |it| it[0] }
	}

	nodeSeqDiffF13{ |id|
		^this.nodeSequenceFilter13( id ).collect{ |it| (it.at( offsetCounter + [0,1] )*[256,1]).sum }.differentiate.drop(1);
	}

	missedPackagesStats{ |nodeid,threshold=1,filter13=false|
		var mpacks = this.missedPackages( nodeid, threshold, filter13 );
		if ( filter13 ){
			^[ mpacks.size / this.nodeSequenceFilter13(nodeid).size, 
				mpacks.size, 
				this.stats( mpacks.collect{ |it| it[2] } ),
				mpacks
			];
		}{
			^[ mpacks.size / this.nodeSequence(nodeid).size, 
				mpacks.size, 
				this.stats( mpacks.collect{ |it| it[2] } ),
				mpacks
			];
		}
	}

	missedPackages{ |nodeid,threshold=1,filter13=false|
		var seq, seqd, ids, res;
		seqd = this.nodeSeqDiff( nodeid );
		ids = seqd.selectIndex{|it| it > threshold };
		seq = this.nodeSequence( nodeid );
		res = ids.collect{ |index| seq.at( [ index, index+1 ] ) ++ seqd[index] };
		if ( filter13 ){
			res = res.select{ |it| 
				(( it[0][offsetCounter + 1] == 12) and: (it[1][offsetCounter + 1] == 14 )).not and: 
				(( it[0].at( offsetCounter + [0,1]) == [12,255] ) and: ( it[1].at( offsetCounter + [0,1] ) == [14,0] )).not 
			//	(( it[0][1] == 12) and: (it[1][1] == 14 )).not and: 
			//	(( it[0] == [12,255] ) and: ( it[1] == [14,0] )).not 
			};
		};
		^res;
	}

	stats{ |seq|
		if ( seq.first.isArray ){
				^seq.collect{ |it| [ it.mean, it.stdDev, it.maxItem, it.minItem ] };
			}{
				^[ seq.mean, seq.stdDev, seq.minItem, seq.maxItem ]
			}
	}

	close{
		file.close;
	}

}