return {
	luau = {
		lint = {
			["*"] = true, -- keep other lints on
			LocalShadow = false,
			LocalUnused = false,
			FunctionUnused = false,
		},
	},
}
