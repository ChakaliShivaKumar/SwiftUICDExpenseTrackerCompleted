//
//  GroupDetailView.swift
//  ExpenseTracker
//
//  Created by ExpenseTracker on 2024.
//

import SwiftUI
import CoreData

struct GroupDetailView: View {
    
    @ObservedObject var group: Group
    @Environment(\.managedObjectContext) var context
    
    @State private var isEditFormPresented: Bool = false
    @State private var isAddExpensePresented: Bool = false
    @State private var showDebts: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Summary Section
            VStack(spacing: 16) {
                Text("Total Expenses")
                    .font(.headline)
                Text(group.totalExpenses.formattedCurrencyText)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Button(action: { showDebts.toggle() }) {
                    HStack {
                        Text(showDebts ? "Show Expenses" : "Show Balances")
                        Image(systemName: showDebts ? "list.bullet" : "dollarsign.circle")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding(.horizontal)
            }
            .padding()
            .background(Color(.systemGroupedBackground))
            
            Divider()
            
            if showDebts {
                DebtsListView(group: group)
            } else {
                GroupExpensesListView(group: group)
            }
        }
        .navigationBarTitle(group.nameText, displayMode: .inline)
        .navigationBarItems(trailing: HStack {
            Button(action: { isAddExpensePresented = true }) {
                Image(systemName: "plus")
            }
            Button(action: { isEditFormPresented = true }) {
                Image(systemName: "pencil")
            }
        })
        .sheet(isPresented: $isEditFormPresented) {
            GroupFormView(groupToEdit: group, context: context)
        }
        .sheet(isPresented: $isAddExpensePresented) {
            LogFormView(context: context, group: group)
        }
    }
}

struct GroupExpensesListView: View {
    @ObservedObject var group: Group
    @Environment(\.managedObjectContext) var context
    
    @FetchRequest var expenses: FetchedResults<ExpenseLog>
    
    init(group: Group) {
        self.group = group
        let request: NSFetchRequest<ExpenseLog> = ExpenseLog.fetchRequest()
        request.predicate = NSPredicate(format: "group == %@", group)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ExpenseLog.date, ascending: false)]
        _expenses = FetchRequest(fetchRequest: request)
    }
    
    var body: some View {
        List {
            ForEach(expenses) { expense in
                NavigationLink(destination: ExpenseDetailView(expense: expense)) {
                    GroupExpenseRowView(expense: expense)
                }
            }
            .onDelete(perform: deleteExpenses)
        }
    }
    
    func deleteExpenses(at offsets: IndexSet) {
        offsets.forEach { index in
            let expense = expenses[index]
            context.delete(expense)
        }
        try? context.saveContext()
        Debt.simplifyDebts(in: group, context: context)
        try? context.saveContext()
    }
}

struct GroupExpenseRowView: View {
    let expense: ExpenseLog
    
    var body: some View {
        HStack(spacing: 16) {
            CategoryImageView(category: expense.categoryEnum)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(expense.nameText)
                    .font(.headline)
                HStack {
                    if let paidBy = expense.paidByUser {
                        Text("Paid by \(paidBy.nameText)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text(expense.dateText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text(expense.amountText)
                    .font(.headline)
                if expense.participantsArray.count > 0 {
                    Text("\(expense.participantsArray.count) people")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct ExpenseDetailView: View {
    let expense: ExpenseLog
    @Environment(\.managedObjectContext) var context
    @State private var isEditPresented: Bool = false
    
    var body: some View {
        List {
            Section(header: Text("Details")) {
                HStack {
                    Text("Amount")
                    Spacer()
                    Text(expense.amountText)
                        .fontWeight(.semibold)
                }
                
                HStack {
                    Text("Category")
                    Spacer()
                    Text(expense.categoryEnum.rawValue.capitalized)
                }
                
                HStack {
                    Text("Date")
                    Spacer()
                    Text(expense.dateText)
                }
                
                if let paidBy = expense.paidByUser {
                    HStack {
                        Text("Paid By")
                        Spacer()
                        Text(paidBy.nameText)
                    }
                }
            }
            
            if !expense.participantsArray.isEmpty {
                Section(header: Text("Split Among")) {
                    ForEach(expense.participantsArray) { participant in
                        HStack {
                            Text(participant.user?.nameText ?? "Unknown")
                            Spacer()
                            Text(participant.amountValue.formattedCurrencyText)
                        }
                    }
                }
            }
        }
        .navigationBarTitle(expense.nameText, displayMode: .inline)
        .navigationBarItems(trailing: Button("Edit") {
            isEditPresented = true
        })
        .sheet(isPresented: $isEditPresented) {
            LogFormView(
                logToEdit: expense,
                context: context,
                group: expense.groupExpense
            )
        }
    }
}

struct DebtsListView: View {
    @ObservedObject var group: Group
    @Environment(\.managedObjectContext) var context
    
    @State private var debts: [Debt] = []
    
    var body: some View {
        List {
            if debts.isEmpty {
                Text("All settled up! 🎉")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(debts) { debt in
                    DebtRowView(debt: debt, onSettled: {
                        loadDebts()
                    })
                }
            }
        }
        .onAppear(perform: loadDebts)
    }
    
    func loadDebts() {
        debts = Debt.fetchAll(context: context, group: group, includeSettled: false)
    }
}

struct DebtRowView: View {
    let debt: Debt
    var onSettled: (() -> Void)? = nil
    @Environment(\.managedObjectContext) var context
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("\(debt.owedBy?.nameText ?? "Unknown") owes")
                    .font(.headline)
                Text(debt.owedTo?.nameText ?? "Unknown")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text(debt.amountValue.formattedCurrencyText)
                    .font(.headline)
                    .foregroundColor(.red)
                
                Button("Settle Up") {
                    settleDebt()
                }
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
        }
        .padding(.vertical, 4)
    }
    
    func settleDebt() {
        debt.settle()
        do {
            try context.saveContext()
            onSettled?()
        } catch {
            print("Error settling debt: \(error.localizedDescription)")
        }
    }
}

struct GroupDetailView_Previews: PreviewProvider {
    static var previews: some View {
        GroupDetailView(group: Group())
    }
}

