local Pads = {
	DefaultEnabledCount = 1,
	UnlockedDataKey = "PadsUnlocked",
	EnabledAttribute = "PadEnabled",
	IndexAttribute = "PadIndex",

	-- Prices are keyed by stage, then the next slot number bought on that stage.
	StageUnlocks = {
		[1] = {
			[2] = { Cost = 10 },
			[3] = { Cost = 20 },
			[4] = { Cost = 30 },
			[5] = { Cost = 40 },
			[6] = { Cost = 50 },
			[7] = { Cost = 60 },
			[8] = { Cost = 70 },
		},
		[2] = {
			[2] = { Cost = 80 },
			[3] = { Cost = 90 },
			[4] = { Cost = 100 },
			[5] = { Cost = 110 },
			[6] = { Cost = 120 },
			[7] = { Cost = 130 },
			[8] = { Cost = 140 },
			[9] = { Cost = 150 },
			[10] = { Cost = 160 },
			[11] = { Cost = 170 },
			[12] = { Cost = 180 },
			[13] = { Cost = 190 },
			[14] = { Cost = 200 },
			[15] = { Cost = 210 },
			[16] = { Cost = 220 },
		},
	},
}

return Pads
