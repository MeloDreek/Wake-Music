//
//  LibraryCoverViewController+Search.swift
//  Waketag
//
//  Created by Melo on 1/10/25.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit

extension LibraryCoverViewController: UISearchBarDelegate {
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        debugPrint("searchText = \(searchText)")
        
        self.searchWithKey(searchText)
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        guard let searchText = searchBar.text, searchText.count > 0 else {
            self.searchController.searchBar.endEditing(true)
            self.searchController.dismiss(animated: true)
            return
        }
        
        debugPrint("searchText = \(searchText)")
        
        if self.localUrlArray.count == 0 {
            self.searchController.searchBar.endEditing(true)
            self.tableView.kaka_playShakeAnim()
            return
        }
        
        self.searchWithKey(searchText)
    }
    
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
//        if searchBar.text?.count == 0 && kaka_IsMacOS() {
//            self.searchController.dismiss(animated: true)
//        }
//
        self.searchWithKey(nil)
        self.stopSearchAction(false)
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        self.stopSearchAction(true)
    }
    
    func searchWithKey(_ keyword: String?) {
        let allArray = SandboxFileManager.shared.coverPathURL().readLocalSubFiles()
        if let keyword = keyword, keyword.removeSpace().count > 0 {
            let searchArray = allArray.filter { $0.lastPathComponent.lowercased().contains(keyword.lowercased()) }
            self.localUrlArray = searchArray
        }else{
            self.localUrlArray = allArray
        }
        
        self.tableView.reloadData()
    }
    
    func configSearchBar() {
        self.navigationItem.searchController = self.searchController
        self.navigationItem.hidesSearchBarWhenScrolling = false
        self.navigationItem.preferredSearchBarPlacement = kaka_IsMacOS() ? .automatic : .stacked
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIApplication.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHidden(_:)), name: UIApplication.keyboardDidHideNotification, object: nil)
    }
    
    @objc func keyboardWillShow(_ notify: Notification) {
        let rect = notify.userInfo?[UIApplication.keyboardFrameEndUserInfoKey] as? CGRect
        let keyboardH = rect?.height ?? 366
                
        self.tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: keyboardH, right: 0)
    }
    
    @objc func keyboardWillHidden(_ notify: Notification) {
        self.tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: kaka_safeAreaInsets().bottom + 30.ckValue(), right: 0)
    }
    
    func stopSearchAction(_ animation: Bool) {
        self.searchController.searchBar.text = nil
        self.tableView.reloadData()
    }
    
}

