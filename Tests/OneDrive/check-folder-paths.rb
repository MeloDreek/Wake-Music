#!/usr/bin/env ruby
require 'open3'
require 'tmpdir'
root = File.expand_path('../..', __dir__)
source = File.read(File.join(root, 'Mobie/Mobie/Business/ConnectModule/Controller/OneDriveFileListController.swift'))
assignment = source[/            let decodedParentPath = path\.removingPercentEncoding.*?\n            newModel\.path = .*?\n/m]
abort('Missing production decoded-parent folder navigation') unless assignment
Dir.mktmpdir('wakemusic-onedrive-paths-') do |directory|
  fixture = <<~SWIFT
    import Foundation
    struct Item { let name: String }
    struct User { var path: String = "" }
    func navigate(_ path: String, name: String) -> String {
        let onedriveFile = Item(name: name)
        var newModel = User()
        #{assignment}
        return newModel.path
    }
    func graphPath(_ value: String) -> String {
        var components = URLComponents()
        components.path = value
        return components.percentEncodedPath
    }
    let first = navigate("/drive/root:", name: "Music Library #1%")
    precondition(first == "/drive/root:/Music Library #1%")
    let second = navigate(graphPath(first), name: "中文 %20 & Mix")
    precondition(second == "/drive/root:/Music Library #1%/中文 %20 & Mix")
    let encodedSecond = graphPath(second)
    precondition(encodedSecond.contains("Music%20Library%20%231%25"))
    precondition(!encodedSecond.contains("Music%2520Library"))
    precondition(encodedSecond.contains("%2520"), "A literal percent in the raw file name must survive")
    let third = navigate(encodedSecond, name: "50% # Final")
    precondition(third == second + "/50% # Final")
    precondition(!graphPath(third).contains("%252520"), "Never decode the raw name, nor re-encode the parent twice")
    print("PASS: 7 nested OneDrive folder encoding checks against production navigation")
  SWIFT
  path = File.join(directory, 'main.swift')
  File.write(path, fixture)
  output, errors, status = Open3.capture3('xcrun', 'swift', '-module-cache-path', File.join(directory, 'Modules'), path)
  abort(errors) unless status.success?
  puts output
end
