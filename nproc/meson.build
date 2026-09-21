# SPDX-License-Identifier: ISC
install_data('nproc.lua',
  rename: 'nproc',
  install_dir: get_option('bindir'),
  install_mode: 'rwxr-xr-x',
)

test('nproc', sh, args: [meson.current_source_dir() / 'test.sh'])
