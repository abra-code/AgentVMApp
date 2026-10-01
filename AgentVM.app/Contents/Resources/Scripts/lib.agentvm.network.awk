# lib.agentvm.network.awk - the connection rows and allow rules of a box's network window
# (lib.agentvm.network.sh).
#
# Copied from Cadabra's aichat.box.network.awk (AIChatApp, 2026-09-30), with the outcome as a
# word instead of a symbol, no time filter, and a third mode for rules typed by hand.
#
#     printf '%s\t%s\t%s\n' host port method | /usr/bin/awk -F'\t' -v mode=rule -f lib.agentvm.network.awk
#     agentvm_netlog_rows | /usr/bin/awk -F'\t' -v mode=rows -f lib.agentvm.network.awk
#     printf '%s\n' text | /usr/bin/awk -v mode=check -f lib.agentvm.network.awk
#
# Modes:
#   rule   one line in (host, port, method), the allow rule for it out, or "-" (see rule() below).
#   rows   agentvm_netlog_rows in (time, decision, host, port, method, why), one row out per host,
#          port and outcome, unsorted and led by two sort keys: the rank (refused 1, failed 2,
#          reached 3) and the last time; then host, port, outcome, connections, why, rule,
#          decision. The library sorts and drops the keys.
#   check  one rule typed by hand in, the rule as agent-vm reads it out (lower case, no trailing
#          dots), or "-" when it is not one: a host, "*.domain", "host:port", "pack:<name>",
#          "public" or "public:port".

# host_ok(host) is 1 for a plain host name: letters, digits, "." and "-", starting with a letter
# or digit and holding at least one letter (an IP address is refused: agent-vm's rules name
# hosts), at most 253 characters in labels of 1 to 63. The letters are spelled out because a
# bracket range follows the locale's collation order. _n, _i and _label are locals.
function host_ok(host,    _n, _i, _label) {
    if (host !~ /^[abcdefghijklmnopqrstuvwxyz0123456789][abcdefghijklmnopqrstuvwxyz0123456789.-]*$/ \
        || host !~ /[abcdefghijklmnopqrstuvwxyz]/ || length(host) > 253) return 0
    _n = split(host, _label, ".")
    for (_i = 1; _i <= _n; _i++) if (_label[_i] == "" || length(_label[_i]) > 63) return 0
    return 1
}

function port_ok(port) {
    return port ~ /^[0123456789]+$/ && port + 0 >= 1 && port + 0 <= 65535
}

# rule(host, port, method) is the allow rule for one connection, or "-" when the host is not a
# plain host name. A plain host covers port 443 for a tunnel (CONNECT) and 80 for plain HTTP, as
# agent-vm reads it; any other port is named ("host:8443"). Trailing dots go, as agent-vm drops
# them when it matches a host. "public", agent-vm's rule for any public host, is not a host. A
# raw tunnel to port 80 gets no rule: agent-vm leaves it out of a plain host's ports on purpose,
# since a raw request there can name another site the server hosts. Whatever passes, agent-vm
# still refuses a host that resolves to an address on this Mac or the local network.
function rule(host, port, method) {
    host = tolower(host)
    sub(/\.+$/, "", host)
    if (!host_ok(host) || host == "public" || !port_ok(port)) return "-"
    if (method == "CONNECT" && port + 0 == 80) return "-"
    if ((method == "CONNECT" && port + 0 == 443) || (method != "CONNECT" && port + 0 == 80)) return host
    return host ":" (port + 0)
}

# check(text) is the rule typed by hand, as agent-vm reads it, or "-". _host, _port and _wild
# are locals.
function check(text,    _host, _port, _wild) {
    text = tolower(text)
    if (text ~ /^pack:[abcdefghijklmnopqrstuvwxyz0123456789][abcdefghijklmnopqrstuvwxyz0123456789._-]*$/) return text
    _host = text
    _port = ""
    if (_host ~ /:[0123456789]+$/) {
        _port = _host
        sub(/^.*:/, "", _port)
        sub(/:[0123456789]+$/, "", _host)
        if (!port_ok(_port)) return "-"
    }
    if (_host == "public") return "public" (_port == "" ? "" : ":" (_port + 0))
    _wild = ""
    if (substr(_host, 1, 2) == "*.") {
        _wild = "*."
        _host = substr(_host, 3)
    }
    sub(/\.+$/, "", _host)
    if (!host_ok(_host)) return "-"
    return _wild _host (_port == "" ? "" : ":" (_port + 0))
}

mode == "rule"  { print rule($1, $2, $3); next }
mode == "check" { print check($0); next }

mode == "rows" && NF < 6 { next }

mode == "rows" {
    key = $3 SUBSEP $4 SUBSEP $2
    if (!(key in count)) { order[++n] = key; host[key] = $3; port[key] = $4; decision[key] = $2 }
    count[key]++
    last[key] = $1
    method[key] = $5
    why[key] = $6
}

# The outcome, one for each decision agent-vm logs: refused (denied), failed (allowed, but
# resolving or connecting failed), reached (allowed). The why column says the reason or the rule.
END {
    if (mode != "rows") exit
    for (i = 1; i <= n; i++) {
        k = order[i]
        rank = decision[k] == "denied" ? 1 : (decision[k] == "failed" ? 2 : 3)
        word = decision[k] == "denied" ? "refused" : (decision[k] == "failed" ? "failed" : "reached")
        printf "%d\t%s\t%s\t%s\t%s\t%d\t%s\t%s\t%s\n", rank, last[k], host[k], port[k], word, count[k], why[k],
            rule(host[k], port[k], method[k]), decision[k]
    }
}
