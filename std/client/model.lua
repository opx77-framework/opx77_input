---@meta

OpxInput.Model = {}

--- The status line's text, or nil for a value the line refuses (not text, or longer than
--- 120 characters). A table is refused rather than cleaned into an empty line.
---@param value any
---@return string|nil
function OpxInput.Model.StatusText(value) end

--- Whether a value is a non-empty string of at most `maximum` bytes of `[%w_:%-%.]`. Used for
--- resource names, form and field ids and event names.
---@type fun(value: any, maximum: integer): boolean
OpxInput.Model.ValidName = nil

--- Validates a caller's spec and builds the form record, whole or not at all. The record has
--- no handle yet: OpxInput.Runtime.Open gives it one.
---@param owner string
---@param generation integer
---@param spec InputSpec
---@return InputRecord|nil record
---@return string|nil error the refusal code
function OpxInput.Model.Build(owner, generation, spec) end

--- The focused field.
---@param record InputRecord
---@return InputEntry|nil
function OpxInput.Model.Entry(record) end

--- Moves the focus between fields, wrapping at both ends.
---@param record InputRecord
---@param delta integer -1 for up, 1 for down
---@return boolean moved false on a single-field form
function OpxInput.Model.Move(record, delta) end

--- LEFT or RIGHT on a choice (wraps) or a slider (clamped, then snapped to its step grid).
---@param entry InputEntry|nil
---@param delta integer
---@return boolean changed
function OpxInput.Model.Adjust(entry, delta) end

--- Takes a candidate buffer from the page. Length and charset refuse: the accepted buffer
--- stays as it was and the page is redrawn from it.
---@param entry InputEntry|nil
---@param text any
---@return boolean redraw the page shows something other than the accepted buffer
---@return string|nil refusal a locale key
---@return table|nil params the refusal's placeholders
function OpxInput.Model.Edit(entry, text) end

--- The first text field that refuses to be submitted (required and empty, or not matching its
--- pattern), with the locale key saying why.
---@param record InputRecord
---@return integer|nil index
---@return string|nil refusal
function OpxInput.Model.Check(record) end

--- The machine-readable value of one field: an option's value, a slider's float, or the text.
---@param entry InputEntry
---@return string|number
function OpxInput.Model.Raw(entry) end

--- The rendered value of one field: an option's label, or a slider's number and suffix.
---@param entry InputEntry
---@return string
function OpxInput.Model.Value(entry) end

--- Every answer, keyed by field id.
---@param record InputRecord
---@return table<string, string|number>
function OpxInput.Model.Values(record) end

--- Everything the page needs for one frame, including the translated key line.
---@param record InputRecord
---@return InputView
function OpxInput.Model.View(record) end

--- The one payload a form answers with; `values` only on a submit.
---@param record InputRecord
---@param action InputAction
---@return InputPayload
function OpxInput.Model.Payload(record, action) end
