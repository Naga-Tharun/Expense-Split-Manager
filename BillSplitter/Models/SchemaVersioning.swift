//
//  SchemaVersioning.swift
//  BillSplitter
//
//  VersionedSchema setup for safe schema migrations.
//
//  Each @Model type is nested inside SchemaV1 (via extensions in
//  each model's own file). Top-level typealiases let the rest of
//  the app keep using `User`, `Group`, etc. without changes.
//
//  When you need to migrate:
//  1. Freeze SchemaV1 by moving its nested types inline here
//  2. Create SchemaV2 with updated model definitions
//  3. Add a MigrationStage to BillSplitterMigrationPlan.stages
//

import SwiftData
import Foundation

// MARK: - Schema V1

enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            User.self,
            Group.self,
            Expense.self,
            ExpenseParticipant.self,
            Settlement.self,
        ]
    }
}

// MARK: - Migration Plan

enum BillSplitterMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self]
    }

    static var stages: [MigrationStage] {
        // No migrations yet — V1 is the only version.
        // Future example:
        //   .lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self)
        []
    }
}
