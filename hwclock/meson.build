# SPDX-License-Identifier: ISC
install_data('hwclock.lua',
  rename: 'hwclock',
  install_dir: get_option('bindir'),
  install_mode: 'rwxr-xr-x',
)

test('hwclock', sh, args: [meson.current_source_dir() / 'test.sh'])
