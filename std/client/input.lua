---@meta

OpxInput.Input = {}

--- Resolves the host's `Open77.input.isCaptured` once, at resource start, and probes it.
--- A reader that is missing, raises or answers a refusal is dropped, and the note says why.
---@return boolean readable
---@return string|nil note why the keyboard cannot be read, for client/main.lua to log
function OpxInput.Input.Attach() end

--- Whether another surface holds the keyboard (chat's composer, the pause menu, a panel).
--- False when the reader could not be attached. Asked only while no form is open.
---@return boolean
function OpxInput.Input.Captured() end

--- Takes the keyboard for the page. Only an explicit `false` from the host is a refusal.
---@param surface table|nil the WebUI page
---@return boolean taken
---@return string|nil note the host's answer when it was not a plain true
function OpxInput.Input.Grab(surface) end

--- Hands the keyboard back. Safe where it was never taken.
---@param surface table|nil the WebUI page
function OpxInput.Input.Release(surface) end

--- What one key name reported by the page means here: up, down, left, right, submit or
--- cancel. Nil for a name the page may not send.
---@param key any
---@return string|nil
function OpxInput.Input.Action(key) end
