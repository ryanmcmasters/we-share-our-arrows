// we share our arrows;
// ryan mcmasters
// for multiple double basses

s.boot;
s.waitForBoot {

	// ---------------- SETUP ----------------
	~numTaps = 7;
	~numOuts = 2;

	~scoreInterval = 45; // seconds
	~score = [
		"II.4 II.6 II.7 II.9 I.7",
		"II.4 II.6 II.7 III.3 I.7",
		"II.4 II.3 II.7 III.3 I.7",
		"II.2 II.3 II.7 III.3 I.7",
		"II.2 III.2 II.7 III.3 I.7",
		"II.2 III.1 II.7 III.3 I.7",
		"II.1 III.1 II.7 III.3 I.7",
		"IV.1 III.1 II.7 III.3 I.7",
		"IV.1 III.1 II.7 I.7",
		"IV.1 III.1 I.7",
		"IV.1 III.1 I.7 I.9",
		"IV.1 I.7 I.9",
		"IV.1 I.7 I.8 I.9",
		"I.7 I.8 I.9",
		"I.8 I.9",
		"I.9"
	];

	~sectionIndex = 0;
	~pieceStartTime = 0;
	~scoreRoutine = nil;
	~clockRoutine = nil;
	~synth = nil;

	// ---------------- COLORS ----------------
	~familyColors = (
		I:   Color(0.35, 0.55, 0.9),
		II:  Color(0.35, 0.8, 0.55),
		III: Color(0.9, 0.7, 0.25),
		IV:  Color(0.7, 0.45, 0.9)
	);

	~getFamilyColor = { |str|
		var fam = str.findRegexp("(IV|III|II|I)")[0][1];
		~familyColors[fam.asSymbol] ? Color.grey;
	};

	// ---------------- DRAW BAR ----------------
	~drawBar = { |view, frac, col|
		view.drawFunc_({
			var w = view.bounds.width;
			var h = view.bounds.height;

			Pen.fillColor = Color.black;
			Pen.fillRect(Rect(0, 0, w, h));

			Pen.fillColor = col;
			Pen.fillRect(Rect(0, 0, w * frac.clip(0,1), h));
		});
		view.refresh;
	};

	// ---------------- SYNTH ----------------
	SynthDef(\arrows, {
		|inBus = 0, outBus = 0,
		maxDelay = 1.5,
		feedback = 0.4,
		delayAmp = 0.7,
		dryAmp = 0.7,
		inputGate = 1,
		fbFadeTime = 1.5|

		var input, gatedInput, delayMem, writeSig, taps, feedbackEnv;
		var rotRate = LFNoise1.kr(0.05).range(0.02, 0.15);
		var rotPos  = LFSaw.kr(rotRate).range(-1, 1);

		input      = SoundIn.ar(inBus);
		gatedInput = input * inputGate;
		feedbackEnv = Lag.kr(feedback * inputGate, fbFadeTime);

		delayMem = LocalIn.ar(1);
		writeSig = gatedInput + (delayMem * feedbackEnv);
		delayMem = DelayC.ar(writeSig, maxDelay, maxDelay);
		LocalOut.ar(delayMem);

		taps = Mix.fill(~numTaps, {
			var tapDelay = Rand(0.05, maxDelay);
			var tapRate  = Rand(0.03, 0.6);
			var tapWidth = Rand(0.2, 1.0);
			var tapPos   = SinOsc.kr(tapRate).range(-1 * tapWidth, tapWidth);

			PanAz.ar(
				~numOuts,
				DelayC.ar(delayMem, maxDelay, tapDelay),
				tapPos + rotPos
			)
		});

		Out.ar(outBus,
			(taps * delayAmp) +
			PanAz.ar(~numOuts, input * dryAmp, 0)
		);
	}).add;

	// ---------------- GUI ----------------
	~win = Window(
		"we share our arrows;",
		Rect(0, 0, Window.availableBounds.width, Window.availableBounds.height)
	)
	.background_(Color.black)
	.front
	.alwaysOnTop_(true);

	// title
	StaticText(~win, Rect(0, 10, ~win.bounds.width, 40))
	.align_(\center)
	.font_(Font(size: 36))
	.stringColor_(Color.grey)
	.string_("we share our arrows;");

	// elapsed time (centered)
	~elapsedText = StaticText(~win, Rect(0, 55, ~win.bounds.width, 36))
	.align_(\center)
	.font_(Font(size: 28))
	.stringColor_(Color.grey)
	.string_("00:00");

	// score
	~scoreText = StaticText(~win, Rect(0, 120, ~win.bounds.width, 260))
	.align_(\center)
	.font_(Font(size: 200))
	.stringColor_(Color.grey)
	.string_("press start");

	// section info
	~sectionText = StaticText(~win, Rect(0, 390, ~win.bounds.width, 60))
	.align_(\center)
	.font_(Font(size: 48))
	.stringColor_(Color.grey);

	~sectionClock = StaticText(~win, Rect(0, 450, ~win.bounds.width, 60))
	.align_(\center)
	.font_(Font(size: 56))
	.stringColor_(Color.grey);

	// progress bars
	~sectionBar = UserView(
		~win,
		Rect(~win.bounds.width * 0.25, 520, ~win.bounds.width * 0.5, 20)
	);

	~totalBar = UserView(
		~win,
		Rect(~win.bounds.width * 0.2, ~win.bounds.height - 220, ~win.bounds.width * 0.6, 18)
	);

	// ---------------- TRANSPORT ----------------
	~startButton = Button(~win, Rect(20, ~win.bounds.height - 190, 280, 40))
	.states_([
		["start", Color.black, Color.green],
		["stop", Color.white, Color.red]
	]);

	~resetButton = Button(~win, Rect(320, ~win.bounds.height - 190, 280, 40))
	.states_([
		["reset", Color.black, Color.grey(0.6)]
	]);

	// START / STOP
	~startButton.action_({ |btn|
		if (btn.value == 1) {

			~synth = Synth(\arrows);
			~pieceStartTime = Main.elapsedTime;
			~sectionIndex = 0;

			~clockRoutine = Routine({
				loop {
					var e = Main.elapsedTime - ~pieceStartTime;
					{
						~elapsedText.string_(
							(e/60).floor.asString.padLeft(2,"0")
							++ ":" ++
							(e%60).floor.asString.padLeft(2,"0")
						)
					}.defer;
					0.5.wait;
				}
			}).play(AppClock);

			~scoreRoutine = Routine({
				~score.do { |text, i|
					var start, color;

					~sectionIndex = i;
					start = Main.elapsedTime;
					color = ~getFamilyColor.(text);

					{
						~scoreText.string_(text);
						~sectionText.string_("section " ++ (i+1) ++ " / " ++ ~score.size);
					}.defer;

					while { (Main.elapsedTime - start) < ~scoreInterval } {
						var frac = (Main.elapsedTime - start) / ~scoreInterval;
						var urgency = (1 - frac).pow(2);

						{
							~sectionClock.string_(
								((~scoreInterval - (Main.elapsedTime-start))/60).floor
								.asString.padLeft(2,"0")
								++ ":" ++
								((~scoreInterval - (Main.elapsedTime-start))%60).floor
								.asString.padLeft(2,"0")
							);

							~drawBar.(~sectionBar, frac, color.blend(Color.red, urgency));
							~drawBar.(~totalBar,
								(Main.elapsedTime - ~pieceStartTime)
								/ (~score.size * ~scoreInterval),
								color
							);
						}.defer;

						0.05.wait;
					};
				};
			}).play(AppClock);

		} {

			[~scoreRoutine, ~clockRoutine].do { |r| if (r.notNil) { r.stop } };

			if (~synth.notNil) {
				~synth.set(\inputGate, 0);
				SystemClock.sched(4, {
					~synth.free;
					~synth = nil;
				});
			};
		};
	});

	// RESET (resets transport, NOT sliders)
	~resetButton.action_({

		[~scoreRoutine, ~clockRoutine].do { |r| if (r.notNil) { r.stop } };
		~scoreRoutine = nil;
		~clockRoutine = nil;
		~sectionIndex = 0;
		~pieceStartTime = 0;

		{
			~startButton.value_(0);
			~scoreText.string_("press start");
			~sectionText.string_("");
			~sectionClock.string_("00:00");
			~elapsedText.string_("00:00");
			~drawBar.(~sectionBar, 0, Color.grey);
			~drawBar.(~totalBar, 0, Color.grey);
		}.defer;

		if (~synth.notNil) {
			~synth.set(\inputGate, 0);
			SystemClock.sched(4, {
				~synth.free;
				~synth = nil;
			});
		};
	});

	// ---------------- SLIDERS ----------------
	~yBase = ~win.bounds.height - 130;

	[
		["delay volume", \delayAmp, 0.7, 0],
		["input volume", \dryAmp,   0.7, 30],
		["feedback",     \feedback, 0.35, 60]
	].do { |spec|
		var label, key, init, y;
		#label, key, init, y = spec;

		StaticText(~win, Rect(20, ~yBase + y, 140, 16))
		.string_(label)
		.stringColor_(Color.grey);

		Slider(~win, Rect(160, ~yBase + y, 280, 20))
		.value_(init)
		.action_({ |sl|
			if (~synth.notNil) {
				~synth.set(key, sl.value.clip(0, 0.95))
			}
		});
	};
};
