import Vapor
import FluentPostgreSQL

final class AccountController: RouteCollection {
    
    func boot(router: Router) throws {
        let accountsRoute = router.grouped("api", "accounts")
        let guardAuthMiddleware = User.guardAuthMiddleware()
        let tokenAuthMiddleware = User.tokenAuthMiddleware()
        let tokenProtected = accountsRoute.grouped(tokenAuthMiddleware, guardAuthMiddleware)

        tokenProtected.post(use: createHeandler)
        tokenProtected.delete(Account.parameter, use: deleteHandler)
        tokenProtected.put(Account.parameter, use: updateHandler)
        tokenProtected.get(Account.parameter, "transactions", use: getTransactionsByAccountId)
        tokenProtected.get(Account.parameter, use: getAccountById)
    }
    
    func createHeandler(_ req: Request) throws -> Future<Account> {
        return try req.content.decode(Account.self).flatMap {
            account in
            account.balance = 0.0
            var accNumber = ""
            for _ in 0...21 {
               accNumber += String(Int.random(in: 0...9))
            }
            account.accountNumber = accNumber
            return account.save(on: req)
        }
    }
    
    func getAllHandler(_ req: Request) throws -> Future<[Account]> {
        return Account.query(on: req).decode(Account.self).all()
    }
    
//    func getAccountById(_ req: Request) throws -> Future<AccountsWithNestedCreditCards> {
//        return try req.parameters.next(Account.self).flatMap(to: AccountsWithNestedCreditCards.self) { accs in
//            return try accs.creditCards.query(on: req).all().map(to: AccountsWithNestedCreditCards.self) { credits in
//                return AccountsWithNestedCreditCards(id: accs.id!, customName: accs.customName, creditCards: credits, balance: accs.balance!, accountNumber: accs.accountNumber!)
//            }
//        }
//    }
    
    func getAccountById(_ req: Request) throws -> Future<AccountWithNested> {
        return try req.parameters.next(Account.self).flatMap(to: AccountWithNested.self) { accs in
            return try accs.creditCards.query(on: req).all().flatMap(to: AccountWithNested.self) { credits in
                return try accs.currency.query(on: req).all().flatMap(to: AccountWithNested.self) { currency in
                    return try accs.transactions.query(on: req).all().flatMap(to: AccountWithNested.self) { transactions in
                        return try accs.recuuringPayment.query(on: req).all().map(to: AccountWithNested.self) { rec in
                            return AccountWithNested(id: accs.id!, customName: accs.customName, transactions: transactions, creditCards: credits, balance: accs.balance!, accountNumber: accs.accountNumber!, currency: currency, reccuring: rec)
                        }
                    }
                }
            }
        }
    }
    
    func getUserHandler(_ req: Request) throws -> Future<User.Public> {
        return try req.parameters.next(Account.self).flatMap(to: User.Public.self) { account in
            return account.user.get(on: req).toPublic()
        }
    }
    
    func getTransactionsByAccountId(_ req: Request) throws -> Future<[Transaction]> {
        return try req.parameters.next(Account.self).flatMap(to: [Transaction].self) { trans in
            return try trans.transactions.query(on: req).all()
        }
    }
    
    func updateHandler(_ req: Request) throws -> Future<Account> {
        return try flatMap(to: Account.self, req.parameters.next(Account.self), req.content.decode(Account.self)) { (account, updatedAccount) in
            account.customName = updatedAccount.customName
            return account.save(on: req)
        }
    }
    
    func deleteHandler(_ req: Request) throws -> Future<HTTPStatus> {
        return try req.parameters.next(Account.self).flatMap { (user) in
            return user.delete(on: req).transform(to: HTTPStatus.noContent)
        }
    }
}
