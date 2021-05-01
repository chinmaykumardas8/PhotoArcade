//
//  PhotoDataSource.swift
//  PhotoArcade
//
//  Created by Chinmay Das on 01/05/21.
//

import Foundation
import UIKit

protocol PhotoDataSourceProtocol: UICollectionViewDataSource {
    
    /// Setup collection cell from view
    var setUpCollectionViewCell: ((_ model: PhotoModelProtocol?, _ indexPath: IndexPath) -> UICollectionViewCell)? { get set }
    
    /// Set data source values
    /// - Parameters:
    ///   - newData: View data to replace the current data
    ///   - keyList: All keys in the new data to
    func setDataSource(newData: [String: PhotoModelProtocol], keyList: [String])
    
    /// Update data source for a new value
    /// - Parameters:
    ///   - newData: New value
    ///   - id: identifire for which the new value will chaNGE
    func updateDataSource(newData: PhotoModelProtocol, forId id: String)
    
    /// Count of all values in the data source
    var count: Int { get }
    
    /// Get value for index
    subscript (_ index: Int) -> PhotoModelProtocol? { get }
    /// Get value for key
    subscript (_ key: String) -> PhotoModelProtocol? { get }
}

class PhotoDataSource: NSObject, PhotoDataSourceProtocol {
    private var keyList: [String] = []
    private var dataSource: [String: PhotoModelProtocol] = [:]
    
    var setUpCollectionViewCell: ((PhotoModelProtocol?, IndexPath) -> UICollectionViewCell)?
    var count: Int { keyList.count }
    
    /// :nodoc:
    func setDataSource(newData: [String: PhotoModelProtocol], keyList: [String]) {
        dataSource = newData
        self.keyList = keyList
    }
    
    /// :nodoc:
    func updateDataSource(newData: PhotoModelProtocol, forId id: String) {
        dataSource[id] = newData
    }
    
    /// :nodoc:
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return dataSource.count
    }
    
    /// :nodoc:
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if let cell = setUpCollectionViewCell?(self[indexPath.item], indexPath) {
            return cell
        } else {
            fatalError()
        }
    }
    
    /// :nodoc:
    subscript(_ index: Int) -> PhotoModelProtocol? {
        if let data = dataSource[keyList[index]] {
            return data
        }
        return nil
    }
    
    /// :nodoc:
    subscript(_ key: String) -> PhotoModelProtocol? {
        if let data = dataSource[key] {
            return data
        }
        return nil
    }
}
