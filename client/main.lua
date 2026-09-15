--- @author DemiAutomatic
--- @file client/main.lua
--- @description The surface, the one open form, and the answer it raises.

local Config = OPX_INPUT_CONFIG
local Model = OpxInput.Model
local Input = OpxInput.Input

OpxInput.Runtime = {}
local Runtime = OpxInput.Runtime

--- @author DemiAutomatic
--- @type {string}
--- @description This resource's own name, for its lifecycle events.
local RESOURCE = GetCurrentResourceName()

--- @author DemiAutomatic
--- @type {table|nil}
--- @description The WebUI surface, nil until created or after a stop.
local page

--- @author DemiAutomatic
--- @type {boolean}
--- @description Whether WebUI.create refused, which makes the exports refuse.
local surfaceFailed = false

--- @author DemiAutomatic
--- @type {boolean}
--- @description Whether the page has reported ready to receive messages.
local pageReady = false

--- @author DemiAutomatic
--- @type {InputRecord|nil}
--- @description The one open form, or nil.
local record

--- @author DemiAutomatic
--- @type {integer}
--- @description Handle the next opened form receives.
local nextHandle = 1

--- @author DemiAutomatic
--- @type {table<string, integer>}
--- @description Generation last seen per caller, to drop a reloaded caller's form.
local ownerGenerations = {}

--- @author DemiAutomatic
--- @type {integer}
--- @description Monotonic milliseconds before which the owner sweep does not run.
local nextOwnerSweepMs = 0

--- @author DemiAutomatic
--- @type {integer}
--- @description Milliseconds between two checks of the open form's owner.
local OWNER_SWEEP_MS = 1000

--- @author DemiAutomatic
--- @type {integer}
--- @description Milliseconds the status line stays up.
local STATUS_MS = 6000

--- @author DemiAutomatic
--- @type {integer}
--- @description Milliseconds between two passes of the form loop.
local IDLE_MS = 250

--- @author DemiAutomatic
--- @type {string}
--- @description Local event raised beside the caller's own for every answer.
local GLOBAL_EVENT = 'opx77:input'

--- @author DemiAutomatic
--- @type {integer}
--- @description Last finite clock reading in milliseconds, held across failed reads.
local lastMs = 0

--- @author DemiAutomatic
--- @method nowMs
--- @description Host-monotonic milliseconds, holding the last finite reading.
--- @returns {integer}
local function nowMs()
	local read, seconds = pcall(Open77.time.monotonic)
	if read and type(seconds) == 'number' and seconds == seconds and
		seconds >= 0 and seconds < math.huge then
		lastMs = math.floor(seconds * 1000)
	end
	return lastMs
end

--- @author DemiAutomatic
--- @type {boolean}
--- @description Whether the last page write failed, so failures log once.
local sendFailing = false

--- @author DemiAutomatic
--- @method send
--- @description Sends one message to the page once ready, logging the first failure.
--- @param name {string}
--- @param payload {table}
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

--- @author DemiAutomatic
--- @method sendConfig
--- @description Sends the configured anchor, width and scrim to the page.
local function sendConfig()
	send('input:config', {
		anchor = Config.ANCHOR,
		width = Config.WIDTH,
		dim = Config.DIM == true,
	})
end

--- @author DemiAutomatic
--- @method draw
--- @description Sends the open form's frame, or hides the page without one.
local function draw()
	if page == nil or not pageReady then return end
	if record == nil then
		send('input:hide', {})
		return
	end
	send('input:frame', Model.View(record))
end

--- @author DemiAutomatic
--- @method finish
--- @description Answers the open form once, releasing the keyboard first.
--- @param action {InputAction}
--- @param reason {string|nil} Why it was cancelled.
--- @returns {InputHandle}
local function finish(action, reason)
	local answered = record
	record = nil
	Input.Release(page)
	draw()
	local payload = Model.Payload(answered, action)
	if action == 'cancel' then payload.reason = reason end
	local event = answered.event
	if event then TriggerEvent(event, payload) end
	if GLOBAL_EVENT ~= event then TriggerEvent(GLOBAL_EVENT, payload) end
	return answered.handle
end

--- @author DemiAutomatic
--- @method OpxInput.Runtime.Close
--- @description Cancels the open form when the handle matches it.
--- @param handle {InputHandle|nil}
--- @param reason {string|nil}
--- @returns {boolean, string|InputHandle|nil}
function OpxInput.Runtime.Close(handle, reason)
	if record == nil then return false, 'no_form_open' end
	if handle ~= nil and handle ~= record.handle then return false, 'not_open' end
	return true, finish('cancel', reason)
end

--- @author DemiAutomatic
--- @method OpxInput.Runtime.SetStatus
--- @description Writes or clears the transient line under the fields.
--- @param text {string|nil}
--- @param ok {boolean|nil} False marks a failure.
--- @returns {boolean}
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

--- @author DemiAutomatic
--- @method notice
--- @description Shows one of this resource's own refusals, translated.
--- @param key {string}
--- @param params {table|nil}
local function notice(key, params)
	Runtime.SetStatus(locale(key, params), false)
end

--- @author DemiAutomatic
--- @method noteOwner
--- @description Records a caller's generation, cancelling its form after a reload.
--- @param owner {string}
--- @param generation {integer}
local function noteOwner(owner, generation)
	if ownerGenerations[owner] ~= nil and ownerGenerations[owner] ~= generation then
		if record ~= nil and record.owner == owner then
			Runtime.Close(record.handle, 'owner_reloaded')
		end
	end
	ownerGenerations[owner] = generation
end

--- @author DemiAutomatic
--- @method OpxInput.Runtime.Open
--- @description Opens a form, replacing only the caller's own.
--- @param owner {string}
--- @param generation {integer}
--- @param spec {InputSpec}
--- @returns {InputRecord|nil, string|nil}
function OpxInput.Runtime.Open(owner, generation, spec)
	noteOwner(owner, generation)

	if record ~= nil and record.owner ~= owner then return nil, 'input_busy' end
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

--- @author DemiAutomatic
--- @method OpxInput.Runtime.Snapshot
--- @description Describes where the player is in the open form.
--- @returns {InputState}
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
		fieldId = entry.id,
	}
end

--- @author DemiAutomatic
--- @method OpxInput.Runtime.Owner
--- @description Answers the resource that owns the open form.
--- @returns {string|nil}
function OpxInput.Runtime.Owner()
	return record and record.owner or nil
end

--- @author DemiAutomatic
--- @method OpxInput.Runtime.Unavailable
--- @description Whether the WebUI surface failed to come up.
--- @returns {boolean}
function OpxInput.Runtime.Unavailable()
	return surfaceFailed
end

--- @author DemiAutomatic
--- @method onKey
--- @description Acts on one key the page reported.
--- @param key {any}
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

--- @author DemiAutomatic
--- @method onEdit
--- @description Decides what the focused text field holds after a page edit.
--- @param payload {any}
local function onEdit(payload)
	if record == nil or type(payload) ~= 'table' then return end
	local entry = Model.Entry(record)
	if entry.id ~= payload.id then return end
	local redraw, refusal, params = Model.Edit(entry, payload.text)
	if refusal ~= nil then
		notice(refusal, params)
	elseif redraw then
		draw()
	end
end

--- @author DemiAutomatic
--- @method expireStatus
--- @description Clears the status line once it has been up long enough.
--- @param atMs {integer}
local function expireStatus(atMs)
	if record == nil or record.status == nil then return end
	if atMs - record.status.atMs < STATUS_MS then return end
	record.status = nil
	draw()
end

--- @author DemiAutomatic
--- @method sweep
--- @description Cancels the form when its owner has stopped or reloaded.
--- @param atMs {integer}
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

--- @author DemiAutomatic
--- @method frameTick
--- @description One pass over the open form: status expiry, then the owner sweep.
local function frameTick()
	local atMs = nowMs()
	expireStatus(atMs)
	sweep(atMs)
end

--- @author DemiAutomatic
--- @method guarded
--- @description Runs one loop pass under pcall, logging the first failure only.
--- @param label {string}
--- @param body {fun()}
--- @param failing {boolean}
--- @returns {boolean}
local function guarded(label, body, failing)
	local ok, reason = pcall(body)
	if ok then return false end
	if not failing then Open77.log.error(('%s failed: %s'):format(label, tostring(reason))) end
	return true
end

--- @author DemiAutomatic
--- @event open77:pauseKey
--- @description Cancels the open form when the platform's pause key is pressed.
AddEventHandler('open77:pauseKey', function()
	if record ~= nil then finish('cancel', 'pause') end
end)

--- @author DemiAutomatic
--- @event onClientResourceStart
--- @description Attaches the keyboard, creates the surface and starts the form loop.
--- @param name {string}
AddEventHandler('onClientResourceStart', function(name)
	if name ~= RESOURCE then return end

	local readable, note = Input.Attach()
	if not readable then
		Open77.log.warn('the keyboard cannot be read (' .. tostring(note) .. ')')
		Open77.log.warn('  a form will open over whatever else already holds it.')
	end

	surfaceFailed = false

	local reason
	page, reason = WebUI.create({
		entry = 'web/index.html',
		layer = 'hud',
		width = 1920,
		height = 1080,
		fps = 60,
		zIndex = 728,
		transparent = true,
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

--- @author DemiAutomatic
--- @event onClientResourceStop
--- @description Answers the open form and releases the keyboard on this resource's stop.
--- @param name {string}
AddEventHandler('onClientResourceStop', function(name)
	if name ~= RESOURCE then return end
	if record ~= nil then finish('cancel', 'input_stopped') end
	Input.Release(page)
	page, pageReady = nil, false
end)
