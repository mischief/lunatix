# SPDX-License-Identifier: ISC
install_data('getty.lua',
  rename: 'getty',
  install_dir: get_option('bindir'),
  install_mode: 'rwxr-xr-x',
)

test('getty', sh, args: [meson.current_source_dir() / 'test.sh'])
