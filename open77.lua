--- @author DemiAutomatic
--- @file open77.lua
--- @description Resource manifest declaring scripts, permissions and reload policy.

resource "opx77_input"
version "0.2.0"
open77_version ">=0.0.1"
auto_start true

reload_policy "reconnect"

client_script "config.lua"
shared_script "shared/text.lua"
shared_script "shared/locale.lua"
shared_script "locales/en.lua"
shared_script "locales/fr.lua"
client_script "client/model.lua"
client_script "client/input.lua"
client_script "client/main.lua"
client_script "client/exports.lua"

web_ui_page "web/index.html"
web_ui_auto_create false
web_files { "web/**" }

permissions {
  "input.actions",
}
