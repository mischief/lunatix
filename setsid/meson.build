# SPDX-License-Identifier: ISC
install_data('setsid.lua',
  rename: 'setsid',
  install_dir: get_option('bindir'),
  install_mode: 'rwxr-xr-x',
)

test('setsid', sh, args: [meson.current_source_dir() / 'test.sh'])
