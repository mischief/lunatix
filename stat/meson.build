# SPDX-License-Identifier: ISC
install_data('stat.lua',
  rename: 'stat',
  install_dir: get_option('bindir'),
  install_mode: 'rwxr-xr-x',
)

test('stat', sh, args: [meson.current_source_dir() / 'test.sh'])
