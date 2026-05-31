//
//  ExportService.swift
//  BillSplitter
//
//  CSV and PDF export for expenses — supports all, per-group, and per-friend scopes.
//

import Foundation
import UIKit
import PDFKit

enum ExportScope {
    case all
    case group(Group)
    case friend(User)
}

enum ExportService {

    // ================================================================
    // MARK: - CSV
    // ================================================================

    static func csvString(from expenses: [Expense], scope: ExportScope) -> String {
        let df = DateFormatter()
        df.dateStyle = .medium

        var lines: [String] = []

        // Add friend share column for friend scope
        switch scope {
        case .friend(let friend):
            lines.append("Date,Description,Amount,\(friend.name)'s Share,Category,Paid By,Group,Notes")
            for e in expenses.sorted(by: { $0.date > $1.date }) {
                let share = friendShare(for: friend.id, in: e)
                lines.append("\(df.string(from: e.date)),\(csvEscape(e.expenseDescription)),\(f2(e.amount)),\(f2(share)),\(e.category.label),\(csvEscape(e.paidBy?.name ?? "Unknown")),\(csvEscape(e.group?.name ?? "")),\(csvEscape(e.notes ?? ""))")
            }
        default:
            lines.append("Date,Description,Amount,Category,Paid By,Split Type,Group,Notes")
            for e in expenses.sorted(by: { $0.date > $1.date }) {
                lines.append("\(df.string(from: e.date)),\(csvEscape(e.expenseDescription)),\(f2(e.amount)),\(e.category.label),\(csvEscape(e.paidBy?.name ?? "Unknown")),\(e.splitType.rawValue),\(csvEscape(e.group?.name ?? "")),\(csvEscape(e.notes ?? ""))")
            }
        }

        return lines.joined(separator: "\n")
    }

    static func csvFile(from expenses: [Expense], scope: ExportScope) -> URL? {
        let csv = csvString(from: expenses, scope: scope)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(csvFilename(for: scope))
        do { try csv.write(to: url, atomically: true, encoding: .utf8); return url }
        catch { return nil }
    }

    // ================================================================
    // MARK: - PDF — Expense List
    // ================================================================

    static func pdfData(from expenses: [Expense], scope: ExportScope, currencySymbol: String) -> Data? {
        let page = PDFPage()
        let sorted = expenses.sorted { $0.date > $1.date }
        let df = DateFormatter(); df.dateStyle = .medium
        let sym = currencySymbol

        // Determine if we show a "Share" column
        let friendForShare: User? = {
            if case .friend(let f) = scope { return f }
            return nil
        }()
        let showShare = friendForShare != nil

        return page.render { draw, newPage in

            // ── Header ──
            newPage(0)
            draw.title(pdfTitle(for: scope))
            draw.subtitle("Generated \(df.string(from: Date())) · \(sorted.count) expenses")
            draw.y += 6
            let total = sorted.reduce(0) { $0 + $1.amount }
            draw.bold("Total: \(sym)\(f2(total))", size: 14)
            draw.y += 8
            draw.line()

            // ── Table Header ──
            let dateX   = draw.margin
            let descX   = draw.margin + 80
            let catX    = draw.margin + 250
            let amtX    = draw.margin + 340
            let shareX  = draw.margin + 430

            draw.row(columns: showShare
                ? [(dateX, "Date"), (descX, "Description"), (catX, "Category"), (amtX, "Total"), (shareX, "\(friendForShare!.name)'s Share")]
                : [(dateX, "Date"), (descX, "Description"), (catX, "Category"), (amtX, "Amount")],
                font: .systemFont(ofSize: 10, weight: .bold), color: .darkGray)
            draw.line(color: .lightGray)

            // ── Rows ──
            for expense in sorted {
                newPage( 28)

                let date = df.string(from: expense.date)
                let desc = String(expense.expenseDescription.prefix(28))
                draw.text(date, at: dateX, size: 10)
                draw.text(desc, at: descX, size: 10)
                draw.text(expense.category.label, at: catX, size: 10)
                draw.text("\(sym)\(f2(expense.amount))", at: amtX, size: 10, weight: .semibold)

                if showShare, let friend = friendForShare {
                    let share = friendShare(for: friend.id, in: expense)
                    draw.text("\(sym)\(f2(share))", at: shareX, size: 10, weight: .semibold, color: .systemBlue)
                }

                draw.text("Paid by \(expense.paidBy?.name ?? "Unknown")", at: descX, size: 8, color: .darkGray, yOffset: 13)
                draw.y += 28
            }

            // ── Friend total share ──
            if showShare, let friend = friendForShare {
                draw.y += 4
                draw.line()
                draw.y += 6
                let totalShare = sorted.reduce(0.0) { $0 + friendShare(for: friend.id, in: $1) }
                draw.bold("\(friend.name)'s total share: \(sym)\(f2(totalShare))", size: 12)
            }

            // ── Group member balances table ──
            if case .group(let group) = scope {
                drawGroupBalancesTable(draw: draw, newPage: newPage, group: group, expenses: sorted, currencySymbol: sym)
            }

            // ── Footer ──
            draw.y += 12
            newPage( 20)
            draw.line()
            draw.text("BillSplitter", at: draw.margin, size: 9, color: .gray)
        }
    }

    static func pdfFile(from expenses: [Expense], scope: ExportScope, currencySymbol: String) -> URL? {
        guard let data = pdfData(from: expenses, scope: scope, currencySymbol: currencySymbol) else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(pdfFilename(for: scope))
        do { try data.write(to: url); return url }
        catch { return nil }
    }

    // ================================================================
    // MARK: - Group Balances Table
    // ================================================================

    private static func drawGroupBalancesTable(
        draw: PDFDrawContext,
        newPage: (_ requiredHeight: CGFloat) -> Void,
        group: Group,
        expenses: [Expense],
        currencySymbol: String
    ) {
        let members = group.members ?? []
        guard !members.isEmpty else { return }

        draw.y += 16
        newPage( 80)
        draw.line()
        draw.y += 10
        draw.bold("Member Summary", size: 14)
        draw.y += 4

        let nameX   = draw.margin
        let paidX   = draw.margin + 160
        let shareX  = draw.margin + 280
        let netX    = draw.margin + 400

        draw.row(columns: [(nameX, "Member"), (paidX, "Total Paid"), (shareX, "Total Share"), (netX, "Net")],
            font: .systemFont(ofSize: 10, weight: .bold), color: .darkGray)
        draw.line(color: .lightGray)

        for member in members.sorted(by: { $0.name < $1.name }) {
            newPage( 22)

            let totalPaid = expenses.filter { $0.paidBy?.id == member.id }.reduce(0) { $0 + $1.amount }
            let totalShare = expenses.reduce(0.0) { $0 + friendShare(for: member.id, in: $1) }
            let net = totalPaid - totalShare // positive = others owe them

            draw.text(member.name, at: nameX, size: 10)
            draw.text("\(currencySymbol)\(f2(totalPaid))", at: paidX, size: 10)
            draw.text("\(currencySymbol)\(f2(totalShare))", at: shareX, size: 10)

            let netColor: UIColor = net > 0.005 ? UIColor(red: 0, green: 0.6, blue: 0, alpha: 1) :
                                    net < -0.005 ? .systemRed : .black
            let netPrefix = net > 0.005 ? "+" : ""
            draw.text("\(netPrefix)\(currencySymbol)\(f2(abs(net)))", at: netX, size: 10, weight: .semibold, color: netColor)

            draw.y += 20
        }
    }

    // ================================================================
    // MARK: - Settlement Summary — Text
    // ================================================================

    static func settlementSummaryText(
        friend: User,
        balance: Double,
        sharedExpenses: [Expense],
        settlements: [Settlement],
        currentUserName: String,
        currencySymbol: String
    ) -> String {
        let df = DateFormatter(); df.dateStyle = .medium
        let sym = currencySymbol
        var lines: [String] = []

        lines.append("Settlement Summary")
        lines.append("Between \(currentUserName) and \(friend.name)")
        lines.append("Date: \(df.string(from: Date()))")
        lines.append("")

        if abs(balance) < BalanceCalculator.epsilon {
            lines.append("Status: All settled up!")
        } else if balance > 0 {
            lines.append("Status: \(friend.name) owes \(currentUserName) \(sym)\(f2(balance))")
        } else {
            lines.append("Status: \(currentUserName) owes \(friend.name) \(sym)\(f2(abs(balance)))")
        }
        lines.append("")

        if !sharedExpenses.isEmpty {
            lines.append("── Shared Expenses (\(sharedExpenses.count)) ──")
            for e in sharedExpenses.sorted(by: { $0.date > $1.date }) {
                let share = friendShare(for: friend.id, in: e)
                let group = e.group.map { " [\($0.name)]" } ?? ""
                lines.append("• \(df.string(from: e.date)) — \(e.expenseDescription): \(sym)\(f2(e.amount)) | \(friend.name)'s share: \(sym)\(f2(share)) (paid by \(e.paidBy?.name ?? "Unknown"))\(group)")
            }

            let totalShare = sharedExpenses.reduce(0.0) { $0 + friendShare(for: friend.id, in: $1) }
            lines.append("\(friend.name)'s total share: \(sym)\(f2(totalShare))")
            lines.append("")
        }

        let friendSettlements = settlements
            .filter { $0.isConfirmed && ($0.fromFriend?.id == friend.id || $0.toFriend?.id == friend.id) }
            .sorted { $0.date > $1.date }

        if !friendSettlements.isEmpty {
            lines.append("── Settlements (\(friendSettlements.count)) ──")
            for s in friendSettlements {
                lines.append("• \(df.string(from: s.date)) — \(s.fromFriend?.name ?? "?") → \(s.toFriend?.name ?? "?"): \(sym)\(f2(s.amount)) via \(s.paymentMethod.label)")
            }
        }

        lines.append("")
        lines.append("— BillSplitter")
        return lines.joined(separator: "\n")
    }

    // ================================================================
    // MARK: - Settlement Summary — PDF
    // ================================================================

    static func settlementSummaryPDF(
        friend: User,
        balance: Double,
        sharedExpenses: [Expense],
        settlements: [Settlement],
        currentUserName: String,
        currencySymbol: String
    ) -> Data? {
        let page = PDFPage()
        let df = DateFormatter(); df.dateStyle = .medium
        let sym = currencySymbol

        return page.render { draw, newPage in
            newPage(0)

            // ── Header ──
            draw.title("Settlement Summary")
            draw.text("Between \(currentUserName) and \(friend.name)", at: draw.margin, size: 12)
            draw.y += 16
            draw.text(df.string(from: Date()), at: draw.margin, size: 10, color: .darkGray)
            draw.y += 20

            // ── Balance ──
            let balanceText: String
            let balanceColor: UIColor
            if abs(balance) < BalanceCalculator.epsilon {
                balanceText = "All settled up!"
                balanceColor = UIColor(red: 0, green: 0.6, blue: 0, alpha: 1)
            } else if balance > 0 {
                balanceText = "\(friend.name) owes \(currentUserName): \(sym)\(f2(balance))"
                balanceColor = UIColor(red: 0, green: 0.6, blue: 0, alpha: 1)
            } else {
                balanceText = "\(currentUserName) owes \(friend.name): \(sym)\(f2(abs(balance)))"
                balanceColor = .systemRed
            }
            draw.text(balanceText, at: draw.margin, size: 14, weight: .bold, color: balanceColor)
            draw.y += 24
            draw.line()

            // ── Shared Expenses with share column ──
            let sortedExpenses = sharedExpenses.sorted { $0.date > $1.date }
            if !sortedExpenses.isEmpty {
                draw.bold("Shared Expenses (\(sortedExpenses.count))", size: 12)
                draw.y += 4

                let dateX  = draw.margin
                let descX  = draw.margin + 80
                let amtX   = draw.margin + 290
                let shareX = draw.margin + 390

                draw.row(columns: [(dateX, "Date"), (descX, "Description"), (amtX, "Total"), (shareX, "\(friend.name)'s Share")],
                    font: .systemFont(ofSize: 9, weight: .bold), color: .darkGray)
                draw.line(color: .lightGray)

                for e in sortedExpenses {
                    newPage( 28)
                    let share = friendShare(for: friend.id, in: e)
                    let group = e.group.map { " [\($0.name)]" } ?? ""

                    draw.text(df.string(from: e.date), at: dateX, size: 9)
                    draw.text(String(e.expenseDescription.prefix(28)) + group, at: descX, size: 9)
                    draw.text("\(sym)\(f2(e.amount))", at: amtX, size: 9)
                    draw.text("\(sym)\(f2(share))", at: shareX, size: 9, weight: .semibold, color: .systemBlue)
                    draw.text("Paid by \(e.paidBy?.name ?? "Unknown")", at: descX, size: 7, color: .darkGray, yOffset: 12)
                    draw.y += 26
                }

                // Total share row
                draw.line(color: .lightGray)
                draw.y += 4
                let totalShare = sortedExpenses.reduce(0.0) { $0 + friendShare(for: friend.id, in: $1) }
                draw.text("Total", at: descX, size: 10, weight: .bold)
                draw.text("\(sym)\(f2(sortedExpenses.reduce(0) { $0 + $1.amount }))", at: amtX, size: 10, weight: .bold)
                draw.text("\(sym)\(f2(totalShare))", at: shareX, size: 10, weight: .bold, color: .systemBlue)
                draw.y += 20

                draw.line()
            }

            // ── Settlements ──
            let friendSettlements = settlements
                .filter { $0.isConfirmed && ($0.fromFriend?.id == friend.id || $0.toFriend?.id == friend.id) }
                .sorted { $0.date > $1.date }

            if !friendSettlements.isEmpty {
                draw.bold("Settlements (\(friendSettlements.count))", size: 12)

                for s in friendSettlements {
                    newPage( 20)
                    let line = "\(df.string(from: s.date)) — \(s.fromFriend?.name ?? "?") → \(s.toFriend?.name ?? "?"): \(sym)\(f2(s.amount)) via \(s.paymentMethod.label)"
                    draw.text(line, at: draw.margin + 10, size: 10)
                    draw.y += 18
                }
                draw.y += 8
            }

            // ── Footer ──
            draw.y += 10
            newPage( 20)
            draw.line()
            draw.text("BillSplitter", at: draw.margin, size: 9, color: .gray)
        }
    }

    static func settlementSummaryPDFFile(
        friend: User, balance: Double, sharedExpenses: [Expense],
        settlements: [Settlement], currentUserName: String, currencySymbol: String
    ) -> URL? {
        guard let data = settlementSummaryPDF(
            friend: friend, balance: balance, sharedExpenses: sharedExpenses,
            settlements: settlements, currentUserName: currentUserName, currencySymbol: currencySymbol
        ) else { return nil }

        let filename = "Settlement_\(friend.name.replacingOccurrences(of: " ", with: "_"))_\(dateStamp()).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do { try data.write(to: url); return url }
        catch { return nil }
    }

    // ================================================================
    // MARK: - Helpers
    // ================================================================

    /// Returns the amount a specific friend owes from an expense's participant list.
    private static func friendShare(for friendID: UUID, in expense: Expense) -> Double {
        expense.participants?.first(where: { $0.friend?.id == friendID })?.amountOwed ?? 0
    }

    private static func f2(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    private static func csvEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }

    private static func dateStamp() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    private static func csvFilename(for scope: ExportScope) -> String {
        let stamp = dateStamp()
        switch scope {
        case .all:            return "BillSplitter_All_\(stamp).csv"
        case .group(let g):   return "BillSplitter_\(g.name.replacingOccurrences(of: " ", with: "_"))_\(stamp).csv"
        case .friend(let f):  return "BillSplitter_\(f.name.replacingOccurrences(of: " ", with: "_"))_\(stamp).csv"
        }
    }

    private static func pdfFilename(for scope: ExportScope) -> String {
        let stamp = dateStamp()
        switch scope {
        case .all:            return "BillSplitter_All_\(stamp).pdf"
        case .group(let g):   return "BillSplitter_\(g.name.replacingOccurrences(of: " ", with: "_"))_\(stamp).pdf"
        case .friend(let f):  return "BillSplitter_\(f.name.replacingOccurrences(of: " ", with: "_"))_\(stamp).pdf"
        }
    }

    private static func pdfTitle(for scope: ExportScope) -> String {
        switch scope {
        case .all:            return "All Expenses"
        case .group(let g):   return "Expenses — \(g.name)"
        case .friend(let f):  return "Expenses — \(f.name)"
        }
    }
}

// ================================================================
// MARK: - PDF Drawing Helpers
// ================================================================

/// Lightweight drawing context that tracks the current Y position.
class PDFDrawContext {
    let margin: CGFloat
    var y: CGFloat

    private let cgContext: CGContext
    private let pageWidth: CGFloat

    init(cgContext: CGContext, pageWidth: CGFloat, margin: CGFloat) {
        self.cgContext = cgContext
        self.pageWidth = pageWidth
        self.margin = margin
        self.y = margin
    }

    func title(_ text: String) {
        let attr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 22, weight: .bold),
            .foregroundColor: UIColor.black
        ]
        NSAttributedString(string: text, attributes: attr).draw(at: CGPoint(x: margin, y: y))
        y += 32
    }

    func subtitle(_ text: String) {
        let attr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: .regular),
            .foregroundColor: UIColor.darkGray
        ]
        NSAttributedString(string: text, attributes: attr).draw(at: CGPoint(x: margin, y: y))
        y += 18
    }

    func bold(_ text: String, size: CGFloat) {
        let attr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: size, weight: .semibold),
            .foregroundColor: UIColor.black
        ]
        NSAttributedString(string: text, attributes: attr).draw(at: CGPoint(x: margin, y: y))
        y += size + 6
    }

    func text(_ text: String, at x: CGFloat, size: CGFloat,
              weight: UIFont.Weight = .regular, color: UIColor = .black, yOffset: CGFloat = 0) {
        let attr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: color
        ]
        NSAttributedString(string: text, attributes: attr).draw(at: CGPoint(x: x, y: y + yOffset))
    }

    func row(columns: [(CGFloat, String)], font: UIFont, color: UIColor) {
        let attr: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        for (x, text) in columns {
            NSAttributedString(string: text, attributes: attr).draw(at: CGPoint(x: x, y: y))
        }
        y += font.pointSize + 8
    }

    func line(color: UIColor = .lightGray) {
        cgContext.setStrokeColor(color.cgColor)
        cgContext.setLineWidth(0.5)
        cgContext.move(to: CGPoint(x: margin, y: y))
        cgContext.addLine(to: CGPoint(x: pageWidth - margin, y: y))
        cgContext.strokePath()
        y += 8
    }
}

/// Helper to manage PDF page lifecycle.
struct PDFPage {
    let pageWidth: CGFloat  = 612
    let pageHeight: CGFloat = 792
    let margin: CGFloat     = 40

    func render(_ block: (_ draw: PDFDrawContext, _ newPage: (_ requiredHeight: CGFloat) -> Void) -> Void) -> Data {
        let bounds = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: bounds)

        return renderer.pdfData { ctx in
            var started = false
            let draw = PDFDrawContext(cgContext: ctx.cgContext, pageWidth: pageWidth, margin: margin)

            let newPage: (CGFloat) -> Void = { requiredHeight in
                if !started || draw.y + requiredHeight > self.pageHeight - self.margin {
                    ctx.beginPage()
                    draw.y = self.margin
                    started = true
                }
            }

            block(draw, newPage)
        }
    }
}
