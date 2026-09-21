# SPDX-License-Identifier: ISC
install_data('lsblk.lua',
  rename: 'lsblk',
  install_dir: get_option('bindir'),
  install_mode: 'rwxr-xr-x',
)

test('lsblk', sh, args: [meson.current_source_dir() / 'test.sh'])
