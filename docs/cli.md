# `unchair` CLI (optional)

Tiny local operator tool. Talks to the running menu-bar app over a Unix socket —
it does **not** reimplement BreakEngine.

```bash
unchair help          # also: unchair -h / --help / no args
unchair status
unchair debt
unchair break start
unchair postpone 15m
unchair presentation 1h
unchair presentation off
unchair history today
unchair doctor
```

## Build / install

```bash
xcodegen generate
xcodebuild -scheme UnchairCLI -configuration Release -derivedDataPath /tmp/UnchairCLI
cp /tmp/UnchairCLI/Build/Products/Release/unchair /usr/local/bin/unchair
```

The Unchair app must be running. Socket: `~/Library/Application Support/Unchair/control.sock` (mode `0600`).

## Security

- No secret output (MQTT passwords never appear)
- No remote listen — Unix socket only
- Cannot mark a break completed
- Cannot fake movement verification

## Doctor sample

```text
Camera .............. OK
Vision .............. OK
Scheduler ........... OK
History ............. 12 records
MQTT ................ OK
OpenMetrics ......... Off
Movement debt ....... 37m
Human ............... questionable
```
