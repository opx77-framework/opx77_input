--- @author DemiAutomatic
--- @file shared/text.lua
--- @description UTF-8 aware text measuring and cleaning helpers.

OpxInput = OpxInput or {}

OpxInput.Text = {}
local Text = OpxInput.Text

--- @author DemiAutomatic
--- @method OpxInput.Text.Span
--- @description Byte length of the first characters, bounded at four bytes each.
--- @param text {string}
--- @param maximum {integer} Characters, not bytes.
--- @returns {integer}
function OpxInput.Text.Span(text, maximum)
	local size = #text
	local ceiling = maximum * 4
	if size > ceiling then size = ceiling end
	local characters, index = 0, 1
	while index <= size do
		local byte = text:byte(index)
		if byte < 0x80 or byte > 0xBF then
			if characters >= maximum then return index - 1 end
			characters = characters + 1
		end
		index = index + 1
	end
	return size
end

--- @author DemiAutomatic
--- @method OpxInput.Text.Clean
--- @description Display text with control characters blanked, cut to a character count.
--- @param value {any}
--- @param maximum {integer} Characters, not bytes.
--- @param ellipsis {string|nil}
--- @returns {string|nil}
function OpxInput.Text.Clean(value, maximum, ellipsis)
	if value == nil then return nil end
	if type(value) == 'number' then value = tostring(value) end
	if type(value) ~= 'string' then return nil end
	value = value:gsub('[%c]', ' ')
	if #value <= maximum then return value end
	local cut = Text.Span(value, maximum)
	if cut >= #value then return value end
	return value:sub(1, cut) .. (ellipsis or '')
end
