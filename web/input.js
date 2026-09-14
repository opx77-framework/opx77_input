/* opx77_input -- the form's page: a renderer, driven entirely by Lua. */
(function () {
  "use strict";

  // CEF console output does not reach the client log, and the WebUI bridge
  // swallows exceptions thrown inside an `Open77.on` handler.
  var reportCount = 0;
  var reporting = false;

  function describe(value) {
    try {
      if (value instanceof Error) return (value.name || "Error") + ": " + value.message;
      if (value === null || value === undefined) return String(value);
      if (typeof value === "object") return Object.prototype.toString.call(value);
      return String(value);
    } catch (ignored) { return "<undescribable>"; }
  }

  function report(text) {
    if (reporting || reportCount >= 20) return;
    reporting = true;
    reportCount += 1;
    try {
      window.Open77.emit("input:diag", { text: String(text).slice(0, 400) });
    } catch (ignored) { /* nowhere left to complain to */ }
    reporting = false;
  }

  window.addEventListener("error", function (event) {
    report("uncaught " + (event.message || "?") + " at line " + (event.lineno || 0));
  });
  (function (original) {
    console.error = function () {
      report(Array.prototype.map.call(arguments, describe).join(" "));
      try { original.apply(console, arguments); } catch (ignored) { /* no console */ }
    };
  })(console.error);

  // An empty Lua table arrives as `{}`, not `[]`, so `value || []` would keep it.
  function list(value) { return Array.isArray(value) ? value : []; }

  function text(value) { return value === null || value === undefined ? "" : String(value); }

  // Lua counts characters and JS counts UTF-16 units: a surrogate pair is one character
  // on both sides once its low half is dropped.
  function characters(value) { return value.replace(/[\uDC00-\uDFFF]/g, "").length; }

  function emit(name, payload) {
    try {
      window.Open77.emit(name, payload);
    } catch (error) { report(name + ": " + describe(error)); }
  }

  var elements = {
    scrim: document.getElementById("scrim"),
    strip: document.getElementById("strip"),
    title: document.getElementById("title"),
    note: document.getElementById("note"),
    fields: document.getElementById("fields"),
    hint: document.getElementById("hint"),
    status: document.getElementById("status"),
    keys: document.getElementById("keys")
  };

  // The keys this page forwards. Every other key is left to the focused field.
  var FORWARD = {
    ArrowUp: "up",
    ArrowDown: "down",
    ArrowLeft: "left",
    ArrowRight: "right",
    Enter: "enter",
    Escape: "escape"
  };

  // The same four anchors as opx77_menu, so a form can sit where the list before it sat.
  var ANCHORS = {
    "top-left": "anchor-top-left",
    "top-right": "anchor-top-right",
    "left": "anchor-left",
    "right": "anchor-right"
  };

  // Whether the focused row's own frame said LEFT and RIGHT change its value. When it did
  // not, those two keys belong to the caret.
  var focusedSpins = false;

  function applyConfig(payload) {
    payload = payload || {};

    var anchor = ANCHORS[text(payload.anchor)] || ANCHORS["top-left"];
    elements.strip.className = "strip " + anchor;

    var width = Number(payload.width);
    if (isFinite(width) && width > 0) {
      elements.strip.style.setProperty("--strip-width", Math.round(width) + "px");
    }
    document.body.classList.toggle("dim", payload.dim === true);
  }

  // One <li> per field, created once and rewritten in place: a fresh element has no
  // previous computed style, so input.css could not transition it.
  var slots = [];

  function make(tag, className) {
    var node = document.createElement(tag);
    node.className = className;
    return node;
  }

  function slot(index) {
    var entry = slots[index];
    if (entry !== undefined) return entry;

    entry = {
      id: "",
      node: make("li", "row"),
      label: make("span", "label"),
      cell: make("span", "cell"),
      input: make("input", "entry"),
      value: make("span", "value"),
      bar: make("span", "bar"),
      fill: make("i", "fill"),
      count: make("span", "count"),
      mark: make("span", "mark-col")
    };
    entry.input.type = "text";
    entry.input.spellcheck = false;
    entry.input.autocomplete = "off";
    entry.bar.appendChild(entry.fill);
    entry.cell.appendChild(entry.input);
    entry.cell.appendChild(entry.value);
    entry.cell.appendChild(entry.bar);
    entry.cell.appendChild(entry.count);
    entry.cell.appendChild(entry.mark);
    entry.node.appendChild(entry.label);
    entry.node.appendChild(entry.cell);
    entry.node.style.setProperty("--slot", index);

    // Reported, never decided: Lua answers with the buffer it accepted.
    entry.input.addEventListener("input", function () {
      emit("input:edit", { id: entry.id, text: entry.input.value });
    });

    slots[index] = entry;
    elements.fields.appendChild(entry.node);
    return entry;
  }

  function drawRow(entry, row) {
    var kind = text(row.kind);
    var typed = kind === "text";

    entry.id = text(row.id);
    entry.label.textContent = text(row.label);

    var classes = "row";
    if (row.on) classes += " on";
    classes += " kind-" + (typed ? "text" : (kind === "slider" ? "slider" : "choice"));
    entry.node.className = classes;
    entry.node.hidden = false;

    entry.input.hidden = !typed;
    entry.count.hidden = !typed;
    if (typed) {
      var buffer = text(row.text);
      // Assigned only when it differs: a same-value write moves the caret to the end.
      if (entry.input.value !== buffer) entry.input.value = buffer;
      entry.input.placeholder = text(row.placeholder);
      // The plate is as wide as the line it holds, placeholder included, plus the caret.
      entry.input.style.setProperty("--chars",
        Math.max(characters(buffer), characters(entry.input.placeholder)) + 1);
      var max = Number(row.max);
      entry.count.textContent = isFinite(max) && max > 0
        ? characters(buffer) + "/" + Math.round(max) : "";
    } else {
      entry.input.value = "";
      entry.count.textContent = "";
    }

    entry.value.hidden = typed;
    entry.value.textContent = typed ? "" : text(row.value);

    var fill = Number(row.fill);
    var sliding = kind === "slider" && isFinite(fill);
    entry.bar.hidden = !sliding;
    if (sliding) {
      entry.fill.style.width = Math.max(0, Math.min(1, fill)) * 100 + "%";
    }

    // `< >` means LEFT and RIGHT change the value beside it.
    entry.mark.textContent = row.spin ? "‹›" : "";
  }

  function render(payload) {
    payload = payload || {};
    var rows = list(payload.rows);

    elements.title.textContent = text(payload.title) || "INPUT";
    elements.note.textContent = text(payload.note);

    var focused = null;
    for (var index = 0; index < rows.length; index += 1) {
      var row = rows[index] || {};
      var entry = slot(index);
      drawRow(entry, row);
      if (row.on) focused = { entry: entry, row: row };
    }

    // Slots past the end of a shorter form. The class is reset too, or a hidden slot
    // that kept `on` would come back focused under a longer one.
    for (var spare = rows.length; spare < slots.length; spare += 1) {
      slots[spare].node.className = "row";
      slots[spare].node.hidden = true;
    }

    elements.hint.textContent = text(payload.hint);
    elements.keys.textContent = text(payload.keys);

    // Only the failure flag crosses the bridge; anything else is a success.
    elements.status.textContent = text(payload.status);
    elements.status.className = payload.statusBad ? "status bad" : "status";

    document.body.classList.add("open");

    focusedSpins = focused !== null && focused.row.spin === true;
    if (focused !== null && text(focused.row.kind) === "text") {
      if (document.activeElement !== focused.entry.input) focused.entry.input.focus();
    } else if (document.activeElement && document.activeElement.blur) {
      // Blurred, not defocused: the document keeps the keyboard, so keydown still fires.
      document.activeElement.blur();
    }
  }

  function hide() {
    document.body.classList.remove("open");
    focusedSpins = false;
    if (document.activeElement && document.activeElement.blur) document.activeElement.blur();
    // Blanked on hide, not on the next open: a frame arriving during the fade-out would
    // show the previous form's fields.
    for (var index = 0; index < slots.length; index += 1) {
      slots[index].node.className = "row";
      slots[index].node.hidden = true;
      slots[index].input.value = "";
    }
    elements.note.textContent = "";
    elements.hint.textContent = "";
    elements.status.textContent = "";
    elements.keys.textContent = "";
  }

  document.addEventListener("keydown", function (event) {
    var key = FORWARD[event.key];
    if (key === undefined) return;
    // LEFT and RIGHT belong to the caret unless the frame said this row spins.
    if ((key === "left" || key === "right") && !focusedSpins) return;
    event.preventDefault();
    emit("input:key", { key: key });
  });

  Open77.on("input:config", function (payload) {
    try { applyConfig(payload); } catch (error) { report("config: " + describe(error)); }
  });

  Open77.on("input:frame", function (payload) {
    try { render(payload); } catch (error) { report("render: " + describe(error)); }
  });

  Open77.on("input:hide", function () {
    try { hide(); } catch (error) { report("hide: " + describe(error)); }
  });

  // Emitted whatever happened above: Lua drops every message until the page is ready.
  try { Open77.ready(); } catch (error) { report("ready: " + describe(error)); }
  Open77.emit("input:ready", {});
})();
