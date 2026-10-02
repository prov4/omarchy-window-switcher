// Turn `hyprctl clients -j` output into rows sorted most-recently-used first.
function parseClients(raw) {
  var data
  try {
    data = JSON.parse(String(raw || ""))
  } catch (e) {
    return []
  }
  if (!Array.isArray(data)) return []

  var out = []
  for (var i = 0; i < data.length; i++) {
    var c = data[i]
    if (!c || !c.mapped || c.hidden || !c.address) continue
    if (c.workspace && c.workspace.id < 0 && String(c.workspace.name || "").indexOf("special") !== 0) continue
    var app = appName(c)
    out.push({
      address: c.address,
      appClass: String(c.class || c.initialClass || ""),
      app: app,
      title: String(c.title || c.initialTitle || app),
      workspace: c.workspace ? String(c.workspace.name || c.workspace.id) : "",
      focusId: typeof c.focusHistoryID === "number" ? c.focusHistoryID : 9999,
      haystack: (app + " " + String(c.class || "") + " " + String(c.title || "")).toLowerCase()
    })
  }
  out.sort(function(a, b) { return a.focusId - b.focusId })
  return out
}

// "org.mozilla.firefox" -> "Firefox", "foot" -> "Foot".
function appName(c) {
  var cls = String(c.class || c.initialClass || "")
  if (!cls) return "Unknown"
  // Chromium web apps: "chrome-mail.google.com__-Profile_1" -> "mail.google.com".
  var web = cls.match(/^(?:chrome|chromium|brave|msedge)-([^_]+)__/)
  if (web) return web[1]
  if (/^(?:chrome|chromium|brave|msedge)-[a-p]{32}/.test(cls)) return "Web app"
  var parts = cls.split(".")
  var last = parts[parts.length - 1] || cls
  last = last.replace(/[-_]+/g, " ")
  return last.charAt(0).toUpperCase() + last.slice(1)
}

// Subsequence fuzzy match. Returns -1 for no match, otherwise a score where
// higher is better: consecutive runs and word-start hits are rewarded.
function fuzzyScore(haystack, needle) {
  if (!needle) return 0
  var score = 0
  var hi = 0
  var run = 0
  for (var ni = 0; ni < needle.length; ni++) {
    var ch = needle.charAt(ni)
    if (ch === " ") { run = 0; continue }
    var found = haystack.indexOf(ch, hi)
    if (found < 0) return -1
    if (found === hi && ni > 0) run++
    else run = 0
    var prev = found > 0 ? haystack.charAt(found - 1) : " "
    var wordStart = /[\s\-_.:\/|·—]/.test(prev)
    score += 1 + run * 3 + (wordStart ? 4 : 0) - Math.min(found - hi, 10) * 0.1
    hi = found + 1
  }
  // Bonus for a plain substring hit.
  if (haystack.indexOf(needle.trim()) >= 0) score += needle.length * 2
  return score
}

function filterWindows(windows, query) {
  var needle = String(query || "").toLowerCase()
  if (!needle.trim()) return windows.slice()
  // Each space-separated term must match somewhere (fzf-style AND).
  var terms = needle.split(/\s+/).filter(function(t) { return t.length > 0 })
  var scored = []
  for (var i = 0; i < windows.length; i++) {
    var w = windows[i]
    var total = 0
    var ok = true
    for (var t = 0; t < terms.length; t++) {
      var s = fuzzyScore(w.haystack, terms[t])
      if (s < 0) { ok = false; break }
      total += s
    }
    if (ok) scored.push({ w: w, s: total })
  }
  scored.sort(function(a, b) { return b.s - a.s || a.w.focusId - b.w.focusId })
  return scored.map(function(x) { return x.w })
}
