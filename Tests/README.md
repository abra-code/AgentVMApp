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
| `11-agentvm-contract.test.sh` | the library against a real agent-vm on an empty store: the JSON fields the fixtures have are still there |
| `20-main-window.test.sh` | the main window: the face it shows, the box and image cards, each list's selection and its detail pane, Settings, the poll loop, activation and closing |
| `21-maintenance.test.sh` | what needs doing to a box or an image: the mark on its card, the lines in its detail pane, and the state line of a running box nobody uses |
| `30-image-detail.test.sh` | the image detail pane's measured facts (`image info`) and when they are read, Show in Finder for an image and a box, Delete and its question |
| `31-box-detail.test.sh` | the box detail pane's actions: the space (`box info`) and when it is read, which buttons each state enables, View and View and Control, Open Shell and Run an Agent in Terminal... (their `.command` files), Recreate and Delete with their questions |
| `98-command-wiring.test.sh` | every command has the exact script the engine looks for, every reference resolves, every script is reachable |
| `helpers/fake_agent_vm.sh` | agent-vm, answered from `fixtures/agentvm/` |
| `helpers/fake_ps.sh`, `helpers/fake_sleep.sh`, `helpers/fake_open.sh` | the process list (a box's owner), the poll loop's wait, and Finder and Terminal (Show in Finder, the `.command` files), answered and recorded |
| `helpers/refresh_agentvm_fixtures.sh` | captures `fixtures/agentvm/` from a real agent-vm |

## After an agent-vm update

`update-agentvmapp.sh` sets the library's `AGENTVM_MIN_VERSION` to the version of the agent-vm working tree beside this repository, and the library test then fails until the fixtures come from that version:

```sh
Tests/helpers/refresh_agentvm_fixtures.sh ../agent-vm/.build/signed/release/agent-vm
```

Then remake `status-variety.json` as `fixtures/agentvm/README.md` shows, and fix the tests that name what changed in the store. The contract test takes the first build in `../agent-vm/.build/signed/release` or `.../work` that is new enough, or `AGENTVM_APP_CONTRACT_AGENT_VM`.
