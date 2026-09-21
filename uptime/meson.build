# SPDX-License-Identifier: ISC
install_data('uptime.lua',
  rename: 'uptime',
  install_dir: get_option('bindir'),
  install_mode: 'rwxr-xr-x',
)

test('uptime', sh, args: [meson.current_source_dir() / 'test.sh'])
