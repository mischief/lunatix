# SPDX-License-Identifier: ISC
install_data('mknod.lua',
  rename: 'mknod',
  install_dir: get_option('bindir'),
  install_mode: 'rwxr-xr-x',
)

test('mknod', sh, args: [meson.current_source_dir() / 'test.sh'])
