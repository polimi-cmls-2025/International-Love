~port = SerialPort.new("COM3", 9600);
~port.close;
s.boot;

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
						("Paquete mal formado: " ++ ~buffer).postln;
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
    fmRate = 1,      // velocidad de modulación FM
    lfoFreq = 1,     // frecuencia LFO para modulación AM
    master = 1, pan = 0|

    var env, mod, osc1, osc2, osc3, osc4, mix, lfo;

    // Envelope ADSR
    env = EnvGen.kr(
        Env.adsr(atk, dec, sus, rel),
        gate: 1, doneAction: 2
    );

    // FM modulation: SinOsc oscila entre -1 y 1, desviación ±5% freq
    mod = SinOsc.ar(fmRate) * (freq * 0.05);

    // Osciladores con FM aplicado a frecuencia
    osc1 = SinOsc.ar(freq + mod) * (vol1 / 900)*3;
    osc2 = Pulse.ar(freq + mod) * (vol2 / 900);
    osc3 = LFTri.ar(freq + mod) * (vol3 / 900);
    osc4 = Saw.ar(freq + mod) * (vol4 / 900);

    // Mezcla de los 4 osciladores
    mix = osc1 + osc2 + osc3 + osc4;

    // LFO para modulación de amplitud fija (aprox 30% de profundidad)
    lfo = SinOsc.kr(lfoFreq).range(0, 1);

    // Aplicar modulación de amplitud con LFO
    mix = mix * lfo;

    // Aplicar envolvente y volumen maestro
    mix = mix * env * (master / 900);

    // Panorámica
    Out.ar(0, Pan2.ar(mix, (pan / 900 * 2) - 1));
}).add;
)






(
Synth(\multiOsc, [
    \freq, 440,
    \vol1, ~volumes[0],
    \vol2, ~volumes[1],
    \vol3, ~volumes[2],
    \vol4, ~volumes[3],
    \atk, ~adsr[0] / 900 * 2,
    \dec, ~adsr[1] / 900 * 2,
    \sus, ~adsr[2] / 900,
    \rel, ~adsr[3] / 900 * 2,
    \fmRate, (~fx[0] / 900).linexp(0.01, 1, 0.3, 10),  // velocidad de modulación FM: 0.5 a 30 Hz
    \lfoFreq, (~fx[1] / 900).linexp(0.01, 1, 1, 12),  // frecuencia LFO AM
    \master, ~masterVol,
    \pan, ~pan
]);

)


