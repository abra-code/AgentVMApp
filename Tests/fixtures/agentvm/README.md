# agent-vm fixtures

Real `--json` answers of agent-vm, which `Tests/helpers/fake_agent_vm.sh` serves to the tests, and which `Tests/10-agentvm-library.test.sh` feeds to the library's row filters directly.

- `version.json` - `agent-vm version --json`.
- `doctor.json` - `agent-vm doctor --json` (55 GB free). Every check `ok`, the signature included (the installed, Developer ID signed agent-vm); no virtual machine ran.
- `status.json` - `agent-vm status --json` on a store with seven images (`dev`, `dev-acp`, `dev-agents`, `dev-node`, `dev-xcode`, `dev-xcode-ios`, `latest-test`) and three stopped boxes (`cadabra-spike`, `s3`, `try1`). Four images need Full Disk Access, and nothing needs a guest update or recreating. No job ran in the last hour (`jobs` is empty). With every box stopped, the fields a running box adds (`pid`, `ownerPid`, `project` and the rest) are absent; `status-variety.json` carries them.
- `image-info.json` - `agent-vm image info <name> --json` of the first ready image built from another (`dev-acp`, built from `dev-node`, with Full Disk Access): the record with what its disk takes (`diskUsage`) and what it added over its base (`addedOverBase`). The fake answers it for that image only; any other name is not found, unless a test leaves `image-info-<name>.json` in the fake's state folder.
- `box-info.json` - `agent-vm box info <name> --json` of the first box (`cadabra-spike`, stopped, made from `dev-agents`): its status entry with what its disk takes (`diskUsage`). The fake answers it for that box only; any other name is not found, unless a test leaves `box-info-<name>.json` in the fake's state folder.
- `box-network.json` - `agent-vm box network <name> --json` with no change, which only reads: the same box's mode and rules. The fake answers it for any box, and keeps a change per box in its state folder.
- `packs.json` - `agent-vm box packs --json`: the host packs of the installed agent-vm.
- `status-empty.json` - `agent-vm status --json` on an empty store.

Captured on 2026-09-30 from agent-vm 0.4.4 with `Tests/helpers/refresh_agentvm_fixtures.sh`, which replaces the home folder with `/Users/you` and sorts keys. When agent-vm's JSON changes, run it again with the new agent-vm and rerun the suite: the drift checks fail when a field the library reads is gone.

## Made by hand

`box-netlog.json` is made by hand, not captured: a real connection log lists what programs in a box reached, which does not belong in a public repository. Its ten connections hold one of each kind the network window treats differently: hosts reached through a pack, a host refused three times over a tunnel to port 443, one refused over plain HTTP to port 80 (allowed by its host name), one refused over a raw tunnel to port 80 and one refused by IP address (neither gets a rule), and a failure to resolve. Its fields are those of a real `box netlog --json` entry on agent-vm 0.4.4.

`status-variety.json` is `status.json` edited to hold every state the window shows, since a capture holds only what the store held that day, and a wedged supervisor cannot be produced on request. The edit, which the refresher does not repeat (rerun it by hand after a refresh, and fix the tests that name what changed):

```sh
/usr/bin/jq -S --arg v "$(/usr/bin/jq -r .version version.json)" '
  .boxes |= map(
    if .box.name == "s3" then . + {state: "running", running: true, pid: 44847, ownerPid: 812,
        project: "/Users/you/src/app", projectReadOnly: false, activeExecs: 2,
        startedAt: "2026-09-29T14:02:10Z", supervisorVersion: $v,
        supervisorPath: "/Users/you/.local/share/agent-vm/versions/\($v)/agent-vm",
        guestVersion: $v, guestFeatures: ["terminal", "prompt-notices", "wallpaper", "time-sync", "user-session", "terminal-pixels"]}
    elif .box.name == "try1" then (. + {state: "unresponsive", running: true,
        statusError: "no answer from the supervisor within 5 s"}) | del(.box.network)
    elif .box.name == "cadabra-spike" then .box.disposable = true
    else . end)
  | .images |= map(
    if .name == "dev" then .needs = [{kind: "guest-update", missing: ["terminal-pixels"]}]
    elif .name == "dev-node" then .needs += [{kind: "guest-update", missing: ["terminal-pixels"]}]
    elif .name == "latest-test" then . + {state: "failed", failure: "the build was canceled", needs: []}
    else . end)
  | .runningVMs.count = 1' status.json > status-variety.json
```

- `s3` runs, with an owner, a project and two programs: the fields follow `BoxStatus` in agent-vm's `Sources/AgentVMKit/Boxes/BoxStatus.swift`, which `status` puts at the top level of each box entry.
- `try1` is unresponsive (something holds its lock, no supervisor answers), and has no network record, as a box made before network rules existed: agent-vm treats that as `open`.
- `cadabra-spike` is a disposable box, as a Cadabra chat window makes.
- `dev` and `dev-node` need a guest update (the `missing` features, as `ImageNeed` in `ImageRecord.swift` reports them), `dev-node` as well as Full Disk Access; `latest-test` failed.
- One virtual machine runs.
