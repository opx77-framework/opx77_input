--- @author DemiAutomatic
--- @file shared/text.lua
--- @description UTF-8 aware measuring of text in characters.

OpxInput = OpxInput or {}

OpxInput.Text = {}

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
