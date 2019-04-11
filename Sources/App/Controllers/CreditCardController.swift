import Vapor

final class CreditCardController: RouteCollection {
    
    
    func boot(router: Router) throws {
        let creditcardsRoute = router.grouped("api", "creditcards")
        let tokenAuthMiddleware = User.tokenAuthMiddleware()
        let tokenProtected = creditcardsRoute.grouped(tokenAuthMiddleware)
        
        tokenProtected.get(use: getAllHandler)
        tokenProtected.get(CreditCard.parameter, "user", use: getUserHandler)
        tokenProtected.post(use: createHeandler)
        
    }
    
    func createHeandler(_ req: Request) throws -> Future<CreditCard> {
        return try req.content.decode(CreditCard.self).flatMap {
            creditCard in
            return creditCard.save(on: req)
        }
    }
    
    func getAllHandler(_ req: Request) throws -> Future<[CreditCard]> {
        return CreditCard.query(on: req).decode(CreditCard.self).all()
    }
    
    func getUserHandler(_ req: Request) throws -> Future<User.Public> {
        return try req.parameters.next(CreditCard.self).flatMap(to: User.Public.self) { (creditCard) in
            return creditCard.user.get(on: req).toPublic()
        }
    }
}
