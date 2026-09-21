# SPDX-License-Identifier: ISC
install_data('last.lua',
  rename: 'last',
  install_dir: get_option('bindir'),
  install_mode: 'rwxr-xr-x',
)

test('last', sh, args: [meson.current_source_dir() / 'test.sh'])
