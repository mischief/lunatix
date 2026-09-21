# SPDX-License-Identifier: ISC
install_data('hexdump.lua',
  rename: 'hexdump',
  install_dir: get_option('bindir'),
  install_mode: 'rwxr-xr-x',
)

test('hexdump', sh, args: [meson.current_source_dir() / 'test.sh'])

install_symlink('xxd',
  install_dir: get_option('bindir'),
  pointing_to: 'hexdump',
)
