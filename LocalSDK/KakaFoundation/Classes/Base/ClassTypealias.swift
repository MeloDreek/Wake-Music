//
//  ClassTypealias.swift
//  Pods
//
//  Created by 张文 on 9/22/24.
//

import Foundation

#if os(iOS)
import UIKit
public typealias KakaView = UIView
public typealias KakaImage = UIImage
public typealias KakaColor = UIColor
public typealias KakaFont = UIFont
public typealias KakaScreen = UIScreen
public typealias KakaWindow = UIWindow
#elseif os(macOS)
import AppKit
public typealias KakaView = NSView
public typealias KakaImage = NSImage
public typealias KakaColor = NSColor
public typealias KakaFont = NSFont
public typealias KakaScreen = NSScreen
public typealias KakaWindow = NSWindow
#endif
