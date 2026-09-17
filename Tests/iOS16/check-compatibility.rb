require 'json'
require 'open3'
require 'rubygems'

# Uses Apple's installed SF Symbols release metadata, not a hand-maintained list.
# This is a source audit of literal symbols; compilation checks SDK APIs separately.
root = File.expand_path('../..', __dir__)
metadata = ENV.fetch('SF_SYMBOL_METADATA', '/Applications/SF Symbols.app/Contents/Resources/Metadata/name_availability.plist')
abort "Install SF Symbols or set SF_SYMBOL_METADATA to Apple's name_availability.plist" unless File.file?(metadata)
json, status = Open3.capture2('plutil', '-convert', 'json', '-o', '-', metadata)
abort 'Could not read SF Symbols availability metadata' unless status.success?
catalog = JSON.parse(json)
minimum = Gem::Version.new('16.0')
count = 0
guarded = 0
errors = []

Dir.chdir(root) do
  %w[Mobie/Mobie.xcodeproj/project.pbxproj Pods/Pods.xcodeproj/project.pbxproj].each do |path|
    File.read(path).scan(/IPHONEOS_DEPLOYMENT_TARGET = ([\d.]+);/).flatten.each do |value|
      errors << "#{path}: deployment target #{value} is not 16.0" unless Gem::Version.new(value) == minimum
    end
  end
  Dir.glob('{Mobie,LocalSDK,Watch}/**/*.swift').each do |path|
    lines = File.readlines(path)
    # All availability branches currently use a closing brace at the if indentation.
    # Deliberately only recognize the true branch, never a following else fallback.
    ranges = lines.each_with_index.map do |line, index|
      match = line.match(/^( *)if #available\(iOS ([\d.]+),.*\{\s*$/)
      next unless match
      ending = ((index + 1)...lines.length).find { |j| lines[j].start_with?(match[1] + '}') }
      next unless ending
      [index, ending, Gem::Version.new(match[2])]
    end.compact
    lines.each_with_index do |line, index|
      next if line.lstrip.start_with?('//')
      location = "#{path}:#{index + 1}"
      # Check misspelled direct calls as well as known symbols assigned to variables.
      line.scan(/(?:systemName:|systemNamed\(|systemImage:)\s*"([^"\\]+)"/).flatten.each do |symbol|
        errors << "#{location}: unknown SF Symbol #{symbol}" unless catalog['symbols'].key?(symbol)
      end
      line.scan(/"([^"\\]+)"/).flatten.each do |symbol|
        year = catalog['symbols'][symbol]
        next unless year
        count += 1
        version = catalog['year_to_release'][year]['iOS']
        next unless version
        required = Gem::Version.new(version)
        next if required <= minimum
        if ranges.any? { |first, last, available| index > first && index < last && available >= required }
          guarded += 1
        else
          errors << "#{location}: #{symbol} requires iOS #{version} without a matching availability guard"
        end
      end
      if path.start_with?('Mobie/Mobie/') && (match = line.match(/^\s*if #available\(iOS ([\d.]+), \*\)/)) && Gem::Version.new(match[1]) <= minimum
        errors << "#{location}: redundant pre-iOS 16 compatibility branch"
      end
    end
  end
end
abort errors.join("\n") unless errors.empty?
puts "iOS 16 source audit passed: #{count} known symbol literals, #{guarded} newer symbols guarded; app/Pods deployment targets checked."
