# amux — Claude Code Multiplexer

Run dozens of Claude Code agents in parallel, unattended, from your browser or phone. No build step, no external services — just Python 3 and tmux.

<video src="amux.mp4" width="920" autoplay loop muted playsinline></video>

```bash
git clone <repo> && cd amux && ./install.sh
amux register myproject --dir ~/Dev/myproject --yolo
amux start myproject
amux serve   # → https://localhost:8822
```

---

## What it does

- **Self-healing** — auto-compacts context, restarts on corruption, unblocks stuck prompts
- **Coordination** — agents discover peers, delegate tasks, and claim work off a shared board via a simple REST API
- **Works everywhere** — web dashboard, PWA on your phone, or plain `tmux attach`

---

## Web Dashboard

- **Session cards** — live status (working / needs input / idle), token stats, quick-action chips
- **Peek mode** — full scrollback with search, file previews, and a send bar
- **Workspace** — full-screen tiled layout to watch multiple agents side by side
- **Board** — kanban backed by SQLite, with atomic task claiming, iCal sync, and custom columns
- **Reports** — pluggable spend dashboards pulling from vendor billing APIs

---

## Agent Orchestration

```bash
# Send a task to another session
curl -sk -X POST -H 'Content-Type: application/json' \
  -d '{"text":"implement the login endpoint and report back"}' \
  $AMUX_URL/api/sessions/worker-1/send

# Atomically claim a board item
curl -sk -X POST $AMUX_URL/api/board/PROJ-5/claim

# Watch another session's output
curl -sk "$AMUX_URL/api/sessions/worker-1/peek?lines=50" | \
  python3 -c "import json,sys; print(json.load(sys.stdin).get('output',''))"
```

Agents get the full API reference in their global memory, so plain-English orchestration just works.

---

## Self-Healing

| Condition | Action |
|-----------|--------|
| Context < 20% | Sends `/compact` (5-min cooldown) |
| `redacted_thinking … cannot be modified` | Restarts + replays last message |
| Stuck waiting + `CC_AUTO_CONTINUE=1` | Auto-responds based on prompt type |
| YOLO session + safety prompt | Auto-answers (never fires on model questions) |

---

## CLI

```bash
amux register <name> --dir <path> [--yolo] [--model sonnet]
amux start <name>
amux stop <name>
amux attach <name>          # attach to tmux
amux peek <name>            # view output without attaching
amux send <name> <text>     # send text to a session
amux exec <name> -- <prompt> # register + start + send in one shot
amux ls                     # list sessions
amux serve                  # start web dashboard
```

Session names support prefix matching — `amux attach my` resolves to `myproject` if unambiguous.

---

## Install

Requires `tmux` and `python3`.

```bash
git clone <repo> && cd amux
./install.sh   # installs amux (alias: cc) to /usr/local/bin
```

### HTTPS

Auto-generates TLS in order: Tailscale cert → mkcert → self-signed fallback. For phone access, Tailscale is the easiest path.

---

## Security

Local-first. No auth built in — use Tailscale or bind to localhost. Never expose port 8822 to the internet.
