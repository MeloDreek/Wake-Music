# Only mutates the generated test fixture, never a user's audio file. Keep each
# DTS frame header so the demuxer can resynchronize after corrupted payloads.
require 'json'
require 'open3'
source, output = ARGV
raw, error, status = Open3.capture3('/opt/homebrew/bin/ffprobe', '-v', 'error', '-show_packets',
                                 '-show_entries', 'packet=pos,size', '-of', 'json', source)
abort(error) unless status.success?
packets = JSON.parse(raw).fetch('packets')
abort('DTS fixture needs at least 300 frames') unless packets.count >= 300
original = File.binread(source)
{
  'dts-isolated.dts' => [packets.count / 2],
  'dts-tail.dts' => [packets.count - 1],
  'dts-many-isolated.dts' => [50, 100, 150, 200, 250],
  'dts-repeated.dts' => (100...120).to_a
}.each do |name, indices|
  bytes = original.dup
  indices.each do |index|
    packet = packets.fetch(index)
    offset, length = packet.fetch('pos').to_i, packet.fetch('size').to_i
    abort('Unexpected DTS frame size') unless length > 64
    bytes[offset + 32, length - 32] = "\xff".b * (length - 32)
  end
  File.binwrite(File.join(output, name), bytes)
end
