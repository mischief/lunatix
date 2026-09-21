# SPDX-License-Identifier: ISC
install_data('chroot.lua',
  rename: 'chroot',
  install_dir: get_option('bindir'),
  install_mode: 'rwxr-xr-x',
)

test('chroot', sh, args: [meson.current_source_dir() / 'test.sh'])
