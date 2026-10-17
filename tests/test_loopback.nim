## E tests: whether a peer can only be reached from this machine (README; LB-01..05).
##
## The mistake that matters is calling a peer outside this machine a
## loopback one: that is what skips authentication or sends a secret in the
## clear. Each suite therefore checks both sides.

import std/unittest
import nim_loopback

suite "LB-01: IPv4 — 127.0.0.0/8, written as four plain decimal numbers":
  test "Given an address in 127.0.0.0/8 When asked Then loopback":
    # SPEC: LB-01 — RFC 1122 3.2.1.3
    for host in ["127.0.0.1", "127.0.0.2", "127.1.2.3", "127.255.255.255", "127.0.0.0"]:
      check isLoopbackHost(host)

  test "Given another address, or all of them (0.0.0.0) When asked Then not":
    # SPEC: LB-01
    for host in ["128.0.0.1", "126.255.255.255", "10.0.0.1", "192.168.1.1", "0.0.0.0", "255.255.255.255"]:
      check not isLoopbackHost(host)

  test "Given a name that only begins like a loopback address When asked Then not — it is resolved by DNS":
    # SPEC: LB-01 — what startsWith("127.") let through
    for host in ["127.evil.example", "127.0.0.1.evil.example", "127.0.0.1.", "127", "127.0.0", "127.0.0.1.1"]:
      check not isLoopbackHost(host)

  test "Given a number with a leading zero, out of range, or not decimal When asked Then not — some parsers read 0177 as octal":
    # SPEC: LB-01
    for host in ["0127.0.0.1", "127.00.0.1", "127.0.0.01", "127.0.0.256", "127.0.0.-1", "127.0.0.0x1",
                 "127.0.0.1 ", " 127.0.0.1", "127..0.1", "2130706433", "0x7f.0.0.1"]:
      check not isLoopbackHost(host)

suite "LB-02: IPv6 — ::1 in any form, and IPv4-mapped 127.0.0.0/8":
  test "Given ::1 compressed, expanded, in capitals, or in brackets When asked Then loopback":
    # SPEC: LB-02 — RFC 4291 2.5.3
    for host in ["::1", "[::1]", "0:0:0:0:0:0:0:1", "0000:0000:0000:0000:0000:0000:0000:0001", "0::1", "::0:1"]:
      check isLoopbackHost(host)

  test "Given an IPv4-mapped address in 127.0.0.0/8 When asked Then loopback; another mapped address, not":
    # SPEC: LB-02 — RFC 4291 2.5.5.2
    check isLoopbackHost("::ffff:127.0.0.1")
    check isLoopbackHost("[::FFFF:127.1.2.3]")
    check not isLoopbackHost("::ffff:10.0.0.1")

  test "Given another IPv6 address, all of them (::), a zone, or a broken form When asked Then not":
    # SPEC: LB-02
    for host in ["::", "::2", "1::1", "fe80::1", "::1%lo0", "[::1%25lo0]", "[::1", "::1]", ":::1", "::1::", "[]",
                 "0:0:0:0:0:0:0:0:1", "::g"]:
      check not isLoopbackHost(host)

  test "Given an IPv4-mapped address When asked Then only 127.0.0.0/8 is loopback, whatever the second number":
    # SPEC: LB-02 — RFC 4291 2.5.5.2
    for host in ["::ffff:127.255.0.1", "::ffff:127.255.255.255", "::ffff:127.0.0.0", "[::ffff:127.128.0.1]"]:
      check isLoopbackHost(host)
    for host in ["::ffff:128.0.0.1", "::ffff:126.255.255.255", "::ffff:0.0.0.1"]:
      check not isLoopbackHost(host)

  test "Given ::1 written with an IPv4 tail When asked Then loopback; any other tail, not":
    # SPEC: LB-02 — the address ::1 in any textual form
    for host in ["::0.0.0.1", "0:0:0:0:0:0:0.0.0.1"]:
      check isLoopbackHost(host)
    for host in ["::0.1.0.1", "::0.0.1.255", "::0.0.1.0", "::127.0.0.1", "::0.0.0.2"]:
      check not isLoopbackHost(host)

  test "Given an IPv4 tail that is not four plain decimal numbers When asked Then not, even after groups that would be loopback":
    # SPEC: LB-02 — a broken tail must not leave a half-read address behind
    for host in ["::ffff:127.0.0.256", "::1:127.0.0.256", "::ffff:127.0.0.01", "::1:127.0.0.x", "::ffff:127.0.0"]:
      check not isLoopbackHost(host)

  test "Given a group of five hex digits When asked Then not, even if its value would make a loopback address":
    # SPEC: LB-02 — a group is 1-4 hex digits (RFC 4291 2.2)
    for host in ["::00001", "[::00001]", "0:0:0:0:0:0:0:00001"]:
      check not isLoopbackHost(host)

  test "Given groups in the last two places other than 0:1 or ffff:127.x When asked Then not":
    # SPEC: LB-02 — only ::1 and ::ffff:127.0.0.0/104 are loopback
    for host in ["::2:1", "::ffff:0:1", "::1:0:1", "::ffff:0:0", "::7f00:1", "::ffff:7e00:1"]:
      check not isLoopbackHost(host)

  test "Given :: standing for one group, or for none When asked Then one group is read, none is not":
    # SPEC: LB-02 — "::" is one or more groups of zeros (RFC 4291 2.2)
    for host in ["0:0:0:0:0:0::1", "::0:0:0:0:0:0:1", "0::0:0:0:0:0:1", "[0:0:0:0:0:0::1]"]:
      check isLoopbackHost(host)
    for host in ["0:0:0:0:0:0:0::1", "0:0:0:0:0:0:0:1::", "::0:0:0:0:0:0:0:1", "1:2:3:4:5:6:7::1"]:
      check not isLoopbackHost(host)

suite "LB-03: the name localhost":
  test "Given localhost in any case When asked Then loopback":
    # SPEC: LB-03 — RFC 6761 6.3
    for host in ["localhost", "LOCALHOST", "LocalHost"]:
      check isLoopbackHost(host)

  test "Given a name under localhost, a trailing dot, another name, or nothing When asked Then not — those may go to DNS":
    # SPEC: LB-03
    for host in ["app.localhost", "localhost.", "localhost.example", "mylocalhost", "", " "]:
      check not isLoopbackHost(host)

suite "LB-04: host and port, as in a Host header or a listening address":
  test "Given a loopback host with or without a port When asked Then loopback":
    # SPEC: LB-04
    for authority in ["127.0.0.1", "127.0.0.1:8080", "localhost:3001", "[::1]:443", "[::1]", "::1",
                      "LOCALHOST:80", "127.0.0.1:8", "[::1]:8", "127.0.0.1:0"]:
      check isLoopbackAuthority(authority)

  test "Given another host, a port that is not a number, or an IPv6 address with a port and no brackets When asked Then not":
    # SPEC: LB-04 — "::1:80" is the address ::1:80, not ::1 port 80
    for authority in ["example.com:80", "10.0.0.1:8080", "127.0.0.1:http", "127.0.0.1:", "::1:80",
                      "[::1]:", "[::1]x", "127.evil.example:80", ""]:
      check not isLoopbackAuthority(authority)

  test "Given a bracket that is never closed When asked Then not, whatever follows":
    # SPEC: LB-04
    for authority in ["[::1", "[::1:80", "[", "[127.0.0.1"]:
      check not isLoopbackAuthority(authority)

suite "LB-05: the host of a URL":
  test "Given a URL whose host is loopback When asked Then loopback, whatever the scheme, port or path":
    # SPEC: LB-05
    for url in ["http://127.0.0.1:3001/oidc/jwks", "http://localhost/x", "http://[::1]:8080/", "https://127.0.0.2/",
                "ws://LOCALHOST:9/"]:
      check isLoopbackUrl(url)

  test "Given a URL whose host is another, a user part that looks like loopback, or no host When asked Then not":
    # SPEC: LB-05 — "http://127.0.0.1@evil.example/" is evil.example
    for url in ["http://evil.example/", "http://127.0.0.1@evil.example/", "http://127.0.0.1.evil.example/",
                "http://localhost.evil.example/", "file:///etc/passwd", "", "not a url", "http:///x"]:
      check not isLoopbackUrl(url)
