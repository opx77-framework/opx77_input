--- @author DemiAutomatic
--- @file client/exports.lua
--- @description The four client exports, each answering an InputResponse.

local Runtime = OpxInput.Runtime
local Model = OpxInput.Model

--- @author DemiAutomatic
--- @method response
--- @description Stamps the ok flag on an answer table.
--- @param ok {boolean}
--- @param values {table}
--- @returns {InputResponse}
local function response(ok, values)
	values.ok = ok
	return values
end

--- @author DemiAutomatic
--- @method caller
--- @description Reads the invoking resource and its generation from the host.
--- @returns {string|nil, string|integer}
local function caller()
	local owner = GetInvokingResource()
	local generation = GetInvokingResourceGeneration()
	if not Model.ValidName(owner, 64) or type(generation) ~= 'number' then
		return nil, 'export_call_required'
	end
	return owner, generation
end

--- @author DemiAutomatic
--- @method unavailable
--- @description Refuses every call when the WebUI surface never came up.
--- @returns {InputResponse|nil}
local function unavailable()
	if Runtime.Unavailable() then
		return response(false, { error = 'no_surface' })
	end
	return nil
end

--- @author DemiAutomatic
--- @method notMine
--- @description Refuses unless the open form belongs to the caller.
--- @param owner {string}
--- @returns {InputResponse|nil}
local function notMine(owner)
	local current = Runtime.Owner()
	if current == nil then return response(false, { error = 'no_form_open' }) end
	if current ~= owner then return response(false, { error = 'not_owner' }) end
	return nil
end

--- @author DemiAutomatic
--- @export open
--- @description Asks the player for one or more values in one form.
--- @param spec {InputSpec}
--- @returns {InputOpened}
exports('open', function(spec)
	local gone = unavailable()
	if gone then return gone end
	local owner, generation = caller()
	if not owner then return response(false, { error = generation }) end
	if type(spec) ~= 'table' then return response(false, { error = 'spec_must_be_a_table' }) end

	local record, reason = Runtime.Open(owner, generation, spec)
	if record == nil then return response(false, { error = reason }) end
	return response(true, {
		handle = record.handle,
		id = record.id,
		fields = #record.fields,
	})
end)

--- @author DemiAutomatic
--- @export close
--- @description Takes the caller's own form down, answering it as cancelled.
--- @param handle {InputHandle|nil}
--- @returns {InputResponse}
exports('close', function(handle)
	local gone = unavailable()
	if gone then return gone end
	local owner, generation = caller()
	if not owner then return response(false, { error = generation }) end
	local refused = notMine(owner)
	if refused then return refused end

	local ok, reason = Runtime.Close(handle, 'caller')
	if not ok then return response(false, { error = reason }) end
	return response(true, {})
end)

--- @author DemiAutomatic
--- @export state
--- @description Reports whether a form is open and whether it is the caller's.
--- @returns {InputState}
exports('state', function()
	local owner = caller()
	local snapshot = Runtime.Snapshot()
	local mine = owner ~= nil and snapshot.owner == owner

	if not mine then
		return response(true, { open = snapshot.open, mine = false })
	end

	snapshot.mine = true
	snapshot.ok = true
	return snapshot
end)

--- @author DemiAutomatic
--- @export setStatus
--- @description Writes or clears the transient line under the caller's fields.
--- @param text {string|nil}
--- @param ok {boolean|nil} False marks a failure.
--- @returns {InputResponse}
exports('setStatus', function(text, ok)
	local gone = unavailable()
	if gone then return gone end
	local owner, generation = caller()
	if not owner then return response(false, { error = generation }) end
	local refused = notMine(owner)
	if refused then return refused end
	if text ~= nil and Model.StatusText(text) == nil then
		return response(false, { error = 'invalid_status' })
	end
	Runtime.SetStatus(text, ok)
	return response(true, {})
end)
