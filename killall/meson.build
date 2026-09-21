# SPDX-License-Identifier: ISC
install_data('killall.lua',
  rename: 'killall',
  install_dir: get_option('bindir'),
  install_mode: 'rwxr-xr-x',
)

install_symlink('pkill',
  install_dir: get_option('bindir'),
  pointing_to: 'killall',
)

test('killall', sh, args: [meson.current_source_dir() / 'test.sh'])
