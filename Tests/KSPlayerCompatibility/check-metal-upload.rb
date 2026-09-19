# Exercise the actual KSPlayer upload methods on real Metal, without launching the app.
require 'tmpdir'
require 'fileutils'
sdk_root = ARGV[0] || '/Users/kaka/Documents/本地公开库/KSPlayer'
source = File.read(File.join(sdk_root, 'Sources/KSPlayer/Metal/MetalRender.swift'))
def method(source, signature)
  start = source.index(signature) or raise "Missing #{signature}"
  opening = source.index('{', start)
  depth = 0
  source[opening..].each_char.with_index do |char, index|
    depth += 1 if char == '{'
    depth -= 1 if char == '}'
    return source[start..(opening + index)] if depth.zero?
  end
  raise 'Unbalanced source'
end
methods = [
  method(source, 'static func textures(formats: [MTLPixelFormat], widths: [Int], heights: [Int], buffers:'),
  method(source, 'static func texture(format: MTLPixelFormat, width: Int, height: Int, bytes:')
]
probe = <<~SWIFT
  import Foundation
  import Metal
  enum MetalRender {
      static let device = MTLCreateSystemDefaultDevice()!
      static let maxTextureDimension2D = 8192
      static let fragmentTextureStorageMode: MTLStorageMode = .shared
      #{methods.join("\n")}
  }
  @main enum Probe {
      static func main() {
          let device = MetalRender.device
          var checks = 0
          // RGB artwork and 8/16-bit luma/chroma planes, odd width with row padding.
          let cases: [(MTLPixelFormat, Int)] = [(.rgba8Unorm, 4), (.bgra8Unorm, 4),
              (.r8Unorm, 1), (.rg8Unorm, 2), (.r16Unorm, 2), (.rg16Unorm, 4)]
          for (format, bytesPerPixel) in cases {
              let width = 17, height = 9
              let alignment = device.minimumLinearTextureAlignment(for: format)
              let stride = ((width * bytesPerPixel + alignment - 1) / alignment) * alignment
              let buffer = device.makeBuffer(length: stride * height, options: .storageModeShared)!
              let input = buffer.contents().assumingMemoryBound(to: UInt8.self)
              for i in 0..<(stride * height) { input[i] = UInt8(i % 251) }
              let textures = MetalRender.textures(formats: [format], widths: [width], heights: [height], buffers: [buffer], lineSizes: [stride])
              precondition(textures.count == 1)
              let texture = textures[0]
              precondition(texture.width == width && texture.height == height && texture.pixelFormat == format)
              #if targetEnvironment(simulator)
              precondition(texture.buffer == nil, "Simulator must not create a shared linear texture")
              #else
              precondition(texture.buffer != nil, "Keep physical-device/macOS zero-copy path")
              #endif
              var output = [UInt8](repeating: 0, count: stride * height)
              output.withUnsafeMutableBytes {
                  texture.getBytes($0.baseAddress!, bytesPerRow: stride, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
              }
              for row in 0..<height {
                  for column in 0..<(width * bytesPerPixel) {
                      precondition(output[row * stride + column] == input[row * stride + column])
                      checks += 1
                  }
              }
              #if targetEnvironment(simulator)
              let original = output
              buffer.contents().initializeMemory(as: UInt8.self, repeating: 0, count: stride * height)
              output.withUnsafeMutableBytes {
                  texture.getBytes($0.baseAddress!, bytesPerRow: stride, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
              }
              precondition(output == original, "Uploaded texture must not alias source buffer")
              #endif
          }
          let y = device.makeBuffer(length: 256 * 8, options: .storageModeShared)!
          let uv = device.makeBuffer(length: 256 * 4, options: .storageModeShared)!
          let planar = MetalRender.textures(formats: [.r8Unorm, .rg8Unorm], widths: [8, 4], heights: [8, 4], buffers: [y, uv], lineSizes: [256, 256])
          precondition(planar.count == 2 && planar[0].width == 8 && planar[1].width == 4)
          precondition(MetalRender.textures(formats: [], widths: [], heights: [], buffers: [], lineSizes: []).isEmpty)
          precondition(MetalRender.textures(formats: [.r8Unorm], widths: [8], heights: [8], buffers: [nil], lineSizes: [256]).isEmpty)
          print("PASS_METAL_UPLOAD formats=6 pixelChecks=\\(checks) paddedRows, planar, empty, nil, storage")
      }
  }
SWIFT
ENV['DEVELOPER_DIR'] ||= '/Applications/Xcode.app/Contents/Developer'
build = Dir.mktmpdir('wake-metal-upload-', '/private/tmp')
path = File.join(build, 'Probe.swift')
File.write(path, probe)
abort 'macOS compile failed' unless system('xcrun', '--sdk', 'macosx', 'swiftc', '-parse-as-library', '-module-cache-path', File.join(build, 'modules'), path, '-o', File.join(build, 'native'))
abort 'macOS Metal test failed' unless system(File.join(build, 'native'))
sdk = IO.popen(['xcrun', '--sdk', 'iphonesimulator', '--show-sdk-path'], &:read).strip
abort 'Simulator compile failed' unless system('xcrun', '--sdk', 'iphonesimulator', 'swiftc', '-parse-as-library', '-target', 'arm64-apple-ios16.0-simulator', '-sdk', sdk,
  '-module-cache-path', File.join(build, 'sim-modules'), path, '-o', File.join(build, 'simulator'))
abort 'Simulator Metal test failed' unless system('xcrun', 'simctl', 'spawn', ENV.fetch('EQ_SIMULATOR_UDID', 'booted'), File.join(build, 'simulator'))
puts "Probe artifacts: #{build}"
