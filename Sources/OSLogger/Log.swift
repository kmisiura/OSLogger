import Foundation
import os.log

public class Log {
    static var dateFormatter: ISO8601DateFormatter = {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.timeZone = .current
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds, .withTimeZone]
        return dateFormatter
    }()
    
    public enum Level: Int, RawRepresentable, CaseIterable {
        case debug = 6
        case verbose = 5
        case info = 4
        case warning = 3
        case error = 2
        case exception = 1
        
        public func event() -> String {
            switch self {
                case .debug:    return "[DEBUG]"
                case .verbose:  return "[VERBOSE]"
                case .info:     return "[INFO]"
                case .warning:  return "[WARNING]"
                case .error:    return "[ERROR]"
                case .exception: return "[EXCEPTION]"
            }
        }
        
        public func osLogType() -> OSLogType {
            switch self {
                case .debug:    return OSLogType.debug
                case .verbose:  return OSLogType.debug
                case .info:     return OSLogType.info
                case .warning:  return OSLogType.default
                case .error:    return OSLogType.error
                case .exception: return OSLogType.fault
            }
        }
        
        public func isEnabled() -> Bool {
            switch self {
                case .debug:
                    return (Log.logLevel.rawValue >= Level.debug.rawValue)
                case .verbose:
                    return Log.logLevel.rawValue >= Level.verbose.rawValue
                case .info:
                    return Log.logLevel.rawValue >= Level.info.rawValue
                case .warning:
                    return Log.logLevel.rawValue >= Level.warning.rawValue
                case .error:
                    return Log.logLevel.rawValue >= Level.error.rawValue
                case .exception:
                    return Log.logLevel.rawValue >= Level.exception.rawValue
            }
        }
    }
    
    public static var logLevel: Log.Level {
        get {
#if DEBUG
            return Log.debugLogLevel
#else
            return Log.releaseLogLevel
#endif
        }
        set {
#if DEBUG
            Log.debugLogLevel = newValue
#else
            Log.releaseLogLevel = newValue
#endif
        }
    }
    
    public static var isLogStorageEnabled: Bool = true
    public static var currentLog: String? {
        if isLogStorageEnabled {
            return logStorage.currentLog()
        }
        
        Log.warning("Log storage is disabbled.")
        return nil
    }
    public static var directoryWithLogs: URL? {
        if isLogStorageEnabled {
            return logStorage.directoryWithLogs()
        }
        
        Log.warning("Log storage is disabbled.")
        return nil
    }
    
    private static let logger = OSLog(subsystem: getSubsystemName(), category: .pointsOfInterest)
    private static let verboseLogger = OSLog(subsystem: getSubsystemName(), category: .dynamicTracing)
    
    private static var logStorage: LogStorage = LogStorage()
    
    private static var debugLogLevel: Log.Level = .debug
    private static var releaseLogLevel: Log.Level = .verbose
    
    public static func writeLogs() {
        logStorage.forceFlushLog()
    }
    
    // MARK: - Loging methods
    
    public class func debug(_ object: Any? = nil, file: String = #file, line: Int = #line, column: Int = #column, funcName: String = #function) {
        let nameAndPackage = sourceFileNameAndPackage(filePath: file)
        log(object, package: nameAndPackage.package, file: nameAndPackage.fileName, line: line, column: column, funcName: funcName, level: .debug)
    }
    
    public class func verbose(_ object: Any? = nil, file: String = #file, line: Int = #line, column: Int = #column, funcName: String = #function) {
        let nameAndPackage = sourceFileNameAndPackage(filePath: file)
        log(object, package: nameAndPackage.package, file: nameAndPackage.fileName, line: line, column: column, funcName: funcName, level: .verbose)
    }
    
    public class func info(_ object: Any, file: String = #file, line: Int = #line, column: Int = #column, funcName: String = #function) {
        let nameAndPackage = sourceFileNameAndPackage(filePath: file)
        log(object, package: nameAndPackage.package, file: nameAndPackage.fileName, line: line, column: column, funcName: funcName, level: .info)
    }
    
    public class func warning(_ object: Any, file: String = #file, line: Int = #line, column: Int = #column, funcName: String = #function) {
        let nameAndPackage = sourceFileNameAndPackage(filePath: file)
        log(object, package: nameAndPackage.package, file: nameAndPackage.fileName, line: line, column: column, funcName: funcName, level: .warning)
    }
    
    public class func error(_ object: Any, file: String = #file, line: Int = #line, column: Int = #column, funcName: String = #function) {
        let nameAndPackage = sourceFileNameAndPackage(filePath: file)
        log(object, package: nameAndPackage.package, file: nameAndPackage.fileName, line: line, column: column, funcName: funcName, level: .error)
    }
    
    public class func exception(_ object: Any, file: String = #file, line: Int = #line, column: Int = #column, funcName: String = #function) {
        let nameAndPackage = sourceFileNameAndPackage(filePath: file)
        log(object, package: nameAndPackage.package, file: nameAndPackage.fileName, line: line, column: column, funcName: funcName, level: .exception)
    }
    
    public class func critical(_ object: Any, file: String = #file, line: Int = #line, column: Int = #column, funcName: String = #function) {
        Log.exception(object, file: file, line: line, column: column, funcName: funcName)
    }
    
    private class func sourceFileNameAndPackage(filePath: String) -> (fileName: String, package: String?) {
        let components = filePath.components(separatedBy: "/")
        let fileName = components.isEmpty ? "" : components.last!
        if let index = components.firstIndex(of: "SourcePackages"), index + 2 < components.count {
            let package = components[index + 2]
            return (fileName, package)
        } else {
            return (fileName, nil)
        }
    }
    
    private class func log(_ object: Any?, package: String? = nil, file: String = #file,
                           line: Int = #line, column: Int = #column, funcName: String = #function, level: Log.Level) {
        if level.isEnabled() {
            let message: String
            if let object = object, let package = package {
                message = "\(level.event()) [\(package)] \(file) \(line):\(column) \(funcName): \(object)"
            } else if let package = package {
                message = "\(level.event()) [\(package)] \(file) \(line):\(column) \(funcName)"
            } else if let object = object {
                message = "\(level.event()) \(file) \(line):\(column) \(funcName): \(object)"
            } else {
                message = "\(level.event()) \(file) \(line):\(column) \(funcName)"
            }
            os_log("%{public}s", log: logger, type: level.osLogType(), message)
            if isLogStorageEnabled { logStorage.log(message: message, timestamp: Date()) }
        }
        
        LogForwarder.shared?.listeners.forEach { $0.log(object: object,
                                                        level: level,
                                                        file: file,
                                                        line: line,
                                                        column: column,
                                                        funcName: funcName) }
    }
    
    private static func getSubsystemName() -> String {
        return Bundle.main.bundlePath.components(separatedBy: "/").last ?? "Logger"
    }
    
    public class func getFileSourceIdentifier(filePath: String) -> String {
        let sourceInfo = sourceFileNameAndPackage(filePath: filePath)
        var sourceIdentifier = ""
        
        if let package = sourceInfo.package {
            sourceIdentifier.append(package)
            sourceIdentifier.append(".")
        }
        
        sourceIdentifier.append(sourceInfo.fileName)
        
        return sourceIdentifier
    }
}

internal extension Date {
    func toString() -> String {
        return Log.dateFormatter.string(from: self as Date)
    }
}
