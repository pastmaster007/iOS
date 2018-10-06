//
//  PDFHelper.swift
//  Core
//
//  Created by Christopher Brind on 06/10/2018.
//  Copyright © 2018 DuckDuckGo. All rights reserved.
//

import Foundation
import Alamofire

public class PDFHelper {

    let url: URL
    var dataRequest: DataRequest?

    public init(url: URL) {
        self.url = url
    }

    public func cancel() {
        dataRequest?.cancel()
        let path = buildPath()
        try? FileManager.default.removeItem(at: path.file)
    }

    public func load() -> Data? {
        let path = buildPath()
        let fileUrl = URL(fileURLWithPath: path.file.absoluteString)
        guard let data = try? Data(contentsOf: fileUrl) else { return Data() }
        return data
    }

    private func buildPath() -> (dir: URL, file: URL) {
        let dirPath = URL(string: NSTemporaryDirectory())!.appendingPathComponent("pdfs")
        let filePath = dirPath.appendingPathComponent(url.lastPathComponent)
        return (dirPath, filePath)
    }

    func download(_ urlRequest: URLRequest,
                  progressHandler: @escaping ((Double) -> Void),
                  completionHandler: @escaping ((Data?) -> Void)) {

        dataRequest = Alamofire.request(urlRequest)

        dataRequest?.downloadProgress { progress in
            progressHandler(progress.fractionCompleted)
        }

        dataRequest?.response { [weak self] response in
            guard let data = response.data else {
                completionHandler(nil)
                return
            }
            self?.persist(data: data)
            completionHandler(data)
        }

    }

    private func persist(data: Data) {
        let path = buildPath()
        let fileManager = FileManager.default
        do {
            try fileManager.createDirectory(atPath: path.dir.absoluteString, withIntermediateDirectories: true, attributes: nil)
            _ = fileManager.createFile(atPath: path.file.absoluteString, contents: data, attributes: nil)
        } catch {
            fatalError(error.localizedDescription)
        }
    }

}
