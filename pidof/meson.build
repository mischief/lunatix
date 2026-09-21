# SPDX-License-Identifier: ISC
install_data('pidof.lua',
  rename: 'pidof',
  install_dir: get_option('bindir'),
  install_mode: 'rwxr-xr-x',
)

test('pidof', sh, args: [meson.current_source_dir() / 'test.sh'])
