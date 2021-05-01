//
//  PhotoCell.swift
//  PhotoArcade
//
//  Created by Chinmay Das on 01/05/21.
//

import UIKit

final class PhotoCell: UICollectionViewCell {
    var assetId: String = ""
    @IBOutlet private var imageView: UIImageView!
    override func prepareForReuse() {
        super.prepareForReuse()
        self.imageView.image = nil
        assetId = ""
    }
    
    func setImage(_ image: UIImage) {
        self.imageView.image = image
    }
}
