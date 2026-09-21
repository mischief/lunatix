# SPDX-License-Identifier: ISC
install_data('sum.lua',
  rename: 'sha256sum',
  install_dir: get_option('bindir'),
  install_mode: 'rwxr-xr-x',
)

foreach name : ['sha1sum', 'sha512sum']
  install_symlink(name,
    install_dir: get_option('bindir'),
    pointing_to: 'sha256sum',
  )
endforeach

test('sum', sh, args: [meson.current_source_dir() / 'test.sh'])
