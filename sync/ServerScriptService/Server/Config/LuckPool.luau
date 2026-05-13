local LuckPoolConfig = {
	OverflowQualityBonus = 0.75,

	PositionPower = {
		Low = -0.35,
		Mid = 0.35,
		High = 1.15,
	},

	Pools = {
		{
			Id = 1,
			Name = "Starter Pool",
			MinLuck = 0,
			MaxLuck = 24,
			Rarities = {
				{ Name = "Common", Position = "Low", Weight = 8500 },
				{ Name = "Rare", Position = "High", Weight = 1500 },
			},
		},

		{
			Id = 2,
			Name = "Small Pool",
			MinLuck = 25,
			MaxLuck = 49,
			Rarities = {
				{ Name = "Common", Position = "Low", Weight = 6500 },
				{ Name = "Rare", Position = "Mid", Weight = 3000 },
				{ Name = "Epic", Position = "High", Weight = 500 },
			},
		},

		{
			Id = 3,
			Name = "Decent Pool",
			MinLuck = 50,
			MaxLuck = 89,
			Rarities = {
				{ Name = "Rare", Position = "Low", Weight = 6500 },
				{ Name = "Epic", Position = "Mid", Weight = 3000 },
				{ Name = "Legendary", Position = "High", Weight = 500 },
			},
		},

		{
			Id = 4,
			Name = "Big Pool",
			MinLuck = 90,
			MaxLuck = 139,
			Rarities = {
				{ Name = "Epic", Position = "Low", Weight = 6500 },
				{ Name = "Legendary", Position = "Mid", Weight = 3000 },
				{ Name = "Mythic", Position = "High", Weight = 500 },
			},
		},

		{
			Id = 5,
			Name = "Huge Pool",
			MinLuck = 140,
			MaxLuck = 209,
			Rarities = {
				{ Name = "Legendary", Position = "Low", Weight = 6500 },
				{ Name = "Mythic", Position = "Mid", Weight = 3000 },
				{ Name = "Godly", Position = "High", Weight = 500 },
			},
		},

		{
			Id = 6,
			Name = "Massive Pool",
			MinLuck = 210,
			MaxLuck = 299,
			Rarities = {
				{ Name = "Mythic", Position = "Low", Weight = 6500 },
				{ Name = "Godly", Position = "Mid", Weight = 3000 },
				{ Name = "Secret", Position = "High", Weight = 500 },
			},
		},

		{
			Id = 7,
			Name = "Giant Pool",
			MinLuck = 300,
			MaxLuck = 424,
			Rarities = {
				{ Name = "Godly", Position = "Low", Weight = 6500 },
				{ Name = "Secret", Position = "Mid", Weight = 3000 },
				{ Name = "Divine", Position = "High", Weight = 500 },
			},
		},

		{
			Id = 8,
			Name = "Colossal Pool",
			MinLuck = 425,
			MaxLuck = 599,
			Rarities = {
				{ Name = "Secret", Position = "Low", Weight = 6500 },
				{ Name = "Divine", Position = "Mid", Weight = 3000 },
				{ Name = "Celestine", Position = "High", Weight = 500 },
			},
		},

		{
			Id = 9,
			Name = "Insane Pool",
			MinLuck = 600,
			MaxLuck = 849,
			Rarities = {
				{ Name = "Divine", Position = "Low", Weight = 6500 },
				{ Name = "Celestine", Position = "Mid", Weight = 3000 },
				{ Name = "Forbidden", Position = "High", Weight = 500 },
			},
		},

		{
			Id = 10,
			Name = "Forbidden Pool",
			MinLuck = 850,
			MaxLuck = math.huge,
			Rarities = {
				{ Name = "Celestine", Position = "Low", Weight = 8000 },
				{ Name = "Forbidden", Position = "High", Weight = 2000 },
			},
		},
	},
}

return LuckPoolConfig
