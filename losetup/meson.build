# SPDX-License-Identifier: ISC
install_data('losetup.lua',
  rename: 'losetup',
  install_dir: get_option('bindir'),
  install_mode: 'rwxr-xr-x',
)

test('losetup', sh, args: [meson.current_source_dir() / 'test.sh'])
