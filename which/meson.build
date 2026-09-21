# SPDX-License-Identifier: ISC
install_data('which.lua',
  rename: 'which',
  install_dir: get_option('bindir'),
  install_mode: 'rwxr-xr-x',
)

test('which', sh, args: [meson.current_source_dir() / 'test.sh'])
