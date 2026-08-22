//
//  UnsupportViewController.swift
//  Mobie
//
//  Created by 张文 on 12/21/24.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit

class UnsupportViewController: SuperViewController {
    init(_ allFiles: [URL]) {
        super.init(nibName: nil, bundle: nil)
        self.allFiles = allFiles
    }
    
    @MainActor public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func preSetupSubViews() {
        super.preSetupSubViews()
        contentView.addSubview(tableView)
    }
    
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.frame = contentView.bounds
    }
    
    override func preSetupHandleBuness() {
        super.preSetupHandleBuness()
        self.navigationItem.largeTitleDisplayMode = .never
        let message = "Unsupported Files".localStr() + "(\(self.allFiles.count))"
        self.title = message

        self.navigationItem.rightBarButtonItem = self.deleteItem
    }
    
    // MARK:  GET && SET
    var allFiles: [URL]!
    
    // MARK:  懒加载
    lazy var tableView: UITableView = {
        let view = UITableView(frame: self.view.bounds, style: .insetGrouped)
        view.dataSource = self
        view.delegate = self
        view.rowHeight = UITableView.automaticDimension
        view.contentInsetAdjustmentBehavior = .automatic
        view.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: playingHeight, right: 0)
        view.register(UITableViewCell.self, forCellReuseIdentifier: "LocalFileTableViewCell")
        return view
    }()
    
    lazy var deleteItem: UIBarButtonItem = {
        let item = UIBarButtonItem(image: UIImage(systemName: "trash"), style: .plain, target: self, action: #selector(deleteBarItemAction))
        return item
    }()
    
    @objc func deleteBarItemAction() {
        self.showTwoAlert(message: "Are you sure to delete it?".localStr(), confirm: "Delete".localStr(), style: kaka_IsiPhone() ? .actionSheet : .alert, complete: { [weak self] () in
            guard let wSelf = self else { return }
            wSelf.deleteFilesAction(wSelf.allFiles)
        })
    }
    
}

extension UnsupportViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.allFiles.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "LocalFileTableViewCell", for: indexPath)
        let subURL = self.allFiles[indexPath.row]
        var cellConfig = UIListContentConfiguration.cell()
        cellConfig.image = UIImage(named: "file_place")
        cellConfig.imageProperties.cornerRadius = 4.ckValue()
        cellConfig.imageProperties.maximumSize = CGSizeMake(45.ckValue(), 45.ckValue())
        cellConfig.text = subURL.lastPathComponent
        cellConfig.secondaryTextProperties.numberOfLines = 2
        cellConfig.secondaryTextProperties.lineBreakMode = .byTruncatingMiddle
        if #available(iOS 16.0, *) {
            cellConfig.secondaryText = subURL.path(percentEncoded: false)
        } else {
            cellConfig.secondaryText = subURL.path
        }
        cellConfig.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 20, leading: 15, bottom: 20, trailing: 15)
        cell.accessoryType = .disclosureIndicator
        cell.contentConfiguration = cellConfig
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        tableView.deselectRow(at: indexPath, animated: true)
        
        let subURL = self.allFiles[indexPath.row]
        
        if kaka_IsMacOS() {
            KakaMusicPlayer.shared.showInFinderCatalyst(subURL)
        }else{
            let documentVC = UIDocumentInteractionController(url: subURL)
            documentVC.delegate = self
            documentVC.presentPreview(animated: true)
        }
        
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        
        let subURL = self.allFiles[indexPath.row]
        
        // 导出
        let exportAction = UIContextualAction(style: .normal, title: nil) { [weak self] action, view, finish in
            self?.shareMusicModel([subURL])
            finish(true)
        }
        exportAction.image = Reasource.systemNamed("square.and.arrow.up", color: .white)
        exportAction.backgroundColor = UIColor.systemGreen
        
        // 删除
        let deleteAction = UIContextualAction(style: .normal, title: nil) { [weak self] action, view, finish in
            self?.tableView.setEditing(false, animated: true)
            self?.showTwoAlert(message: "Are you sure to delete it?".localStr(), confirm: "Delete".localStr(), style: kaka_IsiPhone() ? .actionSheet : .alert, complete: { [weak self] () in
                self?.deleteFilesAction([subURL])
                finish(true)
            })
        }
        deleteAction.image = Reasource.systemNamed("trash", color: .white)
        deleteAction.backgroundColor = UIColor.systemPink
                
        return UISwipeActionsConfiguration(actions: [deleteAction, exportAction])
        
    }
    
    func shareMusicModel(_ files: [URL]) {
        self.tableView.setEditing(false, animated: true)
        let shareVC = UIActivityViewController(activityItems: files, applicationActivities: nil)
        if !kaka_IsiPhone() {
            shareVC.popoverPresentationController?.sourceView = self.navigationController?.navigationBar
        }
        self.present(shareVC, animated: true, completion: nil)
    }
    
    func deleteFilesAction(_ files: [URL]) {
        let fetchDataGroup = DispatchGroup()
        var errorMsg: String?
        
        for subURL in files {
            fetchDataGroup.enter()
            
            do {
#if targetEnvironment(macCatalyst)
                try FileManager.default.trashItem(at: subURL, resultingItemURL: nil)
#else
                try FileManager.default.removeItem(at: subURL)
#endif
                if let index = self.allFiles.firstIndex(of: subURL) {
                    self.allFiles.remove(at: index)
                }
                fetchDataGroup.leave()
            } catch {
                errorMsg?.append(error.localizedDescription + "\r\n")
                fetchDataGroup.leave()
            }
        }
        
        fetchDataGroup.notify(queue: .main) { [weak self] in
            if errorMsg != nil {
                self?.view.makeToast(errorMsg)
            } else {
                self?.tableView.reloadData()
                if self?.allFiles.isEmpty == true {
                    self?.navigationController?.popViewController(animated: true)
                }
                NotificationCenter.default.post(name: Notification.Name(kLocalMusicChangedKey), object: nil, userInfo: nil)
            }
        }
    }
    
}

// MARK: - UIDocumentInteractionControllerDelegate
extension UnsupportViewController: UIDocumentInteractionControllerDelegate {
    func documentInteractionControllerViewControllerForPreview(_ controller: UIDocumentInteractionController) -> UIViewController {
        return self // 返回当前视图控制器
    }

    func documentInteractionControllerRectForPreview(_ controller: UIDocumentInteractionController) -> CGRect {
        // 返回预览的矩形区域，通常可以返回视图的bounds
        return self.view.bounds
    }

//    func documentInteractionControllerViewForPreview(_ controller: UIDocumentInteractionController) -> UIView? {
//        // 返回自定义视图，如果不需要可以返回nil
//        return nil
//    }

    func documentInteractionControllerWillBeginPreview(_ controller: UIDocumentInteractionController) {
        print("将开始预览")
    }

    func documentInteractionControllerDidEndPreview(_ controller: UIDocumentInteractionController) {
        print("预览已结束")
    }

    func documentInteractionControllerWillPresentOptionsMenu(_ controller: UIDocumentInteractionController) {
        print("将显示选项菜单")
    }

    func documentInteractionControllerDidDismissOptionsMenu(_ controller: UIDocumentInteractionController) {
        print("选项菜单已关闭")
    }

    func documentInteractionControllerWillPresentOpenInMenu(_ controller: UIDocumentInteractionController) {
        print("将显示打开菜单")
    }

    func documentInteractionControllerDidDismissOpenInMenu(_ controller: UIDocumentInteractionController) {
        print("打开菜单已关闭")
    }

    func documentInteractionController(_ controller: UIDocumentInteractionController, willBeginSendingToApplication application: String?) {
        print("将开始发送到应用：\(application ?? "")")
    }

    func documentInteractionController(_ controller: UIDocumentInteractionController, didEndSendingToApplication application: String?) {
        print("已结束发送到应用：\(application ?? "")")
    }
    
}
