//
// Synchronizes NSUserDefaults with iCloud
// Just call DefaultsCloudSync.start() and you're done.
//

import Foundation
import OSLog

/// Synchronize User Defaults to iCloud automatically.
///
/// Call ``start()`` on app launch to begin the process
///
@available(iOS 10.0, tvOS 10.0, macOS 11.0, *)
public class HorizonDefaults: NSObject {
   
    /// Set to `true` to enable debug statements printed to the console.
    ///
    /// Defaults to `false` and hides printed console logs.
    ///
    public var verboseLogging: Bool = false
    private static let logger = Logger(subsystem: "HorizonDefaults", category: "default")
    
    /// Generic default syncronization object.
    ///
    public static let standard: HorizonDefaults = HorizonDefaults()
    
    /// Acceptable keys to sync across iCloud.
    /// 
    /// This is useful if you find your app synchronizing system defaults such
    /// as WebKit defaults or macOS display information.
    ///
    /// If no value is set (default), *all* keys will be synced.
    ///
    public var acceptableKeys: [String]?
    
    private let backgroundQueue = DispatchQueue(
        label: "horizonDefaultsQueue",
        qos: .background,
        attributes: .concurrent,
        autoreleaseFrequency: .workItem,
        target: .global()
    )
    
    /// Start synchronizing user defaults to and from iCloud
    ///
    /// Make a call to this function when your app launches or shortly thereafter.
    ///
    public class func start() {
        // Note: NSUbiquitousKeyValueStoreDidChangeExternallyNotification is sent only upon
        // a change received from iCloud, not when your app (i.e., the same instance) sets
        // a value.
        standard.backgroundQueue.async {
            NotificationCenter.default.addObserver(self, selector: #selector(self.updateUserDefaultsFromiCloud(notification:)), name: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(self.updateiCloudFromUserDefaults(notification:)), name: UserDefaults.didChangeNotification, object: nil)
        }
        
        if standard.verboseLogging {
            logger.info("Enabled automatic synchronization of NSUserDefaults and iCloud.")
        }
    }
    
    @objc private class func updateUserDefaultsFromiCloud(notification: NSNotification?) {
        // Prevent loop of notifications by removing our observer before we update
        // NSUserDefaults
        
        standard.backgroundQueue.async {
            NotificationCenter.default.removeObserver(self, name: UserDefaults.didChangeNotification, object: nil);
            
            let userDefaults = UserDefaults.standard
            
            if let keysToSync = HorizonDefaults.standard.acceptableKeys, keysToSync.count > 0 {
                for key in keysToSync {
                    userDefaults.set(NSUbiquitousKeyValueStore.default.object(forKey: key), forKey: key)
                }
            } else {
                let iCloudDictionary = NSUbiquitousKeyValueStore.default.dictionaryRepresentation
                
                for (key, obj) in iCloudDictionary {
                    userDefaults.set(obj, forKey: key as String)
                }
            }
            
            userDefaults.synchronize()
            
            // Re-enable NSUserDefaultsDidChangeNotification notifications
            NotificationCenter.default.addObserver(self, selector: #selector(self.updateiCloudFromUserDefaults(notification:)), name: UserDefaults.didChangeNotification, object: nil)
        }
        
        if standard.verboseLogging == true {
            logger.info("Updated NSUserDefaults from iCloud")
        }
    }
    
    @objc private class func updateiCloudFromUserDefaults(notification: NSNotification?) {
        standard.backgroundQueue.async {
            let defaultsDictionary = UserDefaults.standard.dictionaryRepresentation()
            let cloudStore = NSUbiquitousKeyValueStore.default
            
            if let keysToSync = HorizonDefaults.standard.acceptableKeys, keysToSync.count > 0 {
                for key in keysToSync {
                    cloudStore.set(UserDefaults.standard.object(forKey: key), forKey: key)
                }
            } else {
                for (key, obj) in defaultsDictionary {
                    cloudStore.set(obj, forKey: key as String)
                }
            }
            
            // let iCloud know that new or updated keys, values are ready to be uploaded
            cloudStore.synchronize()
            
            if standard.verboseLogging {
                logger.info("Notified iCloud of local updates")
            }
        }
    }

    deinit {
        backgroundQueue.async { [weak self] in
            guard let self = self else { return }
            NotificationCenter.default.removeObserver(self, name: UserDefaults.didChangeNotification, object: nil)
            NotificationCenter.default.removeObserver(self, name: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: nil)
        }
    }
    
}
