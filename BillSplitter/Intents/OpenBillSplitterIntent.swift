//
//  OpenBillSplitterIntent.swift
//  BillSplitter
//
//  Simple intent that opens the app. Available via Siri voice
//  ("Open BillSplitter") and in the Shortcuts app.
//

import AppIntents

struct OpenBillSplitterIntent: AppIntent {

    static var title: LocalizedStringResource = "Open BillSplitter"

    static var description: IntentDescription {
        "Opens the BillSplitter app."
    }

    /// Tells Siri to launch the app when this intent runs.
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        .result()
    }
}
