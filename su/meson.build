# SPDX-License-Identifier: ISC
install_data('su.lua',
  rename: 'su',
  install_dir: get_option('bindir'),
  install_mode: 'rwxr-xr-x',
)

test('su', sh, args: [meson.current_source_dir() / 'test.sh'])
