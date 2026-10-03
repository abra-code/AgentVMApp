# AgentVM.app tests

The tests run the app's real handler scripts in omctest, AppletBuilder's mock OMC environment: every test file gets its own scratch folder, home folder and window, and the window is a recording that the tests read back.

```sh
AB=../OMC/Distribution/AppletBuilder.app/Contents/Resources/Agents/appletbuilder
"$AB" test AgentVM.app --tests "$PWD/Tests"             # every file
"$AB" test AgentVM.app --tests "$PWD/Tests" --filter '00-*'
```

- Pass `--tests` as an absolute path: the fakes are found relative to it, and a relative path breaks them in the handlers' working directory.
- A coding agent must run the suite with its sandbox off.
- `update-agentvmapp.sh` runs the same suite before it signs.

## Files

| File | What it covers |
|---|---|
| `lib.test.agentvm.sh` | sourced by every file: the guards that keep a test out of the real home folder, and the app's accessors |
| `00-bundle.test.sh` | what `Info.plist` and `Command.json` declare: the main command and its one window, and the command that asks for a project folder |
| `10-agentvm-library.test.sh` | `lib.agentvm.sh`: which agent-vm runs, when it can be used, the store setting, error messages, and the rows read from agent-vm's JSON, against the fake and the fixtures |
| `11-agentvm-contract.test.sh` | the library against a real agent-vm on an empty store: the JSON fields the fixtures have are still there, a job's record and log included (one job that can only fail) |
| `20-main-window.test.sh` | the main window: the face it shows, the box and image cards, each list's selection and its detail pane, Settings, the poll loop, activation and closing |
| `21-maintenance.test.sh` | what needs doing to a box or an image: the mark on its card, the lines in its detail pane, and the state line of a running box nobody uses |
| `30-image-detail.test.sh` | the image detail pane's measured facts (`image info`) and when they are read, Show in Finder for an image and a box, Delete and its question |
| `31-box-detail.test.sh` | the box detail pane and the bar under the list: the space (`box info`) and when it is read, which buttons each state enables, View, Open Shell and Run an Agent in Terminal... (their `.command` files), Recreate and Delete with their questions |
| `32-box-network.test.sh` | a box's network window: Details... on the box pane, one window per box, the Settings tab (the rules read, edited and applied in one call, Discard, the mode), the Activity tab (the connections grouped per host, Allow Selected Host and its question), and what it shows when the box or agent-vm is gone |
| `33-box-programs.test.sh` | a box's programs window: Details... on the box pane, one window per box, the program log newest first, each program's status (running, no end recorded, stopped at a prompt), the prompt notices with the Full Disk Access line, and when the window reads |
| `50-jobs.test.sh` | the library's job functions: a box started and stopped as a job, the rows read from `status`, `job list` and `job log` (a real record and one job in every state), a job's events, cancel and forget, and what never reaches agent-vm |
| `51-box-start-stop.test.sh` | Start and Stop in the box pane: the job each starts, what the card, the pane and its buttons show while a job holds the box, the question Stop asks for a box in use, what is said when a job the window saw running has failed, and the toast when one ends well |
| `52-launch-report.test.sh` | what ended while the app was closed: the time the app keeps of its last reading, and the report a main window makes on opening of the image jobs and downloads that ended after it |
| `53-image-jobs.test.sh` | an image a job holds: what its card and pane say while it is built, updated, built again or set up, or waits to be, that Delete is off meanwhile, and what is said when the job ends; and an image that a command without a job is changing |
| `54-progress-window.test.sh` | a job's progress window: Progress... in the box and image panes, one window per job and only when this run of the app asked for it, what it shows of a job that waits, runs, moves on and ends (steps, the bar, the end of the log, a notice), its poll loop, and Stop with its question |
| `55-update-window.test.sh` | an image's update window: Update... in the image pane, one window per image and only when this run of the app asked for it, what it says about macOS, the tools and the guest daemon and which it ticks, Check Now, what stands in the way of an update, and Update (the job with the parts ticked, the command line shown, the progress window, the main window following the job) |
| `56-access-window.test.sh` | an image's Full Disk Access guide: Set Up... in the image pane, one window per image and only when this run of the app asked for it, what it says about an image that needs the grant and one that has it, Open the Image (the setup job, the command line shown), the four steps following the job's steps, how a setup ended, a setup started elsewhere, what stands in the way, and the question the main window asks when an update took an image's grant away |
| `60-new-image.test.sh` | the New Image window: the library under it (what a build from an image needs to know, the restore files, the recipes that come with agent-vm and what they ask for, the arguments of `image create` and their checks), the two buttons that open it, one window at a time and only when this run of the app asked for it, its five steps with what each keeps and refuses, and Build (the job, the command line shown, the progress window, the main window following the job) |
| `61-get-macos.test.sh` | the Get macOS window: the library under it (what Apple offers, as one row; the download as a job), the two buttons that open it, one window at a time and only when this run of the app asked for it, what it says for a restore file that is not downloaded, partly downloaded, downloaded or too big for the room left, when Apple cannot be asked, and while a download runs, and Download: the job it starts, its progress window, and the main window following it |
| `62-agent-keys.test.sh` | the Agent Keys window: the agents' keys as rows, Agent Keys... in Settings, one window at a time, what it says for a key that is stored, stored by another agent-vm or not stored, Store and Remove... with its question, and that a typed key reaches agent-vm's stdin and nothing else |
| `70-new-box.test.sh` | the New Box window: the library under it (the agents that come with agent-vm and the hosts they need, the arguments of `box create` and their checks), the main window's two buttons, one window at a time and only when this run of the app asked for it, the four steps with what each keeps and refuses (the image, the network with the agents' hosts already allowed, the name and sizes), what stands in the way, and Create: the box made with the command line shown, the job that starts it, and the main window showing the box |
| `80-get-started.test.sh` | the Get started face of the main window: its six steps (agent-vm, this Mac can run boxes, a macOS restore file, an image, Full Disk Access, a box), each with a state, a fact and a button, in every state of a first use, what the buttons open, and the move to Status once a box exists |
| `90-url-scheme.test.sh` | the `agentvm://` URL scheme: which URLs are routed (status, a box, an image), what they show in an open main window, how a main window is opened for one, what another run of the app left, and that a URL changes nothing |
| `91-no-window.test.sh` | every handler run without its window, as a URL naming a command would run it, does nothing: no agent-vm call, nothing opened or written, no pending question touched |
| `98-command-wiring.test.sh` | every command has the exact script the engine looks for, every reference resolves, every script is reachable |
| `helpers/fake_agent_vm.sh` | agent-vm, answered from `fixtures/agentvm/` |
| `helpers/fake_ps.sh`, `helpers/fake_sleep.sh`, `helpers/fake_open.sh` | the process list (a box's owner), the poll loop's wait, and Finder and Terminal (Show in Finder, the `.command` files), answered and recorded |
| `helpers/refresh_agentvm_fixtures.sh` | captures `fixtures/agentvm/` from a real agent-vm |
| `fixtures/recipes/` | seven recipes named as agent-vm's own, made by hand: each has its description and the input files and parameters it declares, and steps that do nothing. `AGENTVM_APP_RECIPES` points the library at them |
| `fixtures/agents.json` | agent-vm's list of agents, made by hand: three as agent-vm's own (id, name, the hosts each needs), and three that test what is left out. `AGENTVM_APP_AGENTS` points the library at it |

## After an agent-vm update

`update-agentvmapp.sh` sets the library's `AGENTVM_MIN_VERSION` to the version of the agent-vm working tree beside this repository, and the library test then fails until the fixtures come from that version:

```sh
Tests/helpers/refresh_agentvm_fixtures.sh ../agent-vm/.build/signed/release/agent-vm
```

Then remake `status-variety.json` as `fixtures/agentvm/README.md` shows, and fix the tests that name what changed in the store. The contract test takes the first build in `../agent-vm/.build/signed/release` or `.../work` that is new enough, or `AGENTVM_APP_CONTRACT_AGENT_VM`.
