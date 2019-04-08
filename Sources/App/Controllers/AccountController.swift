import Vapor

final class AccountController: RouteCollection {
    
    func boot(router: Router) throws {
        let accountsRoute = router.grouped("api", "accounts")
        accountsRoute.get(use: getAllHandler)
        accountsRoute.get(Account.parameter, "user", use: getUserHandler)
        accountsRoute.post(use: createHeandler)
    }
    
    func createHeandler(_ req: Request) throws -> Future<Account> {
        return try req.content.decode(Account.self).flatMap {
            account in
            return account.save(on: req)
        }
    }
    
    func getAllHandler(_ req: Request) throws -> Future<[Account]> {
        return Account.query(on: req).decode(Account.self).all()
    }
    
    func getUserHandler(_ req: Request) throws -> Future<User.Public> {
        return try req.parameters.next(Account.self).flatMap(to: User.Public.self) { account in
            return account.user.get(on: req).toPublic()
        }
    }
}