//
//  ExpenseLog+Extension.swift
//  ExpenseTracker
//
//  Created by Alfian Losari on 19/04/20.
//  Copyright ©️ 2020 Alfian Losari. All rights reserved.
//

import Foundation
import CoreData

extension ExpenseLog {
    
    var categoryEnum: Category {
        Category(rawValue: category ?? "") ?? .other
    }
    
    var dateText: String {
        Utils.dateFormatter.localizedString(for: date ?? Date(), relativeTo: Date())
    }
    
    var nameText: String {
        name ?? ""
    }
    
    var amountText: String {
        Utils.numberFormatter.string(from: NSNumber(value: amount?.doubleValue ?? 0)) ?? ""
    }
    
    var isGroupExpenseValue: Bool {
        isGroupExpense
    }
    
    var groupExpense: Group? {
        group
    }
    
    var paidByUser: User? {
        paidBy
    }
    
    var participantsArray: [ExpenseParticipant] {
        guard let participantsSet = participants as? Set<ExpenseParticipant> else { return [] }
        return Array(participantsSet)
    }
    
    var participantsTotal: Double {
        participantsArray.reduce(0.0) { (total, participant) -> Double in
            let amountValue = participant.amount?.doubleValue ?? 0.0
            return total + amountValue
        }
    }
    
    static func fetchAllCategoriesTotalAmountSum(context: NSManagedObjectContext, completion: @escaping ([(sum: Double, category: Category)]) -> ()) {
        let keypathAmount = NSExpression(forKeyPath: \ExpenseLog.amount)
        let expression = NSExpression(forFunction: "sum:", arguments: [keypathAmount])
        
        let sumDesc = NSExpressionDescription()
        sumDesc.expression = expression
        sumDesc.name = "sum"
        sumDesc.expressionResultType = .decimalAttributeType
        
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: ExpenseLog.entity().name ?? "ExpenseLog")
        request.returnsObjectsAsFaults = false
        request.propertiesToGroupBy = ["category"]
        request.propertiesToFetch = [sumDesc, "category"]
        request.resultType = .dictionaryResultType
        
        context.perform {
            do {
                let results = try request.execute()
                let data = results.map { (result) -> (Double, Category)? in
                    guard
                        let resultDict = result as? [String: Any],
                        let amount = resultDict["sum"] as? Double,
                        let categoryKey = resultDict["category"] as? String,
                        let category = Category(rawValue: categoryKey) else {
                            return nil
                    }
                    return (amount, category)
                }.compactMap { $0 }
                completion(data)
            } catch let error as NSError {
                print((error.localizedDescription))
                completion([])
            }
        }
        
    }
    
    static func predicate(with categories: [Category], searchText: String, group: Group? = nil, isGroupExpense: Bool? = nil) -> NSPredicate? {
        var predicates = [NSPredicate]()
        
        if !categories.isEmpty {
            let categoriesString = categories.map { $0.rawValue }
            predicates.append(NSPredicate(format: "category IN %@", categoriesString))
        }
        
        if !searchText.isEmpty {
            predicates.append(NSPredicate(format: "name CONTAINS[cd] %@", searchText.lowercased()))
        }
        
        if let group = group {
            predicates.append(NSPredicate(format: "group == %@", group))
        }
        
        if let isGroupExpense = isGroupExpense {
            predicates.append(NSPredicate(format: "isGroupExpense == %@", NSNumber(value: isGroupExpense)))
        }
        
        if predicates.isEmpty {
            return nil
        } else {
            return NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }
    }
    
    func splitEqually(among users: [User], context: NSManagedObjectContext) {
        guard !users.isEmpty else { return }
        
        let totalAmount = amount?.doubleValue ?? 0
        let perPerson = totalAmount / Double(users.count)
        
        // Remove existing participants
        if let existingParticipants = participants as? Set<ExpenseParticipant> {
            for participant in existingParticipants {
                context.delete(participant)
            }
        }
        
        // Create new participants
        var newParticipants: [ExpenseParticipant] = []
        for user in users {
            let participant = ExpenseParticipant.create(context: context, user: user, amount: perPerson)
            participant.expense = self
            newParticipants.append(participant)
        }
        
        self.participants = NSSet(array: newParticipants)
    }
    
    func splitByAmounts(amounts: [User: Double], context: NSManagedObjectContext) {
        // Remove existing participants
        if let existingParticipants = participants as? Set<ExpenseParticipant> {
            for participant in existingParticipants {
                context.delete(participant)
            }
        }
        
        // Create new participants
        var newParticipants: [ExpenseParticipant] = []
        for (user, amount) in amounts {
            let participant = ExpenseParticipant.create(context: context, user: user, amount: amount)
            participant.expense = self
            newParticipants.append(participant)
        }
        
        self.participants = NSSet(array: newParticipants)
    }
    
}
