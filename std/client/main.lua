---@meta

OpxInput.Runtime = {}

--- Cancels the open form, which still answers with `action = "cancel"` and `reason`.
---@param handle InputHandle|nil nil closes whatever form is open
---@param reason string|nil the cancel reason carried by the answer
---@return boolean closed
---@return string|InputHandle|nil result the closed handle, or `no_form_open` / `not_open`
function OpxInput.Runtime.Close(handle, reason) end

--- Writes, or clears with nil or an empty string, the transient line under the fields.
--- Answers false only when no form is open.
---@param text string|nil
---@param ok boolean|nil false marks a failure; default true
---@return boolean
function OpxInput.Runtime.SetStatus(text, ok) end

--- Opens a form for `owner`. A caller may replace its own open form, which answers with
--- `reason = "reopened"`; it may never replace another resource's.
---@param owner string the invoking resource
---@param generation integer the invoking resource's generation
---@param spec InputSpec
---@return InputRecord|nil record
---@return string|nil error input_busy, keyboard_busy, no_keyboard or a spec validation code
function OpxInput.Runtime.Open(owner, generation, spec) end

--- Where the player is in the open form, or `{ open = false }`. Never what they typed.
---@return InputState
function OpxInput.Runtime.Snapshot() end

--- The resource that owns the open form, or nil.
---@return string|nil
function OpxInput.Runtime.Owner() end

--- Whether `WebUI.create` refused at the last start, in which case every export refuses.
---@return boolean
function OpxInput.Runtime.Unavailable() end
