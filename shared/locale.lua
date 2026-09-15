--- @author DemiAutomatic
--- @file shared/locale.lua
--- @description Locale catalogues, lookup with fallback and the global locale shorthand.

--- @author DemiAutomatic
--- @type {table<string, table<string, string>>}
--- @description Registered catalogues, keyed by language code then key.
local catalogs = {}

--- @author DemiAutomatic
--- @type {string}
--- @description The language player-facing text is currently read from.
local active = 'en'

--- @author DemiAutomatic
--- @type {string}
--- @description The language every lookup falls back to.
local FALLBACK = 'en'

OpxInput.Locale = {}
local Locale = OpxInput.Locale

--- @author DemiAutomatic
--- @method interpolate
--- @description Fills named placeholders, leaving placeholders without a value as written.
--- @param text {string}
--- @param params {table<string, string|number>|nil}
--- @returns {string}
local function interpolate(text, params)
	if not params then return text end
	return (text:gsub('{(%w+)}', function(name)
		local value = params[name]
		return value ~= nil and tostring(value) or ('{' .. name .. '}')
	end))
end

--- @author DemiAutomatic
--- @method OpxInput.Locale.register
--- @description Merges a language's strings into its catalogue.
--- @param code {string}
--- @param strings {table<string, string>}
function OpxInput.Locale.register(code, strings)
	local catalog = catalogs[code]
	if not catalog then
		catalog = {}
		catalogs[code] = catalog
	end
	for key, text in pairs(strings) do catalog[key] = text end
end

--- @author DemiAutomatic
--- @method OpxInput.Locale.Set
--- @description Selects the catalogue player-facing text is read from.
--- @param code {string}
--- @returns {boolean}
function OpxInput.Locale.Set(code)
	if type(code) ~= 'string' or code == '' then return false end
	active = code
	return true
end

--- @author DemiAutomatic
--- @method OpxInput.Locale.Get
--- @description Resolves a key through the active catalogue, the fallback, then itself.
--- @param key {string}
--- @param params {table<string, string|number>|nil}
--- @returns {string}
function OpxInput.Locale.Get(key, params)
	local catalog = catalogs[active]
	local text = (catalog and catalog[key])
		or (catalogs[FALLBACK] and catalogs[FALLBACK][key])
		or key
	return interpolate(text, params)
end

--- @author DemiAutomatic
--- @type {fun(key: string, params: table|nil): string}
--- @description Global shorthand every file below the catalogues calls.
locale = Locale.Get

Locale.Set(OPX_INPUT_CONFIG and OPX_INPUT_CONFIG.LOCALE)
