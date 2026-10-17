## nim-loopback — whether a peer can only be reached from this machine.
##
## One rule for every place that asks: a listening address, a Host header,
## the host of a URL. The mistake that matters is calling an outside peer a
## loopback one — that is what skips authentication or sends a secret in the
## clear — so what is not plainly loopback is not.
##
## - LB-01 IPv4: four plain decimal numbers 0–255, the first 127 (RFC 1122,
##   127.0.0.0/8). A number with a leading zero is not read: some parsers
##   take `0177` as octal.
## - LB-02 IPv6: `::1` in any textual form, with or without brackets, and
##   IPv4-mapped 127.0.0.0/8 (RFC 4291). An address with a zone is not.
## - LB-03 The name `localhost`, in any case (RFC 6761). Not a name under it,
##   not with a trailing dot: those may be sent to DNS.
## - LB-04 `host[:port]`: the port is cut off first; an IPv6 address with a
##   port is in brackets.
## - LB-05 A URL: its host.
##
## `0.0.0.0` and `::` mean every interface; they are not loopback.
##
## Taken out of seven repositories on 2026-10-15, which each had their own
## rule; one of them let `127.evil.example` through.

import std/[strutils, uri]

func decimalOctet(text: string): int {.raises: [].} =
  ## 0–255 written as plain decimal, or -1.
  if text.len == 0 or text.len > 3: return -1
  if text.len > 1 and text[0] == '0': return -1
  result = 0
  for c in text:
    if c notin Digits: return -1
    result = result * 10 + (ord(c) - ord('0'))
  if result > 255: return -1

func ipv4FirstOctet(text: string): int {.raises: [].} =
  ## The first number of a dotted-quad IPv4 address, or -1 when `text` is
  ## not one.
  let parts = text.split('.')
  if parts.len != 4: return -1
  for part in parts:
    if decimalOctet(part) < 0: return -1
  decimalOctet(parts[0])

func hexGroup(text: string): int {.raises: [].} =
  ## One IPv6 group: 1–4 hex digits, or -1.
  if text.len == 0 or text.len > 4: return -1
  result = 0
  for c in text:
    let digit =
      case c
      of '0'..'9': ord(c) - ord('0')
      of 'a'..'f': ord(c) - ord('a') + 10
      of 'A'..'F': ord(c) - ord('A') + 10
      else: return -1
    result = result * 16 + digit

func ipv6Groups(text: string; groups: var array[8, int]): bool {.raises: [].} =
  ## Reads an IPv6 address (RFC 4291 2.2, without a zone) into its eight
  ## groups. An IPv4 tail fills the last two.
  if text.len == 0 or '%' in text or text.count("::") > 1: return false
  proc read(side: string; into: var seq[int]): bool =
    if side.len == 0: return true
    let parts = side.split(':')
    for i, part in parts:
      if i == parts.high and '.' in part:
        if ipv4FirstOctet(part) < 0: return false
        let octets = part.split('.')
        into.add(decimalOctet(octets[0]) * 256 + decimalOctet(octets[1]))
        into.add(decimalOctet(octets[2]) * 256 + decimalOctet(octets[3]))
      else:
        let group = hexGroup(part)
        if group < 0: return false
        into.add(group)
    true
  var left, right: seq[int]
  let gap = text.find("::")
  if gap < 0:
    if not read(text, left) or left.len != 8: return false
  else:
    if not read(text[0 ..< gap], left) or not read(text[gap + 2 .. ^1], right): return false
    if left.len + right.len > 7: return false
  for i in 0 ..< 8: groups[i] = 0
  for i, g in left: groups[i] = g
  for i, g in right: groups[8 - right.len + i] = g
  true

func isLoopbackIpv6(text: string): bool {.raises: [].} =
  var g: array[8, int]
  if not ipv6Groups(text, g): return false
  for i in 0 ..< 5:
    if g[i] != 0: return false
  if g[5] == 0 and g[6] == 0 and g[7] == 1: return true          # ::1
  g[5] == 0xffff and (g[6] shr 8) == 127                          # ::ffff:127.0.0.0/104

func isLoopbackHost*(host: string): bool {.raises: [].} =
  ## Whether `host` — an address or a name, as in a URL or a listening
  ## address, without a port — is this machine's loopback (LB-01..03).
  if host.len >= 2 and host[0] == '[' and host[^1] == ']':
    return isLoopbackIpv6(host[1 .. ^2])
  if cmpIgnoreCase(host, "localhost") == 0: return true
  if ipv4FirstOctet(host) == 127: return true
  isLoopbackIpv6(host)

func isLoopbackAuthority*(authority: string): bool {.raises: [].} =
  ## Whether `host[:port]` — a Host header, a listening address — names this
  ## machine's loopback (LB-04).
  proc isPort(text: string): bool =
    text.len > 0 and text.allCharsInSet(Digits)
  if authority.startsWith("["):
    let close = authority.find(']')
    if close < 0: return false
    let rest = authority[close + 1 .. ^1]
    if rest.len > 0 and not (rest[0] == ':' and isPort(rest[1 .. ^1])): return false
    return isLoopbackHost(authority[0 .. close])
  case authority.count(':')
  of 0: isLoopbackHost(authority)
  of 1:
    let colon = authority.find(':')
    isPort(authority[colon + 1 .. ^1]) and isLoopbackHost(authority[0 ..< colon])
  else: isLoopbackHost(authority)        # a bare IPv6 address, which has no port

func isLoopbackUrl*(url: string): bool {.raises: [].} =
  ## Whether the host of `url` is this machine's loopback (LB-05). The user
  ## part (`http://127.0.0.1@evil.example/`) is not the host.
  isLoopbackHost(parseUri(url).hostname)
