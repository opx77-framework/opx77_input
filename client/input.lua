--- The keyboard: who holds it, and taking it for exactly as long as a form is open.

OpxInput = OpxInput or {}

local Input = {}
OpxInput.input = Input

--- Resolved once by `Input.attach`.
local isCaptured = nil

--- True while this resource holds the keyboard, so releasing it is never a guess.
local held = false

--- The key names the page may report, and what each one means here. A name outside this
--- table is dropped: the page reports keystrokes, it does not decide.
local ACTIONS = {
  up = "up", down = "down", left = "left", right = "right",
  enter = "submit", escape = "cancel",
}

---@return table|nil
local function api()
  return type(Open77) == "table" and type(Open77.input) == "table" and Open77.input or nil
end

--- Resolve the host's keyboard reader once, at resource start.
---@return boolean readable
---@return string|nil note  why it could not be read, for main.lua to log
function Input.attach()
  local input = api()
  isCaptured = input ~= nil and type(input.isCaptured) == "function" and input.isCaptured or nil
  if isCaptured == nil then
    return false, "no_is_captured -- the manifest must grant input.actions"
  end
  -- `isCaptured` answers `false, "permission_denied:..."` rather than raising, but a raise
  -- here would abandon the resource start that calls this, before the surface is created.
  local probed, answer, refusal = pcall(isCaptured)
  if not probed then
    isCaptured = nil
    return false, tostring(answer)
  end
  if refusal ~= nil then
    isCaptured = nil
    return false, tostring(refusal)
  end
  return true
end

--- Does somebody else own the keyboard -- chat's composer, the pause menu, a panel.
--- False while this resource holds it: then the surface asking is the one that took it.
---@return boolean
function Input.captured()
  if held or isCaptured == nil then return false end
  local ok, answer = pcall(isCaptured)
  return ok and answer == true
end

--- Take the keyboard for the page.
---@param surface table|nil
---@return boolean taken
---@return string|nil note  the host's answer when it was not a plain `true`
function Input.grab(surface)
  if held then return true end
  if surface == nil then return false, "no_surface" end
  local ok, answer = pcall(surface.setFocus, surface, true, false)
  if not ok then return false, tostring(answer) end
  -- Only an explicit `false` is a refusal: a host that answers nothing still focused.
  if answer == false then return false, "refused" end
  held = true
  if answer ~= true then return true, tostring(answer) end
  return true
end

--- Hand the keyboard back. Safe where it was never taken, and on the way out of a resource
--- stop, which is the one path that must never leave a player unable to move.
---@param surface table|nil
function Input.release(surface)
  held = false
  if surface == nil then return end
  pcall(surface.setFocus, surface, false, false)
end

--- What one key name from the page means here, or nil for a name it may not send.
---@param key any
---@return string|nil
function Input.action(key)
  if type(key) ~= "string" then return nil end
  return ACTIONS[key]
end
