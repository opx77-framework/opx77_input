--- @author DemiAutomatic
--- @file client/input.lua
--- @description The keyboard: who holds it, taken only while a form is open.

OpxInput.Input = {}

--- @author DemiAutomatic
--- @type {function|nil}
--- @description The host's keyboard reader, resolved once by OpxInput.Input.Attach.
local isCaptured = nil

--- @author DemiAutomatic
--- @type {boolean}
--- @description Whether this resource currently holds the keyboard.
local held = false

--- @author DemiAutomatic
--- @type {table<string, string>}
--- @description Key names the page may report, and the action each means.
local ACTIONS = {
	up = 'up', down = 'down', left = 'left', right = 'right',
	enter = 'submit', escape = 'cancel',
}

--- @author DemiAutomatic
--- @method OpxInput.Input.Attach
--- @description Resolves and probes the host's keyboard reader at resource start.
--- @returns {boolean, string|nil}
function OpxInput.Input.Attach()
	local input = Open77.input
	isCaptured = type(input) == 'table' and type(input.isCaptured) == 'function' and input.isCaptured or nil
	if isCaptured == nil then
		return false, 'no_is_captured -- the manifest must grant input.actions'
	end
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

--- @author DemiAutomatic
--- @method OpxInput.Input.Captured
--- @description Whether another surface holds the keyboard right now.
--- @returns {boolean}
function OpxInput.Input.Captured()
	if held or isCaptured == nil then return false end
	local ok, answer = pcall(isCaptured)
	return ok and answer == true
end

--- @author DemiAutomatic
--- @method OpxInput.Input.Grab
--- @description Takes the keyboard for the page, answering the host's note.
--- @param surface {table|nil}
--- @returns {boolean, string|nil}
function OpxInput.Input.Grab(surface)
	if held then return true end
	if surface == nil then return false, 'no_surface' end
	local ok, answer = pcall(surface.setFocus, surface, true, false)
	if not ok then return false, tostring(answer) end
	if answer == false then return false, 'refused' end
	held = true
	if answer ~= true then return true, tostring(answer) end
	return true
end

--- @author DemiAutomatic
--- @method OpxInput.Input.Release
--- @description Hands the keyboard back, safe where it was never taken.
--- @param surface {table|nil}
function OpxInput.Input.Release(surface)
	held = false
	if surface == nil then return end
	pcall(surface.setFocus, surface, false, false)
end

--- @author DemiAutomatic
--- @method OpxInput.Input.Action
--- @description Maps one key name from the page to its action.
--- @param key {any}
--- @returns {string|nil}
function OpxInput.Input.Action(key)
	if type(key) ~= 'string' then return nil end
	return ACTIONS[key]
end
