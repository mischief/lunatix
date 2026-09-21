# SPDX-License-Identifier: ISC
install_data('reboot.lua',
  rename: 'reboot',
  install_dir: get_option('bindir'),
  install_mode: 'rwxr-xr-x',
)

foreach name : ['halt', 'poweroff']
  install_symlink(name,
    install_dir: get_option('bindir'),
    pointing_to: 'reboot',
  )
endforeach

test('reboot', sh, args: [meson.current_source_dir() / 'test.sh'])
