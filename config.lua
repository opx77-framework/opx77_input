--- Configuration for opx77_input: where the form sits, how wide it is, and what it dims.

OPX_INPUT_CONFIG = {
  LOCALE = "en",
  -- "center" | "top-left" | "top-right" | "left" | "right". The form is drawn in the menu's
  -- style but it is a question the player has to answer, so it ships in the middle of the
  -- screen rather than where a menu sits; the other four are opx77_menu's anchors, the last
  -- two mid-height. Anything unrecognised falls back to "center".
  ANCHOR = "center",
  WIDTH = 340, -- strip width in pixels, at a 1920-wide surface; opx77_menu's WIDTH
  -- A scrim behind the form. Off, as opx77_menu draws none: the strip is the same panel
  -- the menu is, and a scene dimmed behind one and not the other reads as two UIs.
  DIM = false,
}
