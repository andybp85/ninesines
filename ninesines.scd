// NineSines: nine oscillator additive synth loosely based on a Hammond organ.

(
// set up midi
MIDIClient.init;
MIDIIn.disconnectAll;
MIDIIn.connectAll;
)

(
// Nektar Panorama P6
var midimap = (
	modwheel: 1,
    mastervol: 7,
    osc1: (
        level: 3
    ),
	harms: {|i| (
        level: 40 + i,
        tune: 32 + i,
        fine: 48 + i,
        upordown: 56 + i
    )}!8
);

var a = pow(2,12.reciprocal); // 2^(1/12), need for half step calculation
var c = pow(2,1200.reciprocal); // 2^(1/1200), need for cents calculation

// these functions handle the logic for playing and updating the synth defined in the SynthDef below
// design goal: midi messages are interpreted in these functions, synthdef just speaks frequencies
var calclevels = { | ccs |
    var mastervol = ccs@(midimap.mastervol) / 127;
    // scale the levels so multiple oscs are as loud as one
    var ccsum = [ccs@(midimap.osc1.level)].addAll({|i| ccs@(midimap.harms@i).level}!8).sum;
    if (ccsum == 0,
        { [0]!9 },
        { [mastervol * ((127 * (ccs@(midimap.osc1.level) / ccsum)) / 127)].addAll({ | i |
            var harm = midimap.harms@i;
            mastervol * ((127 *(ccs@(harm.level) / ccsum)) / 127)
        }!8)
    });
};

var calcbend = { | bendval, halfsteps = 2 |
    var benddiff = round((bendval - 8192) / (8192 / 2), 0.01);
	pow(a, benddiff);
};

var calctunings = { | ccs |
    [0].addAll({ | i |
        var harm = midimap.harms@i;
        if( ccs@(harm.upordown) == 0,
            {ccs@(harm.tune) * -1},
            {ccs@(harm.tune)});
    }!8)
};

var calccents = { | ccs |
    [1].addAll({ | i |
        var harm = midimap.harms@i;
        var finediff = (ccs@(harm.fine) + 1) - 64;
        pow(c, finediff)
    }!8);
};

~playninesines = { | note, vel, state |
    var levels = calclevels.value(state.ccs);
    Synth(\ninesines, [
        \note, note,
        \vel, vel,
        \levels, levels,
        // \amp, calcamp.value(levels, state.midinotes),
        \bendfreq, calcbend.value(state.bend),
        \tunings, calctunings.value(state.ccs),
        \fine, calccents.value(state.ccs)
    ])
};

~tuneninesines = { | synth, state |
    var levels = calclevels.value(state.ccs);
    synth.set(
        \levels, levels,
        // \amp, calcamp.value(levels, state.midinotes),
        \bendfreq, calcbend.value(state.bend),
        \tunings, calctunings.value(state.ccs),
        \fine, calccents.value(state.ccs)
    )
};

SynthDef(\ninesines, { |
	note,
	vel,
    // tunings = #[ 1, 0.25, 0.5, 2, 3, 4, 5, 6, 7 ],
    tunings = #[ 0, 0, 0, 0, 0, 0, 0, 0, 0 ],
    fine = #[ 1, 1, 1, 1, 1, 1, 1, 1, 1 ],
    levels = #[ 0, 0, 0 , 0, 0, 0, 0, 0, 0 ],
    amp = 1,
    phases = #[ 0, 0, 0, 0, 0, 0, 0, 0, 0 ],
	bendfreq = 1,
	bendhalfsteps = 2,
	gate = 1 |

    var oscs = tunings.collect({|tuning, i| SinOsc.ar(((note + tuning).midicps * fine@i) * bendfreq, phases@i, vel * 0.00315 /** amp*/ * (levels@i))});

    Out.ar(0, Pan2.ar(EnvGen.kr(Env.asr, gate, doneAction: 2) * oscs.sum));
}).add;
)

(
// TODO: make reusable midi class

var state = (
    midinotes: nil!128,
    ccs: 0!128,
    bend: 0
);

// set controls with midpoint zeros
{|i| state.ccs.put(i + 48, 63)}!8;

// midi listeners
MIDIdef.cc(\updateccs, { | val, num, chan, src |
	state.ccs.put(num, val);
});

MIDIdef.noteOn(\keypress, { | val, num, chan, src |
	var node = state.midinotes@num;
	if (node.notNil, {
		node.release;
		state.midinotes.put(num, nil);
	});

	node = ~playninesines.value(num, val, state);
	state.midinotes.put(num, node);
});

MIDIdef.noteOff(\keyrelease, { | val, num, chan, src |
	var node = state.midinotes@num;
	if (node.notNil, {
		node.release;
		state.midinotes.put(num, nil);
	});
});

MIDIdef.cc(\tune, { | val, num, chan, src |
	state.midinotes.do({ | synth |
        synth.notNil and: { ~tuneninesines.value(synth, state) }
	});
});

MIDIdef.bend(\bend, { | val, num, chan, src |
    state.bend = val;
	state.midinotes.do({ | synth, i |
		synth.notNil and: { ~tuneninesines.value(synth, state, val) }
	});
});
)
