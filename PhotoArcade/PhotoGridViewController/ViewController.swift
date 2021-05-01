//
//  ViewController.swift
//  PhotoArchade
//
//  Created by Chinmay Das on 01/05/21.
//

import UIKit
import Photos
import GDPerformanceView_Swift

enum TileSize: Int {
    case small = 0
    case medium
    case large
    
    func getDivision() -> Int {
        switch self {
        case .small:
            return 4
        case .medium:
            return 3
        case .large:
            return 1
        }
    }
}

final class ViewController: UIViewController {
    
    /// Monitor performance
    var performanceView = PerformanceMonitor()
    
    /// Collection view
    @IBOutlet private var collectionView: UICollectionView!
    
    /// Segment controll
    @IBOutlet private var segment: UISegmentedControl!
    
    /// View model
    let viewModel: ListViewModelProtocol = ListViewModel(withData: PhotoDataSource())
        
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        setupCell()
        collectionView.dataSource = viewModel.dataSource
        viewModel.inputs.setOutputDelegate(self)
        viewModel.inputs.fetchPhotos()

        performanceView.delegate = self
        performanceView.start()
    }
    
    /// Configure cell
    func setupCell() {
        viewModel.dataSource.setUpCollectionViewCell = { [weak self] (model, indexPath) in
            guard let cell = self?.collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as? PhotoCell else {
                fatalError()
            }
            cell.assetId = model?.asset.localIdentifier ?? ""
            return cell
        }
    }
    
    /// Segment change action
    @IBAction func changeSegment(segment: UISegmentedControl) {
        viewModel.inputs.didChangeSegment(segment.selectedSegmentIndex)
    }
}

extension ViewController: UICollectionViewDelegateFlowLayout {
    
    /// :nodoc:
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return getCollectionCellSize(indexPath: indexPath)
    }
    
    /// Gets collection cell size for index
    /// - Parameter indexPath: Indexpath
    /// - Returns: Size for cell
    func getCollectionCellSize(indexPath: IndexPath) -> CGSize {

        guard let tileType = TileSize(rawValue: segment.selectedSegmentIndex) else { return . zero}
        let size = collectionView.bounds.size.width / CGFloat(tileType.getDivision())
        let width = size
        var height = size
        if tileType == .large, let asset = viewModel.dataSource[indexPath.item]?.asset {
            height = size * (CGFloat(asset.pixelHeight) / CGFloat(asset.pixelWidth))
        }
        return CGSize(width: width, height: height)
    }
}

extension ViewController: UICollectionViewDataSourcePrefetching {
    
    /// :nodoc:
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        if let index = indexPaths.first {
            viewModel.inputs.fetchNewImages(forVisibleIndex: collectionView.indexPathsForVisibleItems, cellSize: getCollectionCellSize(indexPath: index), currentIndexPath: index)
        }
    }
}

extension ViewController: UICollectionViewDelegate {
    
    /// :nodoc:
    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        viewModel.inputs.removeImagesFromCache(forVisibleIndex: collectionView.indexPathsForVisibleItems, currentIndexPath: indexPath)
    }
    
    /// :nodoc:
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        viewModel.inputs.setImageInCell(forIndexPath: indexPath, cellSize: cell.bounds.size) { (assetId, image) in
            if (cell as? PhotoCell)?.assetId == assetId {
                (cell as? PhotoCell)?.setImage(image)
            }
        }
    }
}

extension ViewController: ListViewModelOutput {
    
    /// :nodoc:
    func reloadCollection() {
        DispatchQueue.main.async { [weak self] in
            self?.collectionView.reloadData()
        }
    }
    
    // :nodoc:
    func updateCollectionViewLayout() {
        DispatchQueue.main.async { [weak self] in
            let layout = UICollectionViewFlowLayout()
            layout.minimumLineSpacing = 0
            layout.minimumInteritemSpacing = 0
            self?.collectionView.setCollectionViewLayout(layout, animated: true) { (completed) in
                if completed {
                    guard let visibleIndex = self?.collectionView.indexPathsForVisibleItems else { return }
                    self?.collectionView.reloadItems(at: visibleIndex)
                }
            }
        }
    }
}

extension ViewController: PerformanceMonitorDelegate {
    func performanceMonitor(didReport performanceReport: PerformanceReport) {
//        print(performanceReport.fps)
    }
}

