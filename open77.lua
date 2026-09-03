resource "opx77_input"
version "0.1.0"
open77_version ">=0.0.1"
auto_start true

-- Swapping a live CEF surface mid-session is unstable, so a generation change reconnects.
reload_policy "reconnect"

-- Load order is manifest order: config and the text helpers first, then the catalogue,
-- then model before input, and main before exports.
client_script "config.lua"
shared_script "shared/text.lua"
shared_script "shared/locale.lua" -- after config.lua: LOCALE is read at load
shared_script "locales/en.lua" -- registered right after the catalogue, so no file
shared_script "locales/fr.lua" -- below calls locale() against an empty one
client_script "client/model.lua"
client_script "client/input.lua"
client_script "client/main.lua"
client_script "client/exports.lua"

web_ui_page "web/index.html"
web_ui_auto_create false -- client/main.lua creates it, so a failure is one logged line
web_files { "web/**" }

permissions {
  -- `Open77.input.isCaptured`. The modal refuses to open while another surface already
  -- holds the keyboard, because it is about to take it.
  "input.actions",
}
