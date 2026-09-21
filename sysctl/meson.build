# SPDX-License-Identifier: ISC
install_data('sysctl.lua',
  rename: 'sysctl',
  install_dir: get_option('bindir'),
  install_mode: 'rwxr-xr-x',
)

test('sysctl', sh, args: [meson.current_source_dir() / 'test.sh'])
