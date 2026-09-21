# SPDX-License-Identifier: ISC
install_data('findmnt.lua',
  rename: 'findmnt',
  install_dir: get_option('bindir'),
  install_mode: 'rwxr-xr-x',
)

test('findmnt', sh, args: [meson.current_source_dir() / 'test.sh'])
