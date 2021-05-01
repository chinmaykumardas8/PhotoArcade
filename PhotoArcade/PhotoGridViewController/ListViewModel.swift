//
//  ListViewModel.swift
//  PhotoArchade
//
//  Created by Chinmay Das on 01/05/21.
//

import Foundation
import CoreGraphics
import Photos
import UIKit

protocol ListViewModelInput {
    
    /// Sets the output delegate of view model
    /// - Parameter delegate: output delegate
    func setOutputDelegate(_ delegate: ListViewModelOutput)
    
    /// Input og segment control index change
    /// - Parameter index: New index
    func didChangeSegment(_ index: Int)
    
    /// Request to fetch photos
    func fetchPhotos()
    
    /// Request to remove the image from chache (both thumbnail and original). If the collection is scrolling then remove in a index range.
    /// If visible range is 200 - 220 and scrolling up, remove the image chache for  1-100 index.
    /// if scrolling down remove image chache for 300-400 index.
    /// - Parameters:
    ///   - visibleIndex: Visible index set
    ///   - indexPath: Index path which just diapered.
    func removeImagesFromCache(forVisibleIndex visibleIndex: [IndexPath], currentIndexPath indexPath: IndexPath)
    
    /// Request to fetch new thumbnail image.
    /// If the index is 100 and scrolling up then fetch thumbnail image for 100 - 500 index
    /// if scrolling down fetch image thumbnail for 0-100 index
    /// - Parameters:
    ///   - visibleIndex: Visible index set
    ///   - cellSize: Cell size to prefetch image in that size.
    ///   - indexPath: Index path which need to fetch.
    func fetchNewImages(forVisibleIndex visibleIndex: [IndexPath], cellSize: CGSize, currentIndexPath indexPath: IndexPath)
    
    /// Fetches the better sized image and returns in closure.
    /// - Parameters:
    ///   - indexPath: Index path for which we need to fetch.
    ///   - cellSize: Cell size for which we are fetching the image.
    ///   - fetchedImage: Completion closure with image
    func setImageInCell(forIndexPath indexPath: IndexPath, cellSize: CGSize, fetchedImage: @escaping ((_ assetId: String, _ image: UIImage) -> Void))
}

protocol ListViewModelOutput: class {
    
    /// Reload the collection view.
    func reloadCollection()
    
    /// Update the collection view layout
    func updateCollectionViewLayout()
    
    /// Shows alert
    /// - Parameter message: Shows alert in view
    func showAlert(message: String)
}

protocol ListViewModelProtocol {
    /// Data source model for view model
    var dataSource: PhotoDataSourceProtocol { get }
    /// inputs
    var inputs: ListViewModelInput { get }
    /// output
    var output: ListViewModelOutput? { get }
}

final class ListViewModel: ListViewModelProtocol, ListViewModelInput {
    /// :nodoc:
    var inputs: ListViewModelInput { self }
    /// :nodoc:
    var output: ListViewModelOutput? {
        return delegate
    }
    
    /// :nodoc:
    var dataSource: PhotoDataSourceProtocol
    
    /// Image fetcher which also cache the image for use.
    private var fetcher: ImageFetcher?
    
    /// Batch fetching queue
    var batchArray: Queue<(indexToStart: Int, indexToEnd: Int)> = .init()
    
    /// Init the view model with datasource
    /// - Parameter dataSource: Datasource model
    init(withData dataSource: PhotoDataSourceProtocol) {
        self.dataSource = dataSource
        getAuth()
    }
    
    // MARK: - INPUT
    /// :nodoc:
    func setOutputDelegate(_ delegate: ListViewModelOutput) {
        self.delegate = delegate
    }
    
    /// :nodoc:
    func didChangeSegment(_ index: Int) {
        removeAllHighResolutionImage()
        output?.updateCollectionViewLayout()
    }
    
    /// :nodoc:
    func fetchPhotos() {
        guard PHPhotoLibrary.authorizationStatus() == .authorized else {
            self.showPhotoAuthAlert()
            return
        }
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let allPhotos = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        var allModel: [String: PhotoModelProtocol] = [:]
        var allKeys: [String] = []
        allPhotos.enumerateObjects { (asset, _, _) in
            let model = PhotoModel(asset: asset, image: nil)
            allKeys.append(asset.localIdentifier)
            allModel[asset.localIdentifier] = model
        }
        fetcher = ImageFetcher(size: allModel.count)
        dataSource.setDataSource(newData: allModel, keyList: allKeys)
        output?.reloadCollection()
    }
    
    /// :nodoc:
    func removeImagesFromCache(forVisibleIndex visibleIndex: [IndexPath], currentIndexPath indexPath: IndexPath) {
        guard let asset = dataSource[indexPath.item]?.asset else { return }
        fetcher?.cancelRequestForAsset(asset)
        let currentDisplayingIndex = visibleIndex.sorted()
        var isLast: Bool?
        guard let lastItem = currentDisplayingIndex.last?.item else { return }
        guard let firstItem = currentDisplayingIndex.first?.item else { return }
        if indexPath.item < firstItem {
            isLast = false
        } else if indexPath.item > lastItem {
            isLast = true
        }
        
        guard let last = isLast else { return }

        if last {
            let indexWeAreLooking = indexPath.item + 1000
            if indexWeAreLooking < dataSource.count, let imageAsset = dataSource[indexWeAreLooking]?.asset {
                fetcher?.removeImageForAsset(imageAsset)
            }
            
            let highIndexWeAreLooking = indexPath.item + 20
            if highIndexWeAreLooking < dataSource.count, let imageAsset = dataSource[highIndexWeAreLooking]?.asset {
                fetcher?.removeHighImageForAsset(imageAsset)
            }
        } else {
            let indexWeAreLooking = indexPath.item - 1000
            if indexWeAreLooking > 0, let imageAsset = dataSource[indexWeAreLooking]?.asset {
                fetcher?.removeImageForAsset(imageAsset)
            }
            
            let highIndexWeAreLooking = indexPath.item - 20
            if highIndexWeAreLooking > 0, let imageAsset = dataSource[highIndexWeAreLooking]?.asset {
                fetcher?.removeHighImageForAsset(imageAsset)
            }
        }
    }
    
    /// :nodoc:
    func fetchNewImages(forVisibleIndex visibleIndex: [IndexPath], cellSize: CGSize, currentIndexPath indexPath: IndexPath) {
        let currentDisplayingIndex = visibleIndex.sorted()
        var isLast: Bool?
        guard let lastItem = currentDisplayingIndex.last?.item else { return }
        guard let firstItem = currentDisplayingIndex.first?.item else { return }
        if indexPath.item < firstItem{
            isLast = false
        } else if indexPath.item > lastItem{
            isLast = true
        }
        guard let last = isLast else { return }
        if last {
            let indexWeAreLooking = min(indexPath.item + 1000, dataSource.count - 1)
            fetchBatchImage(allAssets: dataSource, indexToStart: indexPath.item, indexToEnd: indexWeAreLooking)
        } else {
            let indexWeAreLooking = max(indexPath.item - 1000, 0)
            fetchBatchImage(allAssets: dataSource, indexToStart: indexWeAreLooking, indexToEnd: indexPath.item)
        }
    }
    
    /// :nodoc:
    func setImageInCell(forIndexPath indexPath: IndexPath, cellSize: CGSize, fetchedImage: @escaping ((_ assetId: String, _ image: UIImage) -> Void)) {
        guard let asset = dataSource[indexPath.item]?.asset else { return }
        if let image = fetcher?.highImageFor(key: asset.localIdentifier) {
            fetchedImage(asset.localIdentifier, image)
        } else {
            if let imageExisting = fetcher?.thumbnailImageFor(key: asset.localIdentifier) {
                fetchedImage(asset.localIdentifier, imageExisting)
            }
            let minSide = min(asset.pixelWidth, asset.pixelHeight)
            let maxSide = max(asset.pixelWidth, asset.pixelHeight)
            let minCellSide = min(cellSize.height, cellSize.width)
            let scaleDownFactor = (CGFloat(minSide) / minCellSide)
            let newSide = CGFloat(maxSide) / scaleDownFactor
            
            fetcher?.fetchHighImageFor(asset, size: CGSize(width: newSide, height: newSide), completion: { image in
                guard let imageObj = image else { return }
                fetchedImage(asset.localIdentifier, imageObj)
            })
        }
    }
    
    // MARK: - Helpers
    weak private var delegate: ListViewModelOutput?
    
    /// Requests for authentication for photo library
    private func getAuth() {
        guard PHPhotoLibrary.authorizationStatus() != .authorized else {
          return
        }
        
        PHPhotoLibrary.requestAuthorization { [weak self] (status) in
            switch status {
            case .authorized:
                self?.fetchPhotos()
            default:
                self?.showPhotoAuthAlert()
            }
        }
    }
    
    /// Shows alert to allow PhotoArcade to read all photos
    private func showPhotoAuthAlert() {
        self.output?.showAlert(message: "Please allow to read all photos, please go to setting to allow.")
    }
    
    /// Fetches the thumbnail images and stores in fetcher. In a index range.
    /// - Parameters:
    ///   - allAssets: Datasource model which have the data.
    ///   - indexToStart: Starting index to fetch
    ///   - indexToEnd: End index to fetch
    ///   - appendInQueue: Should appned in queue or not. If it is a recursive call no need to add to queue.
    private func fetchBatchImage(allAssets: PhotoDataSourceProtocol, indexToStart: Int, indexToEnd: Int, appendInQueue: Bool = true) {
//        print("Request batch: \(indexToStart) ... \(indexToEnd)")
        if appendInQueue {
            batchArray.enqueue(data: (indexToStart, indexToEnd))
        }
        let count = 0
        let batch = 50
        fetchBatchSize(count: count, allAssets: allAssets, batch: batch, indexToStart: indexToStart, indexToEnd: indexToEnd) { [weak self] (count) in
            if let operationObj = self?.batchArray.dequeue() {
                self?.fetchBatchImage(allAssets: allAssets, indexToStart: operationObj.indexToStart, indexToEnd: operationObj.indexToEnd, appendInQueue: false)
            } else {
//                print("Batch completed: \(indexToStart) ... \(indexToEnd)")
            }
        }
    }
    
    /// Fetch recursively  and fetchh all image in batch.
    /// - Parameters:
    ///   - count: Total fetched count
    ///   - allAssets: Datasource model
    ///   - batch: Batch  size
    ///   - indexToStart: Starting index
    ///   - indexToEnd: Ending index
    ///   - completion: completion call only if all images fetched in the index range.
    private func fetchBatchSize(count: Int, allAssets: PhotoDataSourceProtocol, batch: Int, indexToStart: Int, indexToEnd: Int, completion: @escaping ((_ count: Int) -> Void)) {
        let dispatchGroup = DispatchGroup()
        
        let to =  min((indexToEnd - indexToStart) - count, batch)
        for index in 0..<to {
            if let asset = allAssets[indexToStart + count + index]?.asset {
                if fetcher?.thumbnailImageFor(key: asset.localIdentifier) != nil {
                    continue
                }
                dispatchGroup.enter()
                fetcher?.fetchImageFor(asset) {
                    dispatchGroup.leave()
                }
            }
        }
        dispatchGroup.notify(queue: .global()) { [weak self] in
            let newCount = count + to
            if to != 0 {
                self?.fetchBatchSize(count: newCount, allAssets: allAssets, batch: batch, indexToStart: indexToStart, indexToEnd: indexToEnd, completion: completion)
            } else {
                completion(newCount)
            }
        }
    }
    
    /// Remove all high resolution images
    private func removeAllHighResolutionImage() {
        for i in 0..<dataSource.count where dataSource[i] != nil {
            fetcher?.removeHighImageForAsset(dataSource[i]!.asset)
        }
    }
}
