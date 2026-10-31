.pragma library

// Matrix glyph pool: mirrored half-width katakana (as in the film), digits
// and a few operators. Noto Sans CJK JP renders the katakana.
var SET = "ｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜﾝ0123456789Z:.=*+<>|ｦﾞ"

function hash(n) {
  var x = Math.sin(n * 12.9898 + 78.233) * 43758.5453
  return x - Math.floor(x)
}

// Deterministic glyph for a seed, so bindings stay stable between frames.
function at(n) {
  return SET.charAt(Math.floor(hash(n) * SET.length))
}

function random() {
  return SET.charAt(Math.floor(Math.random() * SET.length))
}

function isKata(c) {
  var code = String(c).charCodeAt(0)
  return code >= 0xFF61 && code <= 0xFF9F
}

// Terminal-print decode: the first `reveal` fraction of `text` is real, the
// rest is a churn of glyphs that changes with `tick`.
function decode(text, reveal, tick) {
  var t = String(text || "")
  if (reveal >= 1) return t
  var n = Math.max(0, Math.floor(t.length * reveal))
  var out = t.substring(0, n)
  for (var i = n; i < t.length; i++) {
    var c = t.charAt(i)
    out += (c === " ") ? " " : at(i * 31 + tick * 7)
  }
  return out
}
