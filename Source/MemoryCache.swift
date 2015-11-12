import Foundation

public class MemoryCache: CacheAware {

  public static let prefix = "no.hyper.Cache.Memory"

  public var path: String {
    return cache.name
  }

  public var maxSize: UInt = 0 {
    didSet(value) {
      self.cache.totalCostLimit = Int(maxSize)
    }
  }

  public let cache = NSCache()
  public private(set) var writeQueue: dispatch_queue_t
  public private(set) var readQueue: dispatch_queue_t

  // MARK: - Initialization

  public required init(name: String) {
    cache.name = "\(MemoryCache.prefix).\(name.capitalizedString)"
    writeQueue = dispatch_queue_create("\(cache.name).WriteQueue", DISPATCH_QUEUE_SERIAL)
    readQueue = dispatch_queue_create("\(cache.name).ReadQueue", DISPATCH_QUEUE_SERIAL)
  }

  // MARK: - CacheAware

  public func add<T: Cachable>(key: String, object: T, expiry: Expiry = .Never, completion: (() -> Void)? = nil) {
    dispatch_async(writeQueue) { [weak self] in
      guard let weakSelf = self else {
        completion?()
        return
      }

      let capsule = Capsule(value: object, expiry: expiry)

      weakSelf.cache.setObject(capsule, forKey: key)
      completion?()
    }
  }

  public func object<T: Cachable>(key: String, completion: (object: T?) -> Void) {
    dispatch_async(readQueue) { [weak self] in
      guard let weakSelf = self else {
        completion(object: nil)
        return
      }

      let capsule = weakSelf.cache.objectForKey(key) as? Capsule
      completion(object: capsule?.value as? T)

      if let capsule = capsule {
        weakSelf.removeIfExpired(key, capsule: capsule)
      }
    }
  }

  public func remove(key: String, completion: (() -> Void)? = nil) {
    dispatch_async(writeQueue) { [weak self] in
      guard let weakSelf = self else {
        completion?()
        return
      }

      weakSelf.cache.removeObjectForKey(key)
      completion?()
    }
  }

  public func removeIfExpired(key: String) {
    dispatch_async(writeQueue) { [weak self] in
      guard let weakSelf = self else { return }

      if let capsule = weakSelf.cache.objectForKey(key) as? Capsule {
        weakSelf.removeIfExpired(key, capsule: capsule)
      }
    }
  }

  public func clear(completion: (() -> Void)? = nil) {
    dispatch_async(writeQueue) { [weak self] in
      guard let weakSelf = self else {
        completion?()
        return
      }

      weakSelf.cache.removeAllObjects()
      completion?()
    }
  }

  // MARK: - Helpers

  func removeIfExpired(key: String, capsule: Capsule) {
    if capsule.expired {
      remove(key)
    }
  }
}
