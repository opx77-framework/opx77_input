--- Configuration for opx77_input: where the form sits, how wide it is, and what it dims.

OPX_INPUT_CONFIG = {
  LOCALE = "en",
  -- "top-left" | "top-right" | "left" | "right", as opx77_menu's ANCHOR; the last two are
  -- mid-height. Keep both resources on the same value: a form usually follows a menu, and
  -- it is drawn as that menu's strip. Anything unrecognised falls back to "top-left".
  ANCHOR = "top-left",
  WIDTH = 340, -- strip width in pixels, at a 1920-wide surface; opx77_menu's WIDTH
  -- A scrim behind the form. Off, as opx77_menu draws none: the strip is the same panel
  -- the menu is, and a scene dimmed behind one and not the other reads as two UIs.
  DIM = false,
}
