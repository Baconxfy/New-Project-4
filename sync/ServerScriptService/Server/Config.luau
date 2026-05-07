local Config = {

	Shared = {

		Luckyblocks = require(script.Luckyblocks),
		ControllerCallTimeout = 4.0,

		RateLimits = {
			-- Fallback if no more-specific rule matches
			-- burst = bucket capacity, refill = tokens added per 'every' seconds (default every=1s)
			Default = { burst = 20, refill = 10, every = 1 },

			-- Service rules (client -> server).
			-- Matches in this order:
			--   "<Service>/Client/<Method>"
			--   "<Service>/Client/*"
			--   "<Service>/*"
			--   "*"
			Service = {
				["*"] = { burst = 100, refill = 100 }, -- global catch-all

				-- ["SomeService/*"] = { burst = 50, refill = 25 },
				-- ["SomeService/Client/*"] = { burst = 40, refill = 20 },
			},
		},


	}
}

return Config
