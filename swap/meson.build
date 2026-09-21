# SPDX-License-Identifier: ISC
install_data('swapon.lua',
  rename: 'swapon',
  install_dir: get_option('bindir'),
  install_mode: 'rwxr-xr-x',
)

foreach name : ['swapoff', 'mkswap']
  install_symlink(name,
    install_dir: get_option('bindir'),
    pointing_to: 'swapon',
  )
endforeach

test('swap', sh, args: [meson.current_source_dir() / 'test.sh'])
