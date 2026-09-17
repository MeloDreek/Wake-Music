import UIKit

// Run inside the simulator, since UIKit's state-image fallback is the regression.
for background in [false, true] {
    let button = UIButton(type: .custom)
    let play = UIImage(systemName: "play.fill")!
    let pause = UIImage(systemName: "pause.fill")!
    if background {
        button.setBackgroundImage(play, for: .normal)
        button.setBackgroundImage(pause, for: .selected)
        button.setBackgroundImage(button.backgroundImage(for: .selected), for: [.selected, .highlighted])
    } else {
        button.setImage(play, for: .normal)
        button.setImage(pause, for: .selected)
        button.setImage(button.image(for: .selected), for: [.selected, .highlighted])
    }
    func expect(_ image: UIImage) {
        precondition((background ? button.currentBackgroundImage : button.currentImage) === image)
    }
    for _ in 0..<100 {
        button.isSelected = true
        expect(pause)
        button.isHighlighted = true
        expect(pause) // Touch down must not display play before a pause command.
        button.isHighlighted = false
        expect(pause) // Canceled touch / release before the state update.
        button.isSelected = false
        expect(play)
        button.isHighlighted = true
        expect(play)
        button.isHighlighted = false
        expect(play)
    }
}
print("PASS: 1,200 UIKit foreground/background image checks across press/release/play/pause")
