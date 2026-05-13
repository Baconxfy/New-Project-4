local MutationConfig = {
	DefaultMutationLuck = 1,

	Mutations = {
		Normal = {
			DisplayName = "Normal",
			Multiplier = 1,
			BaseWeight = 40000,
			LuckPower = -0.45,
			IsMutation = false,
		},

		Gold = {
			DisplayName = "Gold",
			Multiplier = 1.5,
			BaseWeight = 940000,
			LuckPower = 0.25,
			IsMutation = true,
		},

		Diamond = {
			DisplayName = "Diamond",
			Multiplier = 3,
			BaseWeight = 12500,
			LuckPower = 0.65,
			IsMutation = true,
		},

		Lava = {
			DisplayName = "Lava",
			Multiplier = 6,
			BaseWeight = 5000,
			LuckPower = 1.00,
			IsMutation = true,
		},

		Glitch = {
			DisplayName = "Glitch",
			Multiplier = 10,
			BaseWeight = 1800,
			LuckPower = 1.35,
			IsMutation = true,
		},

		Galaxy = {
			DisplayName = "Galaxy",
			Multiplier = 18,
			BaseWeight = 550,
			LuckPower = 1.75,
			IsMutation = true,
		},

		DarkMatter = {
			DisplayName = "Dark Matter",
			Multiplier = 35,
			BaseWeight = 140,
			LuckPower = 2.20,
			IsMutation = true,
		},

		Rainbow = {
			DisplayName = "Rainbow",
			Multiplier = 75,
			BaseWeight = 10,
			LuckPower = 2.75,
			IsMutation = true,
		},
	},
}

return MutationConfig
