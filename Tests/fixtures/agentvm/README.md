# agent-vm fixtures

Real `--json` answers of agent-vm, which `Tests/helpers/fake_agent_vm.sh` serves to the tests, and which `Tests/10-agentvm-library.test.sh` feeds to the library's row filters directly.

- `version.json` - `agent-vm version --json`: which agent-vm it is, the guest daemons it installs, the Linux systems it builds an image of (`linuxReleases`) and the sizes it gives a new image (`imageSizes`).
- `doctor.json` - `agent-vm doctor --json` (134 GB free). Every check `ok`, the signature included (the installed, Developer ID signed agent-vm), and one `info`, the Linux guest daemon it found; no virtual machine ran.
- `status.json` - `agent-vm status --json` on a store with six images (`dev`, `dev-acp`, `dev-agents`, `dev-node`, `dev-xcode`, `dev-xcode-ios`) and two stopped boxes (`cadabra-spike`, `s3`). Three images need Full Disk Access, and nothing needs a guest update or recreating. It was taken after `status --check-updates` and one `image update`, so it has the update fields: `newestMacOS`, `macOSUpdate` on the five images behind it, `revision`, `updatedAt`, `macOSCheckedAt` and `toolsCheckedAt` on `dev` (updated once), and `recipes` on `dev-acp` (built after agent-vm began to list them). `jobs` holds the two jobs that ended within the hour before it (an `image setup` and a `box stop`); a capture after a quiet hour has none. With every box stopped, the fields a running box adds (`pid`, `ownerPid`, `project` and the rest) are absent; `status-variety.json` carries them.
- `image-info.json` - `agent-vm image info <name> --json` of the first ready image built from another (`dev-acp`, built from `dev-node`, with Full Disk Access): the record with what its disk takes (`diskUsage`) and what it added over its base (`addedOverBase`). The fake answers it for that image only; any other name is not found, unless a test leaves `image-info-<name>.json` in the fake's state folder.
- `box-info.json` - `agent-vm box info <name> --json` of the first box (`cadabra-spike`, stopped, made from `dev-agents`): its status entry with what its disk takes (`diskUsage`). The fake answers it for that box only; any other name is not found, unless a test leaves `box-info-<name>.json` in the fake's state folder.
- `box-network.json` - `agent-vm box network <name> --json` with no change, which only reads: the same box's mode and rules. The fake answers it for any box, and keeps a change per box in its state folder.
- `packs.json` - `agent-vm box packs --json`: the host packs of the installed agent-vm.
- `recipe-check.json` - `agent-vm recipe check <two recipes> --json` (0.7.11) of two of the test recipes in `fixtures/recipes/`, `xcode` (an input file) and `xcode-platforms` (two parameters): both accepted, for macOS (`guest`, since neither names one), with the warnings agent-vm has for recipes whose steps do nothing, and a note each. Their folder is written as `recipes`. No store is read and nothing is built.
- `ipsw-list.json` - `agent-vm image fetch-ipsw --list --json`: the one macOS restore file agent-vm downloaded on this Mac. The New Image window lists it as a start.
- `ipsw-check.json` - `agent-vm image fetch-ipsw --check --json`: the newest restore file Apple offered on 2026-10-02 (macOS 27.0.1), not downloaded on this Mac, with the room left; the Get macOS window shows it. The tests edit it for the other states (partly downloaded, downloaded, no room).
- `status-empty.json` - `agent-vm status --json` on an empty store.
- `job-list.json` - `agent-vm job list --json` after one job (`box start` of a box that does not exist) was started against that empty store, where it can only fail: a job's record as agent-vm writes it. The store's path is written as the default one.
- `job-log.json` - `agent-vm job log <id> --json` of that same job: its record under `job`, and `events` and `lines`, both empty, since it failed before its command reported a step.
- `status-linux.json` - `agent-vm status --json` (0.7.11) on a store of Linux images and boxes only: `deb` (Debian 13, built from Debian's cloud image), `deb-agents` (built from `deb` with the recipes `linux-node` and `agent-clis`), `ub` (Ubuntu 26.04) and `ub-agents` (built from `ub` with `linux-node`, `linux-python` and `agent-clis`), and one stopped box, `lb`, made from `deb`. What a Linux entry has where a macOS one has its macOS version, its build and Full Disk Access: `guest`, `system`, `linux`, `base` (the cloud image it was first built from) and `systemCheckedAt`. The store's folder is written as the default one.
- `image-info-linux.json` - `agent-vm image info deb-agents --json` in that store: the first ready Linux image built from another.
- `box-info-linux.json` - `agent-vm box info lb --json` in that store: its first Linux box.
- `job-log-linux.json` - `agent-vm job log <id> --json` (0.7.12) of a Debian 13 image built from its cloud image as a job, in a store made for it: the job's record, done after a minute and a half, and all 659 events as agent-vm wrote them. 119 are `progress` events: the checksum, 101 of the download with its fraction, the unpacking, the first boot, twelve numbered `linux-setup` steps with `seal` between the seventh and the eighth, and the shutdown. The rest are `log` lines, most of them what `apt` printed in the guest. No `lines`, no notice. The store's folder is written as the default one; nothing else was edited.
- `status-mixed.json` - a store with both kinds, for what the window shows side by side: `status.json` with the images and the box of `status-linux.json` added, and nothing else changed. Made by `refresh_agentvm_fixtures.sh`, which runs `jq -S -s '.[1] as $linux | .[0] | .images += $linux.images | .boxes += $linux.boxes' status.json status-linux.json`.

Captured on 2026-10-01 from agent-vm 0.5.13 with `Tests/helpers/refresh_agentvm_fixtures.sh`; `doctor.json` (134 GB free; eight checks then, nine since the move to 0.7.11 below) again on 2026-10-04 from agent-vm 0.6.12. The script replaces the home folder with `/Users/you` and sorts keys. When agent-vm's JSON changes, run it again with the new agent-vm (naming the parts that changed, when the stores did not) and rerun the suite: the drift checks fail when a field the library reads is gone.

## The move to agent-vm 0.7.11 (2026-10-08)

agent-vm 0.7.11 knows Linux images and boxes, and says of every image and box which guest it is. The store-bound captures were kept, as before: the tests name their images and boxes. What changed:

- `version.json`, `packs.json` (the packs `debian` and `ubuntu`) and `recipe-check.json` were captured again from the installed agent-vm 0.7.11 (`refresh_agentvm_fixtures.sh <agent-vm> version packs recipe-check`).
- `status.json`, `status-variety.json`, `status-empty.json`, `image-info.json` and `box-info.json` were given what 0.7.11 adds to a macOS entry, by this edit, run in this folder (the system's words are the ones agent-vm forms, `GuestSystemText.description` in its `Sources/AgentVMKit/Images/GuestSystem.swift`):

```sh
for f in status status-variety status-empty; do
  /usr/bin/jq -S 'def macos_system($v; $b): "macOS \($v // "?") (\($b // "?"))";
    .images |= map(. + {guest: "macos", system: macos_system(.macOSVersion; .macOSBuild)})
    | .boxes |= map(. + {guest: "macos", system: macos_system(.box.macOSVersion; .box.macOSBuild)})
    | .runningVMs.linuxBoxes = 0' "$f.json" > "$f.new" && /bin/mv "$f.new" "$f.json"
done
/usr/bin/jq -S '. + {guest: "macos", system: "macOS \(.macOSVersion // "?") (\(.macOSBuild // "?"))"}' image-info.json > image-info.new && /bin/mv image-info.new image-info.json
/usr/bin/jq -S '. + {guest: "macos", system: "macOS \(.box.macOSVersion // "?") (\(.box.macOSBuild // "?"))"}' box-info.json > box-info.new && /bin/mv box-info.new box-info.json
```

- `doctor.json` was given the two things 0.7.11 adds, copied from a real answer of that day: `linuxBoxes` in the `running VMs` check, and the `linux guest daemon` check. It was not captured again: that day's answer had a disk space warning and a virtual machine running, and the tests read the 134 GB and the nine quiet checks.
- The version strings of `status-variety.json` and `job-log-variety.json` were moved from 0.6.14 to 0.7.11.
- The three Linux fixtures are real answers of 0.7.11 from agent-vm's own test store, taken while a test run of agent-vm's used that store: the one image that run had made (`shtest-lbusy-8134`, being updated at that moment) was removed from `status-linux.json`, and its count of running virtual machines, which was 1 for that image's update, set to 0. Nothing else in them was edited. `refresh_agentvm_fixtures.sh <agent-vm> linux`, with `AGENTVM_FIXTURE_LINUX_HOME` naming such a store at rest, captures all three with no edit, and refuses a store where something runs or is being changed.
- Not in any capture, since 0.7.11 does not say it: `runningVMs.linuxImages`, the Linux images being built or updated, which the agent-vm after 0.7.11 counts apart. The library reads it as 0 when it is absent, and the tests give it in JSON of their own.

## The move to agent-vm 0.7.12 (2026-10-08)

agent-vm 0.7.12 counts the Linux images being built or updated apart from the macOS virtual machines, as it did the running Linux boxes: `runningVMs.linuxImages` in `status`, and `linuxImages` in doctor's `running VMs` check. Nothing else the app reads changed.

- `version.json` and `packs.json` were captured again from the installed agent-vm 0.7.12 (`refresh_agentvm_fixtures.sh <agent-vm> version packs recipe-check`; `recipe-check.json` came out as it was).
- The five status fixtures were given the new count, `jq -S '.runningVMs.linuxImages = 0'` on `status.json`, `status-variety.json`, `status-empty.json` and `status-linux.json`, and `status-mixed.json` made again of the first and the last.
- `doctor.json` was given `linuxImages: 0` in its `running VMs` check, and the Linux guest daemon's digest as 0.7.12 prints it.
- The version strings of `status-variety.json` and `job-log-variety.json` were moved from 0.7.11 to 0.7.12. `status-linux.json` and `status-mixed.json` keep the versions their images were built with (0.7.4 to 0.7.11): they are those images' records.
- `job-log-linux.json` is new, and is a capture of 0.7.12.

## The move to agent-vm 0.7.13 (2026-10-08)

agent-vm 0.7.13 says in `version --json` what it builds from nothing: `linuxReleases`, the Linux systems `image create --linux` takes (`id`, `name`, `distribution`, `version`), and `imageSizes`, under `macos` and `linux` the sizes it gives a new image and the two rules it holds a disk to (`cpuCount`, `memoryBytes`, `diskBytes`, `minimumDiskBytes`, `minimumDiskGrowthBytes`). The New Image window lists those systems as starts and takes its numbers from there. Nothing else the app reads changed.

- `version.json` and `packs.json` were captured again from the installed agent-vm 0.7.13 (`refresh_agentvm_fixtures.sh <agent-vm> version packs recipe-check`; `recipe-check.json` came out as it was).
- `doctor.json` was given the Linux guest daemon's digest as 0.7.13 prints it.
- The version strings of `status-variety.json` and `job-log-variety.json` were moved from 0.7.12 to 0.7.13. `job-log-linux.json`, `status-linux.json` and `status-mixed.json` keep the versions they were captured with.

## The move to agent-vm 0.7.23 (2026-10-08)

agent-vm 0.7.14 to 0.7.23 keep a deleted box's logs and say so. What an application reads of it: `status --json` has `keptLogs` (`count`, `bytes`, `holdDays`, `directory`: how many deleted boxes' logs the store keeps, what they take, for how many days it keeps a box's logs, and their folder), and `box delete --json`, which printed nothing, prints `deleted`, with `keptLogs` (the folder the box's logs were moved to) when it kept any. Since 0.7.20 `image create --from` makes a copy with no recipe. Nothing else the app reads changed.

- `version.json` and `packs.json` were captured again from the installed agent-vm 0.7.23 (`refresh_agentvm_fixtures.sh <agent-vm> version packs recipe-check`; `recipe-check.json` came out as it was).
- The five status fixtures were given `keptLogs` as an empty store has it, `jq -S '.keptLogs = {bytes: 0, count: 0, directory: "/Users/you/Library/Application Support/agent-vm/Logs", holdDays: 30}'` on `status.json`, `status-variety.json`, `status-empty.json` and `status-linux.json`, and `status-mixed.json` made again of the first and the last. The values are the real answer of 0.7.21 for a store with no kept logs, the folder written as the default store's.
- `doctor.json` was given the Linux guest daemon's digest as 0.7.23 prints it.
- The version strings of `status-variety.json` and `job-log-variety.json` were moved from 0.7.13 to 0.7.23.
- The fake answers `box delete` as 0.7.23 does: `{"deleted": <name>}`, with `keptLogs` when a test leaves the folder's path in the file `kept-logs` of its state folder.

## The move to agent-vm 0.7.26 (2026-10-09)

agent-vm 0.7.24 to 0.7.26 change nothing in the JSON the app reads. What changed is what `image update` does: a tools update replaces a kept recipe that is an older version of one that came with agent-vm, and a guest daemon asked for with the system or the tools is updated first, as an update of its own, so one job reports `boot` and `commit` twice. The installed `Recipes` folder has a file that is not a recipe, `history.json`.

- `version.json` and `packs.json` were captured again from the installed agent-vm 0.7.26 (`refresh_agentvm_fixtures.sh <agent-vm> version packs recipe-check`; `recipe-check.json` came out as it was).
- `doctor.json` was given the Linux guest daemon's digest as 0.7.26 prints it.
- The version strings of `status-variety.json` and `job-log-variety.json` were moved from 0.7.23 to 0.7.26.
- The check of `fixtures/recipes/python` is `python3 --version`, as the recipe's own: it no longer provides `python` without the 3.

## The move to agent-vm 0.7.33 (2026-10-10)

agent-vm 0.7.27 to 0.7.33 change nothing in the JSON the app reads, and add to it. What an application sees:

- A Linux image's or box's `linux` says its kernel's page size, `pageSize`, in bytes. An entry without it was built before 0.7.30, with the cloud image's kernel: 4096.
- `doctor --json` has one more check, `linux kernels` (a `warning`), last, and only when a ready Linux image has a kernel with 4 KiB pages.
- A Debian image is built in two boots: the setup steps that install the kernel with 16 KiB pages, a `shutdown`, `check-boot`, and then the other setup steps, numbered on over both. `image update --system` of a Debian image built before does the same before `system-update`.
- A `notice` may come before the step it is about: what agent-vm found of the Mac's memory before it boots a guest on a kernel with 4 KiB pages, and a box's note at its start. A job refused for the Mac's memory fails before its first step.

What was done to the fixtures:

- `version.json` and `packs.json` were captured again from the installed agent-vm 0.7.33 (`refresh_agentvm_fixtures.sh <agent-vm> version packs recipe-check`; `recipe-check.json` came out as it was).
- `doctor.json` was given the Linux guest daemon's digest as 0.7.33 prints it. It has no `linux kernels` check, as a store with no such image.
- The version strings of `status-variety.json` and `job-log-variety.json` were moved from 0.7.26 to 0.7.33.
- The Linux fixtures were NOT captured again: `status-linux.json`, `status-mixed.json`, `image-info-linux.json` and `box-info-linux.json` are records of images built before 0.7.30, which have no `pageSize`, and `job-log-linux.json` is a build of 0.7.12, in one boot with twelve setup steps. A capture needs a Debian image built by 0.7.32 or later as a job (about 140 MB of downloads). Until then the two-boot build and the update that changes the kernel are in `Tests/54-progress-window.test.sh`, as events made by hand in the order and the words of two real text logs of 0.7.32.

## The move to agent-vm 0.7.39 (2026-10-11)

agent-vm 0.7.34 to 0.7.39 change nothing in the JSON the app reads. What an application sees:

- `box rename <box> <new-name>` and `image rename <image> <new-name>` (0.7.39). With `--json` each prints the record under its new name; a renamed box's record may have `formerNames`, oldest first. The boxes made from a renamed image, and the images built from it, name it by its new name at once.
- A rename that was interrupted makes reading that box or image fail, with a message that names the command which finishes it.
- `--page-size 64k` is accepted for Ubuntu (0.7.37), and the Linux setup steps that can download a kernel may be silent for three hours (0.7.38). The app passes no page size and has no time limit of its own for a job's step.
- `session start --git-only` and what avm remembers of it per folder (0.7.34 to 0.7.36). The app starts no sessions and shows no session reports.

What was done to the fixtures:

- `version.json` and `packs.json` were captured again from the installed agent-vm 0.7.39 (`refresh_agentvm_fixtures.sh <agent-vm> version packs recipe-check`; `recipe-check.json` came out as it was).
- `doctor.json` was given the Linux guest daemon's digest as 0.7.39 prints it.
- The version strings of `status-variety.json` and `job-log-variety.json` were moved from 0.7.33 to 0.7.39.
- No fixture has `formerNames`: none was captured after a rename. The Linux fixtures are as described above for 0.7.33.

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

## The move to agent-vm 0.7.41 (2026-10-11)

What an application sees of agent-vm 0.7.40 and 0.7.41:

- `linuxReleases` in `version --json` lists Debian 13 alone (0.7.41). Ubuntu 26.04 is withheld: it packages no kernel with 16 KiB pages. `image create --linux ubuntu` and `image rebuild --linux ubuntu` are refused before anything is made. The app lists whatever `linuxReleases` holds, so it offers Debian only.
- `--page-size 64k` is refused for every system (0.7.40): a Mac's processor has no 64 KiB pages. The line about it under 0.7.39 above no longer holds. The app passes no page size.
- Ubuntu images and boxes that exist are listed, started and updated as before, and the pack `ubuntu` stays, so `status-linux.json`, `status-mixed.json` and `packs.json` keep theirs.

What was done to the fixtures:

- `version.json`, `packs.json` and `recipe-check.json` were captured again from the installed agent-vm 0.7.41 (`refresh_agentvm_fixtures.sh <agent-vm> version packs recipe-check`). `version.json` now lists one Linux system.
- `doctor.json`: the digest of the Linux guest daemon in the check's detail, by hand.
- `status-variety.json` and `job-log-variety.json`: the version strings, by hand.
- The tests no longer take a second Linux system from `version.json`: the library test gives its own two-system answer, and the New Image test adds a made-up second system to the fake's answer where it needs one.

## The move to agent-vm 0.7.43 (2026-10-12)

agent-vm 0.7.42 and 0.7.43 change avm's terminal interface only, and nothing in the JSON the app reads:

- After a session in a kept box avm asks whether to stop the box (0.7.42), and lists what changed with undo per entry (0.7.43). `connect list --json` has the remembered answer as `remembered.stop`; the app does not run `connect list`.
- A box can so be stopped by avm while the app's window is open, as by `agent-vm box stop` in a terminal.

What was done to the fixtures: `version.json` and `packs.json` captured again from the installed 0.7.43 (versions, paths and digests only), the Linux guest daemon's digest in `doctor.json` and the version strings in `status-variety.json` and `job-log-variety.json` by hand.

## The move to agent-vm 0.7.44 (2026-10-12)

Nothing in the JSON the app reads changed. What an application sees:

- The installer package's agent-vm part is named for its version (`com_abracode_pkg_agent_vm_0_7_44_choice`; the PATH part keeps `com_abracode_pkg_agent_vm_path_choice`). The fake installer (`helpers/fake_install_tools.sh`) names its default part from the version in the package's file name.
- An image build or update whose macOS guest starts again instead of powering off says so in a `notice` event and asks it to shut down again.

What was done to the fixtures: `version.json` and `packs.json` captured again from the installed 0.7.44 (versions, paths and digests only), the Linux guest daemon's digest in `doctor.json` and the version strings in `status-variety.json` and `job-log-variety.json` by hand.

## The move to agent-vm 0.7.54 (2026-10-15)

What an application sees of agent-vm 0.7.45 to 0.7.54:

- `maxBoxNameLength` in `version --json` (0.7.53): the longest box name the store in use allows, since a box's control socket, `<store>/Boxes/<name>/control.sock`, must fit the 103 bytes macOS allows a socket's path. `box create` and `box rename` refuse a longer name; `box start` and `box recreate` refuse a box that already has one. Image names keep the limit of 63.
- Box and image names may have capital letters (0.7.54), case kept as given. Lookups are exact ("no box work, but there is box Work"), a new name that another has in other case is refused, and a change of case only is a rename.
- The guest daemon has the feature `flow-control` (0.7.46). The app reads features only to list them.
- A macOS box under 3 GB of memory is refused by `box create`, `box set` and `box recreate` (0.7.51).

What was done to the fixtures:

- `version.json` and `packs.json` captured again from the installed 0.7.54 (`refresh_agentvm_fixtures.sh <agent-vm> version packs`). `maxBoxNameLength` is 31, the value for the capturing account's default store, not for the `/Users/you` the paths were rewritten to: the tests take the number as it is and change it with a jq edit where they need another.
- The Linux guest daemon's digest in `doctor.json` and the version strings in `status-variety.json` and `job-log-variety.json` by hand.

## The move to agent-vm 0.7.57 (2026-10-16)

What an application sees of agent-vm 0.7.55 to 0.7.57:

- A recipe ticked again for an image built from one that ran a recipe of that name takes the base entry's place in the new image's `recipes` (0.7.56): an image lists each recipe once, in the order a rebuild would run them. Images made before may still list a name twice; nothing rewrites them.
- `image update --tools --input NAME=PATH` (0.7.57) gives a kept recipe's input a new file: the last kept recipe whose record has that input runs its steps and checks again with it, and the image records the new file in that entry's `inputs` (`name`, `file`, `path`, `bytes`, `sha256`), which `status` and `image info` already list. An input no kept recipe has, `--input` without the tools update, and `--input` with `--if-older-than` are refused before anything boots.

What was done to the fixtures:

- `version.json` and `packs.json` captured again from the installed 0.7.57 (`refresh_agentvm_fixtures.sh <agent-vm> version packs`; versions, paths and digests only).
- The Linux guest daemon's digest in `doctor.json` and the version strings in `status-variety.json` and `job-log-variety.json` by hand.
- No fixture has a recipe entry with `inputs`: the images of `status.json` were built before agent-vm listed their recipes (`dev-xcode` records its one recipe under `recipe`, with `inputs` there). The tests give an image `recipes` with `inputs` in JSON of their own.

## The move to agent-vm 0.7.59 (2026-10-16)

What an application sees of agent-vm 0.7.58 and 0.7.59:

- An image made with `--from` records in `derivedFrom` when its base was built (`baseCreatedAt`) and what the base's recipes installed (`baseRecipes`). When the base was built again since, or has other recipes, input files or parameter values, `needs` has `{"kind": "rebuild", "reason": "base-rebuilt" | "base-recipes-changed", "base": "<name>"}` in `status`, `image list` and `image info`; `image rebuild <image>` clears it. Not for a plain system or tools update of the base, a newer built-in recipe, or a parameter a newer recipe added. An image made before 0.7.59, and one whose base is gone, not ready or itself, has no such need.
- A rebuild no longer runs a recipe the image inherited when the start has a recipe of that name (0.7.58). Nothing the app reads changed for it.

What was done to the fixtures:

- `version.json` and `packs.json` captured again from the installed 0.7.59 (`refresh_agentvm_fixtures.sh <agent-vm> version packs`; versions, paths and digests only).
- The Linux guest daemon's digest in `doctor.json` and the version strings in `status-variety.json`, `job-log-variety.json`, the fake installer and the tests by hand.
- No fixture has a `rebuild` need, `baseCreatedAt` or `baseRecipes`: the images of the captures were made before 0.7.59. The tests add the need with a jq edit. The fake starts `image rebuild` as a job, as agent-vm does.

## The move to agent-vm 0.8.1 (2026-10-17)

What an application sees of agent-vm 0.8.0 and 0.8.1:

- A Linux image or box can have a screen: a recipe with `"screen": true` (today only `linux-desktop`, the XFCE desktop) gives it one. The image records `screen: true` in `status`, `image list` and `image info`, and a box copies it when it is made or recreated, as `box.screen` in `status`, `box list` and `box info`. The key is `true` or absent, never `false`, and a macOS image or box never has it, yet always has a screen. `recipe check` says `screen: true` of such a recipe.
- `box view` shows a running Linux box that has a screen (0.8.0), with no Type Password button; `image view` boots a Linux image that has one and shows it (0.8.1). Its job's steps are `boot`, `window` and `shutdown`. Before the shutdown the image's seal checks run again, and an image that no longer passes them, or that powered itself off during the view, is marked failed (`failure` "after image view: ..."), with a notice, and the job fails.

What was done to the fixtures:

- `version.json` and `packs.json` captured again from the installed 0.8.1 (`refresh_agentvm_fixtures.sh <agent-vm> version packs`; versions, paths and digests only).
- The Linux guest daemon's digest in `doctor.json` and the version strings in `status-variety.json`, `job-log-variety.json`, the fake installer and the tests by hand. The install test's newer release moved from 0.8.0 to 0.8.2, so that it is still newer than the minimum.
- No capture has a `screen` key: their images and boxes were made before 0.8.0, and none has a desktop. One Linux image and one Linux box were given it by hand, so that both kinds of Linux record are tested: the image `deb-agents` in `status-linux.json` and `image-info-linux.json`, and the box `lb` in `status-linux.json` and `box-info-linux.json`; `deb`, `ub` and `ub-agents` keep none. `status-mixed.json` was made again from `status.json` and `status-linux.json`. `lb` was made from `deb`, which has no screen here. A real box has the screen its image had when the box was made or recreated, so this pair needs an image built again without the desktop under the same name; the app reads the box's own, which is what the pair tests. Run in this folder:

```sh
/usr/bin/jq -S '(.images[] | select(.name == "deb-agents")).screen = true | (.boxes[] | select(.box.name == "lb")).box.screen = true' status-linux.json > status-linux.new && /bin/mv status-linux.new status-linux.json
/usr/bin/jq -S '.screen = true' image-info-linux.json > image-info-linux.new && /bin/mv image-info-linux.new image-info-linux.json
/usr/bin/jq -S '.box.screen = true' box-info-linux.json > box-info-linux.new && /bin/mv box-info-linux.new box-info-linux.json
/usr/bin/jq -S -s '.[1] as $linux | .[0] | .images += $linux.images | .boxes += $linux.boxes' status.json status-linux.json > status-mixed.new && /bin/mv status-mixed.new status-mixed.json
```

A capture of `linux` (`refresh_agentvm_fixtures.sh`) replaces these files, and the edit is to be made again unless the store captured has a desktop image and box of its own.

## Desktop recipes of agent-vm 0.8.2 and 0.8.3 (2026-10-17)

Written before 0.8.2 and 0.8.3 were installed, so the minimum is still 0.8.1 and nothing was captured again. What an application sees of them:

- 0.8.2 renames `linux-desktop` to `linux-xfce` and `linux-desktop-extras` to `linux-xfce-extras`, and the refusal of a Linux image or box without a screen names "a desktop recipe, such as linux-xfce".
- 0.8.3 adds `linux-gnome` and `linux-kde`, both with `"screen": true` and a parameter `polkit` (`deny`, the default, or `debian`), so no JSON key is new. A Linux start is offered 11 shipped recipes, a macOS start 9.
- `box create`, `box set` and `box recreate` note a Linux box with a screen under 4 GB as small.

What was done to the tests:

- The fake's refusal of `box view` for a Linux box without a screen is in 0.8.2's words.
- `fixtures/recipes` has no desktop recipe: its lists of recipes stay as the tests count them. A test that needs a desktop recipe writes one of its own with `"screen": true` and adds it with the window's Add a Recipe File... button.

## The move to agent-vm 0.8.4 (2026-10-19)

0.8.2 and 0.8.3 are as described just above. 0.8.4 changes the window of `box view`, `image view` and an image setup, and nothing in the JSON the app reads:

- The window can be resized and go full screen, and the picture follows it. A view-only window scales the picture; an interactive one gives the guest's display the window's size in points (macOS, GNOME and KDE take it, XFCE stays scaled), and sets it back to 1280 by 800 when it closes.

What was done to the fixtures:

- `version.json` and `packs.json` captured again from the installed 0.8.4 (`refresh_agentvm_fixtures.sh <agent-vm> version packs recipe-check`; versions, paths and digests only; `recipe-check.json` came out as it was). Captured from the installed agent-vm, not from the build in `../agent-vm/.build/signed/release`: that one writes its build paths, and a guest daemon requirement that is a code hash instead of the Developer ID one, into `version.json`.
- The Linux guest daemon's digest in `doctor.json` and the version strings in `status-variety.json`, `job-log-variety.json` and the tests by hand. The install test needs nothing: it takes its releases from `AGENTVM_MIN_VERSION`.

## The move to agent-vm 0.8.6 (2026-10-20)

0.8.5 attaches a Linux guest's disk through the Mac's file cache (the caching mode `cached`): a kernel with 4 KiB pages no longer loses memory after the guest reads its disk through the raw device. 0.8.6 offers Ubuntu 26.04 again, second in `linuxReleases`, and drops what went with holding it back: doctor's "linux kernels" check (never in a capture here), the 4 KiB note at `box start` and before `image create`, and the memory notice and refusal before an image job boots a 4 KiB kernel. Nothing the app reads changed shape.

What was done to the fixtures:

- `version.json`, `doctor.json` and `packs.json` captured again from the installed 0.8.6 (`refresh_agentvm_fixtures.sh <agent-vm> version doctor packs recipe-check`; `recipe-check.json` came out as it was). `version.json` lists Ubuntu 26.04 after Debian 13. In `doctor.json` only the Linux guest daemon's digest moved; the free space on the store's volume is kept at the earlier capture's 134 GB, which a test names.
- The version strings in `status-variety.json`, `job-log-variety.json` and the tests by hand.

What was done to the tests:

- New Image (file 60) checks that Ubuntu 26.04 is a start, with its key and the command it builds; the case with a system the app has not seen adds it to every listed system instead of to the first only.
- The progress window's notice said before its step (file 54) uses the box start's memory warning and a refusal for free disk space as its examples, in place of the memory notice and refusal agent-vm no longer has.
