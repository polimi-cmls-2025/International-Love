// DEFINICIONES DE TODOS LOS PLUGINS EN UN SOLO BLOQUE
(
// PLUGIN DE FILTRO (puerto 9001)
~filterOSC = NetAddr("127.0.0.1", 9001);

~setFilter = {|name, active=1|
    ~filterOSC.sendMsg("/filter/active", name, active);
    ("Filter " ++ name ++ (if(active==1){" ON"}{"OFF"})).postln;
};

~setCutoff = {|name, freq=1000|
    ~filterOSC.sendMsg("/filter/cutoff", name, freq);
    ("Filter " ++ name ++ " cutoff: " ++ freq).postln;
};

// PLUGIN DE REVERB (puerto 9002)
~reverbOSC = NetAddr("127.0.0.1", 9002);

~setWet = {|val|
    val = val.clip(0.0, 1.0);
    ~reverbOSC.sendMsg("/wet", val);
    ("Sent reverb wet value: " ++ val).postln;
};

// PLUGIN DE DISTORSIÓN (puerto 9003)
~distortionOSC = NetAddr("127.0.0.1", 9003);

~setDrive = {|val|
    val = val.clip(0.0, 1.0);
    ~distortionOSC.sendMsg("/drive", val);
    ("Sent distortion drive value: " ++ val).postln;
};

"Todos los controladores OSC inicializados".postln;
)



// Activar filtro paso-bajo
~setFilter.("LPF", 1);

// Ajustar frecuencia de corte
~setCutoff.("LPF", 800);

// Desactivar filtro
~setFilter.("LPF", 0);

// Otros tipos de filtro: "HPF", "BPF", "NOTCH"

// Ajustar nivel de reverberación (0.0 a 1.0)
~setWet.value(0.6);

// Ajustar nivel de distorsión (0.0 a 1.0)
~setDrive.value(0.7);