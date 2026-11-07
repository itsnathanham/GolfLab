import Foundation
import UIKit

enum ProfilePhotoStorage {
    static let photosDirectory = "ProfilePhotos"
    
    static func saveProfilePhoto(_ image: UIImage, userId: UUID) throws -> String {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let photosURL = documentsURL.appendingPathComponent(photosDirectory)
        
        try FileManager.default.createDirectory(at: photosURL, withIntermediateDirectories: true)
        
        guard let imageData = image.jpegData(compressionQuality: 0.85) else {
            throw ProfilePhotoError.compressionFailed
        }
        
        let filename = "\(userId.uuidString).jpg"
        let fileURL = photosURL.appendingPathComponent(filename)
        
        try imageData.write(to: fileURL)
        
        return "\(photosDirectory)/\(filename)"
    }
    
    static func loadProfilePhoto(path: String?) -> UIImage? {
        guard let path = path else { return nil }
        
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsURL.appendingPathComponent(path)
        
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let image = UIImage(data: data) else {
            return nil
        }
        
        return image
    }
    
    static func deleteProfilePhoto(path: String?) {
        guard let path = path else { return }
        
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsURL.appendingPathComponent(path)
        
        try? FileManager.default.removeItem(at: fileURL)
    }
}

enum ProfilePhotoError: LocalizedError {
    case compressionFailed
    
    var errorDescription: String? {
        switch self {
        case .compressionFailed:
            return "Failed to compress image"
        }
    }
}
