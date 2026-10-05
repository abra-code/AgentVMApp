# AgentVM app
![AgentVM Icon](Icon/AgentVM-macOS-256x256@1x.png)

AgentVM.app is a Mac app for creating and managing [AgentVM](https://github.com/abra-code/agent-vm) images and boxes: the macOS virtual machines that AI coding agents run in, isolated from your Mac. It is a companion to the `agent-vm` and `avm` command line tools: it guides you through setup and first use (a macOS restore file, the first images, an optional permission you grant by hand, a first box), then shows what exists and what runs, with the everyday actions one or two clicks away. Agents themselves run in Terminal (`avm`) or in [Cadabra](https://github.com/abra-code/AIChatApp).

## Requirements

- macOS 27 or later, on a Mac with Apple silicon. The app does not open anywhere else.
- `agent-vm`, installed for your user account in `~/.local/bin`. The app offers to download and install it when it is missing or too old. Terminal, Cadabra and this app all run that one copy.

## Full Disk Access

[Apple has said](https://developer.apple.com/news/?id=p6zjojqw) that Full Disk Access largely sidesteps the privacy controls of macOS, that it was meant for apps such as backup tools, and that granting it will come to take a very explicit action by the user. It named AI agents as the reason.

AgentVM is the other way to run an AI agent.

- **On your Mac**, AgentVM neither needs nor asks for Full Disk Access. The agent runs in a box and sees only the project folder you share. That is the opposite of Apple's concern that an agent on the Mac has access to everything. Do not give an agent Full Disk Access on your Mac - put it in a VM box instead.

- **Inside an image, Full Disk Access is optional.** The app's guide (Set Up... on an image) grants it to `agent-vm-guest`, the program that starts everything in a box. That grant covers the box's own disk, which holds nothing of yours. Without it boxes still work: only a program that opens the box account's Desktop, Documents or Downloads waits, on a question macOS asks on the box's screen.

## How it works

AgentVM.app is an [OMC](https://github.com/abra-code/OMC) applet: its windows are [ActionUI](https://github.com/abra-code/ActionUI) JSON, and its actions are shell scripts that run `agent-vm` and read its `--json` output. It keeps no copy of what agent-vm knows, so whatever you do in Terminal or in Cadabra shows up here.

## Links

Other apps and scripts can open AgentVM.app at a place:

```sh
open agentvm://status          # the main window
open agentvm://box/<name>      # with that box selected
open agentvm://image/<name>    # with that image selected
```

A link only shows; it never changes a box or an image.

## Building

The repository holds the applet's own files; the OMC engine inside the bundle is installed by AppletBuilder. With AppletBuilder in `/Applications` or in `../OMC/Distribution`:

```sh
./update-agentvmapp.sh              # install the engine, thin to arm64, run the tests, sign (ad hoc)
./update-agentvmapp.sh --skip-tests # the same without the tests
```

The tests run with AppletBuilder's `appletbuilder test`; `Tests/README.md` says how.

## License

Apache License 2.0, as agent-vm. See `LICENSE`.
