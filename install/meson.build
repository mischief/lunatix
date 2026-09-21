# SPDX-License-Identifier: ISC
install_data('install.lua',
  rename: 'install',
  install_dir: get_option('bindir'),
  install_mode: 'rwxr-xr-x',
)

test('install', sh, args: [meson.current_source_dir() / 'test.sh'])
