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
	harms: {|i| (level: 40 + i, tune: 32 + i, fine: 48 + i, upordown: 56 + i)}!8
);

var a = pow(2,12.reciprocal); // 2^(1/12), need for bend freq calculation

// these functions handle the logic for playing and updating the synth defined in the SynthDef below
// design goal: midi messages are interpreted in these functions, synthdef just speaks frequencies
var calclevels = { | ccs |
    var mastervol = ccs@(midimap.mastervol) / 110; // leave some headroom

    [mastervol * (ccs@(midimap.osc1.level) / 127)].addAll({ | i |
        var harm = midimap.harms@i;
        mastervol * (ccs@(harm.level) / 127)
    }!8)
};

var calcbend = { | bendval, halfsteps = 2 |
    var benddiff = round((bendval - 8192) / (8192 / 2), 0.01);
	var bendfreq = pow(a, benddiff);

    bendfreq;
};

var calctunings = { | ccs |
    /*var phases = [0].addAll({|i|
        var harm = midimap.harms@i;
        (ccs@(harm.tune)/10 * pi).mod(2pi);
    }!8);*/

    var tunings = [0].addAll({ | i |
        var harm = midimap.harms@i;
        if( ccs@(harm.upordown) == 0,
            {ccs@(harm.tune) * -1},
            {ccs@(harm.tune)});
    }!8);

    tunings.postln;
    tunings;
};

~playninesines = { | note, vel, ccs, bend |
	 Synth(\ninesines, [
		\note, note,
		\vel, vel,
        \levels, calclevels.value(ccs),
        \bendfreq, calcbend.value(bend),
        \tunings, calctunings.value(ccs)
	]);
};

~tuneninesines = { | synth, val, num, bend, ccs |
    synth.set(
        \levels, calclevels.value(ccs),
        \bendfreq, calcbend.value(bend),
        \tunings, calctunings.value(ccs)
    );
};

SynthDef(\ninesines, { |
	note,
	vel,
    tunings = #[ 1, 0.25, 0.5, 2, 3, 4, 5, 6, 7 ],
    fine = #[ 1, 0.25, 0.5, 2, 3, 4, 5, 6, 7 ],
    levels = #[ 0, 0, 0 , 0, 0, 0, 0, 0, 0 ],
    phases = #[ 0, 0, 0, 0, 0, 0, 0, 0, 0 ],
	bendfreq = 1,
	bendhalfsteps = 2,
	gate = 1 |

    var amp = vel * 0.00315 / (levels.sum.log / 2 + 2); // scale the amplitude to prevent clipping

    var oscs = tunings.collect({|tuning, i| SinOsc.ar(((note + tuning).midicps + fine@i) * bendfreq, phases@i, amp * (levels@i))});

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

	node = ~playninesines.value(num, val, state.ccs, state.bend);
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
		synth.notNil and: { ~tuneninesines.value(synth, val, num, state.bend, state.ccs) }

	});
});

MIDIdef.bend(\bend, { | val, num, chan, src |
    state.bend = val;
	state.midinotes.do({ | synth, i |
		synth.notNil and: {
            ~tuneninesines.value(synth, val, num, val, state.ccs);
        }
	});
});
)
