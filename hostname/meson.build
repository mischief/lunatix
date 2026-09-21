# SPDX-License-Identifier: ISC
install_data('hostname.lua',
  rename: 'hostname',
  install_dir: get_option('bindir'),
  install_mode: 'rwxr-xr-x',
)

test('hostname', sh, args: [meson.current_source_dir() / 'test.sh'])
