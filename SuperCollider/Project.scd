SerialPort.devices;
// Read the port you need to write in SerialPort.new

(
s.reboot;
s.options.device="CABLE Input (VB-Audio Virtual Cable)";
MIDIClient.sources.do({ |src, i| [i, src].postln });
MIDIClient.init;
MIDIIn.connectAll;
MIDIFunc.trace(true);
~port = SerialPort.new("COM3", 9600);
~voices = Array.newClear(128); // For 128 MIDI notes
)

~port.close;
//Close to reset


// Definition of the osc messages
(
// PLUGIN FOR FILTERING (port 9001)
~filterOSC = NetAddr("127.0.0.1", 9001);

~setFilter = {|name, active=1|
    ~filterOSC.sendMsg("/filter/active", name, active);
    //("Filter " ++ name ++ (if(active==1){" ON"}{"OFF"})).postln;
};

~setCutoff = {|name, freq=1000|
    ~filterOSC.sendMsg("/filter/cutoff", name, freq);
    //("Filter " ++ name ++ " cutoff: " ++ freq).postln;
};

// PLUGIN FOR REVERB (port 9002)
~reverbOSC = NetAddr("127.0.0.1", 9002);

~setWet = {|val|
    val = val.clip(0.0, 1.0);
    ~reverbOSC.sendMsg("/wet", val);
    //("Sent reverb wet value: " ++ val).postln;
};

// PLUGIN OF DISTORSION (port 9003)
~distortionOSC = NetAddr("127.0.0.1", 9003);

~setDrive = {|val|
    val = val.clip(0.0, 1.0);
    ~distortionOSC.sendMsg("/drive", val);
    //("Sent distortion drive value: " ++ val).postln;
};

)

//-------------INITIALIZE THE SERIAL RECEIVER AND OSC SENDER-------------------------------
(
~buffer = "";
~reading = false;

~getValues = Routine({
    var c, parts, filterNames;

    filterNames = ["LPF", "HPF", "BPF", "NOTCH"];    loop {
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

                        /*["VOL:", ~volumes,
                         "ADSR:", ~adsr,
                         "FX:", ~fx,
                         "FILTERS:", ~filters,
                         "MASTER:", ~masterVol,
                         "PAN:", ~pan].postln;*/

						 // FILTER OSC MESSAGE

                        4.do{|i|
                            var val = ~filters[i];
                            var name = filterNames[i];
                            var active = if(val > 0, 1, 0);

                            ~setFilter.value(name, active);

                            if(active == 1) {
                                var freq;

                                // Mapping frequency
                                switch(i,
                                    0, { // LPF: 300Hz - 10kHz
                                        freq = 300 * (10000/300).pow(val/900);
                                    },
                                    1, { // HPF: 100Hz - 5kHz
                                        freq = 100 * (5000/100).pow(val/900);
                                    },
                                    2, { // BPF: 300Hz - 10kHz
                                        freq = 300 * (10000/300).pow(val/900);
                                    },
                                    3, { // NOTCH: 300Hz - 10kHz
										freq = 300 * (10000/300).pow(val/900);
                                    }
                                );

                                ~setCutoff.value(name, freq);
                            };
                        };

                        //REVERB OSC MESSAGE
                        if(~fx[2].notNil) {
                            var wet = ~fx[2] / 900.0;
                            ~setWet.value(wet);
                        };

                        // DISTORSION OSC MESSAGE
                        if(~fx[3].notNil) {
                            var drive = ~fx[3] / 900.0;
                            ~setDrive.value(drive);
                        };

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
			\atk, if(~adsr.isNil, {0.01}, {(~adsr[0] / 900).linexp(0, 1, 0.01, 45)}),
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

//----------------Defining the synth-------------------
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

	mix = mix * env * (master / 900)/((vol1+vol2+vol3+vol4)/900)/17;

    Out.ar(0, Pan2.ar(mix, (pan / 900 * 2) - 1));
}).add;
)
