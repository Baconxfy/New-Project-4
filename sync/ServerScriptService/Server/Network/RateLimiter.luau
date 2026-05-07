local RateLimiter = {}
RateLimiter.__index = RateLimiter

local function normalize(conf, fallback)
	-- conf: { capacity or burst, refill, every }
	-- fallback: same shape
	conf = conf or {}
	local cap = tonumber(conf.capacity) or tonumber(conf.burst) or (fallback and (tonumber(fallback.capacity) or tonumber(fallback.burst))) or 0
	local refill = tonumber(conf.refill) or (fallback and tonumber(fallback.refill)) or cap
	local every = tonumber(conf.every) or (fallback and tonumber(fallback.every)) or 1
	if cap <= 0 then
		-- No capacity means "no limiting" (always allow)
		return { capacity = 0, refill = 0, every = every }
	end
	-- Clamp negatives to zero
	if refill < 0 then refill = 0 end
	if every <= 0 then every = 1 end
	return { capacity = cap, refill = refill, every = every }
end

function RateLimiter.new(defaults)
	-- defaults should be {capacity, refill, every}, but we'll normalize anyway
	local norm = normalize(defaults, { capacity = 0, refill = 0, every = 1 })
	return setmetatable({
		defaults = norm,
		buckets  = {}, -- key -> { tokens, last, conf }
	}, RateLimiter)
end

function RateLimiter:_bucket(key, conf)
	local b = self.buckets[key]
	local effective = normalize(conf, self.defaults)
	if not b then
		-- Start full
		b = { tokens = effective.capacity, last = os.clock(), conf = effective }
		self.buckets[key] = b
	else
		-- If caller supplied a new conf for the same key, update and clamp tokens to new capacity
		if conf then
			b.conf = effective
			if b.tokens > b.conf.capacity then
				b.tokens = b.conf.capacity
			end
		end
	end
	return b
end

function RateLimiter:allow(key, cost, conf)
	cost = tonumber(cost) or 1
	if cost <= 0 then return true, 0 end

	local b = self:_bucket(key, conf)
	local now = os.clock()
	local dt  = now - b.last
	b.last    = now
	local c   = b.conf

	-- Unlimited?
	if c.capacity <= 0 then
		return true, 0
	end

	-- Refill based on elapsed time and period
	if c.refill > 0 then
		local periods = dt / c.every
		if periods > 0 then
			b.tokens = math.min(c.capacity, b.tokens + periods * c.refill)
		end
	end

	if b.tokens >= cost then
		b.tokens = b.tokens - cost
		return true, 0
	else
		local need = cost - b.tokens
		local rate = (c.refill > 0) and (c.refill / c.every) or 0
		local retry = (rate > 0) and (need / rate) or math.huge
		return false, retry
	end
end

return RateLimiter
