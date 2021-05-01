//
//  FetchHelper.swift
//  PhotoArchade
//
//  Created by Chinmay Das on 01/05/21.
//

import Foundation
import UIKit
import Photos

final class FetchHelper {
    static func fetchPhotoFromAsset(
        manager: PHImageManager = PHImageManager.default(),
        asset: PHAsset,
        size: CGSize,
        isSyncronous: Bool = false,
        deliveryMode: PHImageRequestOptionsDeliveryMode = .fastFormat,
        resizeMode: PHImageRequestOptionsResizeMode = .fast,
        completion: @escaping ((_ image: UIImage?) -> Void)
    ) -> PHImageRequestID {
        let manager = manager
        let requestOptions = PHImageRequestOptions()
        requestOptions.isSynchronous = isSyncronous
        requestOptions.deliveryMode = deliveryMode
        requestOptions.resizeMode = resizeMode
        return manager.requestImage(
            for: asset,
            targetSize: size,
            contentMode: .aspectFill,
            options: requestOptions
        ) { (imageFetched, _) in
            completion(imageFetched)
        }
    }
    
    static func downsample(imageAt imageData: Data, to pointSize: CGSize, scale: CGFloat) -> UIImage {
        let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        let imageSource = CGImageSourceCreateWithData(imageData as CFData, imageSourceOptions)!
      
        let maxDimentionInPixels = max(pointSize.width, pointSize.height) * scale
      
        let downsampledOptions = [kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceShouldCacheImmediately: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceThumbnailMaxPixelSize: maxDimentionInPixels] as CFDictionary
       let downsampledImage =     CGImageSourceCreateThumbnailAtIndex(imageSource, 0, downsampledOptions)!
      
        return UIImage(cgImage: downsampledImage)
     }
}

final class ThreadSafeReaderWrite {
    let queueId: String
    init(queueId: String) {
        self.queueId = queueId
        self.queue = DispatchQueue(label: queueId, attributes: .concurrent)
    }
    
    private let queue: DispatchQueue
    
    public func concurrentlyRead<T>(_ block: (() throws -> T)) rethrows -> T {
        return try queue.sync {
            try block()
        }
    }
    
    public func exclusivelyWrite(_ block: @escaping (() -> Void)) {
        queue.async(flags: .barrier) {
            block()
        }
    }
}

protocol QueueProtocol {
    associatedtype Data
    func enqueue(data: Self.Data)
    func dequeue() -> Self.Data?
}

final class Queue<T>: QueueProtocol {
    var list: [T] = []
    var readWrite: ThreadSafeReaderWrite = .init(queueId: "com.PhotoArcade.queue")
    
    func enqueue(data: T) {
        readWrite.exclusivelyWrite { [weak self] in
            self?.list.append(data)
        }
    }
    
    private func getPeakData() -> T? {
        return readWrite.concurrentlyRead { () -> T? in
            return list.first
        }
    }
    
    func dequeue() -> T? {
        if let peakData = getPeakData() {
            readWrite.exclusivelyWrite { [weak self] in
                self?.list.remove(at: 0)
            }
            return peakData
        }
        return nil
    }
}



