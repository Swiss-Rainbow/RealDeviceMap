//
//  Webhook.swift
//  RealDeviceMap
//
//  Created by versx on 9/22/19.
//

import Foundation
import PerfectLib
import PerfectMySQL

enum WebhookType: Hashable {
    case pokemon
    case raids
    case eggs
    //case quests
    case lures
    case invasions
    case gyms
    case weather
    
    public static var allCases: [WebhookType] = [
        .pokemon,
        .raids,
        .eggs,
        //.quests,
        .lures,
        .invasions,
        .gyms,
        .weather
    ]
    
    static func fromString(_ s: String) -> WebhookType? {
        if s.lowercased() == "pokemon" {
            return .pokemon
        } else if s.lowercased() == "raids" {
            return .raids
        } else if s.lowercased() == "eggs" {
            return .eggs
        } else if s.lowercased() == "lures" {
            return .lures
        } else if s.lowercased() == "invasions" {
            return .invasions
        } else if s.lowercased() == "gyms" {
            return .gyms
        } else if s.lowercased() == "weather" {
            return .weather
        } else {
            return .pokemon //TODO: Review
        }
    }
    
    static func toString(_ wht: WebhookType) -> String {
        switch wht {
        case .pokemon:   return "Pokemon"
        case .raids:     return "Raids"
        case .eggs:      return "Eggs"
        case .lures:     return "Lures"
        case .invasions: return "Invasions"
        case .gyms:      return "Gyms"
        case .weather:   return "Weather"
        //default:       return "Pokemon"
        }
    }
}

class Webhook: Hashable {
    
    public var hashValue: Int {
        return name.hashValue
    }
    
    var name: String
    var url: String
    var delay: Double
    var types: [WebhookType]
    var data: [String: Any]
    var enabled: Bool
    
    init(name: String, url: String, delay: Double, types: [WebhookType], data: [String: Any], enabled: Bool) {
        self.name = name
        self.url = url
        self.delay = delay
        self.types = types
        self.data = data
        self.enabled = enabled
    }
    
    public func save(mysql: MySQL?=nil, oldName: String) throws {
        
        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[Webhook] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let mysqlStmt = MySQLStmt(mysql)
        let sql = """
                UPDATE webhook
                SET name = ?, url = ?, delay = ?, types = ?, data = ?, enabled = ?
                WHERE name = ?
            """
        
        var typesData = [Any]()
        for type in types {
            typesData.append(WebhookType.toString(type))
        }
        
        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(name)
        mysqlStmt.bindParam(url)
        mysqlStmt.bindParam(delay)
        mysqlStmt.bindParam(try! typesData.jsonEncodedString())
        mysqlStmt.bindParam(try! data.jsonEncodedString())
        mysqlStmt.bindParam(enabled)
        mysqlStmt.bindParam(oldName)
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[Webhook] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
    }
    
    public func create(mysql: MySQL?=nil) throws {
        
        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[Webhook] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let mysqlStmt = MySQLStmt(mysql)
        let sql = """
            INSERT INTO webhook (name, url, delay, types, data, enabled)
            VALUES (?, ?, ?, ?, ?, ?)
        """
        
        var typesData = [Any]()
        for type in types {
            typesData.append(WebhookType.toString(type))
        }
        
        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(name)
        mysqlStmt.bindParam(url)
        mysqlStmt.bindParam(delay)
        mysqlStmt.bindParam(try! typesData.jsonEncodedString())
        mysqlStmt.bindParam(try! data.jsonEncodedString())
        mysqlStmt.bindParam(enabled)
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[Webhook] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
    }
    
    public func delete(mysql: MySQL?=nil) throws {
        
        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[Webhook] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let mysqlStmt = MySQLStmt(mysql)
        let sql = """
            DELETE FROM webhook
            WHERE name = ? AND url = ?
        """
        
        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(name)
        mysqlStmt.bindParam(url)
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[Webhook] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
    }
    
    public static func deleteAll(mysql: MySQL?=nil) throws {
        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[Webhook] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let mysqlStmt = MySQLStmt(mysql)
        let sql = """
            DELETE FROM webhook
        """
        
        _ = mysqlStmt.prepare(statement: sql)
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[Webhook] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
    }
    
    public static func getAll(mysql: MySQL?=nil) throws -> [Webhook] {
        
        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[Webhook] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let sql = """
            SELECT name, url, delay, types, data, enabled
            FROM webhook
        """
        
        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[Webhook] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()
        
        var webhooks = [Webhook]()
        while let result = results.next() {
            let name = result[0] as! String
            let url = result[1] as! String
            let delay = result[2] as! Double
            let typesData = (try? (result[3] as? String)?.jsonDecode() as? [Any]) ?? [Any]()
            var types = [WebhookType]()
            if typesData != nil && !(typesData?.isEmpty ?? false) {
                for type in typesData! {
                    types.append(WebhookType.fromString(type as! String)!)
                }
            }
            /*
            let idsData = try! (result[4] as! String).jsonDecode() as? [Any]
            let ids = idsData as? [UInt16] ?? (idsData as? [Int])?.map({ (e) -> UInt16 in
                return UInt16(e)
            }) ?? [UInt16]()
            */
            let data = (try? ((result[4]) as! String).jsonDecode() as? [String: Any]) ?? [String: Any]()
            let enabledInt = result[5] as? UInt8
            let enabled = enabledInt?.toBool() ?? true
            
            webhooks.append(Webhook(name: name, url: url, delay: delay, types: types, data: data ?? [String: Any](), enabled: enabled))
        }
        return webhooks
        
    }
    
    public static func getByName(mysql: MySQL?=nil, name: String) throws -> Webhook? {
        
        guard let mysql = mysql ?? DBController.global.mysql else {
            Log.error(message: "[Webhook] Failed to connect to database.")
            throw DBController.DBError()
        }
        
        let sql = """
            SELECT name, url, delay, types, data, enabled
            FROM webhook
            WHERE name = ?
        """
        
        let mysqlStmt = MySQLStmt(mysql)
        _ = mysqlStmt.prepare(statement: sql)
        mysqlStmt.bindParam(name)
        
        guard mysqlStmt.execute() else {
            Log.error(message: "[Webhook] Failed to execute query. (\(mysqlStmt.errorMessage())")
            throw DBController.DBError()
        }
        let results = mysqlStmt.results()
        if results.numRows == 0 {
            return nil
        }
        
        let result = results.next()!
        let name = result[0] as! String
        let url = result[1] as! String
        let delay = result[2] as! Double
        let typesData = (try! (result[3] as! String).jsonDecode() as? [Any]) ?? [Any]()
        var types = [WebhookType]()
        if !typesData.isEmpty {
            for type in typesData {
                types.append(WebhookType.fromString(type as! String)!)
            }
        }
        /*
        let idsData = try! (result[4] as! String).jsonDecode() as? [Any]
        let ids = idsData as? [UInt16] ?? (idsData as? [Int])?.map({ (e) -> UInt16 in
            return UInt16(e)
        }) ?? [UInt16]()
        */
        let data = (try? (result[4] as! String).jsonDecode() as? [String: Any]) ?? [String: Any]()
        let enabledInt = result[5] as? UInt8
        let enabled = enabledInt?.toBool() ?? true
        return Webhook(name: name, url: url, delay: delay, types: types, data: data ?? [String: Any](), enabled: enabled)
        
    }
    
    static func == (lhs: Webhook, rhs: Webhook) -> Bool {
        return lhs.name == rhs.name && lhs.url == rhs.url
    }
    
}