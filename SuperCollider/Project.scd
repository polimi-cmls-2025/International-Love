
s.reboot;

MIDIClient.sources.do({ |src, i| [i, src].postln });

MIDIClient.init;
MIDIIn.connectAll;
MIDIFunc.trace(true);

SerialPort.devices;
~port = SerialPort.new("/dev/tty.usbmodem14101", 9600);
~port.close;

~voices = Array.newClear(128); // For 128 MIDI notes

(
~buffer = "";
~reading = false;

~getValues = Routine({
    var c;
    loop {
        c = ~port.read.asAscii;
        if(c.notNil) {
            if(c == $<) {
                ~reading = true;
                ~buffer = "";
            } {
                if(c == $> && ~reading) {
                    var parts = ~buffer.split($,);
                    if(parts.size == 18) {
                        ~volumes = parts[0..3].collect(_.asInteger);
                        ~adsr    = parts[4..7].collect(_.asInteger);
                        ~fx      = parts[8..11].collect(_.asInteger);
                        ~filters = parts[12..15].collect(_.asInteger);
                        ~masterVol = parts[16].asInteger;
                        ~pan       = parts[17].asInteger;

                        ["VOL:", ~volumes,
                         "ADSR:", ~adsr,
                         "FX:", ~fx,
                         "FILTERS:", ~filters,
                         "MASTER:", ~masterVol,
                         "PAN:", ~pan].postln;

                    } {
                        ("Wrong built pckg " ++ ~buffer).postln;
                    };
                    ~reading = false;
                } {
                    if(~reading) {
                        ~buffer = ~buffer ++ c;
                    };
                };
            };
        };
    };
}).play;
)


(
SynthDef(\multiOsc, { |freq = 220,
    vol1 = 0, vol2 = 0, vol3 = 0, vol4 = 0,
    atk = 0.01, dec = 0.3, sus = 0.5, rel = 1,
    fmRate = 1,
    lfoFreq = 1,
    master = 1, pan = 0, gate = 1| // <---

    var env, mod, osc1, osc2, osc3, osc4, mix, lfo, fmMod;

    // Envelope ADSR
    env = EnvGen.kr(
        Env.adsr(atk, dec, sus, rel, curve: -8.0),
        gate: gate, // <---
        doneAction: 2
    );

    fmMod = Select.kr(fmRate > 0.31, [
		0, //
		SinOsc.ar(fmRate) * (freq * 0.05)
	]);

    osc1 = SinOsc.ar(freq + fmMod) * (vol1 / 900);
    osc2 = Pulse.ar(freq + fmMod) * (vol2 / 900);
    osc3 = LFTri.ar(freq + fmMod) * (vol3 / 900);
    osc4 = Saw.ar(freq + fmMod) * (vol4 / 900);

    mix = osc1 + osc2 + osc3 + osc4;

    lfo = Select.kr(lfoFreq > 1.1, [
		1, //
		SinOsc.kr(lfoFreq).range(0.4, 1);
	]);

    mix = mix * lfo;

    mix = mix * env * (master / 900)/3;

    Out.ar(0, Pan2.ar(mix, (pan / 900 * 2) - 1));
}).add;
)


// ---------- MIDI DRIVERS----------
(
MIDIFunc.noteOn({ |velocity, noteNum, channel, srcID|
    var synth;
    var freq = noteNum.midicps;

    if(velocity > 0) {

        synth = Synth(\multiOsc, [
            \freq, freq,
            \gate, 1,
            \vol1, if(~volumes.isNil, {0}, {~volumes[0]}),
            \vol2, if(~volumes.isNil, {0}, {~volumes[1]}),
            \vol3, if(~volumes.isNil, {0}, {~volumes[2]}),
            \vol4, if(~volumes.isNil, {0}, {~volumes[3]}),
			\atk, if(~adsr.isNil, {0.01}, {(~adsr[0] / 900).linexp(0, 1, 0.01, 50)}),
            \dec, if(~adsr.isNil, {0.3}, {~adsr[1] / 900 * 2}),
            \sus, if(~adsr.isNil, {0.5}, {~adsr[2] / 900}),
            \rel, if(~adsr.isNil, {1.0}, {~adsr[3] / 900 * 2}),
            \fmRate, if(~fx.isNil, {1}, {(~fx[0] / 900).linexp(0.01, 1, 0.3, 10)}),
            \lfoFreq, if(~fx.isNil, {1}, {(~fx[1] / 900).linexp(0.01, 1, 1, 12)}),
            \master, if(~masterVol.isNil, {1}, {~masterVol}),
            \pan, if(~pan.isNil, {0}, {~pan})
        ]);
        ~voices[noteNum] = synth;
    } {
        // If vel=0 treat as an noteOff

        var existingSynth = ~voices[noteNum];
        if(existingSynth.notNil) {
            existingSynth.set(\gate, 0); // Close envelope
            ~voices[noteNum] = nil;
        };
    };
});

MIDIFunc.noteOff({ |velocity, noteNum, channel, srcID|
    var synth = ~voices[noteNum];

    if(synth.notNil) {
        synth.set(\gate, 0);
        ~voices[noteNum] = nil;
    };
});
)


// Used only without midi, to initiate it:
(
Synth(\multiOsc, [
    \freq, 440, //Fixed freq to test
    \vol1, ~volumes[0],
    \vol2, ~volumes[1],
    \vol3, ~volumes[2],
    \vol4, ~volumes[3],
    \atk, ~adsr[0] / 900 * 2,
    \dec, ~adsr[1] / 900 * 2,
    \sus, ~adsr[2] / 900,
    \rel, ~adsr[3] / 900 * 2,
    \fmRate, (~fx[0] / 900).linexp(0.01, 1, 0.3, 10),
    \lfoFreq, (~fx[1] / 900).linexp(0.01, 1, 1, 12),
    \master, ~masterVol,
    \pan, ~pan

]);
)
