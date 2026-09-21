# SPDX-License-Identifier: ISC
install_data('base64.lua',
  rename: 'base64',
  install_dir: get_option('bindir'),
  install_mode: 'rwxr-xr-x',
)

test('base64', sh, args: [meson.current_source_dir() / 'test.sh'])
