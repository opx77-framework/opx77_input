--- @author DemiAutomatic
--- @file config.lua
--- @description Operator configuration: language, form anchor, strip width and scrim.
--- @field LOCALE {string} Catalogue code in locales/ player-facing text is read from.
--- @field ANCHOR {string} center, top-left, top-right, left or right; unknown means center.
--- @field WIDTH {integer} Strip width in pixels on the 1920-wide surface.
--- @field DIM {boolean} Dim the scene behind an open form.

OPX_INPUT_CONFIG = {
	LOCALE = 'en',
	ANCHOR = 'center',
	WIDTH = 340,
	DIM = false,
}
