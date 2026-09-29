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
| `00-bundle.test.sh` | what `Info.plist` and `Command.json` declare |
