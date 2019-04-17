import Vapor
import Crypto
import Validation
import Authentication
import FluentPostgreSQL

final class UsersController: RouteCollection {
  
    func boot(router: Router) throws {

        let usersRoute = router.grouped("api", "users")
        usersRoute.post("register", use: register)
        usersRoute.post("login", use: login)
        
        let guardAuthMiddleware = User.guardAuthMiddleware() //
        let tokenAuthMiddleware = User.tokenAuthMiddleware()
        let tokenProtected = usersRoute.grouped(tokenAuthMiddleware, guardAuthMiddleware)
        tokenProtected.get(use: getAllHandler)
        tokenProtected.get(User.parameter, use: getOneHandler)
        tokenProtected.put(User.parameter, use: updateHandler)
        tokenProtected.delete(User.parameter, use: deleteHandler)
        tokenProtected.get(User.parameter, "transactions", use: getTransactionsHandler)
        tokenProtected.get(User.parameter, "creditcards", use: getCreditCardsHandler)
        tokenProtected.get(User.parameter, "reccuring", use: getCreditReccuringPaymentsHandler)
        tokenProtected.get(User.parameter, "accounts", use: getAccountsHeandler)
        tokenProtected.get("logout", use: logout)
    }
    
    func register(_ req: Request) throws -> Future<User.Public> {
        return try req.content.decode(User.self).flatMap { user in
            try user.validate()
            let tempPass = try CryptoRandom().generateData(count: 4).base32EncodedString().lowercased()
            
            let hasher = try req.make(BCryptDigest.self)
            let passwordHashed = try hasher.hash(tempPass)
            
            let newUser = User(email: user.email, password: passwordHashed)
            newUser.isNewUser = true
            return newUser.save(on: req).map { storedUser in
                return User.Public(id: try storedUser.requireID(), email: storedUser.email, password: tempPass , isNewUser: storedUser.isNewUser!)
            }
        }
    }
    
    func login(_ req: Request) throws -> Future<Token> {
        return try req.content.decode(User.self).flatMap { user in
            return User.query(on: req).filter(\.email == user.email).first().flatMap { fetchedUser in
                guard let existingUser = fetchedUser else {
                    throw Abort(HTTPStatus.notFound)
                }
                
                let hasher = try req.make(BCryptDigest.self)
                if try hasher.verify(user.password!, created: existingUser.password!) {
                    return try Token
                        .query(on: req)
                        .filter(\Token.userID, .equal, existingUser.requireID())
                        .delete()
                        .flatMap { _ in
                            let tokenString = try CryptoRandom().generateData(count: 32).base64EncodedString()
                            let token = try Token(token: tokenString, userID: existingUser.requireID())
                            return token.save(on: req)
                    }
                } else {
                    throw Abort(HTTPStatus.unauthorized)
                }
            }
        }
    }
    
    func logout(_ req: Request) throws -> Future<HTTPResponse> {
        let user = try req.requireAuthenticated(User.self)
        return try Token
            .query(on: req)
            .filter(\Token.userID, .equal, user.requireID())
            .delete()
            .transform(to: HTTPResponse(status: .ok))
    }
    
    func getAllHandler(_ req: Request) throws -> Future<[User]> {
        return User.query(on: req).decode(User.self).all()
    }
    
    func getOneHandler(_ req: Request) throws -> Future<User> {
        return try req.parameters.next(User.self)
    }
    
    func updateHandler(_ req: Request) throws -> Future<User> {
        return try flatMap(to: User.self, req.parameters.next(User.self), req.content.decode(User.self)) { (user, updatedUser) in
            user.email = updatedUser.email
//            user.username = updatedUser.username
//            user.password = try BCrypt.hash(updatedUser.password)
            return user.save(on: req)
        }
    }
    
    func deleteHandler(_ req: Request) throws -> Future<HTTPStatus> {
        return try req.parameters.next(User.self).flatMap { (user) in
            return user.delete(on: req).transform(to: HTTPStatus.noContent)
        }
    }
    
    func getTransactionsHandler(_ req: Request) throws -> Future<[Transaction]> {
        return try req.parameters.next(User.self).flatMap(to: [Transaction].self) { (user) in
            return try user.transactions.query(on: req).all()
        }
    }
    
    func getCreditCardsHandler(_ req: Request) throws -> Future<[CreditCard]> {
        return try req.parameters.next(User.self).flatMap(to: [CreditCard].self) { user in
            return try user.creditCards.query(on: req).all()
        }
    }
    
    func getCreditReccuringPaymentsHandler(_ req: Request) throws -> Future<[ReccuringPayment]> {
        return try req.parameters.next(User.self).flatMap(to: [ReccuringPayment].self) { user in
            return try user.reccuringPayments.query(on: req).all()
        }
    }
    
    func getAccountsHeandler(_ req: Request) throws -> Future<[Account]> {
        return try req.parameters.next(User.self).flatMap(to: [Account].self) { user in
            return try user.accounts.query(on: req).all()
        }
    }
}
