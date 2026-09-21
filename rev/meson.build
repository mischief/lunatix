# SPDX-License-Identifier: ISC
install_data('rev.lua',
  rename: 'rev',
  install_dir: get_option('bindir'),
  install_mode: 'rwxr-xr-x',
)

test('rev', sh, args: [meson.current_source_dir() / 'test.sh'])
