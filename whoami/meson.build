# SPDX-License-Identifier: ISC
install_data('whoami.lua',
  rename: 'whoami',
  install_dir: get_option('bindir'),
  install_mode: 'rwxr-xr-x',
)

test('whoami', sh, args: [meson.current_source_dir() / 'test.sh'])
