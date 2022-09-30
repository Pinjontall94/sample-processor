// == SERVER ==
s = Server.local; s.boot; MIDIIn.connectAll;  // BOOT
s.quit;                   					  // QUIT (PANIC) C-c C-p q
s.prepareForRecord("~/Documents/recordings/test9.wav", numChannels: 2); s.record;  // RECORD
s.pauseRecording; // PAUSE
s.stopRecording; // STOP


// == BUFFERS ==
(
b = Buffer.readChannel(
	s,
	"./first_guitar_attempt_emaj_to_fsmin.wav",
	channels:[0]
);
)

b.stop;  // play the buffer
b.free;  // clear/stop the buffer
b.numChannels;


// == GUI ==
(
Window.closeAll;
w = Window("Knob Grid", Rect(0, 0, 400, 400))
.front
.alwaysOnTop_(True);

w.view.decorator_(FlowLayout(w.bounds, 15@15, 7@7));
k = Array.fill(64, {Knob(w,40@40)});
)

(
// Remove & Reset GUI elements
w.view.children.collect(_.remove);
w.view.decorator.reset;
)

k[0].value_(rrand(0.0,1.0));


// == MIDI ==
MIDIFunc.trace(true);
MIDIFunc.trace(false);

(
MIDIdef.cc(\fader1, {
	|val| delay.set(\modRate, val.linexp(0,127,0.0001,10));
	~fd1 = val;
}, 41).add;

MIDIdef.cc(\fader2, {
	|val| delay.set(\modDepth, val.linlin(0,127,0,0.2));
	~fd2 = val;
}, 42).add;

MIDIdef.cc(\fader3, {
	|val| delay.set(\randRate, val.linlin(0,127,0,2));
	~fd3 = val;
}, 43).add;

MIDIdef.cc(\fader4, {
	|val| delay.set(\randAmnt, val.linlin(0,127,0,2));
	~fd4 = val;
}, 44).add;

MIDIdef.cc(\fader5, {
	|val| reverb.set(\bpfreq, val.linlin(0,127,20,20000));
	~fd5 = val;
}, 45).add;

MIDIdef.cc(\fader6, {
	|val| reverb.set(\damp, val.linlin(0,127,0.0001,1));
	~fd6 = val;
}, 46).add;

MIDIdef.cc(\fader7, {
	|val| //reverb.set(\mix, val.linlin(0,127,0,1));
	~fd7 = val;
}, 47).add;

MIDIdef.cc(\fader8, {
	|val| //reverb.set(\room, val.linexp(0,127,0,1));
	~fd8 = val;
}, 47).add;

MIDIdef.cc(\fader9Master, {
	|val| amp.set(\mul, val.linexp(0,127,0.001,1));
	~fd9 = val;
}, 7).add;

MIDIdef.cc(\knob1, {
	|val| g.set(\dur, val.linlin(0,127,0.001,0.2));
	~kn1 = val;
}, 21).add;

MIDIdef.cc(\knob2, {
	|val| g.set(\rate, val.linlin(0,127,0,1));
	~kn2 = val;
}, 22).add;

MIDIdef.cc(\knob3, {
	|val| g.set(\dens, val.linlin(0,127,50,300));
	~kn3 = val;
}, 23).add;

MIDIdef.cc(\knob4, {
	|val| g.set(\panHz, val.linlin(0,127,0.1,100));
	~kn4 = val;
}, 24).add;

MIDIdef.cc(\knob5, {
	|val| g.set(\panRand, val.linlin(0,127,0,1));
	~kn5 = val;
}, 25).add;

MIDIdef.cc(\knob6, {
	|val| g.set(\posRand, val.linlin(0,127,0.01,1));
	~kn6 = val;
}, 26).add;

MIDIdef.cc(\knob7, {
	|val| g.set(\posRate, val.linlin(0,127,-1,1));
	~kn7 = val;
}, 27).add;

MIDIdef.cc(\knob8, {
	|val| g.set(\mul, val.linlin(0,127,0.0001,1));
	~kn8 = val;
}, 28).add;
)


// == SYNTHS ==
(
// Basic Sine tone to test audio routing and FX
SynthDef(\test, {
	|out=0, freq=220, mul=0.1|
	var sig env;
	env = EnvGen.kr(Env.perc, doneAction:2);
	sig = SinOsc.ar(freq, 0, mul)!2 * env;
	Out.ar(out, sig);
}).add;

// Main granular synth for buffer playback
SynthDef(\grainSynth, {
	|out=0, buf=b, dur=0.2, durRand=1, rate=1, pos=0, posRate=1,
	posRand=0.01, dens=100, pan=0, panHz=0.1, panRand=0, mul=0.3|
	var sig, durCntrl, panCntrl, posCntrl;

	durCntrl = dur + LFNoise1.kr(100).exprange(1/durRand,durRand);
	posCntrl = Phasor.ar(0, posRate * BufRateScale.ir(buf), 0, BufSamples.ir(buf) - 1);
	posCntrl = posCntrl + LFNoise1.kr(100).bipolar(posRand * SampleRate.ir);
	posCntrl = posCntrl / BufSamples.ir(buf);
	panCntrl = pan + LFNoise1.kr(panHz).bipolar(panRand);

	sig = GrainBuf.ar(
		2,
		Impulse.ar(dens),
		durCntrl,
		buf,
		rate,
		posCntrl, // position
		2, // linear
		panCntrl,
		-1, // use built-in Hann envelope
		512
	);
	sig = sig * mul;
	Out.ar(out, sig);
}).add;


// FX Section
// == DELAY ==
SynthDef(\delay, {
	|out=0, in, modDepth=0.2, modOffset=0.4, randRate=1, randAmnt=1, modRate=0.3|
	var sig, del, delayCntrl;

	delayCntrl = SinOsc.ar(
		LFNoise1.ar(randRate, randAmnt, modRate),
		0,
		modDepth.lag(0.1),
		modOffset
	);
	sig = In.ar(in, 2);
	del = DelayC.ar(sig,0.6,delayCntrl);
	Out.ar(out, del);
}).add;
)


// == REVERB ==
SynthDef(\reverb, {
	|out=0, in, mix=0.33, room=0.5, damp=0.5, bpfreq=1000, bprq=1.0|
	var sig, verb, bp;
	sig = In.ar(in, 2);
	bp = BPF.ar(sig, bpfreq.lag(0.1), bprq);
	verb = FreeVerb2.ar(bp[0], bp[1], mix, room, damp, 0.3);
	Out.ar(out, verb);
}).add;


// == AMP (VOLUME) ==
SynthDef(\amp, {
	|out=0, in, mul=0.3|
	var sig;
	sig = In.ar(in, 2) * Lag.kr(mul, 0.1);
	Out.ar(out, sig);
}).add;


// == ROUTING ==
(
~sources = Group.new;
~fx = Group.after(~sources);
~dbus = Bus.audio(s, 2);
~rbus = Bus.audio(s, 2);
~abus = Bus.audio(s, 2);
)


// == PERFORMANCE ==
(
amp = Synth(\amp, [\in, ~abus], ~fx);
reverb = Synth(\reverb, [\in, ~rbus], ~fx);
delay = Synth(\delay, [\in, ~dbus, \out, ~rbus], ~fx);
)

x = Synth(\test, [\out, 0], ~sources);
y = Synth(\test, [\out, ~rbus], ~sources);
z = Synth(\test, [\out, ~dbus], ~sources);
g = Synth(\grainSynth, [\out, 0], ~sources);


amp.set(\mul, 0);  // MUTE


// == PANIC ==
~sources.free; ~effects.free; // Turn off sources and effects
~dbus.free; ~rbus.free; ~abus.free;                    // Unplug the cables
