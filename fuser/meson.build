# SPDX-License-Identifier: ISC
install_data('fuser.lua',
  rename: 'fuser',
  install_dir: get_option('bindir'),
  install_mode: 'rwxr-xr-x',
)

test('fuser', sh, args: [meson.current_source_dir() / 'test.sh'])
