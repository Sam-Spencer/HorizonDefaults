//
// Synchronizes NSUserDefaults with iCloud
// Just call DefaultsCloudSync.start() and you're done.
//

import UIKit

/// Synchronize User Defaults to iCloud automatically
/// Call `start()` on app launch to begin the process
@available(iOS 10.0, *)
public class HorizonDefaults: NSObject {
   
    /// Set to `true` to enable debug statements printed to the console
    /// Defaults to `false` and hides printed console logs
    public var verboseLogging: Bool = false
    
    /// Generic default syncronization object
    public static let standard: HorizonDefaults = HorizonDefaults()
    
    private let backgroundQueue = DispatchQueue.init(label: "horizonDefaultsQueue", qos: .background, attributes: .concurrent, autoreleaseFrequency: .workItem, target: .global())
    
    /// Start synchronizing user defaults to and from iCloud
    ///
    /// Make a call to this function when your app launches or shortly thereafter
    public class func start() {
        // Note: NSUbiquitousKeyValueStoreDidChangeExternallyNotification is sent only upon a change received from iCloud, not when your app (i.e., the same instance) sets a value.
        standard.backgroundQueue.async {
            NotificationCenter.default.addObserver(self, selector: #selector(self.updateUserDefaultsFromiCloud(notification:)), name: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(self.updateiCloudFromUserDefaults(notification:)), name: UserDefaults.didChangeNotification, object: nil)
        }
        if standard.verboseLogging == true {
            print("Enabled automatic synchronization of NSUserDefaults and iCloud.")
        }
    }
    
    @objc private class func updateUserDefaultsFromiCloud(notification: NSNotification?) {
        // Prevent loop of notifications by removing our observer before we update NSUserDefaults
        standard.backgroundQueue.async {
            NotificationCenter.default.removeObserver(self, name: UserDefaults.didChangeNotification, object: nil);
            
            let iCloudDictionary = NSUbiquitousKeyValueStore.default.dictionaryRepresentation
            let userDefaults = UserDefaults.standard
            
            for (key, obj) in iCloudDictionary {
                userDefaults.set(obj, forKey: key as String)
            }
            
            userDefaults.synchronize()
            
            // Re-enable NSUserDefaultsDidChangeNotification notifications
            NotificationCenter.default.addObserver(self, selector: #selector(self.updateiCloudFromUserDefaults(notification:)), name: UserDefaults.didChangeNotification, object: nil)
        }
        
        if standard.verboseLogging == true {
            print("Updated NSUserDefaults from iCloud")
        }
    }
    
    @objc private class func updateiCloudFromUserDefaults(notification: NSNotification?) {
        standard.backgroundQueue.async {
            let defaultsDictionary = UserDefaults.standard.dictionaryRepresentation()
            let cloudStore = NSUbiquitousKeyValueStore.default
            
            for (key, obj) in defaultsDictionary {
                cloudStore.set(obj, forKey: key as String)
            }
            
            // let iCloud know that new or updated keys, values are ready to be uploaded
            cloudStore.synchronize()
            
            if standard.verboseLogging == true {
                print("Notified iCloud of local updates")
            }
        }
    }

    deinit {
        backgroundQueue.async {
            NotificationCenter.default.removeObserver(self, name: UserDefaults.didChangeNotification, object: nil)
            NotificationCenter.default.removeObserver(self, name: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: nil)
        }
    }
    
}
