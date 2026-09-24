# Vendored dependencies

## TagLib 2.3.2

- Official source: https://taglib.org/releases/taglib-2.3.2.tar.gz
- Release date: 2026-09-05
- Archive SHA-256: `3ca2d8afaa7f1cf7f6ed10e511ebc368bfacd6dcaa3dbfa690b89e502e8963dc`
- `Classes/TagLib`: upstream `taglib/` C++ sources, headers and `.tcc` files.
- `Classes/TagLib/taglib_config.h`: local static-build configuration enabling all bundled formats.
- Copyright and dual-license notices are retained. Full upstream LGPL/MPL texts are in `Licenses/`.

## UTF8-CPP

`Classes/TagLib/thirdSDK` contains the unmodified `3rdparty/utfcpp/source`
directory shipped in the same official TagLib release archive. Its license is
retained at `Licenses/UTF8CPP.txt`.

The repository's root MIT license covers the Objective-C wrapper, not the
bundled third-party libraries. Retain the applicable third-party copyright
and license notices when redistributing source or applications.
