//
//  PlayerSubViewDelegate.swift
//  Mobie
//
//  Created by 张文 on 5/27/25.
//

import KakaFoundation
import AppGroupKit

protocol PlayerSubViewDelegate: AnyObject {
    
    // 点击控制层
    func controlViewDidBottomControl(controlView: UIView)
    
    // 点击播放列表按钮
    func controlViewDidPlaylistBtn(controlView: UIView, playlistBtn: UIButton)
    
    // 点击歌词自定义按钮
    func controlViewDidLyricSetBtn(controlView: UIView, lyricSetBtn: UIButton)
    
    // 点击查看睡眠倒计时
    func playerBasicCellDidSleepTimer(basicView: UIView, sleepView: UIView?)
    
    // 点击进入横向大歌词
    func playerViewDidClickLyricBtn(playerView: UIView)
    
    // 滑动歌词列表
    func controlViewDidScrollLyric(lyricCell: PlayerLyricCollectCell, isScrollTop: Bool)
    
    // 点击查看支持的声道
    func playerBasicCellDidChannel(backView: UIView)
    
    // 点击封面
    func playerBasicCellDidCoverImage(backView: UIImageView, coverImage: UIImage)
    
    // 音乐标签编辑器
    func playerBasicCellDidMusicEditor(basicView: UIView)
    
    // 音频指纹识别
    func playerBasicCellDidAudioFinger(basicView: UIView)
    
    // 选择歌词
    func playerBasicCellDidSelectLyric(basicView: UIView)
    
    // 播放器内核
    func playerBasicCellDidPlayerEngine(basicView: UIView)
    
    // 播放器样式
    func playerBasicCellDidPlayerStyle(basicView: UIView)
    
    // 播放器背景
    func playerBasicCellDidPlayerBackground(basicView: UIView)
    
    // 歌词设置
    func playerBasicCellDidLyricSettings(basicView: UIView)
    
    // 前往VIP页面
    func playerSubViewDidClickPurchage(baseView: UIView)
    
    // 喜欢
    func playerSubViewDidClickFavorite(baseView: UIView)
    
    // 添加到歌单
    func playerSubViewDidClickAddPlaylisy(baseView: UIView)
    
}
