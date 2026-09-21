# SPDX-License-Identifier: ISC
install_data('blkid.lua',
  rename: 'blkid',
  install_dir: get_option('bindir'),
  install_mode: 'rwxr-xr-x',
)

test('blkid', sh, args: [meson.current_source_dir() / 'test.sh'])
