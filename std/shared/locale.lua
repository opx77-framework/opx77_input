---@meta

OpxInput.Locale = {}

--- Merges a language's strings into its catalogue. Later registrations of the same key win.
--- Operators' own `locales/<code>.lua` files call it, so the name stays lowercase.
---@param code string a language code such as "en"
---@param strings table<string, string> key -> text, with {placeholders}
function OpxInput.Locale.register(code, strings) end

--- Selects the catalogue player-facing text is read from. An unknown code is accepted and
--- falls back to en, because catalogues register after the locale module loads.
---@param code string
---@return boolean applied
function OpxInput.Locale.Set(code) end

--- Resolves a key through the active catalogue, then en, then the key itself. Never nil.
--- A placeholder without a value in `params` is left as written.
---@param key string
---@param params? table<string, string|number>
---@return string
function OpxInput.Locale.Get(key, params) end

--- The shorthand every file below the catalogues calls.
---@type fun(key: string, params?: table<string, string|number>): string
locale = OpxInput.Locale.Get
