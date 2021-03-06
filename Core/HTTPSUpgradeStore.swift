//
//  HTTPSUpgradeStore.swift
//  DuckDuckGo
//
//  Copyright © 2018 DuckDuckGo. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation
import CoreData

public protocol HTTPSUpgradeStore {
    
    func bloomFilter() -> BloomFilterWrapper?
    
    func bloomFilterSpecification() -> HTTPSBloomFilterSpecification?
    
    func persistBloomFilter(specification: HTTPSBloomFilterSpecification, data: Data) -> Bool
    
    func hasWhitelistedDomain(_ domain: String) -> Bool
    
    func persistWhitelist(domains: [String])
}

public class HTTPSUpgradePersistence: HTTPSUpgradeStore {
    
    private let container = DDGPersistenceContainer(name: "HTTPSUpgrade")!
    
    public init() {
    }
    
    private var hasBloomFilterData: Bool {
        return (try? bloomFilterPath.checkResourceIsReachable()) ?? false
    }
    
    private var bloomFilterPath: URL {
        let path = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: ContentBlockerStoreConstants.groupName)
        return path!.appendingPathComponent("HttpsBloomFilter.bin")
    }
    
    public func bloomFilter() -> BloomFilterWrapper? {
        guard hasBloomFilterData else { return nil }
        var bloomFilter: BloomFilterWrapper?
        container.managedObjectContext.performAndWait {
            if let specification = bloomFilterSpecification() {
                let entries = specification.totalEntries
                bloomFilter = BloomFilterWrapper(fromPath: bloomFilterPath.path, withTotalItems: Int32(entries))
            }
        }
        return bloomFilter
    }

    public func bloomFilterSpecification() -> HTTPSBloomFilterSpecification? {
        var specification: HTTPSBloomFilterSpecification?
        container.managedObjectContext.performAndWait {
            let request: NSFetchRequest<HTTPSStoredBloomFilterSpecification> = HTTPSStoredBloomFilterSpecification.fetchRequest()
            guard let result = try? request.execute() else { return }
            specification = HTTPSBloomFilterSpecification.copy(storedSpecification: result.first)
        }
        return specification
    }
    
    public func persistBloomFilter(specification: HTTPSBloomFilterSpecification, data: Data) -> Bool {
        Logger.log(items: "HTTPS Bloom Filter", bloomFilterPath)
        guard data.sha256 == specification.sha256 else { return false }
        guard persistBloomFilter(data: data) else { return false }
        persistBloomFilterSpecification(specification)
        return true
    }
    
    func persistBloomFilter(data: Data) -> Bool {
        do {
            try data.write(to: bloomFilterPath, options: .atomic)
            return true
        } catch _ {
            return false
        }
    }
    
    private func deleteBloomFilter() {
        try? FileManager.default.removeItem(at: bloomFilterPath)
    }
    
    func persistBloomFilterSpecification(_ specification: HTTPSBloomFilterSpecification) {
        
        container.managedObjectContext.performAndWait {
            deleteBloomFilterSpecification()
            
            let entityName = String(describing: HTTPSStoredBloomFilterSpecification.self)
            let context = container.managedObjectContext
            
            if let storedEntity = NSEntityDescription.insertNewObject(
                forEntityName: entityName,
                into: context) as? HTTPSStoredBloomFilterSpecification {
                
                storedEntity.totalEntries = Int64(specification.totalEntries)
                storedEntity.errorRate = specification.errorRate
                storedEntity.sha256 = specification.sha256
                
            }
            _ = container.save()
        }
    }
    
    private func deleteBloomFilterSpecification() {
        container.managedObjectContext.performAndWait {
            container.deleteAll(entities: try? container.managedObjectContext.fetch(HTTPSStoredBloomFilterSpecification.fetchRequest()))
        }
    }
    
    public func hasWhitelistedDomain(_ domain: String) -> Bool {
        var result = false
        container.managedObjectContext.performAndWait {
            let request: NSFetchRequest<HTTPSWhitelistedDomain> = HTTPSWhitelistedDomain.fetchRequest()
            request.predicate = NSPredicate(format: "domain = %@", domain.lowercased())
            guard let count = try? container.managedObjectContext.count(for: request) else { return }
            result = count > 0
        }
        return result
    }
    
    public func persistWhitelist(domains: [String]) {
        container.managedObjectContext.performAndWait {
            deleteWhitelist()

            for domain in domains {
                let entityName = String(describing: HTTPSWhitelistedDomain.self)
                let context = container.managedObjectContext
                if let storedDomain = NSEntityDescription.insertNewObject(forEntityName: entityName, into: context) as? HTTPSWhitelistedDomain {
                    storedDomain.domain = domain.lowercased()
                }
            }
            _ = container.save()
        }
    }
    
    private func deleteWhitelist() {
        container.managedObjectContext.performAndWait {
            container.deleteAll(entities: try? container.managedObjectContext.fetch(HTTPSWhitelistedDomain.fetchRequest()))
        }
    }
    
    func reset() {
        deleteBloomFilterSpecification()
        deleteBloomFilter()
        deleteWhitelist()
    }
}
