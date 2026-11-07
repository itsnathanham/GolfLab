import UIKit

enum ProfilePhotoStorage {
    private static let directoryName = "ProfilePhotos"
    private static let activityByteBudget = 3_600

    static func image(from data: Data, maxPixel: CGFloat) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    static func save(_ image: UIImage, userId: UUID) throws -> String {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let photosURL = documentsURL.appendingPathComponent(directoryName, isDirectory: true)
        try FileManager.default.createDirectory(at: photosURL, withIntermediateDirectories: true)

        let stored = resized(image, maxPixel: 512)
        guard let imageData = stored.jpegData(compressionQuality: 0.85) else {
            throw ProfilePhotoError.compressionFailed
        }

        let relativePath = "\(directoryName)/\(userId.uuidString).jpg"
        try imageData.write(to: documentsURL.appendingPathComponent(relativePath), options: .atomic)
        return relativePath
    }

    static func load(path: String?) -> UIImage? {
        guard let path else { return nil }
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsURL.appendingPathComponent(path)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }

    static func delete(path: String?) {
        guard let path else { return }
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        try? FileManager.default.removeItem(at: documentsURL.appendingPathComponent(path))
    }

    /// JPEG small enough to ride inside a Live Activity. Nil when it cannot fit.
    static func activityThumbnail(from image: UIImage) -> Data? {
        let thumb = resized(image, maxPixel: 72)
        var quality: CGFloat = 0.7
        var data = thumb.jpegData(compressionQuality: quality)
        while let current = data, current.count > activityByteBudget, quality > 0.25 {
            quality -= 0.1
            data = thumb.jpegData(compressionQuality: quality)
        }
        guard let data, data.count <= activityByteBudget else { return nil }
        return data
    }

    private static func resized(_ image: UIImage, maxPixel: CGFloat) -> UIImage {
        let pixelWidth = image.size.width * image.scale
        let pixelHeight = image.size.height * image.scale
        let longest = max(pixelWidth, pixelHeight)
        guard longest > maxPixel, longest > 0 else { return image }
        let ratio = maxPixel / longest
        let size = CGSize(width: (pixelWidth * ratio).rounded(), height: (pixelHeight * ratio).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

enum ProfilePhotoError: LocalizedError {
    case compressionFailed

    var errorDescription: String? {
        switch self {
        case .compressionFailed:
            return "Couldn’t save that photo."
        }
    }
}
