//
//  BalanceCalculator.swift
//  BillSplitter
//

import Foundation

/// All balance amounts are from "my" perspective:
///   positive → that friend owes ME
///   negative → I owe that friend
struct BalanceCalculator {

    static func netBalances(
        expenses: [Expense],
        settlements: [Settlement],
        currentUserID: UUID
    ) -> [UUID: Double] {
        var balances: [UUID: Double] = [:]

        for expense in expenses {
            guard let participants = expense.participants,
                  !participants.isEmpty else { continue }

            // Who paid?
            let payerID: UUID = expense.paidBy?.id ?? currentUserID

            // Build a map: participantID → amountOwed
            var owedMap: [UUID: Double] = [:]
            for p in participants {
                guard let uid = p.friend?.id else { continue }
                owedMap[uid] = p.amountOwed
            }

            if payerID == currentUserID {
                // I paid — every OTHER participant owes me their share
                for (uid, owed) in owedMap where uid != currentUserID {
                    balances[uid, default: 0] += owed
                }
            } else {
                // A friend paid — I owe them my share (if I'm a participant)
                if let myShare = owedMap[currentUserID] {
                    balances[payerID, default: 0] -= myShare
                }
                // Other participants owe the payer — but we only track MY perspective,
                // so we don't touch other friend↔friend debts here.
            }
        }

        // Apply settlements — only those involving current user
        for s in settlements where s.isConfirmed {
            let fromID = s.fromFriend?.id
            let toID   = s.toFriend?.id

            if fromID == currentUserID, let toID {
                // I paid someone → I owe them less (reduce my negative)
                balances[toID, default: 0] += s.amount
            } else if toID == currentUserID, let fromID {
                // Someone paid me → they owe me less (reduce their positive)
                balances[fromID, default: 0] -= s.amount
            }
            // Settlements between two non-current-user people don't affect MY balances
        }

        return balances
    }

    static func totalOwedToYou(_ balances: [UUID: Double]) -> Double {
        balances.values.filter { $0 > 0.005 }.reduce(0, +)
    }

    static func totalYouOwe(_ balances: [UUID: Double]) -> Double {
        abs(balances.values.filter { $0 < -0.005 }.reduce(0, +))
    }
}
