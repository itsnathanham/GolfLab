import SwiftUI
import UIKit

struct CircularPhotoEditor: View {
    let image: UIImage
    let onSave: (UIImage) -> Void
    let onCancel: () -> Void

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private let circleSide: CGFloat = 280
    private let maxScale: CGFloat = 4

    var body: some View {
        VStack(spacing: 0) {
            topNav
                .padding(.horizontal, GLLayout.horizontalInset)
                .padding(.top, GLTopBarMetrics.sheetTopPadding)
                .padding(.bottom, 24)

            Text("Pinch to zoom, drag to reposition")
                .font(.glFootnote)
                .foregroundColor(.textTertiary)
                .padding(.bottom, 32)

            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: circleSide, height: circleSide)
                    .clipped()
                    .scaleEffect(scale)
                    .offset(offset)
                    .frame(width: circleSide, height: circleSide)
                    .clipped()
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    .gesture(magnify)
                    .simultaneousGesture(drag)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: 12) {
                GLPrimaryCTAButton(title: "Save") { onSave(croppedImage()) }
                GLSecondaryGhostButton(title: "Cancel") { onCancel() }
            }
            .padding(.horizontal, GLLayout.horizontalInset)
            .padding(.vertical, 24)
        }
        .background(Color.appBackground)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var topNav: some View {
        HStack {
            GLCircleBackButton { onCancel() }
            Spacer()
            Text("Edit Photo")
                .font(.glNavTitle)
                .foregroundColor(.textPrimary)
            Spacer()
            Color.clear.frame(width: 32, height: 32)
        }
    }

    private var magnify: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let delta = value / lastScale
                lastScale = value
                scale = min(max(scale * delta, 1), maxScale)
                offset = clamped(offset)
                lastOffset = offset
            }
            .onEnded { _ in
                lastScale = 1
            }
    }

    private var drag: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = clamped(CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                ))
            }
            .onEnded { _ in
                lastOffset = offset
            }
    }

    private func fittedSize() -> CGSize {
        let imageSize = image.size
        guard imageSize.width > 0, imageSize.height > 0 else {
            return CGSize(width: circleSide, height: circleSide)
        }
        let fill = max(circleSide / imageSize.width, circleSide / imageSize.height)
        return CGSize(width: imageSize.width * fill, height: imageSize.height * fill)
    }

    private func clamped(_ proposed: CGSize) -> CGSize {
        let fitted = fittedSize()
        let maxX = max(0, (fitted.width * scale - circleSide) / 2)
        let maxY = max(0, (fitted.height * scale - circleSide) / 2)
        return CGSize(
            width: min(max(proposed.width, -maxX), maxX),
            height: min(max(proposed.height, -maxY), maxY)
        )
    }

    private func croppedImage() -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let side = circleSide
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format)
        return renderer.image { _ in
            UIColor.black.setFill()
            UIBezierPath(rect: CGRect(x: 0, y: 0, width: side, height: side)).fill()
            let fitted = fittedSize()
            let drawSize = CGSize(width: fitted.width * scale, height: fitted.height * scale)
            let origin = CGPoint(
                x: (side - drawSize.width) / 2 + offset.width,
                y: (side - drawSize.height) / 2 + offset.height
            )
            image.draw(in: CGRect(origin: origin, size: drawSize))
        }
    }
}
