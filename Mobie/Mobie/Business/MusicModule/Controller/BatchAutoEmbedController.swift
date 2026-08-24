//
//  BatchAutoEmbedController.swift
//  Mobie
//
//  Created by kaka on 2026/8/24.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit

/// 批量自动编辑的页面
class BatchAutoEmbedController: SuperViewController {
    init(_ models: [MusicItemModel]) {
        super.init(nibName: nil, bundle: nil)
        self.models = models
    }
    
    @MainActor public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.setupSubViews()
        self.setupContains()
        self.handleBuness()
    }
    
    func setupSubViews() {
        
    }
    
    func setupContains() {
        
    }
    
    func handleBuness() {
        self.title = "Batch Auto-Embed".localStr()
        self.navigationItem.largeTitleDisplayMode = .never
        
    }
    
    // MARK: GET && SET
    var models: [MusicItemModel]!
    
    var onDoneBlock: (()->Void)?
    
    // MARK: 懒加载
    
}
