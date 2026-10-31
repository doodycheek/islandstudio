import Foundation
import UIKit

/// Reads the battery percentage.
///
/// iOS only hands apps the battery in 5% steps through UIDevice (so 18% shows up as 20%).
/// This reader first asks the system's power-source service, which reports every single percent on
/// most devices, and only falls back to the 5% steps if that isn't available.
@MainActor
enum BatteryReader {
    struct Reading {
        let level: Int
        let charging: Bool
        let exact: Bool
    }

    private static var cached: (reading: Reading, at: Date)?

    static func read() -> Reading {
        if let cached, Date().timeIntervalSince(cached.at) < 0.8 { return cached.reading }
        let device = UIDevice.current
        device.isBatteryMonitoringEnabled = true
        let standard = device.batteryLevel
        let charging = device.batteryState == .charging || device.batteryState == .full

        let reading: Reading
        if let exact = IOKitBattery.percent() {
            reading = Reading(level: exact, charging: charging, exact: true)
        } else {
            reading = Reading(level: standard < 0 ? -1 : Int((standard * 100).rounded()), charging: charging, exact: false)
        }
        cached = (reading, Date())
        return reading
    }

    /// True when the last reading came from the exact method.
    static var isExact: Bool { read().exact }
}

/// Talks to IOKit through dlopen, because Apple doesn't ship its headers for iPhone.
/// Everything here fails quietly: if iOS says no, `percent()` just returns nil.
enum IOKitBattery {
    private typealias CopyInfoFn = @convention(c) () -> UnsafeMutableRawPointer?
    private typealias CopyListFn = @convention(c) (UnsafeRawPointer?) -> UnsafeMutableRawPointer?
    private typealias GetDescriptionFn = @convention(c) (UnsafeRawPointer?, UnsafeRawPointer?) -> UnsafeMutableRawPointer?
    private typealias MatchingFn = @convention(c) (UnsafePointer<CChar>) -> UnsafeMutableRawPointer?
    private typealias GetServiceFn = @convention(c) (UInt32, UnsafeRawPointer?) -> UInt32
    private typealias CreatePropsFn = @convention(c) (UInt32, UnsafeMutablePointer<UnsafeMutableRawPointer?>?, UnsafeRawPointer?, UInt32) -> Int32
    private typealias ReleaseFn = @convention(c) (UInt32) -> Int32

    private static let handle: UnsafeMutableRawPointer? =
        dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_LAZY)

    static func percent() -> Int? {
        if let value = fromPowerSources() { return value }
        return fromRegistry()
    }

    private static func percentFrom(_ dict: [String: Any]) -> Int? {
        let keys = ["Current Capacity", "CurrentCapacity"]
        let maxKeys = ["Max Capacity", "MaxCapacity"]
        guard let current = keys.compactMap({ dict[$0] as? Int }).first else { return nil }
        let maximum = maxKeys.compactMap { dict[$0] as? Int }.first ?? 100
        guard maximum > 0 else { return nil }
        let value = Int((Double(current) / Double(maximum) * 100).rounded())
        return (0...100).contains(value) ? value : nil
    }

    private static func fromPowerSources() -> Int? {
        guard let handle,
              let infoSymbol = dlsym(handle, "IOPSCopyPowerSourcesInfo"),
              let listSymbol = dlsym(handle, "IOPSCopyPowerSourcesList"),
              let descSymbol = dlsym(handle, "IOPSGetPowerSourceDescription") else { return nil }
        let copyInfo = unsafeBitCast(infoSymbol, to: CopyInfoFn.self)
        let copyList = unsafeBitCast(listSymbol, to: CopyListFn.self)
        let getDescription = unsafeBitCast(descSymbol, to: GetDescriptionFn.self)

        guard let infoPointer = copyInfo() else { return nil }
        let info = Unmanaged<AnyObject>.fromOpaque(infoPointer).takeRetainedValue()
        guard let listPointer = copyList(Unmanaged.passUnretained(info).toOpaque()) else { return nil }
        let list = Unmanaged<AnyObject>.fromOpaque(listPointer).takeRetainedValue()
        guard let sources = list as? [AnyObject] else { return nil }

        for source in sources {
            guard let descriptionPointer = getDescription(Unmanaged.passUnretained(info).toOpaque(),
                                                          Unmanaged.passUnretained(source).toOpaque()) else { continue }
            let description = Unmanaged<AnyObject>.fromOpaque(descriptionPointer).takeUnretainedValue()
            if let dict = description as? [String: Any], let value = percentFrom(dict) {
                return value
            }
        }
        return nil
    }

    private static func fromRegistry() -> Int? {
        guard let handle,
              let matchingSymbol = dlsym(handle, "IOServiceMatching"),
              let serviceSymbol = dlsym(handle, "IOServiceGetMatchingService"),
              let propsSymbol = dlsym(handle, "IORegistryEntryCreateCFProperties"),
              let releaseSymbol = dlsym(handle, "IOObjectRelease") else { return nil }
        let matching = unsafeBitCast(matchingSymbol, to: MatchingFn.self)
        let getService = unsafeBitCast(serviceSymbol, to: GetServiceFn.self)
        let createProps = unsafeBitCast(propsSymbol, to: CreatePropsFn.self)
        let release = unsafeBitCast(releaseSymbol, to: ReleaseFn.self)

        for name in ["IOPMPowerSource", "AppleSmartBattery"] {
            guard let dictionary = matching(name) else { continue }
            let service = getService(0, UnsafeRawPointer(dictionary))
            if service == 0 { continue }
            defer { _ = release(service) }
            var properties: UnsafeMutableRawPointer? = nil
            guard createProps(service, &properties, nil, 0) == 0, let pointer = properties else { continue }
            let object = Unmanaged<AnyObject>.fromOpaque(pointer).takeRetainedValue()
            if let dict = object as? [String: Any], let value = percentFrom(dict) {
                return value
            }
        }
        return nil
    }
}
