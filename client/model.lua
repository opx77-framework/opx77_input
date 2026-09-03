--- The model: the validated fields, the focused one, and the view.

OpxInput = OpxInput or {}

--- Mirrors `version` in open77.lua, which no Lua code can read; a release moves both lines.
OpxInput.VERSION = "0.1.0"

local Text = OpxInput.Text

local Model = {}
OpxInput.model = Model

--- How many fields one modal answers. More than this is a list, and a list is what
--- opx77_menu draws.
local MAX_FIELDS = 8

local MAX_OPTIONS = 64
local MAX_DATA_NODES = 64
local MAX_DATA_DEPTH = 4

local MAX_LABEL = 96
local MAX_OPTION_LABEL = 48
local MAX_OPTION_VALUE = 96
local MAX_PLACEHOLDER = 64
local MAX_DESCRIPTION = 160
local MAX_SUFFIX = 8
local MAX_STATUS = 120

--- A text field's default and hardest length, in characters. The whole answer rides in
--- one event payload, so the ceiling is a payload bound rather than a taste.
local DEFAULT_TEXT = 96
local MAX_TEXT = 512

--- A caller's Lua pattern is run against every keystroke's worth of text, so its own
--- length is bounded too.
local MAX_PATTERN = 64

--- The character classes a text field may name. A caller cannot pass a class of its own:
--- an unbalanced one raises inside `string.match`, and a slow one runs on the tick.
local CHARSETS = {
  alnum = "^[%w]+$",
  alpha = "^[%a]+$",
  digits = "^[%d]+$",
  hex = "^[%x]+$",
  name = "^[%w %-_%.']+$",
}

--- A finite number: not NaN, not an infinity.
---@param value any
---@return boolean
local function finite(value)
  -- `value == value` is the NaN test: NaN is the one value unequal to itself
  return type(value) == "number" and value == value
    and value > -math.huge and value < math.huge
end

---@param value any
---@param maximum integer
---@return boolean
local function validName(value, maximum)
  return type(value) == "string" and #value > 0 and #value <= maximum
    and value:match("^[%w_:%-%.]+$") ~= nil
end

--- Display text: control characters out, and refused rather than cut when it runs past
--- `maximum` characters.
---@param value any
---@param maximum integer
---@return string|nil
local function displayText(value, maximum)
  if type(value) == "number" then value = tostring(value) end
  if type(value) ~= "string" then return nil end
  value = value:gsub("%c", " ")
  -- `#value` counts bytes and `maximum` counts characters: fewer bytes needs no measuring
  if #value <= maximum then return value end
  if Text.span(value, maximum) >= #value then return value end
  return nil
end

--- The transient line's text, or nil for a value the line refuses. A table would
--- sanitise to nil and silently clear the line, so it is refused rather than cleaned.
---@param value any
---@return string|nil
function Model.statusText(value)
  return displayText(value, MAX_STATUS)
end

--- Resource-name validator, shared with client/exports.lua.
Model.validName = validName

--- Does this text sit inside the field's character class? An empty field always does:
--- emptiness is what `required` answers.
---@param entry InputEntry
---@param text string
---@return boolean
local function withinCharset(entry, text)
  if entry.charset == nil or text == "" then return true end
  local ok, matched = pcall(string.match, text, entry.charset)
  return ok and matched ~= nil
end

--- Does the whole text match the field's pattern? An empty field always does.
---@param entry InputEntry
---@param text string
---@return boolean
local function matchesPattern(entry, text)
  if entry.pattern == nil or text == "" then return true end
  local ok, matched = pcall(string.match, text, entry.pattern)
  return ok and matched ~= nil
end

--- Count a caller's opaque table, refusing rather than truncating.
---@param value any
---@param depth integer
---@param budget table
---@return boolean
local function fitsInPayload(value, depth, budget)
  budget.data = budget.data + 1
  if budget.data > MAX_DATA_NODES then return false end
  if type(value) ~= "table" then return true end
  if depth > MAX_DATA_DEPTH then return false end
  for key, nested in pairs(value) do
    if not fitsInPayload(key, depth + 1, budget) then return false end
    if not fitsInPayload(nested, depth + 1, budget) then return false end
  end
  return true
end

---@param slider InputSlider
---@return InputSlider|nil, string|nil
local function normalizeSlider(slider)
  if type(slider) ~= "table" then return nil, "invalid_slider" end
  local minimum = finite(slider.min) and slider.min + 0.0 or 0.0
  local maximum = finite(slider.max) and slider.max + 0.0 or 100.0
  if maximum <= minimum then return nil, "invalid_slider_range" end
  local step = finite(slider.step) and math.abs(slider.step) + 0.0 or 1.0
  if step <= 0 then step = 1.0 end
  local value = finite(slider.value) and slider.value + 0.0 or minimum
  if value < minimum then value = minimum end
  if value > maximum then value = maximum end
  local suffix = ""
  if slider.suffix ~= nil then
    suffix = displayText(slider.suffix, MAX_SUFFIX)
    if suffix == nil then return nil, "invalid_slider_suffix" end
  end
  return { min = minimum, max = maximum, step = step, value = value, suffix = suffix }
end

--- The value an option answers with. Kept exactly as the caller wrote it: it is the
--- caller's own datum coming back, not something a player reads.
---@param option table
---@param label string
---@return string|number|nil
local function optionValue(option, label)
  local value = option.value
  if value == nil then return label end
  if type(value) == "number" then
    return finite(value) and value or nil
  end
  if type(value) == "string" and displayText(value, MAX_OPTION_VALUE) ~= nil then
    return value
  end
  return nil
end

---@param field InputField
---@return table|nil, string|nil
local function normalizeOptions(field)
  local raw = field.options
  if type(raw) ~= "table" then return nil, "invalid_options" end
  local total = #raw
  if total == 0 then return nil, "empty_options" end
  if total > MAX_OPTIONS then return nil, "too_many_options" end

  local options = {}
  for index = 1, total do
    local option = raw[index]
    -- A bare string is the common case: the label is the value.
    if type(option) == "string" or type(option) == "number" then
      option = { label = option }
    end
    if type(option) ~= "table" then return nil, "invalid_option" end
    local label = displayText(option.label, MAX_OPTION_LABEL)
    if label == nil or label == "" then return nil, "invalid_option" end
    local value = optionValue(option, label)
    if value == nil then return nil, "invalid_option_value" end
    options[index] = { label = label, value = value }
  end

  local selected = 1
  if field.selected ~= nil then
    if not finite(field.selected) or field.selected % 1 ~= 0 then
      return nil, "invalid_selected"
    end
    selected = math.floor(field.selected)
    if selected < 1 or selected > total then return nil, "invalid_selected" end
  end
  return { options = options, selected = selected }
end

--- Everything a text field carries beyond the fields every kind has.
---@param field InputField
---@return table|nil, string|nil
local function normalizeTyped(field)
  local maxLength = DEFAULT_TEXT
  if field.maxLength ~= nil then
    if not finite(field.maxLength) or field.maxLength % 1 ~= 0 then
      return nil, "invalid_max_length"
    end
    maxLength = math.floor(field.maxLength)
    if maxLength < 1 or maxLength > MAX_TEXT then return nil, "invalid_max_length" end
  end

  local placeholder
  if field.placeholder ~= nil then
    placeholder = displayText(field.placeholder, MAX_PLACEHOLDER)
    if placeholder == nil then return nil, "invalid_placeholder" end
  end

  local charset
  if field.charset ~= nil then
    if type(field.charset) ~= "string" then return nil, "invalid_charset" end
    charset = CHARSETS[field.charset]
    if charset == nil then return nil, "unknown_charset" end
  end

  local pattern
  if field.pattern ~= nil then
    local given = field.pattern
    if type(given) ~= "string" or #given == 0 or #given > MAX_PATTERN then
      return nil, "invalid_pattern"
    end
    -- Compiled by trying it: a malformed class raises rather than answering nil.
    if not pcall(string.match, "", given) then return nil, "invalid_pattern" end
    pattern = given
  end

  local text = ""
  if field.value ~= nil then
    text = displayText(field.value, maxLength)
    if text == nil then return nil, "invalid_value" end
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

--- Normalise one field. The kind comes from the shape, never from a declaration.
---@param field InputField
---@param index integer
---@return InputEntry|nil, string|nil
local function normalizeField(field, index)
  if type(field) ~= "table" then return nil, "field_must_be_a_table" end

  local id = field.id
  if id == nil then
    id = "field_" .. tostring(index)
  elseif not validName(id, 64) then
    return nil, "invalid_field_id"
  end

  local label = displayText(field.label, MAX_LABEL)
  if label == nil or label == "" then return nil, "invalid_field_label" end

  local description
  if field.description ~= nil then
    description = displayText(field.description, MAX_DESCRIPTION)
    if description == nil then return nil, "invalid_field_description" end
  end

  local entry = { id = id, label = label, description = description }

  if field.options ~= nil then
    local choice, reason = normalizeOptions(field)
    if choice == nil then return nil, reason end
    entry.kind = "choice"
    entry.options = choice.options
    entry.selected = choice.selected
    return entry
  end

  if field.slider ~= nil then
    local slider, reason = normalizeSlider(field.slider)
    if slider == nil then return nil, reason end
    entry.kind = "slider"
    entry.slider = slider
    return entry
  end

  local typed, reason = normalizeTyped(field)
  if typed == nil then return nil, reason end
  entry.kind = "text"
  entry.text = typed.text
  entry.placeholder = typed.placeholder
  entry.maxLength = typed.maxLength
  entry.pattern = typed.pattern
  entry.charset = typed.charset
  entry.required = typed.required
  -- An initial value its own field would refuse is a caller's bug, not a player's.
  if not withinCharset(entry, entry.text) then return nil, "invalid_value" end
  if not matchesPattern(entry, entry.text) then return nil, "invalid_value" end
  return entry
end

---@param fields InputField[]
---@return InputEntry[]|nil, string|nil
local function normalizeFields(fields)
  if type(fields) ~= "table" then return nil, "fields_must_be_a_table" end
  local total = #fields
  if total == 0 then return nil, "empty_form" end
  if total > MAX_FIELDS then return nil, "too_many_fields" end

  local list, seen = {}, {}
  for index = 1, total do
    local entry, reason = normalizeField(fields[index], index)
    if entry == nil then return nil, reason end
    -- The answer is keyed by id, so two fields sharing one would lose an answer.
    if seen[entry.id] then return nil, "duplicate_field_id" end
    seen[entry.id] = true
    list[index] = entry
  end
  return list
end

--- Which field is focused first: the one a caller named, or the first.
---@param fields InputEntry[]
---@param wanted InputCursor|nil
---@return integer
local function cursorIndex(fields, wanted)
  if type(wanted) == "string" then
    for index = 1, #fields do
      if fields[index].id == wanted then return index end
    end
  elseif type(wanted) == "number" and wanted % 1 == 0 then
    local index = math.floor(wanted)
    if fields[index] ~= nil then return index end
  end
  return 1
end

--- Build a form from a caller's spec.
---@param owner string
---@param generation integer
---@param spec InputSpec
---@return InputRecord|nil, string|nil  the record, or nil and a reason
function Model.build(owner, generation, spec)
  if not validName(owner, 64) then return nil, "invalid_owner" end
  if type(spec) ~= "table" then return nil, "spec_must_be_a_table" end

  local id = spec.id
  if id == nil then
    id = owner
  elseif not validName(id, 64) then
    return nil, "invalid_form_id"
  end

  local title = displayText(spec.title, MAX_LABEL)
  if title == nil or title == "" then title = owner:upper() end

  local description
  if spec.description ~= nil then
    description = displayText(spec.description, MAX_DESCRIPTION)
    if description == nil then return nil, "invalid_description" end
  end

  if spec.event ~= nil and not validName(spec.event, 96) then
    return nil, "invalid_event"
  end

  if spec.status ~= nil and Model.statusText(spec.status) == nil then
    return nil, "invalid_status"
  end

  if spec.data ~= nil then
    if type(spec.data) ~= "table" then return nil, "invalid_form_data" end
    if not fitsInPayload(spec.data, 1, { data = 0 }) then return nil, "form_data_too_large" end
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

--- The focused field.
---@param record InputRecord
---@return InputEntry|nil
function Model.entry(record)
  return record.fields[record.index]
end

--- Move the focus between fields. Wraps.
---@param record InputRecord
---@param delta integer
---@return boolean  true when the focus moved
function Model.move(record, delta)
  local total = #record.fields
  if total <= 1 then return false end
  record.index = ((record.index - 1 + delta) % total) + 1
  return true
end

--- LEFT/RIGHT on a choice or a slider.
---@param entry InputEntry|nil
---@param delta integer
---@return boolean  true when something changed
function Model.adjust(entry, delta)
  if entry == nil then return false end
  local kind = entry.kind
  if kind == "choice" then
    local total = #entry.options
    if total <= 1 then return false end
    entry.selected = ((entry.selected - 1 + delta) % total) + 1
    return true
  elseif kind == "slider" then
    local slider = entry.slider
    local before = slider.value
    local value = slider.value + (slider.step * delta)
    -- Clamped, not wrapped: a volume that jumps from 0 to 100 is a complaint.
    if value < slider.min then value = slider.min end
    if value > slider.max then value = slider.max end
    -- Snapped to the grid: 0.1 added ten times is not 1.0.
    local steps = math.floor(((value - slider.min) / slider.step) + 0.5)
    value = slider.min + (steps * slider.step)
    if value > slider.max then value = slider.max end
    slider.value = value
    return value ~= before
  end
  return false
end

--- Take a candidate buffer from the page. Every limit refuses: the accepted buffer stays
--- as it was and the page is told to put it back.
---@param entry InputEntry|nil
---@param text any
---@return boolean redraw  the page is showing something other than the accepted buffer
---@return string|nil refusal  a locale key when a limit refused the candidate
---@return table|nil params
function Model.edit(entry, text)
  if entry == nil or entry.kind ~= "text" then return false end
  if type(text) ~= "string" then return false end
  local clean = text:gsub("%c", "")
  if Text.span(clean, entry.maxLength) < #clean then
    return false, "input.refuse.tooLong", { max = entry.maxLength }
  end
  if not withinCharset(entry, clean) then
    return false, "input.refuse.character"
  end
  local moved = clean ~= entry.text
  entry.text = clean
  -- Redrawn even where the accepted buffer did not move: the page is showing the raw
  -- keystrokes, which may have carried a control character.
  return moved or clean ~= text
end

--- The first field that refuses to be submitted, if any.
---@param record InputRecord
---@return integer|nil index
---@return string|nil refusal  a locale key
function Model.check(record)
  for index = 1, #record.fields do
    local entry = record.fields[index]
    if entry.kind == "text" then
      if entry.required and entry.text == "" then
        return index, "input.refuse.required"
      end
      if not matchesPattern(entry, entry.text) then
        return index, "input.refuse.format"
      end
    end
  end
  return nil
end

--- The machine-readable value of one field, for the answer.
---@param entry InputEntry
---@return string|number
function Model.raw(entry)
  local kind = entry.kind
  if kind == "choice" then return entry.options[entry.selected].value end
  if kind == "slider" then return entry.slider.value end
  return entry.text
end

--- The rendered value of one field, for the page.
---@param entry InputEntry
---@return string
function Model.value(entry)
  local kind = entry.kind
  if kind == "choice" then return entry.options[entry.selected].label end
  if kind == "slider" then
    local slider = entry.slider
    local number = slider.value
    -- Whole values print without a decimal: "VOLUME 70.0%" reads as a bug.
    local text = number % 1 == 0 and tostring(math.floor(number))
      or string.format("%.2f", number)
    return text .. slider.suffix
  end
  return entry.text
end

--- Every answer, keyed by field id.
---@param record InputRecord
---@return table<string, string|number>
function Model.values(record)
  local values = {}
  for index = 1, #record.fields do
    local entry = record.fields[index]
    values[entry.id] = Model.raw(entry)
  end
  return values
end

--- The key line under the fields, in the configured language.
---@param record InputRecord
---@return string
local function keyHint(record)
  local entry = record.fields[record.index]
  local parts = {}
  if #record.fields > 1 then parts[#parts + 1] = locale("input.hint.move") end
  if entry ~= nil then
    parts[#parts + 1] = entry.kind == "text"
      and locale("input.hint.edit") or locale("input.hint.spin")
  end
  parts[#parts + 1] = locale("input.hint.confirm")
  parts[#parts + 1] = locale("input.hint.cancel")
  return table.concat(parts, "  ·  ")
end

--- Everything the page needs for one frame.
---@param record InputRecord
---@return InputView
function Model.view(record)
  local rows = {}
  for index = 1, #record.fields do
    local entry = record.fields[index]
    local kind = entry.kind
    local row = {
      id = entry.id,
      kind = kind,
      label = entry.label,
      -- nil rather than false: an absent field costs no value node.
      spin = (kind ~= "text") or nil,
      on = (index == record.index) or nil,
    }
    if kind == "text" then
      row.text = entry.text
      row.placeholder = entry.placeholder
      row.max = entry.maxLength
    else
      row.value = Model.value(entry)
    end
    if kind == "slider" then
      local slider = entry.slider
      -- The range is non-empty: normalizeSlider refuses `max <= min`.
      row.fill = (slider.value - slider.min) / (slider.max - slider.min)
    end
    rows[index] = row
  end

  local focused = record.fields[record.index]
  return {
    title = record.title,
    note = record.description,
    rows = rows,
    hint = focused and focused.description or nil,
    keys = keyHint(record),
    -- Only the failure flag crosses: `a and a.ok or nil` would collapse a false.
    status = record.status and record.status.text or nil,
    statusBad = record.status ~= nil and not record.status.ok or nil,
  }
end

--- The one payload a form answers with.
---@param record InputRecord
---@param action InputAction
---@return InputPayload
function Model.payload(record, action)
  return {
    form = record.id,
    handle = record.handle,
    owner = record.owner,
    action = action,
    data = record.data,
    values = action == "submit" and Model.values(record) or nil,
  }
end
