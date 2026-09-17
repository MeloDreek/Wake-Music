//
//  NavidromeViewController+Search.swift
//  Mobie
//
//  Created by 张文 on 1/3/25.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit

extension NavidromeViewController: UISearchBarDelegate {
    
    func configSearchBar() {
        
        self.navigationItem.searchController = self.searchController
        self.searchController.naviController = self.navigationController
        self.navigationItem.hidesSearchBarWhenScrolling = false
        self.navigationItem.preferredSearchBarPlacement = kaka_IsMacOS() ? .automatic : .stacked
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIApplication.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHidden(_:)), name: UIApplication.keyboardDidHideNotification, object: nil)
    }
    
    func disableSearchBar() {
        self.navigationItem.searchController = nil
        self.navigationItem.hidesSearchBarWhenScrolling = true
        self.navigationItem.preferredSearchBarPlacement = kaka_IsMacOS() ? .automatic : .stacked
        
        NotificationCenter.default.removeObserver(self, name: UIApplication.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.keyboardDidHideNotification, object: nil)
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        debugPrint("searchText = \(searchText)")
        if searchText.isEmpty || searchBar.text == nil { // 清空字符
            self.searchController.stopSearchAction()
        }
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        guard let searchText = searchBar.text, searchText.count > 0 else {
            self.searchController.searchBar.endEditing(true)
            self.searchController.dismiss(animated: true)
            return
        }
        
        debugPrint("searchText = \(searchText)")
        
        if self.navsetModel.randomSongs == nil {
            self.searchController.searchBar.endEditing(true)
            self.tableView.kaka_playShakeAnim()
            return
        }
        
        self.searchWithKey(searchText)
    }
    
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        self.stopSearchAction(true)
    }
    
    func searchWithKey(_ keyword: String) {
        guard keyword.removeSpace().count > 0 else {
            return
        }
        
        self.searchController.navUser = self.navUser
        self.searchController.startSearchAction(keyword)
    }
    
    @objc func keyboardWillShow(_ notify: Notification) {
        let rect = notify.userInfo?[UIApplication.keyboardFrameEndUserInfoKey] as? CGRect
        let keyboardH = rect?.height ?? 366
                
        self.tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: keyboardH + 30.ckValue(), right: 0)
    }
    
    @objc func keyboardWillHidden(_ notify: Notification) {
        
        self.tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: playingHeight + 30.ckValue(), right: 0)
    }
    
    func stopSearchAction(_ animation: Bool) {
        self.searchController.searchBar.text = nil
        self.searchController.stopSearchAction()
        self.searchController.dismiss(animated: animation)
    }
    
}
