//
//  NavidromeSongListController+Search.swift
//  Mobie
//
//  Created by 张文 on 3/19/25.
//


import KakaFoundation
import KakaUIKit
import AppGroupKit

extension NavidromeSongListController: UISearchBarDelegate {
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        debugPrint("searchText1 = \(searchText)")
        
        self.searchWithKey(searchText)
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        guard let searchText = searchBar.text, searchText.count > 0 else {
            self.searchController.searchBar.endEditing(true)
            self.searchController.dismiss(animated: true)
            return
        }
        
        debugPrint("searchText2 = \(searchText)")
        
        if self.songArray.isEmpty {
            self.searchController.searchBar.endEditing(true)
            self.tableView.kaka_playShakeAnim()
            return
        }
        
        self.searchWithKey(searchText)
    }
    
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
       
        self.stopSearchAction(false)
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        self.stopSearchAction(true)
    }
    
    func searchWithKey(_ keyword: String) {
        self.searchKey = keyword
        self.searchDataAction()
    }
    
    func configSearchBar() {
        self.navigationItem.searchController = self.searchController
        self.navigationItem.hidesSearchBarWhenScrolling = false
        if #available(iOS 16.0, *) {
            self.navigationItem.preferredSearchBarPlacement = kaka_IsMacOS() ? .automatic : .stacked
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIApplication.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHidden(_:)), name: UIApplication.keyboardDidHideNotification, object: nil)
    }
    
    @objc func keyboardWillShow(_ notify: Notification) {
        let rect = notify.userInfo?[UIApplication.keyboardFrameEndUserInfoKey] as? CGRect
        let keyboardH = rect?.height ?? 366
                
        self.tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: keyboardH, right: 0)
    }
    
    @objc func keyboardWillHidden(_ notify: Notification) {
        self.tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: kaka_safeAreaInsets().bottom + playingHeight, right: 0)
    }
    
    func stopSearchAction(_ animation: Bool) {
        self.searchController.searchBar.text = nil
        self.searchKey = nil
        self.searchDataAction()
        self.searchController.dismiss(animated: animation)
    }
    
    func searchDataAction() {
        
        guard let searchKey = self.searchKey, searchKey.removeSpace().count > 0 else {
            self.songArray = self.originArray
            self.tableView.reloadData()
            return
        }
        
        let searchArray = self.songArray.filter {
            $0.title.contains(searchKey) || $0.artist.contains(searchKey) || $0.album.contains(searchKey)
        }
        
        self.songArray = searchArray
        self.tableView.reloadData()
    }
}

