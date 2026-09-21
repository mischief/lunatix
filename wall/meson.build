# SPDX-License-Identifier: ISC
install_data('wall.lua',
  rename: 'wall',
  install_dir: get_option('bindir'),
  install_mode: 'rwxr-xr-x',
)

test('wall', sh, args: [meson.current_source_dir() / 'test.sh'])
