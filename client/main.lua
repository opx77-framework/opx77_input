--- The surface, the one open form, and the single answer it raises.

OpxInput = OpxInput or {}

local Config = OPX_INPUT_CONFIG
local Model = OpxInput.Model
local Input = OpxInput.Input

OpxInput.Runtime = {}
local Runtime = OpxInput.Runtime

local RESOURCE = GetCurrentResourceName()

local page

--- True once WebUI.create has refused; the exports refuse too.
local surfaceFailed = false
local pageReady = false

--- The one open form, or nil.
---@type InputRecord|nil
local record

local nextHandle = 1

--- owner -> the generation last seen, so a reloaded caller's form goes away with it.
local ownerGenerations = {}
local nextOwnerSweepMs = 0
local OWNER_SWEEP_MS = 1000

--- How long the line under the fields stays up, and the loop's period while a form is open.
local STATUS_MS = 6000
local IDLE_MS = 250

--- Raised beside the caller's own event, so one listener can watch every form.
local GLOBAL_EVENT = 'opx77:input'

--- The scheduler clock in milliseconds; `monotonic` answers SECONDS. A non-finite reading is
--- dropped rather than propagated: a NaN would expire nothing, an infinity everything.
---@return integer
local lastMs = 0
local function nowMs()
	local read, seconds = pcall(Open77.time.monotonic)
	if read and type(seconds) == 'number' and seconds == seconds and
		seconds >= 0 and seconds < math.huge then
		lastMs = math.floor(seconds * 1000)
	end
	return lastMs
end

--- True while `page:send` is failing, so a dead surface is logged once, not every frame.
local sendFailing = false

--- One write to the page. Guarded: `page:send` raises, and both the exports and the page's
--- own handlers reach it.
---@param name string
---@param payload table
local function send(name, payload)
	if page == nil or not pageReady then return end
	local ok, reason = pcall(page.send, page, name, payload)
	if ok then
		sendFailing = false
		return
	end
	if not sendFailing then
		Open77.log.error(('the page write %s failed: %s'):format(name, tostring(reason)))
	end
	sendFailing = true
end

--- Send the layout to the page. Once, at ready: none of it changes while the resource runs.
local function sendConfig()
	send('input:config', {
		anchor = Config.ANCHOR,
		width = Config.WIDTH,
		dim = Config.DIM == true,
	})
end

local function draw()
	if page == nil or not pageReady then return end
	if record == nil then
		send('input:hide', {})
		return
	end
	send('input:frame', Model.View(record))
end

--- Answer the open form, exactly once, and hand the keyboard back before anything else.
---@param action InputAction
---@param reason string|nil  why it was cancelled
---@return InputHandle
local function finish(action, reason)
	local answered = record
	-- Cleared before dispatch: a handler runs inline and can re-enter this file, and a form
	-- answers once.
	record = nil
	Input.Release(page)
	draw()
	local payload = Model.Payload(answered, action)
	if action == 'cancel' then payload.reason = reason or 'closed' end
	local event = answered.event
	if event then TriggerEvent(event, payload) end
	if GLOBAL_EVENT ~= event then TriggerEvent(GLOBAL_EVENT, payload) end
	return answered.handle
end

---@param handle InputHandle|nil
---@param reason string|nil
---@return boolean, string|InputHandle|nil
function OpxInput.Runtime.Close(handle, reason)
	if record == nil then return false, 'no_form_open' end
	if handle ~= nil and handle ~= record.handle then return false, 'not_open' end
	return true, finish('cancel', reason)
end

--- Write, or clear with `nil`, the transient line under the fields.
---@param text string|nil
---@param ok boolean|nil  false marks a failure. Default true
---@return boolean
function OpxInput.Runtime.SetStatus(text, ok)
	if record == nil then return false end
	local clean = text ~= nil and Model.StatusText(text) or nil
	if clean == nil or clean == '' then
		if record.status == nil then return true end
		record.status = nil
	else
		record.status = { text = clean, ok = ok ~= false, atMs = nowMs() }
	end
	draw()
	return true
end

--- Show one of this resource's own refusals, in the player's language.
---@param key string
---@param params table|nil
local function notice(key, params)
	Runtime.SetStatus(locale(key, params), false)
end

--- Note the caller's generation, and drop its form if it has reloaded since.
---@param owner string
---@param generation integer
local function noteOwner(owner, generation)
	if ownerGenerations[owner] ~= nil and ownerGenerations[owner] ~= generation then
		if record ~= nil and record.owner == owner then
			Runtime.Close(record.handle, 'owner_reloaded')
		end
	end
	ownerGenerations[owner] = generation
end

--- Open a form. A caller may replace its own; it may never replace another's.
---@param owner string
---@param generation integer
---@param spec InputSpec
---@return InputRecord|nil, string|nil
function OpxInput.Runtime.Open(owner, generation, spec)
	noteOwner(owner, generation)

	if record ~= nil and record.owner ~= owner then return nil, 'input_busy' end
	-- Asked before the form is built: this surface is about to take the keyboard, and
	-- taking it from chat's composer would type the player's line into nothing.
	if record == nil and Input.Captured() then return nil, 'keyboard_busy' end

	local built, reason = Model.Build(owner, generation, spec)
	if built == nil then return nil, reason end

	if record ~= nil then finish('cancel', 'reopened') end

	built.handle = nextHandle
	nextHandle = nextHandle + 1
	record = built

	local taken, note = Input.Grab(page)
	if not taken then
		record = nil
		return nil, 'no_keyboard'
	end
	if note ~= nil then Open77.log.warn('keyboard focus answered ' .. note) end

	if spec.status ~= nil then Runtime.SetStatus(spec.status) end
	draw()
	return record
end

---@return InputState
function OpxInput.Runtime.Snapshot()
	if record == nil then return { open = false } end
	local entry = Model.Entry(record)
	return {
		open = true,
		handle = record.handle,
		owner = record.owner,
		form = record.id,
		title = record.title,
		index = record.index,
		total = #record.fields,
		fieldId = entry and entry.id or nil,
	}
end

---@return string|nil
function OpxInput.Runtime.Owner()
	return record and record.owner or nil
end

---@return boolean
function OpxInput.Runtime.Unavailable()
	return surfaceFailed
end

--- One key the page reported. Every decision about what it means is made here.
---@param key any
local function onKey(key)
	if record == nil then return end
	local action = Input.Action(key)
	if action == nil then return end

	if action == 'cancel' then
		finish('cancel', 'escape')
		return
	end

	if action == 'submit' then
		local index, refusal = Model.Check(record)
		if index == nil then
			finish('submit')
			return
		end
		-- Put the player on the field that refused before saying why.
		record.index = index
		notice(refusal)
		return
	end

	local moved = false
	if action == 'up' then moved = Model.Move(record, -1) end
	if action == 'down' then moved = Model.Move(record, 1) end
	if action == 'left' then moved = Model.Adjust(Model.Entry(record), -1) end
	if action == 'right' then moved = Model.Adjust(Model.Entry(record), 1) end
	if moved then draw() end
end

--- One candidate buffer the page reported. Lua decides what the field now holds.
---@param payload any
local function onEdit(payload)
	if record == nil or type(payload) ~= 'table' then return end
	local entry = Model.Entry(record)
	-- An edit from a field that no longer has the focus is stale, and is dropped.
	if entry == nil or entry.id ~= payload.id then return end
	local redraw, refusal, params = Model.Edit(entry, payload.text)
	if refusal ~= nil then
		notice(refusal, params)
	elseif redraw then
		draw()
	end
end

--- Clear the status line once `STATUS_MS` has passed.
---@param atMs integer
local function expireStatus(atMs)
	if record == nil or record.status == nil then return end
	if atMs - record.status.atMs < STATUS_MS then return end
	record.status = nil
	draw()
end

--- Cancel the form when its owner has stopped or reloaded. Runs once per `OWNER_SWEEP_MS`.
---@param atMs integer
local function sweep(atMs)
	if record == nil then return end
	if atMs < nextOwnerSweepMs then return end
	nextOwnerSweepMs = atMs + OWNER_SWEEP_MS
	local owner = record.owner
	local running = GetResourceState(owner) == 'running'
	local generation
	if type(Open77.resource) == 'table' and type(Open77.resource.generation) == 'function' then
		generation = Open77.resource.generation(owner)
	end
	if not running or (generation ~= nil and generation ~= record.generation) then
		Runtime.Close(record.handle, 'owner_stopped')
	end
end

--- One pass over the open form. Every call it makes is a host call, so the thread runs it
--- under `pcall`.
local function frameTick()
	-- One clock read per pass: `monotonic` is a host call.
	local atMs = nowMs()
	expireStatus(atMs)
	sweep(atMs)
end

--- One pass of a forever-thread. A raise from a host call would otherwise end that loop for
--- the session, so it is logged once per run of failures and the loop carries on.
---@param label string
---@param body fun()
---@param failing boolean  whether the previous pass already failed
---@return boolean failing
local function guarded(label, body, failing)
	local ok, reason = pcall(body)
	if ok then return false end
	if not failing then Open77.log.error(('%s failed: %s'):format(label, tostring(reason))) end
	return true
end

-- The plugin swallows Escape and raises this instead. The page reports the same key; both
-- reach `finish`, and the record is cleared there, so the second one finds nothing to do.
AddEventHandler('open77:pauseKey', function()
	if record ~= nil then finish('cancel', 'pause') end
end)

AddEventHandler('onClientResourceStart', function(name)
	if name ~= RESOURCE then return end

	local readable, note = Input.Attach()
	if not readable then
		Open77.log.warn('the keyboard cannot be read (' .. tostring(note) .. ')')
		Open77.log.warn('  a form will open over whatever else already holds it.')
	end

	-- Cleared on every start: a reload after a failure must be able to succeed.
	surfaceFailed = false

	local reason
	page, reason = WebUI.create({
		entry = 'web/index.html',
		-- "hud", like opx77_chat's box: the surface takes focus explicitly, and only while a
		-- form is open.
		layer = 'hud',
		width = 1920,
		height = 1080,
		-- 60, not the menu's 30: this surface carries a caret and the player is typing at it.
		fps = 60,
		-- Above opx77_menu (725), below open77_admin's strip (730).
		zIndex = 728,
		transparent = true,
		-- Created visible: a surface created hidden never uploads a frame once shown.
		visible = true,
	})
	if page == nil then
		Open77.log.error('WebUI surface failed: ' .. tostring(reason))
		Open77.log.error('  the exports will refuse: there is nothing to ask on.')
		surfaceFailed = true
		return
	end

	page:on('input:ready', function()
		pageReady = true
		sendConfig()
		draw()
	end)

	page:on('input:key', function(payload)
		if type(payload) ~= 'table' then return end
		onKey(payload.key)
	end)

	page:on('input:edit', onEdit)

	page:on('input:diag', function(payload)
		if type(payload) ~= 'table' then return end
		Open77.log.info('page: ' .. tostring(payload.text or ''))
	end)

	CreateThread(function()
		local failing = false
		while page ~= nil do
			if record == nil then
				Wait(IDLE_MS)
			else
				failing = guarded('the form pass', frameTick, failing)
				Wait(IDLE_MS)
			end
		end
	end)
end)

AddEventHandler('onClientResourceStop', function(name)
	if name ~= RESOURCE then return end
	-- Tell whoever had a form open, while there is still a Lua state to do it.
	if record ~= nil then finish('cancel', 'input_stopped') end
	-- Unconditional: a keyboard left captured over a stop leaves the player unable to move.
	Input.Release(page)
	page, pageReady = nil, false
end)
