.pragma library

// Format with ' between every 3 digits
function intToSeparatedString(i) {
  var value = i.toString()
  var s = ""
  while (value.length > 3) {
    s = "'" + value.substring(value.length - 3, value.length) + s
    value = value.substring(0, value.length - 3)
  }
  return value + s
}

function decodeSpec(spec) {
  return JSON.parse(spec)
}

function encodeSpec(spec) {
  return JSON.stringify(spec)
}
