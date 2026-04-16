//
//  FullScreenNavController.swift
//  Mobie
//
//  Created by 张文 on 10/24/24.
//

import KakaFoundation
import KakaUIKit
import PanModal

class FullScreenNavController: UINavigationController, PanModalPresentable {
    
    init(_ initVC: UIViewController) {
        super.init(nibName: nil, bundle: nil)
        self.viewControllers = [initVC]
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError()
    }
    
    override func popViewController(animated: Bool) -> UIViewController? {
        let vc = super.popViewController(animated: animated)
        self.panModalSetNeedsLayoutUpdate()
        return vc
    }

    override func pushViewController(_ viewController: UIViewController, animated: Bool) {
        super.pushViewController(viewController, animated: animated)
        self.panModalSetNeedsLayoutUpdate()
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    var panScrollable: UIScrollView? {
        return (topViewController as? PanModalPresentable)?.panScrollable
    }
    
    var orientation: PanModalOrientation {
        return .vertical
    }
    
    var verticalOffset: CGFloat {
        return 0
    }
    
    var horizontalOffset: CGFloat {
        return 0
    }

    var longForm: PanModalHeight {
        return .maxHeight
    }

    var shortFormHeight: PanModalHeight {
        return .maxHeight
    }
    
    var cornerRadius: CGFloat {
        let cornerRadius = (self.view.window?.screen ?? UIScreen.main).cornerRadius()
        return cornerRadius * 0.9
    }
    
}

extension UIScreen {
    func cornerRadius() -> CGFloat {
        guard let cornerRadius = self.value(forKey:"_displayCornerRadius") as? CGFloat else {
            return 0
        }
        
        return cornerRadius
    }
}
