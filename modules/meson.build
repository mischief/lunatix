# SPDX-License-Identifier: ISC
install_data('insmod.lua',
  rename: 'insmod',
  install_dir: get_option('bindir'),
  install_mode: 'rwxr-xr-x',
)

foreach name : ['rmmod', 'lsmod', 'modprobe']
  install_symlink(name,
    install_dir: get_option('bindir'),
    pointing_to: 'insmod',
  )
endforeach

test('modules', sh, args: [meson.current_source_dir() / 'test.sh'])
