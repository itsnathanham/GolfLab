import SwiftUI
import UIKit

/// Golf-themed fireworks: three shells climb from the bottom edge and burst into mini golf balls, flags, or tees.
/// Timing constants are shared with `WeeklyGoalCelebrationOverlay` so haptics land on each burst.
struct GolfFireworkEmitterView: UIViewRepresentable {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Seconds after appear until each shell leaves the bottom edge. The first waits for a dismissing sheet to clear.
    static let launchDelays: [TimeInterval] = [0.5, 1.1, 1.7]
    /// Seconds a shell climbs before it bursts.
    static let riseDuration: TimeInterval = 0.55
    /// Seconds after appear when each shell bursts.
    static var burstTimes: [TimeInterval] { launchDelays.map { $0 + riseDuration } }
    /// Seconds until the last particles have faded.
    static var showDuration: TimeInterval { (burstTimes.last ?? 0) + 2.6 }

    func makeUIView(context: Context) -> GolfFireworkView {
        let view = GolfFireworkView()
        view.animationsEnabled = !reduceMotion
        return view
    }

    func updateUIView(_ uiView: GolfFireworkView, context: Context) {
        uiView.animationsEnabled = !reduceMotion
    }
}

/// Runs the show once it has a non-zero size, so it does not depend on how often SwiftUI calls `updateUIView`.
final class GolfFireworkView: UIView {
    var animationsEnabled = true
    private var hasLaunched = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard animationsEnabled, !hasLaunched, bounds.width > 0, bounds.height > 0 else { return }
        hasLaunched = true
        scheduleShow()
    }

    private func scheduleShow() {
        let kinds = ParticleKind.allCases.shuffled()
        for (index, delay) in GolfFireworkEmitterView.launchDelays.enumerated() {
            let kind = kinds[index % kinds.count]
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.launchShell(kind: kind)
            }
        }
    }

    // MARK: - Shell

    private func launchShell(kind: ParticleKind) {
        guard window != nil else { return }
        let rise = GolfFireworkEmitterView.riseDuration
        let startX = bounds.width * CGFloat.random(in: 0.2...0.8)
        let start = CGPoint(x: startX, y: bounds.height + 16)
        let apex = CGPoint(
            x: min(max(startX + CGFloat.random(in: -48...48), 32), bounds.width - 32),
            y: bounds.height * CGFloat.random(in: 0.26...0.46)
        )

        let path = UIBezierPath()
        path.move(to: start)
        path.addQuadCurve(to: apex, controlPoint: CGPoint(x: start.x, y: apex.y + (start.y - apex.y) * 0.35))

        let flight = CAKeyframeAnimation(keyPath: "position")
        flight.path = path.cgPath
        flight.duration = rise
        flight.timingFunction = CAMediaTimingFunction(name: .easeOut)
        flight.fillMode = .forwards
        flight.isRemovedOnCompletion = false

        let shell = CALayer()
        shell.contents = ParticleKind.balls.image.cgImage
        shell.contentsScale = ParticleKind.balls.image.scale
        shell.bounds = CGRect(origin: .zero, size: ParticleKind.balls.image.size)
        shell.position = start
        layer.addSublayer(shell)
        shell.add(flight, forKey: "flight")

        let trail = makeTrailEmitter(color: kind.trailColor)
        trail.emitterPosition = start
        layer.addSublayer(trail)
        let trailFlight = CAKeyframeAnimation(keyPath: "emitterPosition")
        trailFlight.path = path.cgPath
        trailFlight.duration = rise
        trailFlight.timingFunction = flight.timingFunction
        trailFlight.fillMode = .forwards
        trailFlight.isRemovedOnCompletion = false
        trail.add(trailFlight, forKey: "flight")

        DispatchQueue.main.asyncAfter(deadline: .now() + rise) { [weak self] in
            shell.removeFromSuperlayer()
            trail.birthRate = 0
            self?.burst(at: apex, kind: kind)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + rise + 1.0) {
            trail.removeFromSuperlayer()
        }
    }

    private func makeTrailEmitter(color: UIColor) -> CAEmitterLayer {
        let emitter = CAEmitterLayer()
        emitter.frame = bounds
        emitter.emitterShape = .point
        emitter.renderMode = .additive
        emitter.beginTime = CACurrentMediaTime()

        let cell = CAEmitterCell()
        cell.contents = ParticleKind.sparkImage.cgImage
        cell.contentsScale = ParticleKind.sparkImage.scale
        cell.birthRate = 110
        cell.lifetime = 0.45
        cell.velocity = 30
        cell.velocityRange = 20
        cell.emissionLongitude = .pi / 2
        cell.emissionRange = .pi / 6
        cell.yAcceleration = 140
        cell.scale = 0.7
        cell.scaleRange = 0.3
        cell.scaleSpeed = -0.9
        cell.alphaSpeed = -2.2
        cell.color = color.cgColor
        emitter.emitterCells = [cell]
        return emitter
    }

    // MARK: - Burst

    private func burst(at point: CGPoint, kind: ParticleKind) {
        guard window != nil else { return }
        let emitWindow: TimeInterval = 0.12
        let particleCount = Int.random(in: 38...58)
        let colors = kind.colors
        let speed = CGFloat.random(in: 170...250)
        let image = kind.image

        let emitter = CAEmitterLayer()
        emitter.frame = bounds
        emitter.emitterPosition = point
        emitter.emitterShape = .point
        emitter.beginTime = CACurrentMediaTime()
        emitter.emitterCells = colors.map { color in
            let cell = CAEmitterCell()
            cell.contents = image.cgImage
            cell.contentsScale = image.scale
            cell.birthRate = Float(particleCount) / Float(colors.count) / Float(emitWindow)
            cell.lifetime = Float.random(in: 1.7...2.3)
            cell.lifetimeRange = 0.3
            cell.velocity = speed
            cell.velocityRange = speed * 0.35
            cell.emissionRange = .pi * 2
            cell.yAcceleration = 170
            cell.spin = CGFloat.random(in: 1.5...3.5)
            cell.spinRange = 2
            cell.scale = 1
            cell.scaleRange = 0.25
            cell.scaleSpeed = -0.25
            cell.alphaSpeed = -0.45
            cell.color = color.cgColor
            return cell
        }
        layer.addSublayer(emitter)
        addFlash(at: point, color: kind.trailColor)

        DispatchQueue.main.asyncAfter(deadline: .now() + emitWindow) {
            emitter.birthRate = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
            emitter.removeFromSuperlayer()
        }
    }

    private func addFlash(at point: CGPoint, color: UIColor) {
        let flash = CALayer()
        flash.bounds = CGRect(x: 0, y: 0, width: 44, height: 44)
        flash.cornerRadius = 22
        flash.position = point
        flash.backgroundColor = color.withAlphaComponent(0.85).cgColor
        layer.addSublayer(flash)

        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1
        fade.toValue = 0
        let grow = CABasicAnimation(keyPath: "transform.scale")
        grow.fromValue = 0.3
        grow.toValue = 1.8
        let group = CAAnimationGroup()
        group.animations = [fade, grow]
        group.duration = 0.35
        group.timingFunction = CAMediaTimingFunction(name: .easeOut)
        group.fillMode = .forwards
        group.isRemovedOnCompletion = false
        flash.add(group, forKey: "flash")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            flash.removeFromSuperlayer()
        }
    }

    // MARK: - Particles

    /// Each burst is a single kind so the eye reads "golf balls", "flags", or "tees" rather than a mixed cloud.
    private enum ParticleKind: CaseIterable {
        case balls
        case flags
        case tees

        /// Cell tints multiply the white artwork; nothing here may be black or it vanishes on the dark theme.
        var colors: [UIColor] {
            switch self {
            case .balls:
                return [.white, .white, UIColor(Color.streakSuccessDeep)]
            case .flags:
                return [UIColor(Color.accent), UIColor(Color.chartPurple), .white]
            case .tees:
                return [UIColor(Color.chartYellow), UIColor(Color.accentMid), .white]
            }
        }

        var trailColor: UIColor {
            switch self {
            case .balls:
                return .white
            case .flags:
                return UIColor(Color.accent)
            case .tees:
                return UIColor(Color.chartYellow)
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

        static let sparkImage: UIImage = {
            let size = CGSize(width: 4, height: 4)
            return UIGraphicsImageRenderer(size: size).image { ctx in
                UIColor.white.setFill()
                ctx.cgContext.fillEllipse(in: CGRect(origin: .zero, size: size))
            }
        }()

        private static let golfBallImage: UIImage = {
            let size = CGSize(width: 12, height: 12)
            return UIGraphicsImageRenderer(size: size).image { ctx in
                UIColor.white.setFill()
                ctx.cgContext.fillEllipse(in: CGRect(origin: .zero, size: size))
                UIColor(white: 0.72, alpha: 1).setFill()
                for row in 0..<3 {
                    for column in 0..<3 {
                        let x = 2.5 + CGFloat(column) * 3 + (row.isMultiple(of: 2) ? 0 : 1.2)
                        let y = 2.5 + CGFloat(row) * 3
                        ctx.cgContext.fillEllipse(in: CGRect(x: x, y: y, width: 1.4, height: 1.4))
                    }
                }
            }
        }()

        private static let flagImage: UIImage = {
            let size = CGSize(width: 12, height: 16)
            return UIGraphicsImageRenderer(size: size).image { ctx in
                UIColor.white.setStroke()
                UIColor.white.setFill()
                ctx.cgContext.setLineWidth(1.6)
                ctx.cgContext.setLineCap(.round)
                ctx.cgContext.move(to: CGPoint(x: 1.5, y: 0.8))
                ctx.cgContext.addLine(to: CGPoint(x: 1.5, y: 15.2))
                ctx.cgContext.strokePath()

                let pennant = UIBezierPath()
                pennant.move(to: CGPoint(x: 2, y: 1))
                pennant.addLine(to: CGPoint(x: 11.5, y: 4.2))
                pennant.addLine(to: CGPoint(x: 2, y: 7.4))
                pennant.close()
                pennant.fill()
            }
        }()

        private static let teeImage: UIImage = {
            let size = CGSize(width: 8, height: 16)
            return UIGraphicsImageRenderer(size: size).image { ctx in
                UIColor.white.setFill()
                ctx.cgContext.fillEllipse(in: CGRect(x: 0.5, y: 0, width: 7, height: 4))
                let stem = UIBezierPath()
                stem.move(to: CGPoint(x: 2.2, y: 3.5))
                stem.addLine(to: CGPoint(x: 5.8, y: 3.5))
                stem.addLine(to: CGPoint(x: 4.6, y: 16))
                stem.addLine(to: CGPoint(x: 3.4, y: 16))
                stem.close()
                stem.fill()
            }
        }()
    }
}
