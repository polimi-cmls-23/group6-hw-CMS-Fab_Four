(
s.waitForBoot{

	~sensorValue = 0;  // initialize sensor value to a default of 0
    ~sensorTrigger = 0;  // initial trigger

	~x = Bus.control(s, 3);
    ~y = Bus.control(s, 3);

	~reverbBus = Bus.audio(s, 2);
    ~delayBus = Bus.audio(s, 2);


    // effects
    SynthDef(\reverbEffect, { |roomsize = 25, revtime = 3.5, bypass = 1, rwet = 0.1|
        var input = In.ar(~reverbBus, 2);
        var wetSignal = GVerb.ar(input, roomsize, revtime) * rwet;
        var drySignal = input;
		Out.ar([0, 1], Select.ar(bypass, [drySignal, XFade2.ar(drySignal, wetSignal, rwet * 2 - 1)]));
    }).add;

    SynthDef(\delayEffect, { |maxdelaytime = 5, delaytime = 0.5, decaytime = 10, bypass = 1, dwet = 0.1|
        var input = In.ar(~delayBus, 2);
        var wetSignal = CombC.ar(input, maxdelaytime, delaytime, decaytime) * dwet;
        var drySignal = input;
        Out.ar([0, 1], Select.ar(bypass, [drySignal, XFade2.ar(drySignal, wetSignal, dwet * 2 - 1)]));
    }).add;

    // hit synth
    SynthDef(\hit, { |out = 0, amp = 1, trig = 0|
        var noise, env, x, y, filterFreq, filterBW;
		x = (In.kr(~x, 3));
		y = (In.kr(~y, 3));
		trig = Impulse.kr(1);

        filterFreq = y.linexp(0, 1, 100, 10000);
        filterBW = x.linexp(0, 1, 0.05, 1);

        noise = WhiteNoise.ar(amp) * trig;
		amp.postln;
        noise = BPF.ar(noise, filterFreq, filterBW);

        env = EnvGen.kr(Env.perc(0.01, 0.1

		), gate: trig, doneAction: 2);
        Out.ar([~reverbBus, ~delayBus], noise * env);
    }).add;

    // Start the effect synths
    s.sync;
    // Initialize reverb and delay synths
	~reverbSynth = Synth(\reverbEffect);
	~delaySynth = Synth(\delayEffect);
	~hit = Synth(\hit);


//OSC

	//receive OSC sensor values from python server
	OSCdef(\sensor, { |msg|
		~sensorValue = msg[1].asFloat;
		~sensorTrigger = 1;

		// Trigger a new hit synth with the sensor value as the amplitude
		Synth.new(\hit, [\amp, ~sensorValue, \trig, ~sensorTrigger]);
	}, '/sensor');


	 //address for Processing
	~processingAddr = NetAddr("localhost", 45777);

	//receive TouchOSC XY
	OSCdef(\touchOSCListener, { |msg, time, addr, recvPort|
		var x, y;
		if(msg[0] == '/XY/1') {
			x = msg[1].asFloat;
			y = msg[2].asFloat;

			// write x and y to the control buses
			~x.set(x);
			~y.set(y);

			// Send x and y to Processing
			~processingAddr.sendMsg("/XY", x, y);
		}
	}, '/XY/1', recvPort: 57120);


	// Control reverb
	OSCdef(\roomsize, { |msg|
		~reverbSynth.set(\roomsize, msg[1]);
		("Delay parameters updated: roomsize = " ++ msg[1]).postln;
		// Send an OSC message to Processing
		NetAddr("localhost", 45777).sendMsg("/roomsize", msg[1]);
	}, '/roomsize');

	OSCdef(\revtime, { |msg|
		~reverbSynth.set(\revtime, msg[1]);
		("Delay parameters updated: revtime = " ++ msg[1]).postln;
		// Send an OSC message to Processing
		NetAddr("localhost", 45777).sendMsg("/revtime", msg[1]);
	}, '/revtime');


	OSCdef(\rwet, { |msg|
		~reverbSynth.set(\rwet, msg[1]);
		("Delay parameters updated: rwet = " ++ msg[1]).postln;
		// Send an OSC message to Processing
		NetAddr("localhost", 45777).sendMsg("/rwet", msg[1]);
	}, '/rwet');



	// Control delay
	OSCdef(\maxdelaytime, { |msg|
		~delaySynth.set(\maxdelaytime, msg[1]);
		("Delay parameters updated: maxdelaytime = " ++ msg[1]).postln;
		// Send an OSC message to Processing
		NetAddr("localhost", 45777).sendMsg("/maxdelaytime", msg[1]);
	}, '/maxdelaytime');


	OSCdef(\delaytime, { |msg|
		~delaySynth.set(\delaytime, msg[1]);
		("Delay parameters updated: delaytime = " ++ msg[1]).postln;
		// Send an OSC message to Processing
		NetAddr("localhost", 45777).sendMsg("/delaytime", msg[1]);
	}, '/delaytime');


	OSCdef(\decaytime, { |msg|
		~delaySynth.set(\decaytime, msg[1]);
		("Delay parameters updated: decaytime = " ++ msg[1]).postln;
		// Send an OSC message to Processing
		NetAddr("localhost", 45777).sendMsg("/decaytime", msg[1]);
	}, '/decaytime');


	OSCdef(\dwet, { |msg|
		~delaySynth.set(\dwet, msg[1]);
		("Delay parameters updated: dwet = " ++ msg[1]).postln;
		// Send an OSC message to Processing
		NetAddr("localhost", 45777).sendMsg("/dwet", msg[1]);
	}, '/dwet');

};
)
