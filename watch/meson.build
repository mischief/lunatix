# SPDX-License-Identifier: ISC
install_data('watch.lua',
  rename: 'watch',
  install_dir: get_option('bindir'),
  install_mode: 'rwxr-xr-x',
)

test('watch', sh, args: [meson.current_source_dir() / 'test.sh'])
