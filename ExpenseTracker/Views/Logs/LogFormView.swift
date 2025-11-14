//
//  LogFormView.swift
//  ExpenseTracker
//
//  Created by Alfian Losari on 19/04/20.
//  Copyright © 2020 Alfian Losari. All rights reserved.
//

import SwiftUI
import CoreData

enum SplitMethod: String, CaseIterable {
    case equal = "Equal"
    case amount = "By Amount"
    case percentage = "By Percentage"
}

struct LogFormView: View {
    
    var logToEdit: ExpenseLog?
    var context: NSManagedObjectContext
    var group: Group? = nil
    
    @State var name: String = ""
    @State var amount: Double = 0
    @State var category: Category = .utilities
    @State var date: Date = Date()
    @State var isGroupExpense: Bool = false
    @State var paidBy: User?
    @State var selectedParticipants: Set<User> = Set()
    @State var splitMethod: SplitMethod = .equal
    @State var customAmounts: [User: Double] = [:]
    @State var customPercentages: [User: Double] = [:]
    @State var availableUsers: [User] = []
    @State var showSplitOptions: Bool = false
    
    @Environment(\.presentationMode)
    var presentationMode
    
    var title: String {
        logToEdit == nil ? "Create Expense Log" : "Edit Expense Log"
    }
    
    var isGroupMode: Bool {
        group != nil || isGroupExpense
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Basic Information")) {
                    TextField("Name", text: $name)
                        .disableAutocorrection(true)
                    TextField("Amount", value: $amount, formatter: Utils.numberFormatter)
                        .keyboardType(.numbersAndPunctuation)
                    
                    Picker(selection: $category, label: Text("Category")) {
                        ForEach(Category.allCases) { category in
                            Text(category.rawValue.capitalized).tag(category)
                        }
                    }
                    DatePicker(selection: $date, displayedComponents: .date) {
                        Text("Date")
                    }
                }
                
                if group == nil {
                    Section(header: Text("Group Expense")) {
                        Toggle("Split with others", isOn: $isGroupExpense)
                    }
                }
                
                if isGroupMode {
                    Section(header: Text("Paid By")) {
                        Picker("Paid By", selection: $paidBy) {
                            Text("Select person").tag(nil as User?)
                            ForEach(availableUsers) { user in
                                Text(user.nameText).tag(user as User?)
                            }
                        }
                    }
                    
                    Section(header: Text("Split Among")) {
                        ForEach(availableUsers) { user in
                            HStack {
                                Text(user.nameText)
                                Spacer()
                                if selectedParticipants.contains(user) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if selectedParticipants.contains(user) {
                                    selectedParticipants.remove(user)
                                    customAmounts.removeValue(forKey: user)
                                    customPercentages.removeValue(forKey: user)
                                } else {
                                    selectedParticipants.insert(user)
                                    if splitMethod == .equal {
                                        updateEqualSplit()
                                    }
                                }
                            }
                        }
                    }
                    
                    if !selectedParticipants.isEmpty {
                        Section(header: Text("Split Method")) {
                            Picker("Method", selection: $splitMethod) {
                                ForEach(SplitMethod.allCases, id: \.self) { method in
                                    Text(method.rawValue).tag(method)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            
                            if splitMethod == .amount {
                                ForEach(Array(selectedParticipants), id: \.id) { user in
                                    HStack {
                                        Text(user.nameText)
                                        Spacer()
                                        TextField("Amount", value: Binding(
                                            get: { customAmounts[user] ?? 0 },
                                            set: { customAmounts[user] = $0 }
                                        ), formatter: Utils.numberFormatter)
                                        .keyboardType(.decimalPad)
                                        .frame(width: 100)
                                    }
                                }
                            } else if splitMethod == .percentage {
                                ForEach(Array(selectedParticipants), id: \.id) { user in
                                    HStack {
                                        Text(user.nameText)
                                        Spacer()
                                        TextField("%", value: Binding(
                                            get: { customPercentages[user] ?? 0 },
                                            set: { customPercentages[user] = $0 }
                                        ), formatter: NumberFormatter())
                                        .keyboardType(.decimalPad)
                                        .frame(width: 80)
                                        Text("%")
                                    }
                                }
                            }
                            
                            if splitMethod == .equal {
                                Text("Each person: \(equalSplitAmount.formattedCurrencyText)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            let total = splitTotal
                            if total != amount && amount > 0 {
                                HStack {
                                    Text("Total split:")
                                    Spacer()
                                    Text(total.formattedCurrencyText)
                                        .foregroundColor(total == amount ? .green : .red)
                                }
                                if total != amount {
                                    Text("Amounts don't match total expense")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                }
            }
            .navigationBarTitle(title)
            .navigationBarItems(
                leading: Button("Cancel") { onCancelTapped() },
                trailing: Button("Save") { onSaveTapped() }
                    .disabled(name.isEmpty || amount <= 0 || (isGroupMode && (paidBy == nil || selectedParticipants.isEmpty)))
            )
            .onAppear(perform: loadData)
        }
    }
    
    var equalSplitAmount: Double {
        guard !selectedParticipants.isEmpty, amount > 0 else { return 0 }
        return amount / Double(selectedParticipants.count)
    }
    
    var splitTotal: Double {
        switch splitMethod {
        case .equal:
            return equalSplitAmount * Double(selectedParticipants.count)
        case .amount:
            return customAmounts.values.reduce(0, +)
        case .percentage:
            let percentageTotal = customPercentages.values.reduce(0, +)
            return amount * (percentageTotal / 100.0)
        }
    }
    
    func loadData() {
        availableUsers = User.fetchAll(context: context)
        
        if let logToEdit = self.logToEdit {
            name = logToEdit.nameText
            amount = logToEdit.amount?.doubleValue ?? 0
            category = logToEdit.categoryEnum
            date = logToEdit.date ?? Date()
            isGroupExpense = logToEdit.isGroupExpenseValue
            paidBy = logToEdit.paidByUser
            group = logToEdit.groupExpense
            
            // Load participants
            selectedParticipants = Set(logToEdit.participantsArray.compactMap { $0.user })
            
            // Load custom amounts if any
            for participant in logToEdit.participantsArray {
                if let user = participant.user {
                    customAmounts[user] = participant.amountValue
                }
            }
        } else if let group = group {
            isGroupExpense = true
            availableUsers = group.membersArray
            if let firstUser = availableUsers.first {
                paidBy = firstUser
            }
        }
        
        if availableUsers.isEmpty {
            let defaultUser = User.createDefaultUser(context: context)
            try? context.saveContext()
            availableUsers = User.fetchAll(context: context)
        }
        
        if paidBy == nil && !availableUsers.isEmpty {
            paidBy = availableUsers.first
        }
    }
    
    func updateEqualSplit() {
        // Equal split is calculated on the fly
    }
    
    func onCancelTapped() {
        presentationMode.wrappedValue.dismiss()
    }
    
    func onSaveTapped() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        
        let log: ExpenseLog
        if let logToEdit = self.logToEdit {
            log = logToEdit
        } else {
            log = ExpenseLog(context: self.context)
            log.id = UUID()
        }
        
        log.name = self.name
        log.category = self.category.rawValue
        log.amount = NSDecimalNumber(value: self.amount)
        log.date = self.date
        log.isGroupExpense = isGroupMode
        log.group = group
        log.paidBy = paidBy
        
        // Handle splitting
        if isGroupMode && !selectedParticipants.isEmpty {
            switch splitMethod {
            case .equal:
                log.splitEqually(among: Array(selectedParticipants), context: context)
            case .amount:
                log.splitByAmounts(amounts: customAmounts, context: context)
            case .percentage:
                var amounts: [User: Double] = [:]
                for (user, percentage) in customPercentages {
                    amounts[user] = amount * (percentage / 100.0)
                }
                log.splitByAmounts(amounts: amounts, context: context)
            }
        }
        
        do {
            try context.saveContext()
            
            // Calculate debts if it's a group expense
            if isGroupMode && log.group != nil {
                Debt.calculateAndCreateDebts(from: log, context: context)
                try context.saveContext()
            }
            
            presentationMode.wrappedValue.dismiss()
        } catch let error as NSError {
            print("Error saving: \(error.localizedDescription)")
        }
    }
}

struct LogFormView_Previews: PreviewProvider {
    static var previews: some View {
        let stack = CoreDataStack(containerName: "ExpenseTracker")
        return LogFormView(context: stack.viewContext)
    }
}
