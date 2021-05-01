//
//  ImageFetcher.swift
//  PhotoArchade
//
//  Created by Chinmay Das on 01/05/21.
//

import Foundation
import Photos
import UIKit

final class ImageFetcher {
    private let manager = PHImageManager.default()
    private let readWrite: ThreadSafeReaderWrite = .init(queueId: "com.fetchQueue.queue")
    private var thumbnailImageCache: [String: UIImage] = [:]
    private var thumbnailRequests: [String: PHImageRequestID] = [:]
    
    private var highImageCatch: [String: UIImage] = [:]
    private var highImagerequests: [String: PHImageRequestID] = [:]
       
    init(size: Int) {
        thumbnailImageCache.reserveCapacity(size)
        thumbnailRequests.reserveCapacity(size)
    }
    
    /// Fetches images for asset and adds into dictionary as a cache.
    /// - Parameters:
    ///   - asset: Asset to fetch image
    ///   - completion: completion of fetching image.
    func fetchImageFor(_ asset: PHAsset, completion: (() -> Void)? = nil) {

        guard thumbnailRequestFor(key: asset.localIdentifier) == nil else { return }
        guard thumbnailImageFor(key: asset.localIdentifier) == nil else { return }
        let ratio: CGFloat = CGFloat(asset.pixelHeight) / CGFloat(asset.pixelWidth)
        let size = CGSize(width: 50, height: 50 * ratio)
        let newRequest = FetchHelper.fetchPhotoFromAsset(manager: manager, asset: asset, size: size) { [weak self] (image) in
            if let image = image {
                self?.readWrite.exclusivelyWrite { [weak self] in
                    self?.thumbnailImageCache[asset.localIdentifier] = image
                }
            }
            self?.readWrite.exclusivelyWrite { [weak self] in
                self?.thumbnailRequests[asset.localIdentifier] = nil
            }
            completion?()
        }
        readWrite.exclusivelyWrite { [weak self] in
            self?.thumbnailRequests[asset.localIdentifier] = newRequest
        }
    }
    
    /// Fetches image in high resolution and caches the image in dict.
    /// - Parameters:
    ///   - asset: Asset to fetch image in high quality
    ///   - size: Size of image view for which image will get fetched.
    ///   - completion: Completion of fetching image.
    func fetchHighImageFor(_ asset: PHAsset, size: CGSize, completion: ((_ image: UIImage?) -> Void)? = nil) {

        guard highRequestFor(key: asset.localIdentifier) == nil else { return }
        guard highImageFor(key: asset.localIdentifier) == nil else { return }

        let newRequest = FetchHelper.fetchPhotoFromAsset(manager: manager, asset: asset, size: size, deliveryMode: .highQualityFormat) { [weak self] (image) in
            if let image = image {
                self?.readWrite.exclusivelyWrite { [weak self] in
                    self?.highImageCatch[asset.localIdentifier] = image
                }
            }
            self?.readWrite.exclusivelyWrite { [weak self] in
                self?.highImagerequests[asset.localIdentifier] = nil
            }
            completion?(image)
        }
        readWrite.exclusivelyWrite { [weak self] in
            self?.highImagerequests[asset.localIdentifier] = newRequest
        }
    }
    
    /// Thread safe read of thumbnailImageCache
    /// - Parameter key: Asset local identifire
    /// - Returns: Image for the identifire
    func thumbnailImageFor(key: String) -> UIImage? {
        return readWrite.concurrentlyRead { () -> UIImage? in
            return thumbnailImageCache[key]
        }
    }
    
    /// Thread safe read of high quality ImageCache
    /// - Parameter key: Asset local identifire
    /// - Returns: Image for the identifire
    func highImageFor(key: String) -> UIImage? {
        return readWrite.concurrentlyRead { () -> UIImage? in
            return highImageCatch[key]
        }
    }
    
    /// Thread safe read of photo requests for thumbnail image
    /// - Parameter key: Asset local identifire
    /// - Returns: Image request id
    func thumbnailRequestFor(key: String) -> PHImageRequestID? {
        return readWrite.concurrentlyRead { () -> PHImageRequestID? in
            return thumbnailRequests[key]
        }
    }
    
    /// Thread safe read of photo requests for high quality image
    /// - Parameter key: Asset local identifire
    /// - Returns: Image request id
    func highRequestFor(key: String) -> PHImageRequestID? {
        return readWrite.concurrentlyRead { () -> PHImageRequestID? in
            return highImagerequests[key]
        }
    }
    
    /// Cancel requests of high quality image for asset
    /// - Parameter asset: asset for which it need to be removed
    func cancelRequestForAsset(_ asset: PHAsset) {
        guard let requestId = highRequestFor(key: asset.localIdentifier) else { return }
        manager.cancelImageRequest(requestId)
        readWrite.exclusivelyWrite {
            self.highImagerequests[asset.localIdentifier] = nil
        }
    }
    
    /// Thread safe remove thumbnail image from from cache
    /// - Parameter asset: asset for which it need to be removed
    func removeImageForAsset(_ asset: PHAsset) {
        if thumbnailImageFor(key: asset.localIdentifier) != nil {
            readWrite.exclusivelyWrite {
                self.thumbnailImageCache[asset.localIdentifier] = nil
            }
        }
    }
    
    /// Thread safe remove high size image from from cache
    /// - Parameter asset: asset for which it need to be removed
    func removeHighImageForAsset(_ asset: PHAsset) {
        if highImageFor(key: asset.localIdentifier) != nil {
            readWrite.exclusivelyWrite {
                self.highImageCatch[asset.localIdentifier] = nil
            }
        }
    }
}
