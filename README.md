# opx77_input

> [!WARNING]
> **This project is currently in early development and is not considered production-ready.**
>
> The API, architecture, features, and internal systems are subject to change at any time without prior notice. Breaking changes may be introduced as development progresses.
>
> **Do not rely on the current API for production resources yet.**

A value-asking service for **Opx77**. One resource owns the modal; every other resource asks it for a value through an export and is told what the player answered.

`opx77_menu` draws a list of choices. This draws the things a list cannot: a typed line, a picked option, a number on a slider — answered together, in one modal.

## Features

- Text fields, choice lists and sliders, in one form
- Every limit a refusal, never a truncation, and the refusal names itself
- One form at a time, keyed on the resource that opened it
- Takes the keyboard for exactly as long as a form is open, and never longer
- Its own `en`/`fr` catalogue for the lines it owns
- Drawn as `opx77_menu`'s strip, so a menu and the form it leads to read as one UI

## Look and keys

The form is drawn exactly as `opx77_menu` draws a menu, and its stylesheet carries the menu's values: the same width, a title plate with the yellow rule, and one cut plate per field — label on the left, value on the right, `‹›` beside a value that LEFT and RIGHT change. The focused field is the menu's cursor row: it slides out of the column in yellow. A text field's typed line sits where a menu row's value does, and grows with what it holds. The form's description, the focused field's description, the status line (red on a refusal) and the key line each follow as their own plate underneath.

The arrows and ENTER mean what they mean in the menu: UP and DOWN move between fields, LEFT and RIGHT change a choice or a slider (on a text field they move the caret), ENTER submits. ESCAPE cancels. BACKSPACE, the menu's way back, belongs to the text fields here.

## Why a form, and not one value at a time

A caller that needs three values from a one-value service opens three modals in a row, and has to sequence them itself: listen for the first answer, open the second from inside that handler, and hold its own half-built result across all three. Worse, this resource is one-at-a-time keyed on the caller, so a second resource can take the slot between two of them and the sequence is left half-answered.

So the primitive here is the form, and one field is simply a form with one field — the same code path, and the common case still reads as one call. The answer is one event carrying every value at once, which is also the shape a caller wants: `payload.values.plate`.

## Exports

The exports are client-side only: a server resource calls them from its own client half.

| Export | Does |
|---|---|
| `open` | ask the player for one or more values, refusing the spec whole if any field is malformed |
| `close` | take your own form back down |
| `state` | whether a form is open and whether it is yours |
| `setStatus` | write the transient line under the fields |

Every export answers `{ ok = boolean, error = string|nil }` and never raises; `error` is a stable code, never player-facing text. `open` adds `handle`, `id` and `fields`, how many it built. Types for every spec, payload and response are in `types.lua`.

There is no `update`. A form is answered in seconds, and rebuilding one under the player would throw away what they have already typed; a caller that needs different fields closes and opens again.

### A form

```lua
Open77.exports.call("opx77_input", "open", {
  title = "New plate",
  event = "garage:plateAnswered",
  data = { vehicle = 7 },
  fields = {
    { id = "plate", label = "Plate", placeholder = "KV-000",
      maxLength = 8, charset = "name", required = true },
    { id = "colour", label = "Colour",
      options = { "Crimson", { label = "Ice", value = "ice" } }, selected = 1 },
    { id = "tint", label = "Tint",
      slider = { min = 0, max = 100, step = 5, value = 40, suffix = "%" } },
  },
})
```

A field's kind comes from its shape, never from a declaration: `options` makes a choice, `slider` a slider, anything else a text field.

### Rules a caller needs

- One form at a time. `open` answers `input_busy` when another resource owns the open one. There is no way to steal it: the player is typing into it, and taking it away loses their work and fires an answer at somebody who did not ask for one.
- A caller may replace its **own** open form. The one it replaces still answers, with `action = "cancel"` and `reason = "reopened"`.
- `close` and `setStatus` answer `not_owner` unless the open form is yours.
- `state` reports only `open` and `mine` for a form you do not own. It never reports what the player has typed: the answer is the event, and there is no second way to read it.
- `open` answers `keyboard_busy` when another surface already holds the keyboard — chat's composer, the pause menu — and `no_keyboard` when the host refuses to give it to this one.
- The form cancels itself when its owner stops or reloads, within a second.
- The status line clears itself after six seconds; `setStatus(nil)` clears it now.

### Limits

Every one of them is a refusal, with a code. Nothing is silently cut, and nothing a caller sends comes back shorter than it was sent.

| Bound | Value |
|---|---|
| fields per form | 8 |
| options per choice | 64 |
| title, field label | 96 characters |
| option label | 48; option value 96 |
| placeholder | 64; description 160; slider suffix 8 |
| text answer | `maxLength`, default 96, ceiling 512 |
| `pattern` | 64 characters |
| `data` | 64 nodes — keys count as well as values — nested at most 4 deep |

Eight fields is the point where a form stops being a question and becomes a list, and a list is what `opx77_menu` draws.

### What a text field refuses, and when

- **Length and character class are refused as they are typed.** The accepted buffer does not grow, the page is told to put it back, and a line under the fields says why. `charset` is one of `alnum`, `alpha`, `digits`, `hex` or `name` — a fixed table, because a caller's own character class can be malformed or slow and it would be run against every keystroke.
- **`required` and `pattern` are checked on ENTER.** The focus moves to the field that refused and the same line says why. `pattern` is a Lua pattern the whole answer must match; an empty field passes it, because emptiness is what `required` answers.

## Events

One event per form, raised exactly once: on the spec's `event` if it has one, and on `opx77:input` beside it, so one listener can watch every form.

```lua
AddEventHandler("garage:plateAnswered", function(payload)
  if payload.action ~= "submit" then return end
  print(payload.values.plate, payload.values.colour, payload.values.tint)
end)
```

`action` is `submit` or `cancel`. `values` is present on a submit only, keyed by field id — a field's `id` is the caller's own handle on it, which is why there is no per-field `data` to echo. The form's `data` comes back untouched on both. On a cancel, `reason` says which of these it was: `escape`, `pause`, `caller`, `reopened`, `owner_reloaded`, `owner_stopped` or `input_stopped`.

Escape always cancels. So does the platform's own pause key, which is raised even where the page never sees the keystroke — that is the backstop that stops a broken page from stranding a player in a modal they cannot leave.

A slider answers a number, and it is a float even where it renders whole: `40` comes back as `40.0`. Handing it straight to `%d` raises.

## Configuration

`config.lua`. Language, anchor, strip width, and whether the scene behind it is dimmed. `ANCHOR` ships `"center"`: the form is drawn in the menu's style, but it is a question the player has to answer, so it sits in the middle of the screen rather than where a menu does. It also takes `opx77_menu`'s four anchors (`"top-left"`, `"top-right"`, `"left"`, `"right"`) for a server that wants the form where the list before it sat. `WIDTH` takes the same value as the menu's and ships with the same default. `DIM` ships off, because the menu draws no scrim.

## Locales

`locales/en.lua` and `locales/fr.lua`, selected by `LOCALE` in `config.lua`, and both carrying the same nine keys.

Unlike `opx77_menu`, which renders only its caller's text, this resource owns lines a player reads: the key line under the fields, and the four refusals a field can answer with. Those are translated. Everything a caller sends is rendered as the caller wrote it, and the error codes are a branching surface rather than text, so neither is.

## Community & Support

Join the Open77 and Opx77 communities to discover the platform, share your projects, and connect with other developers.

<!-- TODO: replace with the final URLs before publication. -->

* [Open77](#)
* [Open77 GitHub](#)
* [OPX Discord](#)

## License

opx77_input is licensed under the [**MIT License**](LICENSE).

Copyright © 2026 **Luis MOUTA**.

<p align="center">
    <sub>opx77_input is an independent community project and is not affiliated with or endorsed by CD PROJEKT RED.</sub>
</p>
