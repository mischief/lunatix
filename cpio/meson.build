# SPDX-License-Identifier: ISC
install_data('cpio.lua',
  rename: 'cpio',
  install_dir: get_option('bindir'),
  install_mode: 'rwxr-xr-x',
)

test('cpio', sh, args: [meson.current_source_dir() / 'test.sh'])
