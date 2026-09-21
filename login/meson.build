# SPDX-License-Identifier: ISC
install_data('login.lua',
  rename: 'login',
  install_dir: get_option('bindir'),
  install_mode: 'rwxr-xr-x',
)

test('login', sh, args: [meson.current_source_dir() / 'test.sh'])
