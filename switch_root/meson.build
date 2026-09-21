# SPDX-License-Identifier: ISC
install_data('switch_root.lua',
  rename: 'switch_root',
  install_dir: get_option('bindir'),
  install_mode: 'rwxr-xr-x',
)

test('switch_root', sh, args: [meson.current_source_dir() / 'test.sh'])

install_symlink('pivot_root',
  install_dir: get_option('bindir'),
  pointing_to: 'switch_root',
)
