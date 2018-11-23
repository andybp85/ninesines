// this is working towards a generic midi synth interface
// js func ref:
// filter -> select
// map -> collect
// reduce -> reduce
(
// set up midi
MIDIClient.init;
MIDIIn.disconnectAll;
MIDIIn.connectAll;
)

(
var midimap = (
	modwheel: 1,
    osc1: (
        level: 3
    ),
	harms: {|i| (level: 40 + i, tune: 32 + i, on: 56 + i)}!8
);

// these functions handle the logic for playing and updating the synth defined in the SynthDef below
~playninesines = { | note, vel, ccs, bend |

    var levels = [ccs@(midimap.osc1.level)].addAll({|i| ccs@((midimap.harms@i).level)}!8);

	 Synth(\ninesines, [
		\note, note,
		\vel, vel,
        \levels, levels
        // \o1l, levels@0, \o2l, levels@1, \o3l, levels@2, \o4l, levels@3, \o5l, levels@4, \o6l, levels@5, \o7l, levels@6, \o8l, levels@7, \o9l, levels@8,
	]);
};

~tuneninesines= { | synth, val, num, bend, ccs |
    // var levels = #[];
    var levels = [(ccs@(midimap.osc1.level))].addAll({|i| ccs@((midimap.harms@i).level)}!8);
    levels.postln;
    synth.postln;
    synth.set(\bend, bend, \levels, levels);
    // synth.setn(\o1l, levels);
    // synth.setn(\o1l, levels);
};

SynthDef(\ninesines, { |
	note,
	vel,
    tunings = #[1, 0.25, 0.5, 2, 3, 4, 5, 6, 7],
    levels = #[ 0, 0, 0 , 0, 0, 0, 0, 0, 0 ],
    // o1l = 0, o2l = 0, o3l = 0, o4l = 0, o5l = 0, o6l = 0, o7l = 0, o8l = 0, o9l = 0,
    phases = #[ 0, 0, 0 , 0, 0, 0, 0, 0, 0 ],
	bend = 0,
	bendhalfsteps = 2,
	gate = 1 |

	var benddiff = round((bend - 8192) / (8192 / bendhalfsteps), 0.01);
	var bendfreq = pow(pow(2,12.reciprocal), benddiff);
    // var amp = vel * 0.00315 / ([o1l, o2l, o3l, o4l, o5l, o6l, o7l, o8l, o9l].sum.log / 2 + 2);
    var amp = vel * 0.00315 / (levels.sum.log / 2 + 2);

    /*// var oscs = [
    var osc0 = SinOsc.ar(note.midicps * bendfreq, 0, amp * (o1l / 127 ));
    var osc1 = SinOsc.ar(note.midicps * (1/4) * bendfreq, 0, amp * (o2l / 127 ));
    var osc2 = SinOsc.ar(note.midicps * (1/2) * bendfreq, 0, amp * (o3l / 127 ));
    var osc3 = SinOsc.ar(note.midicps * 2 * bendfreq, 0, amp * (o4l / 127 ));
    var osc4 = SinOsc.ar(note.midicps * 3 * bendfreq, 0, amp * (o5l / 127 ));
    var osc5 = SinOsc.ar(note.midicps * 4 * bendfreq, 0, amp * (o6l / 127 ));
    var osc6 = SinOsc.ar(note.midicps * 5 * bendfreq, 0, amp * (o7l / 127 ));
    var osc7 = SinOsc.ar(note.midicps * 6 * bendfreq, 0, amp * (o8l / 127 ));
    var osc8 = SinOsc.ar(note.midicps * 7 * bendfreq, 0, amp * (o9l / 127 ));
// ];*/

    /*var oscs = [
        SinOsc.ar(note.midicps * bendfreq, 0, amp * (levels@0 /127 )),
        SinOsc.ar(note.midicps * (1/4) * bendfreq, 0, amp * (levels@1 /127 )),
        SinOsc.ar(note.midicps * (1/2) * bendfreq, 0, amp * (levels@2 /127 )),
        SinOsc.ar(note.midicps * 2 * bendfreq, 0, amp * (levels@3 /127 )),
        SinOsc.ar(note.midicps * 3 * bendfreq, 0, amp * (levels@4 /127 )),
        SinOsc.ar(note.midicps * 4 * bendfreq, 0, amp * (levels@5 /127 )),
        SinOsc.ar(note.midicps * 5 * bendfreq, 0, amp * (levels@6 /127 )),
        SinOsc.ar(note.midicps * 6 * bendfreq, 0, amp * (levels@7 /127 )),
        SinOsc.ar(note.midicps * 7 * bendfreq, 0, amp * (levels@8 /127 ))
    ];*/

    var oscs = tunings.collect({|tuning, i| SinOsc.ar(note.midicps * tuning * bendfreq, phases@i, amp * (levels@i /127 ))});

    Out.ar(0, Pan2.ar(EnvGen.kr(Env.asr, gate, doneAction: 2) * oscs.sum /*(osc0 + osc1 + osc2 + osc3 + osc4 + osc5 + osc6 + osc7 + osc8)*/));
}).add;
)

(
// TODO: make reusable midi class

// synth state
var keys = nil!128;
var ccs = 0!128;
var bend = 0;

// midi listeners
MIDIdef.cc(\updateccs, { | val, num, chan, src |
	ccs.put(num, val);
});

MIDIdef.noteOn(\keypress, { | val, num, chan, src |
	var node = keys@num;
	if (node.notNil, {
		node.release;
		keys.put(num, nil);
	});

	node = ~playninesines.value(num, val, ccs, bend);
	keys.put(num, node);
});

MIDIdef.noteOff(\keyrelease, { | val, num, chan, src |
	var node = keys@num;
	if (node.notNil, {
		node.release;
		keys.put(num, nil);
	});
});

MIDIdef.cc(\tune, { | val, num, chan, src |
	keys.do({ | synth |
		synth.notNil and: { ~tuneninesines.value(synth, val, num, bend, ccs) }

	});
});

MIDIdef.bend(\bend, { | val, num, chan, src |
	keys.do({ | synth, i |
		synth.notNil and: {
            bend = val;
            // synth.set(\bend, val);
             ~tuneninesines.value(synth, val, num, bend, ccs)
        }
	});
});
)
