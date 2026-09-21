# SPDX-License-Identifier: ISC
install_data('mount.lua',
  rename: 'mount',
  install_dir: get_option('bindir'),
  install_mode: 'rwxr-xr-x',
)

test('mount', sh, args: [meson.current_source_dir() / 'test.sh'])
