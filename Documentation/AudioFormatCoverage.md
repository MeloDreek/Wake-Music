# Audio extensions and metadata coverage

The format catalog follows the `FileRef::defaultFileExtensions()` registry in
WaketagLibKit **2.3.3**, which bundles TagLib **2.3.2**. The registry contains
**40 suffixes**, not 40 independently verified audio codecs.

`AudioExtensionType` contains the **35 audio-oriented suffixes**. The five
video-oriented containers (`3g2`, `mp4`, `m4v`, `mkv`, `webm`) remain video types;
their ability to carry audio or metadata must not classify every movie as a song.
`AudioExtension.taglibMetadataSuffixs` combines both sets for exact registry
comparison.

| Category | Suffixes |
| --- | --- |
| DSD containers | `dsf`, `dff`, `dsdiff` |
| MPEG, Ogg and Musepack | `mp3`, `mp2`, `aac`, `ogg`, `oga`, `opus`, `spx`, `mpc` |
| Tracker modules | `mod`, `module`, `nst`, `wow`, `it`, `xm`, `s3m` |
| Audio containers | `m4a`, `m4b`, `m4p`, `m4r`, `mka`, `wav`, `asf`, `aif`, `afc`, `aifc`, `aiff`, `wma`, `wv` |
| Lossless codecs | `flac`, `ape`, `tta`, `shn` |

`dsdiff` uses the DFF parser, `afc` uses the AIFF-C parser, and
`module`/`nst`/`wow` use the MOD parser. Extension aliases retain their real suffix;
files are not renamed. The same DSD streaming restriction and Premium entitlement
apply to DFF and DSDIFF on 115 Drive.

The supported-formats screen no longer infers lossless quality from WAV, MP4,
ASF or WavPack extensions. For example, a WAV container may contain compressed
audio, and WavPack supports hybrid modes. Such containers and tracker modules
are displayed under “Other.” No suffix establishes original master quality,
channel layout, or sample rate.

## Metadata is not decoding or tag-writing support

The registry is a **parser-entry inventory**. Tracker writing is rejected by the
wrapper; Shorten has no editable metadata; Matroska artwork/lyrics writing is not
supported; protected MP4 may not be playable. ADTS AAC and less common variants
have weaker regression coverage than common MP3/FLAC/M4A. Refer to the
[WaketagLibKit capability matrix](https://github.com/MeloDreek/WaketagLibKit#readme)
for individual read/write guarantees and limitations. Audio fingerprinting also
requires that the operating-system decoder can open the actual audio stream.

## Compatibility with existing music libraries

The following old suffixes are **playback-only compatibility candidates**, not
part of the metadata-format count:
`dsd`, `dts`, `alac`, `au`, `caf`, `wave`, `mqa`, `3gp`, `amr`.

They remain accepted by local scans, imports, download migration and remote file
classification through `AudioExtension.playableAudioSuffixs`. The actual player
must still validate their content. This prevents existing DTS/CAF libraries from
disappearing when the metadata catalog is corrected. `.alac`, `.dsd` and `.mqa`
often describe a codec rather than a standardized container extension and do not
establish metadata support on their own.

`.wvc` is a WavPack correction sidecar, not a standalone song; `.ogv` remains a
video container. Neither is advertised as an audio format or added to the music
queue. No existing file is deleted.

## Regression checks

```sh
TAGLIB_ROOT=/path/to/resolved/WaketagLibKit bash Tests/AudioExtensions/run-tests.sh
ruby Tests/Drive115/run-format-regressions.rb
```

Tests compile the production extension registry and URL filtering helpers. They
compare the complete metadata set with the actual TagLib source, check grouping,
case normalization, legacy playback compatibility, sidecar/video exclusion,
fingerprint candidates and Premium aliases. They do not decode or edit audio.
