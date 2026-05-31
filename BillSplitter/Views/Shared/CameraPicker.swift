//
//  CameraPicker.swift
//  BillSplitter
//
//  UIImagePickerController wrapper for camera capture.
//  Appends the captured image to the receipts array.
//  Guards against devices without a camera.
//

import SwiftUI
import UIKit
import AVFoundation

// MARK: - Camera Availability

enum CameraAccess {
    /// Returns true only when the device has a camera AND permission is not denied.
    static var isAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }
}

// MARK: - Camera Picker

struct CameraPicker: UIViewControllerRepresentable {
    @Binding var receiptImages: [Data]
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.allowsEditing = false
        picker.delegate = context.coordinator

        // Use back camera with auto device to avoid unsupported device errors
        if UIImagePickerController.isCameraDeviceAvailable(.rear) {
            picker.cameraDevice = .rear
        }

        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker

        init(_ parent: CameraPicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                let downsized = Self.downsizeIfNeeded(image, maxDimension: 2048)
                if let jpeg = downsized.jpegData(compressionQuality: 0.7) {
                    parent.receiptImages.append(jpeg)
                }
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }

        /// Downscale large camera images to avoid memory issues and zero-dimension render bugs.
        private static func downsizeIfNeeded(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
            let size = image.size
            guard size.width > maxDimension || size.height > maxDimension else { return image }

            let scale: CGFloat
            if size.width > size.height {
                scale = maxDimension / size.width
            } else {
                scale = maxDimension / size.height
            }

            let newSize = CGSize(
                width: max(1, floor(size.width * scale)),
                height: max(1, floor(size.height * scale))
            )

            let renderer = UIGraphicsImageRenderer(size: newSize)
            return renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: newSize))
            }
        }
    }
}
