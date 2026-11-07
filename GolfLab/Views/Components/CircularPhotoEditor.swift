import SwiftUI
import PhotosUI

struct CircularPhotoEditor: View {
    let image: UIImage
    let onSave: (UIImage) -> Void
    let onCancel: () -> Void
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    private let circleSize: CGFloat = 280
    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 4.0
    
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
                Color.black.opacity(0.7)
                
                GeometryReader { geometry in
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    let delta = value / lastScale
                                    lastScale = value
                                    scale = min(max(scale * delta, minScale), maxScale)
                                }
                                .onEnded { _ in
                                    lastScale = 1.0
                                }
                        )
                        .simultaneousGesture(
                            DragGesture()
                                .onChanged { value in
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                }
                                .onEnded { _ in
                                    lastOffset = offset
                                }
                        )
                }
                .frame(width: circleSize, height: circleSize)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.opacity(0.9))
            
            actionButtons
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
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            GLPrimaryCTAButton(title: "Save") {
                savePhoto()
            }
            GLSecondaryGhostButton(title: "Cancel") {
                onCancel()
            }
        }
    }
    
    private func savePhoto() {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: circleSize, height: circleSize))
        let croppedImage = renderer.image { context in
            let rect = CGRect(origin: .zero, size: CGSize(width: circleSize, height: circleSize))
            context.cgContext.addEllipse(in: rect)
            context.cgContext.clip()
            
            let imageSize = image.size
            let widthRatio = circleSize / imageSize.width
            let heightRatio = circleSize / imageSize.height
            let ratio = max(widthRatio, heightRatio)
            
            let scaledWidth = imageSize.width * ratio * scale
            let scaledHeight = imageSize.height * ratio * scale
            
            let xOffset = (circleSize - scaledWidth) / 2 + offset.width
            let yOffset = (circleSize - scaledHeight) / 2 + offset.height
            
            image.draw(in: CGRect(x: xOffset, y: yOffset, width: scaledWidth, height: scaledHeight))
        }
        
        onSave(croppedImage)
    }
}
