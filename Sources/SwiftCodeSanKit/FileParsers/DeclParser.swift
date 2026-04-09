//
//  Copyright (c) 2018. Uber Technologies
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
import SwiftSyntax
import SwiftParser

public class DeclParser: @unchecked Sendable {
    
    nonisolated(unsafe) var wpaths = 0
    nonisolated(unsafe) var npaths = 0
    
    public init() {}

    func scanAndMapDecls(fileToModuleMap: [String: String],
                         moduleToPackageMap: [String: String]? = nil,
                         topDeclsOnly: Bool,
                         whitelist: Whitelist?) -> DeclMap {
        nonisolated(unsafe) var allDeclMap = DeclMap()
        let lock = NSLock()

        scanDecls(fileToModuleMap: fileToModuleMap, moduleToPackageMap: moduleToPackageMap, topDeclsOnly: topDeclsOnly, whitelist: whitelist) { @Sendable (filepath, subResults) in
            lock.lock()
            defer { lock.unlock() }
            for (k, decls) in subResults {
                if allDeclMap[k] == nil {
                    allDeclMap[k] = []
                }

                for decl in decls {
                    if allDeclMap[k]?.contains(decl) ?? false {
                        // Already added, so do nothing
                    } else {
                        allDeclMap[k]?.append(decl)
                    }
                }
            }
        }
        return allDeclMap
    }

    func scanAndMapDecls(fileToModuleMap: [String: String],
                         topDeclsOnly: Bool) -> DeclMap {
        return scanAndMapDecls(fileToModuleMap: fileToModuleMap,
                               topDeclsOnly: topDeclsOnly,
                               whitelist: nil)
    }

    func scanDecls(fileToModuleMap: [String: String],
                   moduleToPackageMap: [String: String]? = nil,
                   topDeclsOnly: Bool,
                   completion: @Sendable @escaping (String, DeclMap) -> ()) {
        scan(fileToModuleMap) { (path: String, module: String, lock: NSLock?) in
            self.visitSrc(path: path,
                          module: module,
                          package: moduleToPackageMap?[module],
                          topDeclsOnly: topDeclsOnly,
                          whitelist: nil,
                          lock: lock,
                          completion: completion)
        }
    }

    func scanDecls(fileToModuleMap: [String: String],
                   moduleToPackageMap: [String: String]? = nil,
                   topDeclsOnly: Bool,
                   whitelist: Whitelist?,
                   completion: @Sendable @escaping (String, DeclMap) -> ()) {
        scan(fileToModuleMap) { (path: String, module: String, lock: NSLock?) in
            self.visitSrc(path: path,
                          module: module,
                          package: moduleToPackageMap?[module],
                          topDeclsOnly: topDeclsOnly,
                          whitelist: whitelist,
                          lock: lock,
                          completion: completion)
        }
    }

    private func visitSrc(path: String,
                          module: String?,
                          package: String?,
                          topDeclsOnly: Bool,
                          whitelist: Whitelist?,
                          lock: NSLock?,
                          completion: @Sendable @escaping (String, DeclMap) -> ()) {
        do {
            let node = Parser.parse(source: try String(contentsOfFile: path, encoding: .utf8))
            let whitelistPath = FileManager.modifiedWithin(whitelist?.thresholdDays, at: path)
            if whitelistPath {
                wpaths += 1
            }
            npaths += 1
            let visitor = DeclVisitor(path,
                                      module: module,
                                      topDeclsOnly: topDeclsOnly,
                                      whitelistPath: whitelistPath,
                                      whitelist: whitelist,
                                      package: package)
            visitor.walk(node)
            
            lock?.lock()
            defer {lock?.unlock()}
            completion(path, visitor.declMap)
        } catch {
            fatalError(error.localizedDescription)
        }
    }

    func checkRefs(fileToModuleMap: [String: String],
                   declMap: DeclMap,
                   completion: @Sendable @escaping (String, Set<String>, [String]) -> ()) {

        scan(fileToModuleMap) { (path: String, module: String, lock: NSLock?) in
            self.referenceSrc(path: path, module: module, declMap: declMap, lock: lock, completion: completion)
        }
    }

    private func referenceSrc(path: String,
                               module: String,
                               declMap: DeclMap,
                               lock: NSLock?,
                               completion: @Sendable @escaping (String, Set<String>, [String]) -> ()) {
        do {
            let node = Parser.parse(source: try String(contentsOfFile: path, encoding: .utf8))
            let visitor = RefChecker(path, module: module, declMap: declMap)
            visitor.walk(node)
            
            lock?.lock()
            completion(path, visitor.refs, visitor.imports)
            lock?.unlock()
        } catch {
            fatalError(error.localizedDescription)
        }
    }

    // MARK - input is dirs or filepaths

    func scanDecls(paths: [String],
                   isDirs: Bool,
                   topDeclsOnly: Bool,
                   pathToModules: [String: String],
                   whitelist: Whitelist?,
                   completion: @Sendable @escaping (String, DeclMap) -> ()) {
        if isDirs {
            scan(dirs: paths) { (path: String, lock: NSLock?) in
                self.visitSrc(path: path,
                              module: pathToModules[path],
                              package: nil,
                              topDeclsOnly: topDeclsOnly,
                              whitelist: whitelist,
                              lock: lock,
                              completion: completion)
            }
        } else {
            scan(paths) { (path: String, lock: NSLock?) in
                self.visitSrc(path: path,
                              module: pathToModules[path],
                              package: nil,
                              topDeclsOnly: topDeclsOnly,
                              whitelist: whitelist,
                              lock: lock,
                              completion: completion)
            }
        }
    }


    func checkRefs(paths: [String],
                   isDirs: Bool,
                   pathToModules: [String: String],
                   declMap: DeclMap,
                   completion: @Sendable @escaping (String, Set<String>, [String]) -> ()) {

        if isDirs {
            scan(dirs: paths) { (path: String, lock: NSLock?) in
                self.referenceSrc(path: path, module: pathToModules[path] ?? "", declMap: declMap, lock: lock, completion: completion)
            }
        } else {
            scan(paths) { (path: String, lock: NSLock?) in
                self.referenceSrc(path: path, module: pathToModules[path] ?? "", declMap: declMap, lock: lock, completion: completion)
            }
        }
    }
}
