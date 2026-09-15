---@meta

OpxInput = {}

OpxInput.Text = {}

--- The byte length of the first `maximum` characters, or of the whole text when it is shorter.
--- Never more than `maximum * 4`, the widest a UTF-8 character can be, so a run of
--- continuation bytes cannot make the scan unbounded.
---@param text string
---@param maximum integer characters, not bytes
---@return integer
function OpxInput.Text.Span(text, maximum) end
