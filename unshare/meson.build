# SPDX-License-Identifier: ISC
install_data('unshare.lua',
  rename: 'unshare',
  install_dir: get_option('bindir'),
  install_mode: 'rwxr-xr-x',
)

test('unshare', sh, args: [meson.current_source_dir() / 'test.sh'])
