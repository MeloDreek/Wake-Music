# CocoaPods treats Mac Catalyst as iOS. Apply Xcode's platform filters as well as
# SDK-specific link/embed settings after CocoaPods has generated its integration.
require 'xcodeproj'

module IOSOnlyKeyboardPods
  NAMES = %w[IQKeyboardCore IQKeyboardManagerSwift IQKeyboardNotification
             IQKeyboardReturnManager IQKeyboardToolbar IQKeyboardToolbarManager
             IQTextInputViewNotification IQTextView].freeze
  NAME_PATTERN = Regexp.union(NAMES)
  SUFFIX_SETTING = 'WAKE_IQ_PLATFORM_SUFFIX'.freeze
  CONFIG_MARKER = '// WakeMusic: IQ dependencies are iOS-only'.freeze
  SCRIPT_MARKER = '# WakeMusic: iOS-only IQ frameworks'.freeze

  def self.iq_target?(name)
    NAMES.any? { |pod| name == pod || name.start_with?(pod + '-') }
  end

  def self.apply(root)
    pods = Xcodeproj::Project.open(File.join(root, 'Pods/Pods.xcodeproj'))
    pods.targets.each do |target|
      target.dependencies.each do |dependency|
        next unless dependency.target && iq_target?(dependency.target.name)
        dependency.platform_filter = nil
        dependency.platform_filters = ['ios']
      end
      target.build_phases.grep(Xcodeproj::Project::Object::PBXFrameworksBuildPhase).each do |phase|
        phase.files.each do |file|
          next unless NAMES.include?(File.basename(file.file_ref&.path.to_s, '.framework'))
          file.platform_filter = nil
          file.platform_filters = ['ios']
        end
      end
    end
    pods.save

    app = Xcodeproj::Project.open(File.join(root, 'Mobie/Mobie.xcodeproj'))
    %w[Mobie Mobie_Pro].each do |target_name|
      aggregate = 'Pods-' + target_name
      support = File.join(root, 'Pods/Target Support Files', aggregate)
      Dir.glob(File.join(support, '*.xcconfig')).each do |path|
        contents = File.read(path)
        next if contents.include?(CONFIG_MARKER + ' (scoped variables)')
        original = contents.split(CONFIG_MARKER, 2).first.rstrip + "\n"
        variables = []
        filtered = original.lines.map do |line|
          match = line.match(/\A([A-Z_]+) = (.*)$/)
          next line unless match && match[2].match?(NAME_PATTERN)
          value = match[2]
          removed = []
          # Remove paired options too, not just the path they apply to.
          value = value.gsub(/-framework "(?:#{NAME_PATTERN})"\s*/) { |token| removed << token.strip; '' }
          value = value.gsub(/(?:-iframework|-isystem|-iquote|-F)\s+"[^"]*\/(?:#{NAME_PATTERN})(?:\/[^\"]*)?"\s*/) { |token| removed << token.strip; '' }
          value = value.gsub(/"[^"]*\/(?:#{NAME_PATTERN})(?:\/[^\"]*)?"\s*/) { |token| removed << token.strip; '' }
          raise "Unfiltered IQ setting: #{path}: #{match[1]}" if value.match?(NAME_PATTERN)
          variable = 'WAKE_IQ_' + match[1]
          variables << "#{variable} =\n#{variable}[sdk=iphone*] = #{removed.join(' ')}\n"
          # Keep inherited settings intact, without conditionally inheriting the
          # unfiltered value of OTHER_LDFLAGS (which would reintroduce IQ on Mac).
          "#{match[1]} = #{value.rstrip} $(#{variable})\n"
        end
        File.write(path, filtered.join + "\n#{CONFIG_MARKER} (scoped variables)\n#{SUFFIX_SETTING} =\n#{SUFFIX_SETTING}[sdk=macosx*] = -macosx\n" + variables.join)
      end

      # Xcode resolves script input/output lists before executing the script.
      # Give Catalyst separate lists so absent iOS frameworks aren't build inputs.
      Dir.glob(File.join(support, '*-frameworks-*-files.xcfilelist')).each do |path|
        next if path.include?('-macosx-')
        catalyst = path.sub(/-(input|output)-files\.xcfilelist$/, '-macosx-\1-files.xcfilelist')
        File.write(catalyst, File.readlines(path).reject { |line| line.match?(NAME_PATTERN) }.join)
      end
      script_path = File.join(support, aggregate + '-frameworks.sh')
      script = File.read(script_path)
      unless script.include?(SCRIPT_MARKER)
        script = script.gsub(/(?:^  install_framework "[^\n]*\/(?:#{NAME_PATTERN})\.framework"\n)+/) do |block|
          "  #{SCRIPT_MARKER}\n  if [ \"${PLATFORM_NAME:-}\" != \"macosx\" ]; then\n#{block}  fi\n"
        end
        raise "Missing IQ embed block: #{script_path}" unless script.include?(SCRIPT_MARKER)
        File.write(script_path, script)
      end
      target = app.targets.find { |item| item.name == target_name }
      raise "Missing app target: #{target_name}" unless target
      target.shell_script_build_phases.select { |phase| phase.name == '[CP] Embed Pods Frameworks' }.each do |phase|
        %i[input_file_list_paths output_file_list_paths].each do |property|
          paths = phase.public_send(property).map do |path|
            path.include?(SUFFIX_SETTING) ? path : path.sub('${CONFIGURATION}', '${CONFIGURATION}${' + SUFFIX_SETTING + '}')
          end
          phase.public_send("#{property}=", paths)
        end
      end
    end
    app.save
  end
end

IOSOnlyKeyboardPods.apply(File.expand_path('..', __dir__)) if $PROGRAM_NAME == __FILE__
