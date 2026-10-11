# AgentVM app
![AgentVM Icon](Icon/AgentVM-macOS-256@1x.png)

AgentVM.app is a Mac app for creating and managing [AgentVM](https://github.com/abra-code/agent-vm) images and boxes: the virtual machines, running macOS or Linux, that AI coding agents run in, isolated from your Mac. It is a companion to the `agent-vm` and `avm` command line tools: it guides you through setup and first use (the first images, a macOS restore file and an optional permission you grant by hand for a macOS image, a first box), then shows what exists and what runs, with the everyday actions one or two clicks away. Agents themselves run in Terminal (`avm`) or in [Cadabra](https://github.com/abra-code/AIChatApp).

## Requirements

- macOS 27 or later, on a Mac with Apple silicon. The app does not open anywhere else.
- `agent-vm`, installed for your user account in `~/.local/bin`. The app offers to download and install it when it is missing or too old. Terminal, Cadabra and this app all run that one copy.

## Full Disk Access

[Apple has said](https://developer.apple.com/news/?id=p6zjojqw) that Full Disk Access largely sidesteps the privacy controls of macOS, that it was meant for apps such as backup tools, and that granting it will come to take a very explicit action by the user. It named AI agents as the reason.

AgentVM is the other way to run an AI agent.

- **On your Mac**, AgentVM neither needs nor asks for Full Disk Access. The agent runs in a box and sees only the project folder you share. That is the opposite of Apple's concern that an agent on the Mac has access to everything. Do not give an agent Full Disk Access on your Mac - put it in a VM box instead.

- **Inside a macOS image, Full Disk Access is optional.** The app's guide (Set Up... on an image) grants it to `agent-vm-guest`, the program that starts everything in a box. That grant covers the box's own disk, which holds nothing of yours. Without it boxes still work: only a program that opens the box account's Desktop, Documents or Downloads waits, on a question macOS asks on the box's screen. A Linux image has no such permission, and nothing in its boxes waits for one.

## Linux images and boxes

Since version 1.1 the app makes and runs Linux images and boxes beside macOS ones. A Linux box starts in seconds and is for work that does not need a Mac.

- **A first image without downloading macOS.** New Image... lists the Linux systems your agent-vm builds (Debian 13 and Ubuntu 26.04 today), each made from the distribution's own cloud image, which agent-vm downloads when it is needed. That needs no macOS restore file. How long it takes is mostly the downloads (the cloud image, and for Debian a kernel with 16 KiB memory pages): a few minutes on a fast connection.
- **Tools.** They are added as for a macOS image, by ticking recipes: in the same build, or later in a copy of the image. The window lists the recipes that fit the system you start from.
- **Boxes.** A Linux box is made, started, stopped, recreated and deleted like a macOS box, with the same network rules and shared folder. Connect opens a shell in it and Run an Agent starts an agent in it. It has no screen, so it has no View.
- **Updates.** Update... on a Linux image installs the distribution's package updates, the tools' own updates and the newer guest daemon, the part of agent-vm that runs in the image.
- **The kernel's memory pages.** A Linux image is built with a kernel whose memory pages are 16 KiB, the Mac's own size, or larger. The image and box panes say which each has.
- **Told apart at a glance.** The card of a Linux image or of a running Linux box is teal (a stopped box: slate), and every pane says which system an image or a box runs.
- **Beside two macOS boxes.** macOS runs at most two macOS virtual machines at once. Linux ones are not counted among them, and the app never holds a Linux box or build back for that limit.

What the app leaves to `agent-vm` in Terminal:

- an image from a cloud image file of your own (`image create --linux ... --cloud-image`), and building an image again from a fresh start (`image rebuild`);
- a program run as root in a Linux box, such as installing a system package (`agent-vm exec --user root`);
- copying files into a box (`box send`).

The rest is in `Docs/linux-boxes.md` of the [agent-vm](https://github.com/abra-code/agent-vm) repository: Debian or Ubuntu, the account and root, the network, the shared folder.

## Logs

agent-vm records what it started in a box, what the box contacted and what was refused, in files on your Mac that nothing in a box can change. A box's Network and Programs windows show the recent connections and programs; for everything else the app shows where the files are.

- **A box and an image** each have a Logs row: the box's log files in Finder, and for an image the log of the job that last built or updated it (a Linux image also has the console of its system).
- **A build, an update or a start** has Show Log in Finder in its progress window: every step and line of the job, which agent-vm keeps for a week.
- **A deleted box** leaves its logs behind, for 30 days unless you change it. The button under the box list shows them in Finder, and Settings says how many are kept and what they take, removes them, and sets for how long they are kept.
- **Where the Logs Are...,** in How to Use a Box, says which file answers which question, and gives the Terminal commands that read them.

## How it works

AgentVM.app is an [OMC](https://github.com/abra-code/OMC) applet: its windows are [ActionUI](https://github.com/abra-code/ActionUI) JSON, and its actions are shell scripts that run `agent-vm` and read its `--json` output. It keeps no copy of what agent-vm knows, so whatever you do in Terminal or in Cadabra shows up here.

## Links

Other apps and scripts can open AgentVM.app at a place:

```sh
open agentvm://status          # the main window
open agentvm://box/<name>      # with that box selected
open agentvm://image/<name>    # with that image selected
open agentvm://logs            # the Where the Logs Are window
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
