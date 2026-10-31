import SwiftUI
import UIKit

/// Golf-themed firework celebration: golf balls launch and explode into themed particles.
struct GolfFireworkEmitterView: UIViewRepresentable {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        uiView.layer.sublayers?
            .filter { $0.name?.hasPrefix(Self.layerNamePrefix) ?? false }
            .forEach { $0.removeFromSuperlayer() }

        guard !reduceMotion, uiView.bounds.width > 0, uiView.bounds.height > 0 else { return }

        let launches = [
            LaunchConfig(delay: 0.0, xPosition: 0.3, particleType: .balls),
            LaunchConfig(delay: 0.6, xPosition: 0.7, particleType: .flags),
            LaunchConfig(delay: 1.2, xPosition: 0.5, particleType: .tees)
        ]

        for launch in launches {
            DispatchQueue.main.asyncAfter(deadline: .now() + launch.delay) {
                self.createFireworkBurst(
                    in: uiView,
                    xFraction: launch.xPosition,
                    particleType: launch.particleType
                )
            }
        }
    }

    private func createFireworkBurst(in view: UIView, xFraction: Double, particleType: ParticleType) {
        let startX = view.bounds.width * xFraction
        let startY = view.bounds.height
        let explosionY = view.bounds.height * Double.random(in: 0.35...0.50)

        let emitter = CAEmitterLayer()
        emitter.name = "\(Self.layerNamePrefix)_\(UUID().uuidString)"
        emitter.emitterPosition = CGPoint(x: startX, y: explosionY)
        emitter.emitterShape = .point
        emitter.emitterSize = CGSize(width: 1, height: 1)
        emitter.renderMode = .additive
        emitter.beginTime = CACurrentMediaTime()

        let colors = particleType.colors
        let particleImage = particleType.image

        emitter.emitterCells = colors.map { color in
            let cell = CAEmitterCell()
            cell.birthRate = Float.random(in: 22...28)
            cell.lifetime = Float.random(in: 1.8...2.4)
            cell.velocity = CGFloat.random(in: 180...260)
            cell.velocityRange = 70
            cell.emissionRange = .pi * 2
            cell.spin = Double.random(in: 2.5...5.0)
            cell.spinRange = 3
            cell.scale = particleType.scale + CGFloat.random(in: -0.02...0.02)
            cell.scaleRange = 0.03
            cell.scaleSpeed = -0.15
            cell.alphaSpeed = -0.5
            cell.contents = particleImage.cgImage
            cell.color = color.cgColor
            return cell
        }

        view.layer.addSublayer(emitter)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            emitter.birthRate = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            emitter.removeFromSuperlayer()
        }
    }

    private static let layerNamePrefix = "glFirework"

    private struct LaunchConfig {
        let delay: TimeInterval
        let xPosition: Double
        let particleType: ParticleType
    }

    private enum ParticleType {
        case balls
        case flags
        case tees

        var colors: [UIColor] {
            switch self {
            case .balls:
                return [
                    UIColor(Color.streakSuccess),
                    UIColor(Color.streakSuccessDeep),
                    UIColor(Color.streakOnSuccess)
                ]
            case .flags:
                return [
                    UIColor(Color.accent),
                    UIColor(Color.accentMid),
                    UIColor(Color.accentTrack)
                ]
            case .tees:
                return [
                    UIColor(Color.streakSuccess),
                    UIColor(Color.accent),
                    UIColor(Color.streakSuccessDeep)
                ]
            }
        }

        var image: UIImage {
            switch self {
            case .balls:
                return Self.golfBallImage
            case .flags:
                return Self.flagImage
            case .tees:
                return Self.teeImage
            }
        }

        var scale: CGFloat {
            switch self {
            case .balls:
                return 0.08
            case .flags:
                return 0.10
            case .tees:
                return 0.06
            }
        }

        private static let golfBallImage: UIImage = {
            let size = CGSize(width: 12, height: 12)
            let renderer = UIGraphicsImageRenderer(size: size)
            return renderer.image { ctx in
                UIColor.white.setFill()
                ctx.cgContext.fillEllipse(in: CGRect(origin: .zero, size: size))
                
                UIColor.white.withAlphaComponent(0.3).setFill()
                for _ in 0..<8 {
                    let x = CGFloat.random(in: 2...10)
                    let y = CGFloat.random(in: 2...10)
                    ctx.cgContext.fillEllipse(in: CGRect(x: x, y: y, width: 1.5, height: 1.5))
                }
            }
        }()

        private static let flagImage: UIImage = {
            let size = CGSize(width: 10, height: 14)
            let renderer = UIGraphicsImageRenderer(size: size)
            return renderer.image { ctx in
                UIColor.white.setStroke()
                UIColor.white.setFill()
                
                ctx.cgContext.setLineWidth(1.5)
                ctx.cgContext.move(to: CGPoint(x: 1, y: 0))
                ctx.cgContext.addLine(to: CGPoint(x: 1, y: 14))
                ctx.cgContext.strokePath()
                
                let flagPath = UIBezierPath()
                flagPath.move(to: CGPoint(x: 1, y: 1))
                flagPath.addLine(to: CGPoint(x: 9, y: 3.5))
                flagPath.addLine(to: CGPoint(x: 1, y: 6))
                flagPath.close()
                flagPath.fill()
            }
        }()

        private static let teeImage: UIImage = {
            let size = CGSize(width: 8, height: 12)
            let renderer = UIGraphicsImageRenderer(size: size)
            return renderer.image { ctx in
                UIColor.white.setFill()
                
                ctx.cgContext.fillEllipse(in: CGRect(x: 1, y: 0, width: 6, height: 4))
                
                let teePath = UIBezierPath()
                teePath.move(to: CGPoint(x: 3, y: 4))
                teePath.addLine(to: CGPoint(x: 2, y: 12))
                teePath.addLine(to: CGPoint(x: 6, y: 12))
                teePath.addLine(to: CGPoint(x: 5, y: 4))
                teePath.close()
                teePath.fill()
            }
        }()
    }
}
