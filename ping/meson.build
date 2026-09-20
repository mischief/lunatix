# SPDX-License-Identifier: ISC
install_data('ping.lua',
  rename: 'ping',
  install_dir: get_option('bindir'),
  install_mode: 'rwxr-xr-x',
)

test('ping', sh, args: [meson.current_source_dir() / 'test.sh'], timeout: 30)
