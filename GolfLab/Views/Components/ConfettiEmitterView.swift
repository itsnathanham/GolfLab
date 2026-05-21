import SwiftUI
import UIKit

/// Short-lived confetti burst for weekly-goal celebrations (disabled when Reduce Motion is on).
struct ConfettiEmitterView: UIViewRepresentable {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        uiView.layer.sublayers?
            .filter { $0.name == Self.emitterLayerName }
            .forEach { $0.removeFromSuperlayer() }

        guard !reduceMotion, uiView.bounds.width > 0 else { return }

        let emitter = CAEmitterLayer()
        emitter.name = Self.emitterLayerName
        emitter.emitterPosition = CGPoint(x: uiView.bounds.midX, y: -12)
        emitter.emitterShape = .line
        emitter.emitterSize = CGSize(width: uiView.bounds.width, height: 1)
        emitter.beginTime = CACurrentMediaTime()
        emitter.birthRate = 1

        let colors: [UIColor] = [
            UIColor(Color.streakSuccess),
            UIColor(Color.streakSuccessDeep),
            UIColor(Color.accentMid),
            UIColor(Color.streakOnSuccess),
            UIColor(Color.calendarPracticeDot)
        ]

        emitter.emitterCells = colors.map { color in
            let cell = CAEmitterCell()
            cell.birthRate = 14
            cell.lifetime = 4.2
            cell.velocity = 210
            cell.velocityRange = 90
            cell.emissionLongitude = .pi
            cell.emissionRange = .pi / 5
            cell.spin = 3.5
            cell.spinRange = 5
            cell.scale = 0.07
            cell.scaleRange = 0.04
            cell.contents = Self.rectangleImage.cgImage
            cell.color = color.cgColor
            return cell
        }

        uiView.layer.addSublayer(emitter)

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            emitter.birthRate = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            emitter.removeFromSuperlayer()
        }
    }

    private static let emitterLayerName = "glWeeklyGoalConfetti"

    private static let rectangleImage: UIImage = {
        let size = CGSize(width: 8, height: 12)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }()
}
