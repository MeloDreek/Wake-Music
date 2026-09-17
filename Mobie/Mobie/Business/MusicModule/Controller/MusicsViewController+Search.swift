//
//  MusicsViewController+Search.swift
//  Wakemusic
//
//  Created by Melo on 7/26/24.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit

extension MusicsViewController: UISearchBarDelegate {
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        debugPrint("searchText = \(searchText)")
        
        if searchText.isEmpty {
            self.viewModel.searchKey = nil
            
            let _ = self.viewModel.sortHomeMusics(viewModel.allMusicArray)
            self.tableView.reloadData()
        }else{
            self.searchWithKey(searchText)
        }
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        guard let searchText = searchBar.text, searchText.count > 0 else {
            self.searchController.searchBar.endEditing(true)
            self.searchController.dismiss(animated: true)
            return
        }
        
        debugPrint("searchText = \(searchText)")
        
        if self.isNoneMusic {
            self.searchController.searchBar.endEditing(true)
            self.tableView.kaka_playShakeAnim()
            return
        }
        
        self.searchWithKey(searchText)
    }
    
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        debugPrint("停止编辑 = \(searchBar.text ?? "")")
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        self.stopSearchAction(true)
    }
    
    func searchWithKey(_ keyword: String) {
        self.viewModel.searchKey = keyword
        
        let searchArray = self.viewModel.allMusicArray.filter { $0.searchMatcheItem(keyword) }
        let _ = self.viewModel.sortHomeMusics(searchArray)
        self.tableView.reloadData()
    }
    
    func configSearchBar() {
        self.navigationItem.searchController = self.searchController
        self.navigationItem.hidesSearchBarWhenScrolling = true
        self.navigationItem.preferredSearchBarPlacement = kaka_IsMacOS() ? .automatic : .stacked
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIApplication.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHidden(_:)), name: UIApplication.keyboardDidHideNotification, object: nil)
    }
    
    @objc func keyboardWillShow(_ notify: Notification) {
        let rect = notify.userInfo?[UIApplication.keyboardFrameEndUserInfoKey] as? CGRect
        let keyboardH = rect?.height ?? 366
                
        self.tableView.contentInset = UIEdgeInsets(top: kaka_IsMacOS() ? 20 : 0, left: 0, bottom: keyboardH, right: 0)
    }
    
    @objc func keyboardWillHidden(_ notify: Notification) {
        self.tableView.contentInset = UIEdgeInsets(top: kaka_IsMacOS() ? 20 : 0, left: 0, bottom: playingHeight, right: 0)
    }
    
    func stopSearchAction(_ animation: Bool) {
        self.searchController.searchBar.text = nil
        self.viewModel.searchKey = nil
        self.searchController.dismiss(animated: animation)
        
        let _ = self.viewModel.sortHomeMusics(viewModel.allMusicArray)
        self.tableView.reloadData()
    }
    
}
