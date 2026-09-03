--- The public export surface. Every call answers an InputResponse and never raises; `error`
--- is one of the codes in types.lua. Client-side only: called from a caller's client half.

local Runtime = OpxInput.runtime
local Model = OpxInput.model

---@param ok boolean
---@param values table|nil
---@return InputResponse
local function response(ok, values)
  values = values or {}
  values.ok = ok == true
  return values
end

--- Who is calling, and at which generation of their code, both from the host.
---@return string|nil owner
---@return string|integer generation  the refusal reason when owner is nil
local function caller()
  local owner = GetInvokingResource()
  local generation = GetInvokingResourceGeneration()
  if not Model.validName(owner, 64) or type(generation) ~= "number" then
    return nil, "export_call_required"
  end
  return owner, generation
end

--- Refuse everything when the WebUI surface never came up.
---@return InputResponse|nil
local function unavailable()
  if Runtime.unavailable and Runtime.unavailable() then
    return response(false, { error = "no_surface" })
  end
  return nil
end

--- Refuse unless the open form belongs to the caller.
---@param owner string
---@return InputResponse|nil
local function notMine(owner)
  if Runtime.owner() == nil then return response(false, { error = "no_form_open" }) end
  if Runtime.owner() ~= owner then return response(false, { error = "not_owner" }) end
  return nil
end

--- Ask the player for one or more values. Refused whole if any field is malformed;
--- `error` names why. The answer arrives on `spec.event`, and on `opx77:input` beside it.
---@param spec InputSpec
---@return InputOpened  `error` is "input_busy" when another resource owns the open form
exports("open", function(spec)
  local gone = unavailable()
  if gone then return gone end
  local owner, generation = caller()
  if not owner then return response(false, { error = generation }) end
  if type(spec) ~= "table" then return response(false, { error = "spec_must_be_a_table" }) end

  local record, reason = Runtime.open(owner, generation, spec)
  if record == nil then return response(false, { error = reason }) end
  return response(true, {
    handle = record.handle,
    id = record.id,
    fields = #record.fields,
  })
end)

--- Take your own form back down. A caller may not close another resource's, and the form
--- still answers: `action` is "cancel", `reason` is "caller".
---@param handle InputHandle|nil
---@return InputResponse  "not_owner" unless the open form belongs to the caller
exports("close", function(handle)
  local gone = unavailable()
  if gone then return gone end
  local owner, generation = caller()
  if not owner then return response(false, { error = generation }) end
  local refused = notMine(owner)
  if refused then return refused end

  local ok, reason = Runtime.close(handle, "caller")
  if not ok then return response(false, { error = reason }) end
  return response(true, {})
end)

--- Whether a form is open and whether it is yours. It reports where the player is, never
--- what they have typed: the answer is the event.
---@return InputState
exports("state", function()
  local owner = caller()
  local snapshot = Runtime.snapshot()
  local mine = owner ~= nil and snapshot.owner == owner

  if not mine then
    return response(true, { open = snapshot.open, mine = false })
  end

  snapshot.mine = true
  snapshot.ok = true
  return snapshot
end)

--- Write the transient line under the fields; `setStatus(nil)` clears it now.
---@param text string|nil  cleared automatically after six seconds
---@param ok boolean|nil  false marks a failure, which changes its colour
---@return InputResponse  "not_owner" unless the open form belongs to the caller
exports("setStatus", function(text, ok)
  local gone = unavailable()
  if gone then return gone end
  local owner, generation = caller()
  if not owner then return response(false, { error = generation }) end
  local refused = notMine(owner)
  if refused then return refused end
  if text ~= nil and Model.statusText(text) == nil then
    return response(false, { error = "invalid_status" })
  end
  Runtime.setStatus(text, ok)
  return response(true, {})
end)
