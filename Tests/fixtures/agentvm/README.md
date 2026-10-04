# agent-vm fixtures

Real `--json` answers of agent-vm, which `Tests/helpers/fake_agent_vm.sh` serves to the tests, and which `Tests/10-agentvm-library.test.sh` feeds to the library's row filters directly.

- `version.json` - `agent-vm version --json`.
- `doctor.json` - `agent-vm doctor --json` (134 GB free). Every check `ok`, the signature included (the installed, Developer ID signed agent-vm); no virtual machine ran.
- `status.json` - `agent-vm status --json` on a store with six images (`dev`, `dev-acp`, `dev-agents`, `dev-node`, `dev-xcode`, `dev-xcode-ios`) and two stopped boxes (`cadabra-spike`, `s3`). Three images need Full Disk Access, and nothing needs a guest update or recreating. It was taken after `status --check-updates` and one `image update`, so it has the update fields: `newestMacOS`, `macOSUpdate` on the five images behind it, `revision`, `updatedAt`, `macOSCheckedAt` and `toolsCheckedAt` on `dev` (updated once), and `recipes` on `dev-acp` (built after agent-vm began to list them). `jobs` holds the two jobs that ended within the hour before it (an `image setup` and a `box stop`); a capture after a quiet hour has none. With every box stopped, the fields a running box adds (`pid`, `ownerPid`, `project` and the rest) are absent; `status-variety.json` carries them.
- `image-info.json` - `agent-vm image info <name> --json` of the first ready image built from another (`dev-acp`, built from `dev-node`, with Full Disk Access): the record with what its disk takes (`diskUsage`) and what it added over its base (`addedOverBase`). The fake answers it for that image only; any other name is not found, unless a test leaves `image-info-<name>.json` in the fake's state folder.
- `box-info.json` - `agent-vm box info <name> --json` of the first box (`cadabra-spike`, stopped, made from `dev-agents`): its status entry with what its disk takes (`diskUsage`). The fake answers it for that box only; any other name is not found, unless a test leaves `box-info-<name>.json` in the fake's state folder.
- `box-network.json` - `agent-vm box network <name> --json` with no change, which only reads: the same box's mode and rules. The fake answers it for any box, and keeps a change per box in its state folder.
- `packs.json` - `agent-vm box packs --json`: the host packs of the installed agent-vm.
- `ipsw-list.json` - `agent-vm image fetch-ipsw --list --json`: the one macOS restore file agent-vm downloaded on this Mac. The New Image window lists it as a start.
- `ipsw-check.json` - `agent-vm image fetch-ipsw --check --json`: the newest restore file Apple offered on 2026-10-02 (macOS 27.0.1), not downloaded on this Mac, with the room left; the Get macOS window shows it. The tests edit it for the other states (partly downloaded, downloaded, no room).
- `status-empty.json` - `agent-vm status --json` on an empty store.
- `job-list.json` - `agent-vm job list --json` after one job (`box start` of a box that does not exist) was started against that empty store, where it can only fail: a job's record as agent-vm writes it. The store's path is written as the default one.
- `job-log.json` - `agent-vm job log <id> --json` of that same job: its record under `job`, and `events` and `lines`, both empty, since it failed before its command reported a step.

Captured on 2026-10-01 from agent-vm 0.5.13 with `Tests/helpers/refresh_agentvm_fixtures.sh`; `version.json`, `doctor.json` (134 GB free, eight checks) and `packs.json` again on 2026-10-04 from agent-vm 0.6.12, the version the library now requires. The store-bound captures were kept: the store holds two images and one box now, and a fresh capture differs from them only by fields agent-vm added (`passwordStorage`, `passwordID`, the box's `guestVersion` and `guestDigest`, a recorded input's `path`), none of which the app reads. The script replaces the home folder with `/Users/you` and sorts keys. When agent-vm's JSON changes, run it again with the new agent-vm and rerun the suite: the drift checks fail when a field the library reads is gone.

## Made by hand

`box-netlog.json` is made by hand, not captured: a real connection log lists what programs in a box reached, which does not belong in a public repository. Its ten connections hold one of each kind the network window treats differently: hosts reached through a pack, a host refused three times over a tunnel to port 443, one refused over plain HTTP to port 80 (allowed by its host name), one refused over a raw tunnel to port 80 and one refused by IP address (neither gets a rule), and a failure to resolve. Its fields are those of a real `box netlog --json` entry on agent-vm 0.4.4.

`box-execlog.json` is made by hand for the same reason: a real program log lists the commands run in a box and the folders they ran in. Its six programs: one that ended at once, one that failed with status 1 in a project folder, exec's own "not found" (127), a login shell that waited on two folder prompts, a program agent-vm stopped at a prompt (143), and one with no end recorded. Its fields are those of a real `box execlog --json` entry on agent-vm 0.4.4 (`ExecLog.Record` in agent-vm's `Sources/AgentVMKit/Boxes/ExecLog.swift`).

`jobs-variety.json` is made by hand: the store held only two finished jobs, and a running build cannot be produced on request. Seven jobs, oldest first, one in each state and of each kind the app starts or shows: a box stopped (done), a box that could not start for want of a virtual machine slot (failed, status 75), a download canceled, a guest update whose runner was stopped (lost), an image being built with a progress event that has a fraction, an index, a count and a tab in its message, and a notice; a Full Disk Access job queued after it; and a box starting. The fields are those of agent-vm's `Job` and `ProgressEvent`, and `job-list.json` is the real record they are checked against.

`job-log-variety.json` is made by hand for the same reason: the log of an image being built from another, as `job log --json` gives it. Thirteen events in the order agent-vm writes them: the steps `clone`, `boot`, `recipe` and three `recipe-step` events with `index`, `count` and `fraction`; log lines, some of them a guest program's output (`output`), one with a tab in it; and a notice. One line under `lines`. The steps and fields are those of agent-vm's `docs/progress-events.md`, and `job-log.json` is the real answer its shape is checked against.

`status-variety.json` is the `status.json` of 2026-09-30 (agent-vm 0.4.4; a store that still had the box `try1` and the image `latest-test`) edited to hold every state the window shows, since a capture holds only what the store held that day, and a wedged supervisor cannot be produced on request. It is not made again at a refresh, since the store no longer holds those two: after a refresh only its version strings are moved to the new agent-vm's (`sed s/<old>/<new>/g`), and a field the new agent-vm adds to `status` is added by hand when the app reads it. The edit that made it, run then in this folder:

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

Added by hand since, as agent-vm added them to `status` (0.5.7): `revision`, `updatedAt`, `macOSCheckedAt` and `toolsCheckedAt` on `dev`, as after two updates; and on `dev-acp` the `recipes` of the real capture. It has no `newestMacOS` and no `macOSUpdate`, as a store where Apple was never asked: a test that needs them adds them with a jq edit. Its images are otherwise those of 2026-09-30, so `dev-acp` there is an older image than the one `image-info.json` measures now.
