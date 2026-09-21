# SPDX-License-Identifier: ISC
install_data('mountpoint.lua',
  rename: 'mountpoint',
  install_dir: get_option('bindir'),
  install_mode: 'rwxr-xr-x',
)

test('mountpoint', sh, args: [meson.current_source_dir() / 'test.sh'])
