# lunatix

The unix programs POSIX never named, in Lua 5.4.

[luaposixcli](https://github.com/mischief/luaposixcli) is the POSIX half:
the utilities the standard names, and the modules under `luaposixcli`.
This is the rest — what unix grew anyway.

## Programs

| program | what it is |
| --- | --- |
| `ping` | ICMP echo |
| `top` | the `ps` table, repainting |
| `gzip`, `gunzip`, `zcat` | the gzip container over DEFLATE |
| `sz`, `rz` | ZMODEM send and receive over a terminal |
| `fetch` | an HTTP GET |

## Modules

| module | what it is |
| --- | --- |
| `lunatix.zmodem` | the protocol, sans-io: feed bytes, pull bytes, step it |
| `lunatix.http` | an HTTP/1.1 client, handed its transport |
| `lunatix.tcp` | that transport, over sockets, and a resolver |

## Building

```
meson setup build
ninja -C build
meson test -C build
```

luaposixcli must be installed, or its tree beside this one: these programs
use `luaposixcli.util`, `luaposixcli.term`, `luaposixcli.zlib` and `ps.list`.
The tests look for it at `../os`, which `LUAPOSIXCLI` overrides.
