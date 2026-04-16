//
//  File+Animation.swift
//  Mobie
//
//  Created by 张文 on 5/29/25.
//

import KakaFoundation
import KakaUIKit

extension MusicPlayerViewController {
    
    // 烟花特效
    func setupFireworks() {
        let caELayer = CAEmitterLayer()
        // 发射源
        caELayer.emitterPosition = CGPointMake(self.view.width / 2, self.view.height * 0.68)
        // 发射源尺寸大小
        caELayer.emitterSize = CGSize(width: 50.ckValue(), height: 0)
        // 发射源模式
        caELayer.emitterMode = .outline
        // 发射源的形状
        caELayer.emitterShape = .line
        // 渲染模式
        caELayer.renderMode = .additive
        // 发射方向
        caELayer.velocity = 1
        // 随机产生粒子
        caELayer.seed = UInt32(arc4random() % 100) + 1
        
        let liziColors: [UIColor] = [UIColor.systemGreen, UIColor.systemYellow, UIColor.systemBlue, UIColor.systemRed, UIColor.systemOrange, UIColor.hexColor("#B149FA"), UIColor.hexColor("#FF00FF")]
        
        // cell
        let cell = CAEmitterCell()
        // 速率
        cell.birthRate = 1.0
        // 发射的角度
        cell.emissionRange = 0.11 * .pi
        // 速度
        cell.velocity = 300
        // 范围
        cell.velocityRange = 150
        // Y轴 加速度分量
        cell.yAcceleration = 65
        // 生命周期
        cell.lifetime = 2.04
        // 是个CGImageRef的对象,既粒子要展现的图片
        cell.contents = UIImage(named: "lizi_green")!.cgImage
        // 缩放比例
        cell.scale = 0.2
        // 粒子的颜色
        cell.color = liziColors.randomElement()!.cgColor
        // 一个粒子的颜色green 能改变的范围
        cell.greenRange = 1.0
        // 一个粒子的颜色red 能改变的范围
        cell.redRange = 1.0
        // 一个粒子的颜色blue 能改变的范围
        cell.blueRange = 1.0
        // 子旋转角度范围
        cell.spinRange = .pi

        // 爆炸
        let burst = CAEmitterCell()
        // 粒子产生系数
        burst.birthRate = 1.0
        // 速度
        burst.velocity = 0
        // 缩放比例
        burst.scale = 2.5
        // shifting粒子red在生命周期内的改变速度
        burst.redSpeed = -1.5
        // shifting粒子blue在生命周期内的改变速度
        burst.blueSpeed = 1.5
        // shifting粒子green在生命周期内的改变速度
        burst.greenSpeed = 1.0
        // 生命周期
        burst.lifetime = 0.35

        // 火花 and finally, the sparks
        let spark = CAEmitterCell()
        // 粒子产生系数，默认为1.0
        spark.birthRate = 400
        // 速度
        spark.velocity = 125
        // 360 deg //周围发射角度
        spark.emissionRange = 2 * .pi
        // gravity //y方向上的加速度分量
        spark.yAcceleration = 75
        // 粒子生命周期
        spark.lifetime = 4
        // 是个CGImageRef的对象,既粒子要展现的图片
        spark.contents = UIImage(named: "lizi_red")!.cgImage
        // 缩放比例速度
        spark.scaleSpeed = -0.2
        // 粒子green在生命周期内的改变速度
        spark.greenSpeed = -0.1
        // 粒子red在生命周期内的改变速度
        spark.redSpeed = 0.4
        // 粒子blue在生命周期内的改变速度
        spark.blueSpeed = -0.1
        // 粒子透明度在生命周期内的改变速度
        spark.alphaSpeed = -0.25
        // 子旋转角度
        spark.spin = 2 * .pi
        // 子旋转角度范围
        spark.spinRange = 2 * .pi

        caELayer.emitterCells = [cell]
        cell.emitterCells = [burst]
        burst.emitterCells = [spark]

        self.view.layer.addSublayer(caELayer)
    }
}
