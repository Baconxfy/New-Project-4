--!strict
-- NumberUtil.lua (Luau / Roblox-compatible, expanded syntax)
-- Comprehensive numeric helpers for Roblox:
-- rounding/clamping/mapping, angles, damping, stats, combinatorics, random,
-- bit/integer helpers, numeric methods, easing, formatting (commas, abbreviations),
-- parsing, and a practical Physics toolbox (SI units).

local NumberUtil = {}

-- ===== Constants =====
local EPSILON: number = 1e-7
local TAU: number = math.pi * 2
local LOG10: number = math.log(10)

NumberUtil.EPSILON = EPSILON
NumberUtil.TAU = TAU

-- ===== Type Guards / Safe Checks =====
function NumberUtil.isNaN(x: number): boolean
	return x ~= x
end

function NumberUtil.isFinite(x: number): boolean
	return x == x and x ~= math.huge and x ~= -math.huge
end

-- ===== Basic Utilities =====
function NumberUtil.abs(x: number): number
	return math.abs(x)
end

function NumberUtil.sign(x: number): number
	if x > 0 then
		return 1
	elseif x < 0 then
		return -1
	else
		return 0
	end
end

function NumberUtil.copySign(x: number, s: number): number
	return math.abs(x) * NumberUtil.sign(s)
end

function NumberUtil.min(a: number, b: number): number
	if a < b then
		return a
	else
		return b
	end
end

function NumberUtil.max(a: number, b: number): number
	if a > b then
		return a
	else
		return b
	end
end

function NumberUtil.clamp(x: number, minV: number, maxV: number): number
	if minV > maxV then
		local tmp = minV
		minV = maxV
		maxV = tmp
	end
	if x < minV then
		return minV
	elseif x > maxV then
		return maxV
	else
		return x
	end
end

function NumberUtil.saturate(x: number): number
	return NumberUtil.clamp(x, 0, 1)
end

function NumberUtil.within(x: number, a: number, b: number, inclusive: boolean?): boolean
	local inc = true
	if inclusive == false then
		inc = false
	end
	if a > b then
		local t = a
		a = b
		b = t
	end
	if inc then
		return x >= a and x <= b
	else
		return x > a and x < b
	end
end

function NumberUtil.frac(x: number): number
	return x - math.floor(x)
end

-- Rounding with precision
function NumberUtil.round(x: number, decimals: number?): number
	local d = decimals or 0
	local m = 10 ^ d
	return math.floor(x * m + 0.5) / m
end

function NumberUtil.floorTo(x: number, decimals: number?): number
	local d = decimals or 0
	local m = 10 ^ d
	return math.floor(x * m) / m
end

function NumberUtil.ceilTo(x: number, decimals: number?): number
	local d = decimals or 0
	local m = 10 ^ d
	return math.ceil(x * m) / m
end

function NumberUtil.trunc(x: number, decimals: number?): number
	local d = decimals or 0
	local m = 10 ^ d
	if x >= 0 then
		return math.floor(x * m) / m
	else
		return math.ceil(x * m) / m
	end
end

function NumberUtil.roundToStep(x: number, step: number, offset: number?): number
	local off = offset or 0
	return math.floor(((x - off) / step) + 0.5) * step + off
end

function NumberUtil.snap(x: number, step: number, offset: number?): number
	return NumberUtil.roundToStep(x, step, offset)
end

function NumberUtil.nearest(x: number, candidates: { number }): number
	assert(#candidates > 0, "candidates must not be empty")
	local best = candidates[1]
	local bestd = math.abs(x - best)
	for i = 2, #candidates do
		local d = math.abs(x - candidates[i])
		if d < bestd then
			best = candidates[i]
			bestd = d
		end
	end
	return best
end

function NumberUtil.approximately(a: number, b: number, eps: number?): boolean
	local e = eps or EPSILON
	return math.abs(a - b) <= e
end

function NumberUtil.nearlyZero(x: number, eps: number?): boolean
	local e = eps or EPSILON
	return math.abs(x) <= e
end

-- ===== Modular / Wrap / Oscillate =====
function NumberUtil.mod(x: number, m: number): number
	return (x % m + m) % m
end

function NumberUtil.wrap(x: number, minV: number, maxV: number): number
	local width = maxV - minV
	if width == 0 then
		return minV
	end
	return NumberUtil.mod((x - minV), width) + minV
end

function NumberUtil.pingPong(t: number, length: number): number
	if length <= 0 then
		return 0
	end
	local tt = NumberUtil.mod(t, 2 * length)
	if tt < length then
		return tt
	else
		return 2 * length - tt
	end
end

-- ===== Ranges / Mapping =====
function NumberUtil.lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

function NumberUtil.inverseLerp(a: number, b: number, v: number): number
	if NumberUtil.approximately(a, b) then
		return 0
	end
	return (v - a) / (b - a)
end

function NumberUtil.remap(v: number, inMin: number, inMax: number, outMin: number, outMax: number, clampOut: boolean?): number
	local t = NumberUtil.inverseLerp(inMin, inMax, v)
	if clampOut then
		t = NumberUtil.saturate(t)
	end
	return NumberUtil.lerp(outMin, outMax, t)
end

-- Smoothstep family
function NumberUtil.smoothstep(t: number): number
	local tt = NumberUtil.saturate(t)
	return tt * tt * (3 - 2 * tt)
end

function NumberUtil.smootherstep(t: number): number
	local tt = NumberUtil.saturate(t)
	return tt * tt * tt * (tt * (6 * tt - 15) + 10)
end

-- Hermite/Bezier
function NumberUtil.hermite(t: number, p0: number, m0: number, p1: number, m1: number): number
	local t2 = t * t
	local t3 = t2 * t
	local h00 = 2 * t3 - 3 * t2 + 1
	local h10 = t3 - 2 * t2 + t
	local h01 = -2 * t3 + 3 * t2
	local h11 = t3 - t2
	return h00 * p0 + h10 * m0 + h01 * p1 + h11 * m1
end

function NumberUtil.bezier3(t: number, p0: number, p1: number, p2: number, p3: number): number
	local u = 1 - t
	return u * u * u * p0 + 3 * u * u * t * p1 + 3 * u * t * t * p2 + t * t * t * p3
end

-- ===== Angles (deg/rad) =====
function NumberUtil.deg2rad(d: number): number
	return d * math.pi / 180
end

function NumberUtil.rad2deg(r: number): number
	return r * 180 / math.pi
end

function NumberUtil.wrapAngleRad(r: number): number
	local rr = NumberUtil.mod(r + math.pi, TAU) - math.pi
	if rr <= -math.pi then
		rr = rr + TAU
	end
	return rr
end

function NumberUtil.wrapAngleDeg(d: number): number
	local dd = NumberUtil.mod(d + 180, 360) - 180
	if dd <= -180 then
		dd = dd + 360
	end
	return dd
end

function NumberUtil.shortestAngleDeltaRad(a: number, b: number): number
	return NumberUtil.wrapAngleRad(b - a)
end

function NumberUtil.shortestAngleDeltaDeg(a: number, b: number): number
	return NumberUtil.wrapAngleDeg(b - a)
end

function NumberUtil.lerpAngleRad(a: number, b: number, t: number): number
	return a + NumberUtil.shortestAngleDeltaRad(a, b) * t
end

function NumberUtil.lerpAngleDeg(a: number, b: number, t: number): number
	return a + NumberUtil.shortestAngleDeltaDeg(a, b) * t
end

function NumberUtil.rotateTowardsAngleDeg(current: number, target: number, maxStepDeg: number): number
	local delta = NumberUtil.shortestAngleDeltaDeg(current, target)
	local step = NumberUtil.clamp(delta, -maxStepDeg, maxStepDeg)
	return NumberUtil.wrapAngleDeg(current + step)
end

-- ===== Movement / Damping =====
function NumberUtil.approach(current: number, target: number, maxDelta: number): number
	if math.abs(target - current) <= maxDelta then
		return target
	end
	return current + maxDelta * NumberUtil.sign(target - current)
end

function NumberUtil.expDamp(current: number, target: number, lambda: number, dt: number): number
	local k = math.exp(-lambda * dt)
	return target + (current - target) * k
end

function NumberUtil.smoothDamp(current: number, target: number, velocity: number, smoothTime: number, maxSpeed: number, dt: number): (number, number)
	local st = math.max(0.0001, smoothTime)
	local omega = 2 / st
	local x = omega * dt
	local exp = 1 / (1 + x + 0.48 * x * x + 0.235 * x * x * x)

	local change = current - target
	local maxChange = maxSpeed * st
	change = NumberUtil.clamp(change, -maxChange, maxChange)

	local temp = (velocity + omega * change) * dt
	local newVel = (velocity - omega * temp) * exp
	local newVal = target + (change + temp) * exp

	if (target - current > 0) == (newVal > target) then
		newVal = target
		newVel = 0
	end
	return newVal, newVel
end

-- ===== Statistics =====
function NumberUtil.sum(arr: { number }): number
	local s = 0
	for _, v in ipairs(arr) do
		s = s + v
	end
	return s
end

function NumberUtil.mean(arr: { number }): number
	assert(#arr > 0, "mean requires non-empty")
	return NumberUtil.sum(arr) / #arr
end

function NumberUtil.median(arr: { number }): number
	assert(#arr > 0, "median requires non-empty")
	local t: { number } = table.create(#arr) :: { number }
	for i, v in ipairs(arr) do
		t[i] = v
	end
	table.sort(t)
	local n = #t
	if n % 2 == 1 then
		return t[(n + 1) // 2]
	else
		return 0.5 * (t[n // 2] + t[n // 2 + 1])
	end
end

function NumberUtil.mode(arr: { number }): number?
	if #arr == 0 then
		return nil
	end
	local counts: { [number]: number } = {}
	local best: number? = nil
	local bestC = 0
	for _, v in ipairs(arr) do
		local c = counts[v]
		if c == nil then
			counts[v] = 1
		else
			counts[v] = c + 1
		end
		if counts[v] > bestC then
			best = v
			bestC = counts[v]
		end
	end
	return best
end

function NumberUtil.variance(arr: { number }, sample: boolean?): number
	assert(#arr > 0, "variance requires non-empty array")
	local n = #arr
	local m = NumberUtil.mean(arr)
	local s = 0
	for _, v in ipairs(arr) do
		local d = v - m
		s = s + d * d
	end
	if sample then
		return s / (n - 1)
	else
		return s / n
	end
end

function NumberUtil.stddev(arr: { number }, sample: boolean?): number
	return math.sqrt(NumberUtil.variance(arr, sample))
end

function NumberUtil.percentile(arr: { number }, p: number): number
	assert(#arr > 0, "percentile requires non-empty array")
	local pp = NumberUtil.saturate(p)
	local t: { number } = table.create(#arr) :: { number }
	for i, v in ipairs(arr) do
		t[i] = v
	end
	table.sort(t)
	local idx = pp * (#t - 1) + 1
	local lo = math.floor(idx)
	local hi = math.min(lo + 1, #t)
	local frac = idx - lo
	return t[lo] + (t[hi] - t[lo]) * frac
end

-- ===== Combinatorics / Number Theory =====
function NumberUtil.gcd(a: number, b: number): number
	local aa = math.abs(a)
	local bb = math.abs(b)
	while bb ~= 0 do
		local tmp = bb
		bb = aa % bb
		aa = tmp
	end
	return aa
end

function NumberUtil.lcm(a: number, b: number): number
	if a == 0 or b == 0 then
		return 0
	end
	return math.abs(a * b) // NumberUtil.gcd(a, b)
end

-- Use bit32 for portability instead of |, &, >> (which can squiggle in strict Luau)

function NumberUtil.isPowerOfTwo(n: number): boolean
	-- must be a positive integer
	if n < 1 or n % 1 ~= 0 then
		return false
	end
	-- bit32 works on 32-bit ints (Lua treats numbers as doubles, but bit32 truncates safely)
	return bit32.band(n, n - 1) == 0
end

function NumberUtil.nextPowerOfTwo(n: number): number
	if n < 1 then
		return 1
	end
	n = math.floor(n)

	-- If it's already a power of two, return it as-is.
	-- (Also avoids overflowing the bit trick on exactly 2^31 etc.)
	if NumberUtil.isPowerOfTwo(n) then
		return n
	end

	-- Prefer the classic bit-hack within 32-bit range
	if n <= 0x7FFFFFFF then
		local x = n - 1
		x = bit32.bor(x, bit32.rshift(x, 1))
		x = bit32.bor(x, bit32.rshift(x, 2))
		x = bit32.bor(x, bit32.rshift(x, 4))
		x = bit32.bor(x, bit32.rshift(x, 8))
		x = bit32.bor(x, bit32.rshift(x, 16))
		return x + 1
	end

	-- Fallback (no bits): multiply by two until we pass n (exact up to 2^53)
	local p = 1
	while p < n and p < 2^53 do
		p = p * 2
	end
	return p
end


function NumberUtil.factorial(n: number): number
	assert(n >= 0 and n % 1 == 0, "factorial requires non-negative integer")
	local res = 1
	for i = 2, n do
		res = res * i
	end
	return res
end

function NumberUtil.nPr(n: number, r: number): number
	assert(n >= 0 and r >= 0 and r <= n, "nPr requires 0 <= r <= n")
	local res = 1
	for i = 0, r - 1 do
		res = res * (n - i)
	end
	return res
end

function NumberUtil.nCr(n: number, r: number): number
	assert(n >= 0 and r >= 0 and r <= n, "nCr requires 0 <= r <= n")
	local rr = math.min(r, n - r)
	if rr == 0 then
		return 1
	end
	local num = 1
	local den = 1
	for i = 1, rr do
		num = num * (n - rr + i)
		den = den * i
	end
	return num // den
end

function NumberUtil.isPrime(n: number): boolean
	if n <= 1 or n % 1 ~= 0 then
		return false
	end
	if n == 2 or n == 3 then
		return true
	end
	if n % 2 == 0 or n % 3 == 0 then
		return false
	end
	local i = 5
	local w = 2
	while i * i <= n do
		if n % i == 0 then
			return false
		end
		i = i + w
		w = 6 - w
	end
	return true
end

function NumberUtil.primeFactors(n: number): { number }
	local factors: { number } = {}
	local nn = n
	if nn < 0 then
		nn = -nn
	end
	while nn % 2 == 0 do
		table.insert(factors, 2)
		nn = nn // 2
	end
	local f = 3
	while f * f <= nn do
		while nn % f == 0 do
			table.insert(factors, f)
			nn = nn // f
		end
		f = f + 2
	end
	if nn > 1 then
		table.insert(factors, nn)
	end
	return factors
end

-- ===== Random Helpers =====
function NumberUtil.randomFloat(minV: number?, maxV: number?): number
	if minV == nil then
		return math.random()
	end
	if maxV == nil then
		return math.random() * (minV :: number)
	end
	return (minV :: number) + math.random() * ((maxV :: number) - (minV :: number))
end

function NumberUtil.randomInt(minV: number, maxV: number): number
	local a = minV
	local b = maxV
	if a > b then
		local t = a
		a = b
		b = t
	end
	return math.random(a, b)
end

function NumberUtil.randomBool(pTrue: number?): boolean
	local p = pTrue or 0.5
	return math.random() < p
end

function NumberUtil.randomSign(): number
	if math.random(0, 1) == 0 then
		return -1
	else
		return 1
	end
end

function NumberUtil.randomNormal(mu: number?, sigma: number?): number
	local mean = mu or 0
	local sd = sigma or 1
	local u1 = math.max(math.random(), EPSILON)
	local u2 = math.random()
	local z0 = math.sqrt(-2 * math.log(u1)) * math.cos(TAU * u2)
	return mean + z0 * sd
end

function NumberUtil.randomWeighted(weights: any): any
	local total = 0
	if typeof(weights) == "table" and #weights > 0 and typeof(weights[1]) == "table" then
		for _, pair in ipairs(weights) do
			total = total + pair[2]
		end
		local r = NumberUtil.randomFloat(0, total)
		local acc = 0
		for _, pair in ipairs(weights) do
			acc = acc + pair[2]
			if r <= acc then
				return pair[1]
			end
		end
	else
		for _, w in pairs(weights) do
			total = total + w
		end
		local r2 = NumberUtil.randomFloat(0, total)
		local acc2 = 0
		for k, w2 in pairs(weights) do
			acc2 = acc2 + w2
			if r2 <= acc2 then
				return k
			end
		end
	end
	return nil
end

-- ===== Integer / Bit Helpers =====
-- Counts set bits (Hamming weight) in a 32-bit integer
function NumberUtil.bitCount(x: number): number
	-- force to int, then mask to 32 bits (bit32 treats numbers as 32-bit ints)
	local xx = bit32.band(math.floor(x), 0xFFFFFFFF)
	local c = 0
	while xx ~= 0 do
		xx = bit32.band(xx, xx - 1) -- clear lowest set bit
		c = c + 1
	end
	return c
end

-- floor(log2(n)) for positive integers
function NumberUtil.log2i(n: number): number
	assert(n > 0 and n % 1 == 0, "log2i requires positive integer")
	local v = math.floor(n)
	local p = -1
	while v > 0 do
		v = bit32.rshift(v, 1)
		p = p + 1
	end
	return p
end


-- ===== Root Finding / Numeric Methods =====
function NumberUtil.newtonRaphson(
	f: (number) -> number,
	df: (number) -> number,
	x0: number,
	maxIter: number?,
	tol: number?
): (number, boolean, number)
	local maxI = maxIter or 25
	local tolerance = tol or 1e-6
	local x = x0
	for i = 1, maxI do
		local fx = f(x)
		local dfx = df(x)
		if NumberUtil.nearlyZero(dfx, EPSILON) then
			return x, false, i
		end
		local nx = x - fx / dfx
		if math.abs(nx - x) < tolerance then
			return nx, true, i
		end
		x = nx
	end
	return x, false, maxI
end

function NumberUtil.secant(
	f: (number) -> number,
	x0: number,
	x1: number,
	maxIter: number?,
	tol: number?
): (number, boolean, number)
	local maxI = maxIter or 30
	local tolerance = tol or 1e-6
	local f0 = f(x0)
	local f1 = f(x1)
	for i = 1, maxI do
		local denom = (f1 - f0)
		if NumberUtil.nearlyZero(denom, EPSILON) then
			return x1, false, i
		end
		local x2 = x1 - f1 * (x1 - x0) / denom
		if math.abs(x2 - x1) < tolerance then
			return x2, true, i
		end
		x0 = x1
		x1 = x2
		f0 = f1
		f1 = f(x1)
	end
	return x1, false, maxI
end

-- ===== Easing Curves (t in [0,1]) =====
NumberUtil.Ease = {}

local function _quadIn(t: number): number
	return t * t
end

local function _quadOut(t: number): number
	local u = 1 - t
	return 1 - u * u
end

local function _quadInOut(t: number): number
	if t < 0.5 then
		return 2 * t * t
	else
		local a = -2 * t + 2
		return 1 - (a * a) / 2
	end
end

local function _cubicIn(t: number): number
	return t * t * t
end

local function _cubicOut(t: number): number
	local u = 1 - t
	return 1 - u * u * u
end

local function _cubicInOut(t: number): number
	if t < 0.5 then
		return 4 * t * t * t
	else
		local a = -2 * t + 2
		return 1 - (a * a * a) / 2
	end
end

local function _quartIn(t: number): number
	return t ^ 4
end

local function _quartOut(t: number): number
	return 1 - (1 - t) ^ 4
end

local function _quartInOut(t: number): number
	if t < 0.5 then
		return 8 * t ^ 4
	else
		local a = -2 * t + 2
		return 1 - (a ^ 4) / 2
	end
end

local function _quintIn(t: number): number
	return t ^ 5
end

local function _quintOut(t: number): number
	return 1 - (1 - t) ^ 5
end

local function _quintInOut(t: number): number
	if t < 0.5 then
		return 16 * t ^ 5
	else
		local a = -2 * t + 2
		return 1 - (a ^ 5) / 2
	end
end

local function _expoIn(t: number): number
	if t == 0 then
		return 0
	end
	return 2 ^ (10 * (t - 1))
end

local function _expoOut(t: number): number
	if t == 1 then
		return 1
	end
	return 1 - 2 ^ (-10 * t)
end

local function _expoInOut(t: number): number
	if t == 0 then
		return 0
	end
	if t == 1 then
		return 1
	end
	if t < 0.5 then
		return (2 ^ (20 * t - 10)) / 2
	else
		return (2 - 2 ^ (-20 * t + 10)) / 2
	end
end

local function _circIn(t: number): number
	return 1 - math.sqrt(1 - t * t)
end

local function _circOut(t: number): number
	local a = t - 1
	return math.sqrt(1 - a * a)
end

local function _circInOut(t: number): number
	if t < 0.5 then
		return (1 - math.sqrt(1 - (2 * t) ^ 2)) / 2
	else
		local a = -2 * t + 2
		return (math.sqrt(1 - a * a) + 1) / 2
	end
end

local function _sineIn(t: number): number
	return 1 - math.cos((t * math.pi) / 2)
end

local function _sineOut(t: number): number
	return math.sin((t * math.pi) / 2)
end

local function _sineInOut(t: number): number
	return -(math.cos(math.pi * t) - 1) / 2
end

local function _backIn(t: number, s: number?): number
	local ss = s or 1.70158
	return (ss + 1) * t ^ 3 - ss * t ^ 2
end

local function _backOut(t: number, s: number?): number
	local ss = s or 1.70158
	local u = t - 1
	return 1 + (ss + 1) * u ^ 3 + ss * u ^ 2
end

local function _backInOut(t: number, s: number?): number
	local ss = (s or 1.70158) * 1.525
	if t < 0.5 then
		local u = t * 2
		return (u * u) * ((ss + 1) * u - ss) / 2
	else
		local u2 = t * 2 - 2
		return (u2 ^ 2 * ((ss + 1) * u2 + ss) + 2) / 2
	end
end

local function _elasticIn(t: number): number
	if t == 0 or t == 1 then
		return t
	end
	return -2 ^ (10 * (t - 1)) * math.sin((t - 1.075) * TAU / 0.3)
end

local function _elasticOut(t: number): number
	if t == 0 or t == 1 then
		return t
	end
	return 2 ^ (-10 * t) * math.sin((t - 0.075) * TAU / 0.3) + 1
end

local function _elasticInOut(t: number): number
	if t == 0 or t == 1 then
		return t
	end
	local u = t * 2
	if u < 1 then
		return -0.5 * 2 ^ (10 * (u - 1)) * math.sin((u - 1.1125) * TAU / 0.45)
	else
		return 0.5 * 2 ^ (-10 * (u - 1)) * math.sin((u - 1.1125) * TAU / 0.45) + 1
	end
end

local function _bounceOut(t: number): number
	local n1 = 7.5625
	local d1 = 2.75
	if t < 1 / d1 then
		return n1 * t * t
	elseif t < 2 / d1 then
		local u = t - 1.5 / d1
		return n1 * u * u + 0.75
	elseif t < 2.5 / d1 then
		local u2 = t - 2.25 / d1
		return n1 * u2 * u2 + 0.9375
	else
		local u3 = t - 2.625 / d1
		return n1 * u3 * u3 + 0.984375
	end
end

local function _bounceIn(t: number): number
	return 1 - _bounceOut(1 - t)
end

local function _bounceInOut(t: number): number
	if t < 0.5 then
		return (1 - _bounceOut(1 - 2 * t)) / 2
	else
		return (_bounceOut(2 * t - 1) + 1) / 2
	end
end

NumberUtil.Ease.linear = function(t: number): number return t end
NumberUtil.Ease.quadIn = _quadIn
NumberUtil.Ease.quadOut = _quadOut
NumberUtil.Ease.quadInOut = _quadInOut
NumberUtil.Ease.cubicIn = _cubicIn
NumberUtil.Ease.cubicOut = _cubicOut
NumberUtil.Ease.cubicInOut = _cubicInOut
NumberUtil.Ease.quartIn = _quartIn
NumberUtil.Ease.quartOut = _quartOut
NumberUtil.Ease.quartInOut = _quartInOut
NumberUtil.Ease.quintIn = _quintIn
NumberUtil.Ease.quintOut = _quintOut
NumberUtil.Ease.quintInOut = _quintInOut
NumberUtil.Ease.expoIn = _expoIn
NumberUtil.Ease.expoOut = _expoOut
NumberUtil.Ease.expoInOut = _expoInOut
NumberUtil.Ease.circIn = _circIn
NumberUtil.Ease.circOut = _circOut
NumberUtil.Ease.circInOut = _circInOut
NumberUtil.Ease.sineIn = _sineIn
NumberUtil.Ease.sineOut = _sineOut
NumberUtil.Ease.sineInOut = _sineInOut
NumberUtil.Ease.backIn = function(t: number): number return _backIn(t, nil) end
NumberUtil.Ease.backOut = function(t: number): number return _backOut(t, nil) end
NumberUtil.Ease.backInOut = function(t: number): number return _backInOut(t, nil) end
NumberUtil.Ease.elasticIn = _elasticIn
NumberUtil.Ease.elasticOut = _elasticOut
NumberUtil.Ease.elasticInOut = _elasticInOut
NumberUtil.Ease.bounceIn = _bounceIn
NumberUtil.Ease.bounceOut = _bounceOut
NumberUtil.Ease.bounceInOut = _bounceInOut

-- ===== Misc Helpers =====
function NumberUtil.mapIndexToRange(index: number, count: number, outMin: number, outMax: number): number
	if count <= 1 then
		return outMin
	end
	local t = (index - 1) / (count - 1)
	return NumberUtil.lerp(outMin, outMax, t)
end

function NumberUtil.gammaToLinear(x: number, gamma: number?): number
	local g = gamma or 2.2
	return x ^ g
end

function NumberUtil.linearToGamma(x: number, gamma: number?): number
	local g = gamma or 2.2
	return x ^ (1 / g)
end

-- ========================================================================
-- ========== TEXT/FORMAT HELPERS (commas, abbreviations, etc.) ===========
-- ========================================================================
NumberUtil.Format = {}

function NumberUtil.Format.withCommas(n: number, decimals: number?): string
	local d = decimals or 0
	local neg = ""
	if n < 0 then
		neg = "-"
	end
	local absn = math.abs(n)
	local intPart = tostring(math.floor(absn + 0.0000001))
	local frac = ""
	if d > 0 then
		local fracVal = NumberUtil.round(absn - math.floor(absn), d)
		local s = string.format("%." .. d .. "f", fracVal)
		s = s:gsub("^0", "")
		if s ~= "" then
			frac = s
		end
	end
	local k = #intPart % 3
	if k == 0 then
		k = 3
	end
	local out = intPart:sub(1, k)
	local i = k + 1
	while i <= #intPart do
		out = out .. "," .. intPart:sub(i, i + 2)
		i = i + 3
	end
	if out == "" then
		out = "0"
	end
	return neg .. out .. (frac ~= "" and frac or "")
end

function NumberUtil.Format.abbreviate(n: number, decimals: number?, system: string?): string
	local d = decimals or 1
	local sys = system or "short"
	local neg = ""
	local absn = n
	if n < 0 then
		neg = "-"
		absn = -n
	end
	if absn < 1000 then
		return neg .. NumberUtil.Format.withCommas(NumberUtil.round(absn, d), d)
	end

	local unitsShort = { "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }
	local unitsEng = { "k", "M", "G", "T", "P", "E", "Z", "Y" }

	local base = 1000
	local exp = math.floor(math.log(absn) / LOG10 / 3)
	local value = absn / (base ^ exp)

	local suffix = ""
	if sys == "eng" then
		if exp > #unitsEng then
			exp = #unitsEng
		end
		suffix = unitsEng[exp]
	else
		if exp > #unitsShort then
			exp = #unitsShort
		end
		suffix = unitsShort[exp]
	end

	return neg .. tostring(NumberUtil.round(value, d)) .. suffix
end

function NumberUtil.Format.ordinal(i: number): string
	local ii = math.floor(math.abs(i))
	local j = ii % 10
	local k = ii % 100
	if j == 1 and k ~= 11 then
		return tostring(ii) .. "st"
	elseif j == 2 and k ~= 12 then
		return tostring(ii) .. "nd"
	elseif j == 3 and k ~= 13 then
		return tostring(ii) .. "rd"
	else
		return tostring(ii) .. "th"
	end
end

local romanMap: { { number | string } } = {
	{ 1000, "M" }, { 900, "CM" }, { 500, "D" }, { 400, "CD" },
	{ 100, "C" }, { 90, "XC" }, { 50, "L" }, { 40, "XL" },
	{ 10, "X" }, { 9, "IX" }, { 5, "V" }, { 4, "IV" }, { 1, "I" },
}

function NumberUtil.Format.toRoman(n: number): string
	local nn = math.clamp(math.floor(n), 1, 3999)
	local s = ""
	for _, p in ipairs(romanMap) do
		local val = p[1] :: number
		local sym = p[2] :: string
		while nn >= val do
			s = s .. sym
			nn = nn - val
		end
	end
	return s
end

local romanValue: { [string]: number } = { I = 1, V = 5, X = 10, L = 50, C = 100, D = 500, M = 1000 }

function NumberUtil.Format.fromRoman(s: string): number
	local up = string.upper(s)
	local total = 0
	local prev = 0
	local i = #up
	while i >= 1 do
		local c = up:sub(i, i)
		local v = romanValue[c] or 0
		if v < prev then
			total = total - v
		else
			total = total + v
			prev = v
		end
		i = i - 1
	end
	return total
end

function NumberUtil.Format.percent(x: number, decimals: number?): string
	local d = decimals or 0
	return string.format("%." .. d .. "f%%", (x * 100))
end

function NumberUtil.Format.currency(x: number, symbol: string?, decimals: number?): string
	local sym = symbol or "$"
	local d = decimals or 2
	local s = NumberUtil.Format.withCommas(NumberUtil.round(x, d), d)
	return sym .. s
end

function NumberUtil.Format.toScientific(n: number, sigfigs: number?): string
	local sig = sigfigs or 3
	if n == 0 then
		return "0e+0"
	end
	local e = math.floor(math.log(math.abs(n)) / LOG10)
	local m = n / (10 ^ e)
	local fmt = "%." .. math.max(0, sig - 1) .. "f"
	local mant = string.format(fmt, m)
	local sign = "+"
	if e < 0 then
		sign = ""
	end
	return mant .. "e" .. sign .. tostring(e)
end

function NumberUtil.Format.sigfig(n: number, sig: number): number
	if n == 0 then
		return 0
	end
	local e = math.floor(math.log(math.abs(n)) / LOG10)
	local f = 10 ^ (sig - 1 - e)
	return NumberUtil.round(n * f) / f
end

function NumberUtil.Format.parseNumber(s: string): number?
	if s == nil then
		return nil
	end
	local str = s:gsub("%s", "")
	local sign = 1
	if str:sub(1, 1) == "-" then
		sign = -1
		str = str:sub(2)
	end
	str = str:gsub(",", "")
	local suffix = str:sub(-1)
	local mult = 1
	if suffix == "K" or suffix == "k" then
		mult = 1e3
		str = str:sub(1, -2)
	elseif suffix == "M" then
		mult = 1e6
		str = str:sub(1, -2)
	elseif suffix == "B" or suffix == "G" then
		mult = 1e9
		str = str:sub(1, -2)
	elseif suffix == "T" then
		mult = 1e12
		str = str:sub(1, -2)
	end
	local num = tonumber(str)
	if not num then
		return nil
	end
	return sign * num * mult
end

-- ========================================================================
-- ========================= PHYSICS TOOLBOX (SI) =========================
-- ========================================================================
NumberUtil.Physics = {}

NumberUtil.Physics.g = 9.80665
NumberUtil.Physics.G = 6.67430e-11
NumberUtil.Physics.R = 8.314462618
NumberUtil.Physics.rhoWater = 1000

-- Kinematics (SUVAT)
function NumberUtil.Physics.v_from_u_a_t(u: number, a: number, t: number): number
	return u + a * t
end

function NumberUtil.Physics.s_from_u_a_t(u: number, a: number, t: number): number
	return u * t + 0.5 * a * t * t
end

function NumberUtil.Physics.v_from_u_a_s(u: number, a: number, s: number): number
	local v2 = u * u + 2 * a * s
	if v2 >= 0 then
		return math.sqrt(v2)
	else
		return 0 / 0
	end
end

function NumberUtil.Physics.t_from_u_v_a(u: number, v: number, a: number): number
	if NumberUtil.nearlyZero(a) then
		return 0 / 0
	end
	return (v - u) / a
end

function NumberUtil.Physics.a_from_u_v_s(u: number, v: number, s: number): number
	if NumberUtil.nearlyZero(s) then
		return 0 / 0
	end
	return (v * v - u * u) / (2 * s)
end

-- Projectiles (no drag)
function NumberUtil.Physics.timeOfFlight(v0: number, angleDeg: number, g: number?): number
	local gg = g or NumberUtil.Physics.g
	return (2 * v0 * math.sin(NumberUtil.deg2rad(angleDeg))) / gg
end

function NumberUtil.Physics.range(v0: number, angleDeg: number, g: number?): number
	local gg = g or NumberUtil.Physics.g
	return (v0 * v0 * math.sin(NumberUtil.deg2rad(2 * angleDeg))) / gg
end

function NumberUtil.Physics.maxHeight(v0: number, angleDeg: number, g: number?): number
	local gg = g or NumberUtil.Physics.g
	local vy = v0 * math.sin(NumberUtil.deg2rad(angleDeg))
	return vy * vy / (2 * gg)
end

function NumberUtil.Physics.freeFallTime(height: number, g: number?): number
	local gg = g or NumberUtil.Physics.g
	return math.sqrt(2 * height / gg)
end

-- Forces / Dynamics
function NumberUtil.Physics.F(ma: number, a: number?): number
	if a == nil then
		return ma
	else
		return ma * (a :: number)
	end
end

function NumberUtil.Physics.weight(m: number, g: number?): number
	local gg = g or NumberUtil.Physics.g
	return m * gg
end

function NumberUtil.Physics.frictionForce(mu: number, normal: number): number
	return mu * normal
end

function NumberUtil.Physics.impulse(F: number, dt: number): number
	return F * dt
end

function NumberUtil.Physics.momentum(m: number, v: number): number
	return m * v
end

function NumberUtil.Physics.elastic1D(m1: number, v1: number, m2: number, v2: number): (number, number)
	local v1p = ((m1 - m2) / (m1 + m2)) * v1 + (2 * m2 / (m1 + m2)) * v2
	local v2p = (2 * m1 / (m1 + m2)) * v1 + ((m2 - m1) / (m1 + m2)) * v2
	return v1p, v2p
end

-- Energy / Work / Power
function NumberUtil.Physics.KE(m: number, v: number): number
	return 0.5 * m * v * v
end

function NumberUtil.Physics.PEg(m: number, h: number, g: number?): number
	local gg = g or NumberUtil.Physics.g
	return m * gg * h
end

function NumberUtil.Physics.PEs(k: number, x: number): number
	return 0.5 * k * x * x
end

function NumberUtil.Physics.work(F: number, d: number, thetaDeg: number?): number
	if thetaDeg == nil then
		return F * d
	else
		return F * d * math.cos(NumberUtil.deg2rad(thetaDeg :: number))
	end
end

function NumberUtil.Physics.powerFromWork(W: number, t: number): number
	if NumberUtil.nearlyZero(t) then
		return 0 / 0
	end
	return W / t
end

function NumberUtil.Physics.powerFromForce(F: number, v: number): number
	return F * v
end

-- Springs / Oscillation
function NumberUtil.Physics.hookeForce(k: number, x: number): number
	return -k * x
end

function NumberUtil.Physics.pendulumPeriod(L: number, g: number?): number
	local gg = g or NumberUtil.Physics.g
	return 2 * math.pi * math.sqrt(L / gg)
end

-- Circular Motion
function NumberUtil.Physics.centripetalAcc(v: number, r: number): number
	return v * v / r
end

function NumberUtil.Physics.centripetalForce(m: number, v: number, r: number): number
	return m * v * v / r
end

-- Gravity / Orbits
function NumberUtil.Physics.gravForce(m1: number, m2: number, r: number, G: number?): number
	local GG = G or NumberUtil.Physics.G
	return GG * m1 * m2 / (r * r)
end

function NumberUtil.Physics.orbitalSpeed(GM: number, r: number): number
	return math.sqrt(GM / r)
end

-- Waves / Sound
function NumberUtil.Physics.waveSpeed(freq: number, lambda: number): number
	return freq * lambda
end

function NumberUtil.Physics.periodFromFreq(f: number): number
	if NumberUtil.nearlyZero(f) then
		return 0 / 0
	end
	return 1 / f
end

function NumberUtil.Physics.freqFromPeriod(T: number): number
	if NumberUtil.nearlyZero(T) then
		return 0 / 0
	end
	return 1 / T
end

function NumberUtil.Physics.decibels(I: number, I0: number?): number
	local Iref = I0 or 1e-12
	if I <= 0 or Iref <= 0 then
		return 0 / 0
	end
	return 10 * (math.log(I / Iref) / LOG10)
end

-- Electricity (DC)
function NumberUtil.Physics.ohmsLaw_V(I: number, R: number): number
	return I * R
end

function NumberUtil.Physics.ohmsLaw_I(V: number, R: number): number
	if NumberUtil.nearlyZero(R) then
		return 0 / 0
	end
	return V / R
end

function NumberUtil.Physics.ohmsLaw_R(V: number, I: number): number
	if NumberUtil.nearlyZero(I) then
		return 0 / 0
	end
	return V / I
end

function NumberUtil.Physics.electricPower_VI(V: number, I: number): number
	return V * I
end

function NumberUtil.Physics.electricPower_I2R(I: number, R: number): number
	return I * I * R
end

function NumberUtil.Physics.electricPower_V2overR(V: number, R: number): number
	if NumberUtil.nearlyZero(R) then
		return 0 / 0
	end
	return V * V / R
end

-- Thermo / Gas
function NumberUtil.Physics.idealGas_P(n: number, T: number, V: number, R: number?): number
	local RR = R or NumberUtil.Physics.R
	return n * RR * T / V
end

function NumberUtil.Physics.idealGas_T(P: number, V: number, n: number, R: number?): number
	local RR = R or NumberUtil.Physics.R
	return P * V / (n * RR)
end

function NumberUtil.Physics.idealGas_V(n: number, T: number, P: number, R: number?): number
	local RR = R or NumberUtil.Physics.R
	return n * RR * T / P
end

-- Fluids
function NumberUtil.Physics.buoyantForce(rho: number, V: number, g: number?): number
	local gg = g or NumberUtil.Physics.g
	return rho * V * gg
end

function NumberUtil.Physics.hydroPressure(rho: number, g: number, h: number): number
	return rho * g * h
end

return NumberUtil
