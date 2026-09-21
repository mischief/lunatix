# SPDX-License-Identifier: ISC
# The unix programs POSIX never named. Needs luaposixcli installed: these
# use its modules (luaposixcli.util, .term, .zlib) and its ps.list.
project('lunatix', meson_version: '>=1.1')

lua_name = get_option('lua')
lua_ver = lua_name.replace('lua', '')
lua_mod_dir = get_option('datadir') / 'lua' / lua_ver

stylua = find_program('stylua', required: false)
if stylua.found()
  run_target('format',
    command: [stylua, meson.project_source_root()],
  )
endif

lua_prog = find_program(lua_name)
sh = find_program('sh')

install_data(
  'lunatix/auth.lua', 'lunatix/http.lua', 'lunatix/tcp.lua',
  'lunatix/zmodem.lua',
  install_dir: lua_mod_dir / 'lunatix',
)

install_data(
  'lunatix/crypto/hashstate.lua', 'lunatix/crypto/sha1.lua',
  'lunatix/crypto/sha256.lua', 'lunatix/crypto/sha512.lua',
  install_dir: lua_mod_dir / 'lunatix' / 'crypto',
)

foreach p : ['ping', 'top', 'sz', 'rz', 'fetch', 'gzip', 'mount', 'umount', 'reboot', 'dmesg',
    'sum', 'sync', 'killall',
    'login', 'su', 'getty']
  subdir(p)
endforeach
