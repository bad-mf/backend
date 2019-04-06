import Vapor
import FluentSQLite

final class User: Codable {
    
    var id: Int?
    var name: String
    var username: String
    var password: String
    
    init(name: String, username: String, password: String) {
        self.name = name
        self.username = username
        self.password = password
    }
    
    final class Public: Codable {
        var id: Int?
        var name: String
        var username: String
        
        init(id: Int?, name: String, username: String) {
            self.id = id
            self.name = name
            self.username = username
        }
    }
}

extension User {
    func toPublic() -> User.Public {
        return User.Public(id: id, name: name, username: username)
    }
}

extension Future where T: User {
    func toPublic() -> Future<User.Public> {
        return map(to: User.Public.self) { (user) in
            return user.toPublic()
        }
    }
}

extension User: SQLiteModel {}
extension User: Migration {}
extension User: Content {}
extension User.Public: Content {}
extension User: Parameter {}
