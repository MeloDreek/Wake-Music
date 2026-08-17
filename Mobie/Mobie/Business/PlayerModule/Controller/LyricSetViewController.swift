//
//  LyricSetViewController.swift
//  Mobie
//
//  Created by 张文 on 5/27/25.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit


/// 设置歌词样式
class LyricSetViewController: SuperViewController {
    override func preSetupSubViews() {
        super.preSetupSubViews()

        contentView.addSubview(tableView)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        tableView.frame = contentView.bounds
    }
    
    override func preSetupHandleBuness() {
        super.preSetupHandleBuness()
        
        if let navigationController = self.navigationController {
            navigationController.overrideUserInterfaceStyle = .dark
            self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(cancelButtonClick))
        }
        
        self.view.overrideUserInterfaceStyle = .dark
        self.title = "Lyrics Settings".localStr()
    }
    
    // MARK:  GET && SET
    
    // MARK:  懒加载
    
    lazy var tableView: UITableView = {
        let view = UITableView(frame: contentView.bounds, style: .insetGrouped)
        view.delegate = self
        view.dataSource = self
        view.overrideUserInterfaceStyle = .dark
        view.backgroundColor = .clear
        view.rowHeight = UITableView.automaticDimension
        view.contentInsetAdjustmentBehavior = .automatic
        view.register(LyricAnimationTableCell.self, forCellReuseIdentifier: "LyricAnimationTableCell")
        view.register(LyricFontSizeTableCell.self, forCellReuseIdentifier: "LyricFontSizeTableCell")
        view.register(LyricFontColorTableCell.self, forCellReuseIdentifier: "LyricFontColorTableCell")
        view.register(LyricFontAlignTableCell.self, forCellReuseIdentifier: "LyricFontAlignTableCell")
        view.register(LyricFontSpaceTableCell.self, forCellReuseIdentifier: "LyricFontSpaceTableCell")
        view.register(LyricOtherConfigTableCell.self, forCellReuseIdentifier: "LyricOtherConfigTableCell")
        return view
    }()
    
    lazy var dataArray: [LyricSetCellModel] = {
        let model1 = LyricSetCellModel(group: .animationGroup, headTitle: "Mini Lyric Animation".localStr(), footTitle: nil)
        let model2 = LyricSetCellModel(group: .timeOffsetGroup, headTitle: "Lyrics".localStr(), footTitle: "Only applies to the currently playing song".localStr())
        let model3 = LyricSetCellModel(group: .lowPowerGroup, headTitle: "Performance".localStr(), footTitle: "When enabled, the UI refreshes 1,000 times per second for millisecond-precise lyrics, but CPU usage and power consumption can be 10× higher than in Power Saving mode.".localStr())
        let model4 = LyricSetCellModel(group: .norFontGroup, headTitle: "Regular Font".localStr(), footTitle: nil)
        let model5 = LyricSetCellModel(group: .selFontGroup, headTitle: "Highlight Font".localStr(), footTitle: nil)
        let model6 = LyricSetCellModel(group: .norColorGroup, headTitle: "Regular Color".localStr(), footTitle: nil)
        let model7 = LyricSetCellModel(group: .selColorGroup, headTitle: "Highlight Color".localStr(), footTitle: nil)
        let model8 = LyricSetCellModel(group: .alignmentGroup, headTitle: "Alignment".localStr(), footTitle: nil)
        let model9 = LyricSetCellModel(group: .lineSpaceGroup, headTitle: "Line Spacing".localStr(), footTitle: nil)
        return [model1, model2, model3, model4, model5, model6, model7, model8, model9]
    }()
    
}

extension LyricSetViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return dataArray.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellModel = dataArray[indexPath.section]
        if cellModel.group == .animationGroup {
            // 迷你动画
            let cell = tableView.dequeueReusableCell(withIdentifier: "LyricAnimationTableCell", for: indexPath) as! LyricAnimationTableCell
            cell.animationArray = MiniLyricAnimation.allCases
            return cell
        }else if cellModel.group == .lowPowerGroup || cellModel.group == .timeOffsetGroup {
            // 节能模式
            let cell = tableView.dequeueReusableCell(withIdentifier: "LyricOtherConfigTableCell", for: indexPath) as! LyricOtherConfigTableCell
            cell.itemType = cellModel.group
            return cell
        }else if cellModel.group == .norFontGroup || cellModel.group == .selFontGroup {
            // 字体大小
            let cell = tableView.dequeueReusableCell(withIdentifier: "LyricFontSizeTableCell", for: indexPath) as! LyricFontSizeTableCell
            cell.itemType = cellModel.group
            return cell
        }else if cellModel.group == .norColorGroup || cellModel.group == .selColorGroup {
            // 字体颜色
            let cell = tableView.dequeueReusableCell(withIdentifier: "LyricFontColorTableCell", for: indexPath) as! LyricFontColorTableCell
            cell.itemType = cellModel.group
            return cell
        }else if cellModel.group == .alignmentGroup {
            // 对齐方式
            let cell = tableView.dequeueReusableCell(withIdentifier: "LyricFontAlignTableCell", for: indexPath) as! LyricFontAlignTableCell
            cell.itemType = cellModel.group
            return cell
        }else{
            // 上下间距
            let cell = tableView.dequeueReusableCell(withIdentifier: "LyricFontSpaceTableCell", for: indexPath) as! LyricFontSpaceTableCell
            cell.itemType = cellModel.group
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let cellModel = dataArray[section]
        return cellModel.headTitle
    }
    
    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        let cellModel = dataArray[section]
        return cellModel.footTitle
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let cellModel = dataArray[indexPath.section]
        if cellModel.group == .animationGroup {
            return LyricAnimationTableCell.cellHeight
        }else{
            return UITableView.automaticDimension
        }
    }
    
}
