local StringUtil = {}

-- ========= Roblox PUA glyphs (render in Roblox UI font) =========
-- NOTE: These are Private-Use Area codepoints; outside Roblox they may show as tofu/□
StringUtil.PUA = {
	Verified = utf8.char(0xE000), -- verified badge
	Premium  = utf8.char(0xE001), -- premium badge
	Robux    = utf8.char(0xE002), -- robux icon
}


-- ========= Basic wrappers / QoL =========
function StringUtil.upper(s: string): string return string.upper(s) end
function StringUtil.lower(s: string): string return string.lower(s) end
function StringUtil.reverse(s: string): string return string.reverse(s) end
function StringUtil.rep(s: string, n: number): string return string.rep(s, n) end
function StringUtil.len(s: string): number return #s end
function StringUtil.format(fmt: string, ...): string return string.format(fmt, ...) end

function StringUtil.safeFormat(fmt: string, ...): (string?, string?)
	local ok, res = pcall(string.format, fmt, ...)
	if ok then
		return res :: string, nil
	else
		return nil, tostring(res)
	end
end

function StringUtil.trim(s: string): string
	return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end
function StringUtil.trimStart(s: string): string return (s:gsub("^%s+", "")) end
function StringUtil.trimEnd(s: string): string return (s:gsub("%s+$", "")) end
function StringUtil.isEmpty(s: string): boolean return s == "" end
function StringUtil.isBlank(s: string): boolean return StringUtil.trim(s) == "" end

-- ========= Search / starts/ends / contains =========
function StringUtil.escapePattern(s: string): string
	return (s:gsub("(%W)", "%%%1"))
end

function StringUtil.contains(s: string, needle: string, plain: boolean?): boolean
	return string.find(s, needle, 1, plain == true) ~= nil
end

function StringUtil.startsWith(s: string, prefix: string, plain: boolean?): boolean
	local i = string.find(s, prefix, 1, plain == true)
	return i == 1
end

function StringUtil.endsWith(s: string, suffix: string, plain: boolean?): boolean
	if suffix == "" then return true end
	local start = #s - #suffix + 1
	if start < 1 then return false end
	if plain == true then
		return s:sub(start) == suffix
	else
		-- pattern match with end anchor
		return string.find(s, suffix .. "$") ~= nil
	end
end

function StringUtil.startsWithAny(s: string, prefixes: {string}, plain: boolean?): boolean
	for _, p in ipairs(prefixes) do
		if StringUtil.startsWith(s, p, plain) then return true end
	end
	return false
end

function StringUtil.endsWithAny(s: string, suffixes: {string}, plain: boolean?): boolean
	for _, sf in ipairs(suffixes) do
		if StringUtil.endsWith(s, sf, plain) then return true end
	end
	return false
end

function StringUtil.count(s: string, sub: string, plain: boolean?): number
	if sub == "" then return 0 end
	local c = 0
	local i = 1
	while true do
		local j, k = string.find(s, sub, i, plain == true)
		if not j then break end
		c = c + 1
		i = k + 1
	end
	return c
end

-- ========= Replace / split / join / lines =========
function StringUtil.replaceFirst(s: string, search: string, repl: string, plain: boolean?): string
	local j, k = string.find(s, search, 1, plain == true)
	if not j then return s end
	return s:sub(1, j - 1) .. repl .. s:sub(k + 1)
end

function StringUtil.replaceAll(s: string, search: string, repl: string, plain: boolean?): string
	if search == "" then return s end
	if plain == true then
		-- Escape search as literal; also escape % in replacement
		return (s:gsub(StringUtil.escapePattern(search), repl:gsub("%%", "%%%%")))
	else
		return (s:gsub(search, repl))
	end
end

-- split with:
--   nil sep -> collapses whitespace (%S+)
--   sep + plain=true -> literal separator
--   sep + plain=false/nil -> pattern separator
function StringUtil.split(s: string, sep: string?, plain: boolean?): {string}
	if sep == nil then
		local out: {string} = {}
		for token in s:gmatch("%S+") do
			table.insert(out, token)
		end
		return out
	end
	local out: {string} = {}
	local i = 1
	while true do
		local j, k = string.find(s, sep, i, plain == true)
		if not j then
			table.insert(out, s:sub(i))
			break
		end
		table.insert(out, s:sub(i, j - 1))
		i = k + 1
	end
	return out
end

function StringUtil.join(parts: {any}, sep: string?): string
	sep = sep or ""
	local mapped = table.create(#parts)
	for i = 1, #parts do
		mapped[i] = tostring(parts[i])
	end
	return table.concat(mapped, sep)
end

function StringUtil.lines(s: string): () -> string?
	local i, n = 1, #s
	return function()
		if i > n then return nil end
		local j = s:find("\n", i, true)
		local line: string
		if j then
			line = s:sub(i, j - 1)
			i = j + 1
		else
			line = s:sub(i)
			i = n + 1
		end
		return line
	end
end

-- ========= Pad / indent / clip =========
function StringUtil.padLeft(s: string, width: number, ch: string?): string
	local fill = ((ch ~= nil and ch ~= "") and ch or " ") :: string
	if #s >= width then return s end
	return string.rep(fill, width - #s) .. s
end

function StringUtil.padRight(s: string, width: number, ch: string?): string
	local fill = ((ch ~= nil and ch ~= "") and ch or " ") :: string
	if #s >= width then return s end
	return s .. string.rep(fill, width - #s)
end

function StringUtil.padCenter(s: string, width: number, ch: string?): string
	local fill = ((ch ~= nil and ch ~= "") and ch or " ") :: string
	local diff = width - #s
	if diff <= 0 then return s end
	local left = math.floor(diff / 2)
	return string.rep(fill, left) .. s .. string.rep(fill, diff - left)
end

function StringUtil.ellipsis(s: string, maxLen: number): string
	if #s <= maxLen then return s end
	if maxLen <= 1 then return "…" end
	return s:sub(1, maxLen - 1) .. "…"
end

function StringUtil.truncateMiddle(s: string, maxLen: number): string
	if #s <= maxLen then return s end
	if maxLen <= 3 then return string.rep(".", maxLen) end
	local side = math.floor((maxLen - 1) / 2)
	local left = s:sub(1, side)
	local right = s:sub(#s - (maxLen - side - 1) + 1)
	return left .. "…" .. right
end

function StringUtil.indent(s: string, prefix: string): string
	return prefix .. s:gsub("\n", "\n" .. prefix)
end

-- ========= Case helpers =========
function StringUtil.capitalize(s: string): string
	if s == "" then return s end
	return string.upper(s:sub(1, 1)) .. s:sub(2)
end

function StringUtil.toTitleCase(s: string): string
	return (s:gsub("(%S+)", function(word)
		return StringUtil.capitalize(string.lower(word))
	end))
end

function StringUtil.ensurePrefix(s: string, prefix: string): string
	if StringUtil.startsWith(s, prefix, true) then return s end
	return prefix .. s
end

function StringUtil.ensureSuffix(s: string, suffix: string): string
	if StringUtil.endsWith(s, suffix, true) then return s end
	return s .. suffix
end

function StringUtil.removePrefix(s: string, prefix: string): string
	return StringUtil.startsWith(s, prefix, true) and s:sub(#prefix + 1) or s
end

function StringUtil.removeSuffix(s: string, suffix: string): string
	return StringUtil.endsWith(s, suffix, true) and s:sub(1, #s - #suffix) or s
end

-- ========= RichText (basic) =========
function StringUtil.stripRichTextTags(s: string): string
	return (s:gsub("<.->", ""))
end

-- ========= UTF-8 helpers (codepoint-aware) =========
local function ulen(s: string): number
	local ok, n = pcall(utf8.len, s)
	return ok and (n :: number) or #s
end
StringUtil.ulen = ulen

-- UTF-8 substring by codepoint indices (1-based, inclusive)
function StringUtil.usub(s: string, iCode: number, jCode: number?): string
	local j = (jCode or iCode) :: number
	if iCode < 1 then iCode = 1 end
	local iByte = utf8.offset(s, iCode)
	if not iByte then return "" end
	local jByte = utf8.offset(s, j + 1)
	if jByte then
		return s:sub(iByte, jByte - 1)
	else
		return s:sub(iByte)
	end
end

-- Reverse by codepoint (not grapheme cluster–aware)
function StringUtil.ureverse(s: string): string
	local parts: {string} = {}
	local i = 1
	while i <= #s do
		local startByte = i
		local c = string.byte(s, i)
		local len = (c < 0x80) and 1 or (c < 0xE0 and 2 or (c < 0xF0 and 3 or 4))
		i = i + len
		table.insert(parts, 1, s:sub(startByte, i - 1))
	end
	return table.concat(parts)
end

-- ========= Change case of a specific character =========
-- ASCII/byte index (1..#s)
function StringUtil.upperAt(s: string, i: number): string
	if i < 1 or i > #s then return s end
	local a, b = s:sub(1, i - 1), s:sub(i, i)
	return a .. string.upper(b) .. s:sub(i + 1)
end

function StringUtil.lowerAt(s: string, i: number): string
	if i < 1 or i > #s then return s end
	local a, b = s:sub(1, i - 1), s:sub(i, i)
	return a .. string.lower(b) .. s:sub(i + 1)
end

-- UTF-8 codepoint index (1..utf8.len(s))
function StringUtil.uupperAt(s: string, k: number): string
	if k < 1 then return s end
	local iByte = utf8.offset(s, k)
	if not iByte then return s end
	local jByte = utf8.offset(s, k + 1) or (#s + 1)
	local head, mid, tail = s:sub(1, iByte - 1), s:sub(iByte, jByte - 1), s:sub(jByte)
	return head .. string.upper(mid) .. tail
end

function StringUtil.ulowerAt(s: string, k: number): string
	if k < 1 then return s end
	local iByte = utf8.offset(s, k)
	if not iByte then return s end
	local jByte = utf8.offset(s, k + 1) or (#s + 1)
	local head, mid, tail = s:sub(1, iByte - 1), s:sub(iByte, jByte - 1), s:sub(jByte)
	return head .. string.lower(mid) .. tail
end

-- General: replace a codepoint at k with any replacement text
function StringUtil.ureplaceAt(s: string, k: number, replacement: string): string
	if k < 1 then return s end
	local iByte = utf8.offset(s, k)
	if not iByte then return s end
	local jByte = utf8.offset(s, k + 1) or (#s + 1)
	return s:sub(1, iByte - 1) .. replacement .. s:sub(jByte)
end

-- ========= Interpolation / quoting / slug =========
function StringUtil.interpolate(s: string, dict: { [string]: any }): string
	return (s:gsub("{([_%a][_%w]*)}", function(key)
		local v = dict[key]
		return v == nil and "{" .. key .. "}" or tostring(v)
	end))
end

function StringUtil.quote(s: string): string
	return '"' .. s:gsub('"', '\\"') .. '"'
end

function StringUtil.enclose(s: string, left: string, right: string): string
	return left .. s .. right
end

function StringUtil.slugify(s: string): string
	s = StringUtil.lower(StringUtil.trim(s))
	s = (s:gsub("%s+", "-"))
	s = (s:gsub("[^a-z0-9%-]", ""))
	s = (s:gsub("%-+", "-"))
	return s
end

-- ========= Table key=val join =========
function StringUtil.joinKeyVals(t: { [string]: any }, pairSep: string?, kvSep: string?): string
	local pair = pairSep or "&"
	local kv = kvSep or "="
	local out: {string} = {}
	for k, v in pairs(t) do
		table.insert(out, tostring(k) .. kv .. tostring(v))
	end
	return table.concat(out, pair)
end

return StringUtil
