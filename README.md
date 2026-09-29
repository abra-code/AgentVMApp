# AgentVM

AgentVM.app is a Mac app for making and looking after [AgentVM](https://github.com/abra-code/agent-vm) images and boxes: the macOS virtual machines that coding agents run in, isolated from your Mac. It is a companion to the `agent-vm` and `avm` command line tools, not a replacement: it leads you through first use (a macOS restore file, the first images, the one permission you grant by hand, a first box), then shows what exists and what runs, with the everyday actions one or two clicks away. Agents themselves run in Terminal (`avm`) or in [Cadabra](https://github.com/abra-code/AIChatApp).

**Status: in development.** The app does not do anything useful yet.

## Requirements

- macOS 27 or later, on a Mac with Apple silicon. The app does not open anywhere else.
- `agent-vm`, installed for your user account in `~/.local/bin`. The app offers to download and install it when it is missing or too old. Terminal, Cadabra and this app all run that one copy.

## How it works

AgentVM.app is an [OMC](https://github.com/abra-code/OMC) applet: its windows are [ActionUI](https://github.com/abra-code/ActionUI) JSON, and its actions are shell scripts that run `agent-vm` and read its `--json` output. It keeps no copy of what agent-vm knows, so whatever you do in Terminal or in Cadabra shows up here.

## Building

The repository holds the applet's own files; the OMC engine inside the bundle is installed by AppletBuilder. With AppletBuilder in `/Applications` or in `../OMC/Distribution`:

```sh
./update-agentvmapp.sh              # install the engine, thin to arm64, run the tests, sign (ad hoc)
./update-agentvmapp.sh --skip-tests # the same without the tests
```

The tests run with AppletBuilder's `appletbuilder test`; `Tests/README.md` says how.

## License

Apache License 2.0, as agent-vm. See `LICENSE`.
