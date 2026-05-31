//
//  ExportButton.swift
//  BillSplitter
//
//  Reusable export menu (CSV / PDF) with preview and share.
//

import SwiftUI
import QuickLook

/// A toolbar-style button that presents CSV / PDF export options.
/// PDFs open in a preview (with share button); CSVs go straight to share sheet.
struct ExportButton: View {
    let expenses: [Expense]
    let scope: ExportScope

    @State private var previewFile: IdentifiableURL?
    @State private var csvFile: IdentifiableURL?

    var body: some View {
        Menu {
            Button {
                if let url = ExportService.csvFile(from: expenses, scope: scope) {
                    csvFile = IdentifiableURL(url: url)
                }
            } label: {
                Label("Export as CSV", systemImage: "tablecells")
            }

            Button {
                if let url = ExportService.pdfFile(
                    from: expenses, scope: scope, currencySymbol: CurrencyHelper.symbol
                ) {
                    previewFile = IdentifiableURL(url: url)
                }
            } label: {
                Label("Export as PDF", systemImage: "doc.richtext")
            }
        } label: {
            Image(systemName: "square.and.arrow.up")
        }
        .disabled(expenses.isEmpty)
        .sheet(item: $previewFile) { item in
            FilePreviewSheet(url: item.url)
        }
        .sheet(item: $csvFile) { item in
            ShareSheet(items: [item.url])
        }
    }
}

/// A button that presents settlement summary share options (text / PDF).
struct SettlementShareButton: View {
    let friend: User
    let balance: Double
    let sharedExpenses: [Expense]
    let settlements: [Settlement]
    let currentUserName: String

    @State private var previewFile: IdentifiableURL?
    @State private var textPayload: SharePayload?

    var body: some View {
        Menu {
            Button {
                let text = ExportService.settlementSummaryText(
                    friend: friend, balance: balance,
                    sharedExpenses: sharedExpenses, settlements: settlements,
                    currentUserName: currentUserName, currencySymbol: CurrencyHelper.symbol
                )
                textPayload = SharePayload(items: [text])
            } label: {
                Label("Share as Text", systemImage: "text.bubble")
            }

            Button {
                if let url = ExportService.settlementSummaryPDFFile(
                    friend: friend, balance: balance,
                    sharedExpenses: sharedExpenses, settlements: settlements,
                    currentUserName: currentUserName, currencySymbol: CurrencyHelper.symbol
                ) {
                    previewFile = IdentifiableURL(url: url)
                }
            } label: {
                Label("Share as PDF", systemImage: "doc.richtext")
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "square.and.arrow.up")
                Text("Share Summary")
            }
            .font(.subheadline).fontWeight(.semibold)
            .foregroundStyle(.white)
            .padding(.horizontal, 16).padding(.vertical, 8)
            .background(Capsule().fill(Color.cyan))
        }
        .sheet(item: $previewFile) { item in
            FilePreviewSheet(url: item.url)
        }
        .sheet(item: $textPayload) { payload in
            ShareSheet(items: payload.items)
        }
    }
}

// MARK: - File Preview (QLPreviewController with share built in)

/// Presents a file using the system QuickLook preview with a built-in share button.
struct FilePreviewSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UINavigationController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        let nav = UINavigationController(rootViewController: controller)
        return nav
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(url: url) }

    class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL
        init(url: URL) { self.url = url }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> any QLPreviewItem {
            url as NSURL
        }
    }
}

// MARK: - Identifiable wrappers for sheet(item:)

struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

struct SharePayload: Identifiable {
    let id = UUID()
    let items: [Any]
}

// MARK: - UIKit Share Sheet Wrapper

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
