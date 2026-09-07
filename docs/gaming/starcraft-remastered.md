# StarCraft: Remastered

Cerberus provides a Nix-managed Lutris bootstrap and launcher for the modern
Battle.net release of StarCraft: Remastered. Battle.net credentials, downloads,
and the Wine prefix stay mutable outside the Nix store at:

```text
/home/warby/Games/battlenet
```

## First run

After rebuilding Cerberus, start the desktop entry **StarCraft: Remastered** or
run:

```bash
starcraft-remastered install
```

Lutris confirms the destination, downloads the official Battle.net installer,
and creates the shared 64-bit prefix. The Battle.net setup executable runs with
`--quiet`; its background client processes are excluded from Lutris's installer
monitor so setup can finish without the old Continue/close-window sequence.
Then run:

```bash
starcraft-remastered play
```

Sign in, install StarCraft: Remastered when Battle.net opens its `S1` product
page, and keep the default location inside the shared prefix. Future launches
go directly through the same Lutris entry with GameMode enabled.

Battle.net remembers the authenticated session in the mutable prefix. The
Bitwarden desktop/SSH-agent integration does not expose vault fields to Wine,
so credentials are deliberately not placed in launcher arguments, Nix store
paths, generated YAML, or logs.

## Commands

```text
starcraft-remastered install  bootstrap or register the shared prefix
starcraft-remastered play     launch SC:R
starcraft-remastered status   inspect prefix and Lutris registration
starcraft-remastered debug    launch with Lutris debug logging
scbw ...                      short alias for the same command
```

The installer never removes an existing prefix. If Battle.net is already
present, `install` only registers it with Lutris. A partial prefix is reused so
the interactive installer can repair it without deleting downloaded data.

## Classic bot development

BWAPI targets classic Brood War 1.16.1 and cannot inject into Remastered. Its
OpenBW, BWAPI, and MinGW build dependencies are therefore disabled by default.
Enable them separately when needed:

```nix
host.scbw.botDev.enable = true;
```
