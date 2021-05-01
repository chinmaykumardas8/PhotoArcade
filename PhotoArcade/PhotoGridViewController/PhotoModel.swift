//
//  PhotoModel.swift
//  PhotoArcade
//
//  Created by Chinmay Das on 01/05/21.
//

import Foundation
import Photos
import UIKit

protocol PhotoModelProtocol {
    var localId: String { get }
    var asset: PHAsset { get }
    var image: UIImage? { get }
}

class PhotoModel: PhotoModelProtocol {
    var localId: String {
        asset.localIdentifier
    }
    var asset: PHAsset
    var image: UIImage?
    
    init(asset: PHAsset, image: UIImage?) {
        self.asset = asset
        self.image = image
    }
}
