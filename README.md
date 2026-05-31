# BillSplitter

A native iOS app for splitting expenses with friends, tracking balances, and settling debts — built with SwiftUI and SwiftData.

## Features

- **Expense tracking** — Add expenses with descriptions, amounts, categories, and flexible split options (equal, exact, percentage)
- **Groups** — Organize expenses by trip, household, or any shared context. Edit details, manage members, and view group-level stats
- **Balance calculator** — Real-time balance tracking across all friends with settlement history
- **Settle up** — Record payments with multiple payment methods and confirmation flow
- **Search & filter** — Find expenses by keyword, category, or sort by date/amount
- **Spotlight search** — Expenses and friends are indexed for system-wide search
- **Siri Shortcuts** — Add expenses, check balances, and settle up with voice commands
- **Dark mode** — Full dark mode support throughout the app

## Tech Stack

- **UI**: SwiftUI (iOS 26.1+)
- **Data**: SwiftData with versioned schema and migration plan
- **Platform**: Spotlight (CoreSpotlight), Siri (AppIntents), App Groups (shared container)
- **Architecture**: MVVM with `@Query` and `@Environment(\.modelContext)`
- **Language**: Swift 6.2

## Project Structure

```
BillSplitter/
├── Models/          — SwiftData @Model types (User, Group, Expense, Settlement, ExpenseParticipant)
├── Views/
│   ├── NavBar/      — Tab bar and navigation
│   ├── Splits/      — Add/edit/view expenses
│   ├── Friends/     — Friend list and detail views
│   ├── Groups/      — Group management (create, edit, members)
│   ├── Balances/    — Balance overview and settlement suggestions
│   ├── Profile/     — User profile and settings
│   └── Shared/      — Reusable components (filters, avatars, onboarding)
├── Services/        — Business logic (BalanceCalculator, DataService, SpotlightIndexer, CurrencyHelper)
├── Intents/         — Siri AppIntents (AddExpense, CheckBalance, SettleUp, OpenApp)
├── Extensions/      — Swift extensions (Color, SharedContainer, Haptics)
BillSplitterTests/   — Unit tests
BillSplitterWidget/  — WidgetKit extension (WIP)
```

## Requirements

- Xcode 26+
- iOS 26.1+
- Swift 6.2

## Getting Started

1. Clone the repository
2. Open `BillSplitter.xcodeproj` in Xcode
3. Select your development team under Signing & Capabilities
4. Build and run on a simulator or device (Cmd+R)
