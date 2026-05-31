//
//  ReceiptGalleryView.swift
//  BillSplitter
//
//  Uses the system QLPreviewController for viewing receipt images.
//  Provides pinch-to-zoom, share, and swipe between images for free.
//

import SwiftUI
import QuickLook

// MARK: - SwiftUI wrapper

struct ReceiptGalleryView: View {
    let images: [Data]
    let initialIndex: Int
    @Environment(\.dismiss) private var dismiss

    @State private var tempURLs: [URL] = []

    var body: some View {
        ReceiptQuickLook(urls: tempURLs, initialIndex: initialIndex, onDismiss: { dismiss() })
            .ignoresSafeArea()
            .onAppear { tempURLs = writeTempFiles() }
            .onDisappear { cleanupTempFiles() }
    }

    private func writeTempFiles() -> [URL] {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("receipts_\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        return images.enumerated().compactMap { index, data in
            let url = dir.appendingPathComponent("Receipt_\(index + 1).jpg")
            do {
                try data.write(to: url)
                return url
            } catch {
                return nil
            }
        }
    }

    private func cleanupTempFiles() {
        guard let first = tempURLs.first else { return }
        let dir = first.deletingLastPathComponent()
        try? FileManager.default.removeItem(at: dir)
    }
}

// MARK: - QLPreviewController wrapper

struct ReceiptQuickLook: UIViewControllerRepresentable {
    let urls: [URL]
    let initialIndex: Int
    let onDismiss: () -> Void

    func makeUIViewController(context: Context) -> UINavigationController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        controller.delegate = context.coordinator
        controller.currentPreviewItemIndex = initialIndex
        let nav = UINavigationController(rootViewController: controller)
        return nav
    }

    func updateUIViewController(_ nav: UINavigationController, context: Context) {
        context.coordinator.urls = urls
        if let ql = nav.viewControllers.first as? QLPreviewController {
            ql.reloadData()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(urls: urls, onDismiss: onDismiss)
    }

    class Coordinator: NSObject, QLPreviewControllerDataSource, QLPreviewControllerDelegate {
        var urls: [URL]
        let onDismiss: () -> Void

        init(urls: [URL], onDismiss: @escaping () -> Void) {
            self.urls = urls
            self.onDismiss = onDismiss
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            urls.count
        }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> any QLPreviewItem {
            urls[index] as NSURL
        }

        func previewControllerDidDismiss(_ controller: QLPreviewController) {
            onDismiss()
        }
    }
}
