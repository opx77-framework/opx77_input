--- @author DemiAutomatic
--- @file client/model.lua
--- @description The form model: validated fields, the focused one, and the view.

local Text = OpxInput.Text

OpxInput.Model = {}
local Model = OpxInput.Model

--- @author DemiAutomatic
--- @type {integer}
--- @description Most fields one form answers; more is a menu list.
local MAX_FIELDS = 8

--- @author DemiAutomatic
--- @type {integer}
--- @description Most options one choice field carries.
local MAX_OPTIONS = 64

--- @author DemiAutomatic
--- @type {integer}
--- @description Most keys and values a caller's data table may hold.
local MAX_DATA_NODES = 64

--- @author DemiAutomatic
--- @type {integer}
--- @description Deepest nesting a caller's data table may reach.
local MAX_DATA_DEPTH = 4

--- @author DemiAutomatic
--- @type {integer}
--- @description Longest form title or field label, in characters.
local MAX_LABEL = 96

--- @author DemiAutomatic
--- @type {integer}
--- @description Longest option label, in characters.
local MAX_OPTION_LABEL = 48

--- @author DemiAutomatic
--- @type {integer}
--- @description Longest string option value, in characters.
local MAX_OPTION_VALUE = 96

--- @author DemiAutomatic
--- @type {integer}
--- @description Longest text field placeholder, in characters.
local MAX_PLACEHOLDER = 64

--- @author DemiAutomatic
--- @type {integer}
--- @description Longest form or field description, in characters.
local MAX_DESCRIPTION = 160

--- @author DemiAutomatic
--- @type {integer}
--- @description Longest slider suffix, in characters.
local MAX_SUFFIX = 8

--- @author DemiAutomatic
--- @type {integer}
--- @description Longest status line, in characters.
local MAX_STATUS = 120

--- @author DemiAutomatic
--- @type {integer}
--- @description Text field length when the caller names none, in characters.
local DEFAULT_TEXT = 96

--- @author DemiAutomatic
--- @type {integer}
--- @description Hardest text field length a caller may ask for.
local MAX_TEXT = 512

--- @author DemiAutomatic
--- @type {integer}
--- @description Longest Lua pattern a caller may hand a text field.
local MAX_PATTERN = 64

--- @author DemiAutomatic
--- @type {integer}
--- @description Most captures a Lua pattern may open.
local MAX_CAPTURES = 32

--- @author DemiAutomatic
--- @type {table<string, string>}
--- @description Named character classes a text field may accept.
local CHARSETS = {
	alnum = '^[%w]+$',
	alpha = '^[%a]+$',
	digits = '^[%d]+$',
	hex = '^[%x]+$',
	name = "^[%w %-_%.']+$",
}

--- @author DemiAutomatic
--- @method finite
--- @description Whether a value is a number that is neither NaN nor infinite.
--- @param value {any}
--- @returns {boolean}
local function finite(value)
	return type(value) == 'number' and value == value
		and value > -math.huge and value < math.huge
end

--- @author DemiAutomatic
--- @method validName
--- @description Whether a value is a bounded identifier of word characters.
--- @param value {any}
--- @param maximum {integer}
--- @returns {boolean}
local function validName(value, maximum)
	return type(value) == 'string' and #value > 0 and #value <= maximum
		and value:match('^[%w_:%-%.]+$') ~= nil
end

--- @author DemiAutomatic
--- @method displayText
--- @description Display text with control characters blanked, refused past a character count.
--- @param value {any}
--- @param maximum {integer} Characters, not bytes.
--- @returns {string|nil}
local function displayText(value, maximum)
	if type(value) == 'number' then value = tostring(value) end
	if type(value) ~= 'string' then return nil end
	value = value:gsub('%c', ' ')
	if #value <= maximum then return value end
	if Text.Span(value, maximum) >= #value then return value end
	return nil
end

--- @author DemiAutomatic
--- @method OpxInput.Model.StatusText
--- @description The status line's text, or nil for a value it refuses.
--- @param value {any}
--- @returns {string|nil}
function OpxInput.Model.StatusText(value)
	return displayText(value, MAX_STATUS)
end

--- @author DemiAutomatic
--- @type {fun(value: any, maximum: integer): boolean}
--- @description Identifier validator shared with client/exports.lua.
OpxInput.Model.ValidName = validName

--- @author DemiAutomatic
--- @method withinCharset
--- @description Whether text sits inside the field's character class.
--- @param entry {InputEntry}
--- @param text {string}
--- @returns {boolean}
local function withinCharset(entry, text)
	if entry.charset == nil or text == '' then return true end
	return text:match(entry.charset) ~= nil
end

--- @author DemiAutomatic
--- @method matchesPattern
--- @description Whether the whole text matches the field's pattern.
--- @param entry {InputEntry}
--- @param text {string}
--- @returns {boolean}
local function matchesPattern(entry, text)
	if entry.pattern == nil or text == '' then return true end
	local ok, matched = pcall(string.match, text, entry.pattern)
	if ok then return matched ~= nil end
	if not entry.patternFailed then
		entry.patternFailed = true
		Open77.log.warn(('the pattern of field %s failed: %s'):format(entry.id, tostring(matched)))
	end
	return false
end

--- @author DemiAutomatic
--- @method fitsInPayload
--- @description Counts a caller's opaque table, refusing past the node and depth bounds.
--- @param value {any}
--- @param depth {integer}
--- @param budget {table}
--- @returns {boolean}
local function fitsInPayload(value, depth, budget)
	budget.data = budget.data + 1
	if budget.data > MAX_DATA_NODES then return false end
	if type(value) ~= 'table' then return true end
	if depth > MAX_DATA_DEPTH then return false end
	for key, nested in pairs(value) do
		if not fitsInPayload(key, depth + 1, budget) then return false end
		if not fitsInPayload(nested, depth + 1, budget) then return false end
	end
	return true
end

--- @author DemiAutomatic
--- @method normalizeSlider
--- @description Validates a slider and fills its defaults, clamping the start value.
--- @param slider {InputSlider}
--- @returns {InputSlider|nil, string|nil}
local function normalizeSlider(slider)
	if type(slider) ~= 'table' then return nil, 'invalid_slider' end
	local minimum = finite(slider.min) and slider.min + 0.0 or 0.0
	local maximum = finite(slider.max) and slider.max + 0.0 or 100.0
	if maximum <= minimum then return nil, 'invalid_slider_range' end
	local step = finite(slider.step) and math.abs(slider.step) + 0.0 or 1.0
	if step <= 0 then step = 1.0 end
	local value = finite(slider.value) and slider.value + 0.0 or minimum
	if value < minimum then value = minimum end
	if value > maximum then value = maximum end
	local suffix = ''
	if slider.suffix ~= nil then
		suffix = displayText(slider.suffix, MAX_SUFFIX)
		if suffix == nil then return nil, 'invalid_slider_suffix' end
	end
	return { min = minimum, max = maximum, step = step, value = value, suffix = suffix }
end

--- @author DemiAutomatic
--- @method optionValue
--- @description The value an option answers with, kept exactly as written.
--- @param option {table}
--- @param label {string}
--- @returns {string|number|nil}
local function optionValue(option, label)
	local value = option.value
	if value == nil then return label end
	if type(value) == 'number' then
		return finite(value) and value or nil
	end
	if type(value) == 'string' and displayText(value, MAX_OPTION_VALUE) ~= nil then
		return value
	end
	return nil
end

--- @author DemiAutomatic
--- @method normalizeOptions
--- @description Validates a choice field's options and its starting selection.
--- @param field {InputField}
--- @returns {table|nil, string|nil}
local function normalizeOptions(field)
	local raw = field.options
	if type(raw) ~= 'table' then return nil, 'invalid_options' end
	local total = #raw
	if total == 0 then return nil, 'empty_options' end
	if total > MAX_OPTIONS then return nil, 'too_many_options' end

	local options = {}
	for index = 1, total do
		local option = raw[index]
		if type(option) == 'string' or type(option) == 'number' then
			option = { label = option }
		end
		if type(option) ~= 'table' then return nil, 'invalid_option' end
		local label = displayText(option.label, MAX_OPTION_LABEL)
		if label == nil or label == '' then return nil, 'invalid_option' end
		local value = optionValue(option, label)
		if value == nil then return nil, 'invalid_option_value' end
		options[index] = { label = label, value = value }
	end

	local selected = 1
	if field.selected ~= nil then
		if not finite(field.selected) or field.selected % 1 ~= 0 then
			return nil, 'invalid_selected'
		end
		selected = math.floor(field.selected)
		if selected < 1 or selected > total then return nil, 'invalid_selected' end
	end
	return { options = options, selected = selected }
end

--- @author DemiAutomatic
--- @method classEnd
--- @description Answers the index after a pattern set, or nil when unclosed.
--- @param pattern {string}
--- @param index {integer} First character after the opening bracket.
--- @param size {integer}
--- @returns {integer|nil}
local function classEnd(pattern, index, size)
	if pattern:sub(index, index) == '^' then index = index + 1 end
	repeat
		if index > size then return nil end
		local character = pattern:sub(index, index)
		index = index + 1
		if character == '%' and index <= size then index = index + 1 end
	until pattern:sub(index, index) == ']'
	return index + 1
end

--- @author DemiAutomatic
--- @method wellFormed
--- @description Whether a Lua pattern would never raise a malformed pattern error.
--- @param pattern {string}
--- @returns {boolean}
local function wellFormed(pattern)
	local size = #pattern
	local index = pattern:sub(1, 1) == '^' and 2 or 1
	local level, open, closed = 0, {}, {}
	while index <= size do
		local character = pattern:sub(index, index)
		if character == '(' then
			level = level + 1
			if level > MAX_CAPTURES then return false end
			if pattern:sub(index + 1, index + 1) == ')' then
				closed[level] = true
				index = index + 2
			else
				open[#open + 1] = level
				index = index + 1
			end
		elseif character == ')' then
			if #open == 0 then return false end
			closed[open[#open]] = true
			open[#open] = nil
			index = index + 1
		elseif character == '%' then
			local class = pattern:sub(index + 1, index + 1)
			if class == '' then return false end
			if class == 'b' then
				if index + 3 > size then return false end
				index = index + 4
			elseif class == 'f' then
				if pattern:sub(index + 2, index + 2) ~= '[' then return false end
				index = classEnd(pattern, index + 3, size)
				if index == nil then return false end
			elseif class:find('%d') then
				if not closed[tonumber(class)] then return false end
				index = index + 2
			else
				index = index + 2
			end
		elseif character == '[' then
			index = classEnd(pattern, index + 1, size)
			if index == nil then return false end
		else
			index = index + 1
		end
	end
	return #open == 0
end

--- @author DemiAutomatic
--- @method anchored
--- @description Anchors a caller's pattern at both ends so it matches whole text.
--- @param pattern {string}
--- @returns {string}
local function anchored(pattern)
	if pattern:sub(1, 1) ~= '^' then pattern = '^' .. pattern end
	local escapes = pattern:match('(%%*)%$$')
	if escapes == nil or #escapes % 2 == 1 then pattern = pattern .. '$' end
	return pattern
end

--- @author DemiAutomatic
--- @method normalizeTyped
--- @description Validates what a text field carries beyond the common fields.
--- @param field {InputField}
--- @returns {table|nil, string|nil}
local function normalizeTyped(field)
	local maxLength = DEFAULT_TEXT
	if field.maxLength ~= nil then
		if not finite(field.maxLength) or field.maxLength % 1 ~= 0 then
			return nil, 'invalid_max_length'
		end
		maxLength = math.floor(field.maxLength)
		if maxLength < 1 or maxLength > MAX_TEXT then return nil, 'invalid_max_length' end
	end

	local placeholder
	if field.placeholder ~= nil then
		placeholder = displayText(field.placeholder, MAX_PLACEHOLDER)
		if placeholder == nil then return nil, 'invalid_placeholder' end
	end

	local charset
	if field.charset ~= nil then
		if type(field.charset) ~= 'string' then return nil, 'invalid_charset' end
		charset = CHARSETS[field.charset]
		if charset == nil then return nil, 'unknown_charset' end
	end

	local pattern
	if field.pattern ~= nil then
		local given = field.pattern
		if type(given) ~= 'string' or #given == 0 or #given > MAX_PATTERN then
			return nil, 'invalid_pattern'
		end
		if not wellFormed(given) then return nil, 'invalid_pattern' end
		pattern = anchored(given)
	end

	local text = ''
	if field.value ~= nil then
		text = displayText(field.value, maxLength)
		if text == nil then return nil, 'invalid_value' end
	end

	return {
		text = text,
		placeholder = placeholder,
		maxLength = maxLength,
		pattern = pattern,
		charset = charset,
		required = field.required == true or nil,
	}
end

--- @author DemiAutomatic
--- @method normalizeField
--- @description Validates one field, deriving its kind from its shape.
--- @param field {InputField}
--- @param index {integer}
--- @returns {InputEntry|nil, string|nil}
local function normalizeField(field, index)
	if type(field) ~= 'table' then return nil, 'field_must_be_a_table' end

	local id = field.id
	if id == nil then
		id = 'field_' .. tostring(index)
	elseif not validName(id, 64) then
		return nil, 'invalid_field_id'
	end

	local label = displayText(field.label, MAX_LABEL)
	if label == nil or label == '' then return nil, 'invalid_field_label' end

	local description
	if field.description ~= nil then
		description = displayText(field.description, MAX_DESCRIPTION)
		if description == nil then return nil, 'invalid_field_description' end
	end

	local entry = { id = id, label = label, description = description }

	if field.options ~= nil then
		local choice, reason = normalizeOptions(field)
		if choice == nil then return nil, reason end
		entry.kind = 'choice'
		entry.options = choice.options
		entry.selected = choice.selected
		return entry
	end

	if field.slider ~= nil then
		local slider, reason = normalizeSlider(field.slider)
		if slider == nil then return nil, reason end
		entry.kind = 'slider'
		entry.slider = slider
		return entry
	end

	local typed, reason = normalizeTyped(field)
	if typed == nil then return nil, reason end
	entry.kind = 'text'
	entry.text = typed.text
	entry.placeholder = typed.placeholder
	entry.maxLength = typed.maxLength
	entry.pattern = typed.pattern
	entry.charset = typed.charset
	entry.required = typed.required
	if not withinCharset(entry, entry.text) then return nil, 'invalid_value' end
	if not matchesPattern(entry, entry.text) then return nil, 'invalid_value' end
	return entry
end

--- @author DemiAutomatic
--- @method normalizeFields
--- @description Validates every field of a spec, refusing duplicate ids.
--- @param fields {InputField[]}
--- @returns {InputEntry[]|nil, string|nil}
local function normalizeFields(fields)
	if type(fields) ~= 'table' then return nil, 'fields_must_be_a_table' end
	local total = #fields
	if total == 0 then return nil, 'empty_form' end
	if total > MAX_FIELDS then return nil, 'too_many_fields' end

	local list, seen = {}, {}
	for index = 1, total do
		local entry, reason = normalizeField(fields[index], index)
		if entry == nil then return nil, reason end
		if seen[entry.id] then return nil, 'duplicate_field_id' end
		seen[entry.id] = true
		list[index] = entry
	end
	return list
end

--- @author DemiAutomatic
--- @method cursorIndex
--- @description Resolves the first focused field, falling back to field one.
--- @param fields {InputEntry[]}
--- @param wanted {InputCursor|nil}
--- @returns {integer}
local function cursorIndex(fields, wanted)
	if type(wanted) == 'string' then
		for index = 1, #fields do
			if fields[index].id == wanted then return index end
		end
	elseif type(wanted) == 'number' and wanted % 1 == 0 then
		local index = math.floor(wanted)
		if fields[index] ~= nil then return index end
	end
	return 1
end

--- @author DemiAutomatic
--- @method OpxInput.Model.Build
--- @description Builds a form record from a spec, whole or not at all.
--- @param owner {string}
--- @param generation {integer}
--- @param spec {InputSpec}
--- @returns {InputRecord|nil, string|nil}
function OpxInput.Model.Build(owner, generation, spec)
	local id = spec.id
	if id == nil then
		id = owner
	elseif not validName(id, 64) then
		return nil, 'invalid_form_id'
	end

	local title = displayText(spec.title, MAX_LABEL)
	if title == nil or title == '' then title = owner:upper() end

	local description
	if spec.description ~= nil then
		description = displayText(spec.description, MAX_DESCRIPTION)
		if description == nil then return nil, 'invalid_description' end
	end

	if spec.event ~= nil and not validName(spec.event, 96) then
		return nil, 'invalid_event'
	end

	if spec.status ~= nil and Model.StatusText(spec.status) == nil then
		return nil, 'invalid_status'
	end

	if spec.data ~= nil then
		if type(spec.data) ~= 'table' then return nil, 'invalid_form_data' end
		if not fitsInPayload(spec.data, 1, { data = 0 }) then return nil, 'form_data_too_large' end
	end

	local fields, reason = normalizeFields(spec.fields)
	if fields == nil then return nil, reason end

	return {
		owner = owner,
		generation = generation,
		id = id,
		title = title,
		description = description,
		event = spec.event,
		data = spec.data,
		fields = fields,
		index = cursorIndex(fields, spec.cursor),
	}
end

--- @author DemiAutomatic
--- @method OpxInput.Model.Entry
--- @description Answers the focused field of a form.
--- @param record {InputRecord}
--- @returns {InputEntry}
function OpxInput.Model.Entry(record)
	return record.fields[record.index]
end

--- @author DemiAutomatic
--- @method OpxInput.Model.Move
--- @description Moves the focus between fields, wrapping at both ends.
--- @param record {InputRecord}
--- @param delta {integer}
--- @returns {boolean}
function OpxInput.Model.Move(record, delta)
	local total = #record.fields
	if total <= 1 then return false end
	record.index = ((record.index - 1 + delta) % total) + 1
	return true
end

--- @author DemiAutomatic
--- @method OpxInput.Model.Adjust
--- @description Cycles a choice or steps a slider, answering whether it changed.
--- @param entry {InputEntry}
--- @param delta {integer}
--- @returns {boolean}
function OpxInput.Model.Adjust(entry, delta)
	local kind = entry.kind
	if kind == 'choice' then
		local total = #entry.options
		if total <= 1 then return false end
		entry.selected = ((entry.selected - 1 + delta) % total) + 1
		return true
	elseif kind == 'slider' then
		local slider = entry.slider
		local before = slider.value
		local value = slider.value + (slider.step * delta)
		if value < slider.min then value = slider.min end
		if value > slider.max then value = slider.max end
		local steps = math.floor(((value - slider.min) / slider.step) + 0.5)
		value = slider.min + (steps * slider.step)
		if value > slider.max then value = slider.max end
		slider.value = value
		return value ~= before
	end
	return false
end

--- @author DemiAutomatic
--- @method OpxInput.Model.Edit
--- @description Accepts or refuses a candidate text buffer reported by the page.
--- @param entry {InputEntry}
--- @param text {any}
--- @returns {boolean, string|nil, table|nil}
function OpxInput.Model.Edit(entry, text)
	if entry.kind ~= 'text' then return false end
	if type(text) ~= 'string' then return false end
	local clean = text:gsub('%c', '')
	if Text.Span(clean, entry.maxLength) < #clean then
		return false, 'input.refuse.tooLong', { max = entry.maxLength }
	end
	if not withinCharset(entry, clean) then
		return false, 'input.refuse.character'
	end
	local moved = clean ~= entry.text
	entry.text = clean
	return moved or clean ~= text
end

--- @author DemiAutomatic
--- @method OpxInput.Model.Check
--- @description Finds the first field that refuses to be submitted.
--- @param record {InputRecord}
--- @returns {integer|nil, string|nil}
function OpxInput.Model.Check(record)
	for index = 1, #record.fields do
		local entry = record.fields[index]
		if entry.kind == 'text' then
			if entry.required and entry.text == '' then
				return index, 'input.refuse.required'
			end
			if not matchesPattern(entry, entry.text) then
				return index, 'input.refuse.format'
			end
		end
	end
	return nil
end

--- @author DemiAutomatic
--- @method rawValue
--- @description The machine-readable value one field answers with.
--- @param entry {InputEntry}
--- @returns {string|number}
local function rawValue(entry)
	local kind = entry.kind
	if kind == 'choice' then return entry.options[entry.selected].value end
	if kind == 'slider' then return entry.slider.value end
	return entry.text
end

--- @author DemiAutomatic
--- @method renderedValue
--- @description The rendered value of one field, for the page.
--- @param entry {InputEntry}
--- @returns {string}
local function renderedValue(entry)
	local kind = entry.kind
	if kind == 'choice' then return entry.options[entry.selected].label end
	if kind == 'slider' then
		local slider = entry.slider
		local number = slider.value
		local text = number % 1 == 0 and tostring(math.floor(number))
			or string.format('%.2f', number)
		return text .. slider.suffix
	end
	return entry.text
end

--- @author DemiAutomatic
--- @method answers
--- @description Every field's answer, keyed by field id.
--- @param record {InputRecord}
--- @returns {table<string, string|number>}
local function answers(record)
	local values = {}
	for index = 1, #record.fields do
		local entry = record.fields[index]
		values[entry.id] = rawValue(entry)
	end
	return values
end

--- @author DemiAutomatic
--- @method keyHint
--- @description Builds the translated key line for the focused field.
--- @param record {InputRecord}
--- @returns {string}
local function keyHint(record)
	local entry = record.fields[record.index]
	local parts = {}
	if #record.fields > 1 then parts[#parts + 1] = locale('input.hint.move') end
	parts[#parts + 1] = entry.kind == 'text'
		and locale('input.hint.edit') or locale('input.hint.spin')
	parts[#parts + 1] = locale('input.hint.confirm')
	parts[#parts + 1] = locale('input.hint.cancel')
	return table.concat(parts, '  ·  ')
end

--- @author DemiAutomatic
--- @method OpxInput.Model.View
--- @description Builds everything the page needs to draw one frame.
--- @param record {InputRecord}
--- @returns {InputView}
function OpxInput.Model.View(record)
	local rows = {}
	for index = 1, #record.fields do
		local entry = record.fields[index]
		local kind = entry.kind
		local row = {
			id = entry.id,
			kind = kind,
			label = entry.label,
			spin = (kind ~= 'text') or nil,
			on = (index == record.index) or nil,
		}
		if kind == 'text' then
			row.text = entry.text
			row.placeholder = entry.placeholder
			row.max = entry.maxLength
		else
			row.value = renderedValue(entry)
		end
		if kind == 'slider' then
			local slider = entry.slider
			row.fill = (slider.value - slider.min) / (slider.max - slider.min)
		end
		rows[index] = row
	end

	local focused = record.fields[record.index]
	return {
		title = record.title,
		note = record.description,
		rows = rows,
		hint = focused.description,
		keys = keyHint(record),
		status = record.status and record.status.text or nil,
		statusBad = record.status ~= nil and not record.status.ok or nil,
	}
end

--- @author DemiAutomatic
--- @method OpxInput.Model.Payload
--- @description Builds the one payload a form answers with.
--- @param record {InputRecord}
--- @param action {InputAction}
--- @returns {InputPayload}
function OpxInput.Model.Payload(record, action)
	return {
		form = record.id,
		handle = record.handle,
		owner = record.owner,
		action = action,
		data = record.data,
		values = action == 'submit' and answers(record) or nil,
	}
end
