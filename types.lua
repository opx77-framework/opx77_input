---@meta
--- Type annotations for opx77_input. Never loaded at runtime.

---@alias InputHandle integer  unique for the life of the client session
---@alias InputAction "submit"|"cancel"
---@alias InputKind
---| "text"    a typed line
---| "choice"  one of an ordered list; LEFT/RIGHT cycle it
---| "slider"  a number with a step; LEFT/RIGHT step it

--- The characters a text field accepts. Anything outside the named set is refused as it
--- is typed, so an answer can never carry one.
---@alias InputCharset
---| "alnum"   letters and digits
---| "alpha"   letters
---| "digits"  digits
---| "hex"     hexadecimal digits
---| "name"    letters, digits, space, and - _ . '

--- Which field is focused first: a field `id`, or a 1-based index. Advisory -- an
--- unresolvable value falls back to the first field.
---@alias InputCursor string|integer

--- The table handed to the `open` export. Only `fields` is required.
---@class InputSpec
---@field fields InputField[]
---@field id string|nil          unique per owner; defaults to the owner name
---@field title string|nil       defaults to the owner name, upper-cased
---@field event string|nil       the event the answer is raised on
---@field data table|nil         opaque, echoed in the answer as `data`
---@field cursor InputCursor|nil which field is focused first
---@field description string|nil a sentence above the fields
---@field status string|nil      a line under the fields. Refused if not text

--- One field. The kind is derived from the shape, never declared: `options` makes a
--- choice, `slider` a slider, anything else a text field.
---@class InputField
---@field label string             required
---@field id string|nil            defaults to "field_<n>"
---@field description string|nil   shown under the fields while this one is focused
---@field value string|number|nil  text only, the initial value
---@field placeholder string|nil   text only, drawn while the field is empty
---@field maxLength integer|nil    text only. Default 96, ceiling 512
---@field pattern string|nil       text only, a Lua pattern the whole answer must match
---@field charset InputCharset|nil text only, the characters the field accepts
---@field required boolean|nil     text only, an empty answer is refused
---@field options InputOption[]|nil  a choice. A bare string means `{label=s, value=s}`
---@field selected integer|nil     which option starts selected. 1-based
---@field slider InputSlider|nil   a number the player steps

--- One option of a choice.
---@class InputOption
---@field label string         what the player reads
---@field value string|number  what the answer carries

---@class InputSlider
---@field min number|nil     default 0
---@field max number|nil     default 100
---@field step number|nil    default 1
---@field value number|nil   default `min`
---@field suffix string|nil  drawn after the number, e.g. "%"

--- The one event this resource raises, on the spec's `event` and on `opx77:input`
--- beside it. Exactly one is raised per open form.
---@class InputPayload
---@field form string           the form's id
---@field handle InputHandle
---@field owner string          the resource that opened it
---@field action InputAction
---@field reason string|nil     why it was cancelled; on `cancel` only
---@field values table<string, string|number>|nil  field id -> answer; on `submit` only
---@field data table|nil        the spec's `data`, echoed untouched

--- Every export answers one of these and never raises. `error` is a stable code,
--- never player-facing text.
---@class InputResponse
---@field ok boolean
---@field error string|nil

---@class InputOpened : InputResponse
---@field handle InputHandle|nil
---@field id string|nil
---@field fields integer|nil  how many fields it built

--- What `state` answers. It reports where the player is, never what they have typed:
--- the answer is the event, and there is no second way to read it.
---@class InputState : InputResponse
---@field open boolean
---@field mine boolean       true when the open form belongs to the caller
---@field handle InputHandle|nil
---@field owner string|nil
---@field form string|nil
---@field title string|nil
---@field index integer|nil  the focused field's position
---@field total integer|nil
---@field fieldId string|nil

--- A normalised field. `kind` is decided once, at build.
---@class InputEntry
---@field id string
---@field kind InputKind
---@field label string
---@field description string|nil
---@field text string|nil          a text field's accepted buffer
---@field placeholder string|nil
---@field maxLength integer|nil
---@field pattern string|nil
---@field charset string|nil       the Lua character class the field accepts
---@field required boolean|nil
---@field options InputOption[]|nil
---@field selected integer|nil
---@field slider InputSlider|nil

--- One open form.
---@class InputRecord
---@field handle InputHandle
---@field owner string
---@field generation integer
---@field id string
---@field title string
---@field description string|nil
---@field event string|nil
---@field data table|nil
---@field fields InputEntry[]
---@field index integer            the focused field
---@field status InputStatus|nil

--- A transient line under the fields, cleared automatically after a few seconds.
---@class InputStatus
---@field text string
---@field ok boolean
---@field atMs integer

--- One frame, as the page receives it.
---@class InputView
---@field title string
---@field note string|nil      the form's own description
---@field rows InputRow[]
---@field hint string|nil      the focused field's description
---@field keys string          the key line, already in the player's language
---@field status string|nil
---@field statusBad true|nil   absent when the line reports a success

--- One row as the page receives it. Absent flags are `nil`, never `false`.
---@class InputRow
---@field id string
---@field kind InputKind
---@field label string
---@field text string|nil         text only, the authoritative buffer
---@field placeholder string|nil  text only
---@field max integer|nil         text only, for the character counter
---@field value string|nil        choice and slider, the rendered value
---@field fill number|nil         slider only, 0..1
---@field spin true|nil           LEFT and RIGHT change this row's value
---@field on true|nil             the focused row
