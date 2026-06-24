//
//  PdfOverviewCvcCell.swift
//  NorthLib
//
//  Created by Ringo.Mueller on 14.10.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import UIKit

public class PdfOverviewCvcCell : UICollectionViewCell {
  
  public let imageView = UIImageView()
  public let label = UILabel()
  public let dateLabel = UILabel()
  public var imageWidthConstraint: NSLayoutConstraint?
  
  public override func prepareForReuse() {
    self.imageView.image = nil
    self.label.text = nil
    self.dateLabel.text = nil
    imageWidthConstraint?.isActive = false
  }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    /**
     Bugfix after Merge
     set ImageViews BG Color to same color like Collection Views BG fix white layer on focus
     UIColor.clear or UIColor(white: 0, alpha: 0) did not work
     Issue is not in last Build before Merge 0.4.18-2021011501 ...but flickering is there on appearing so its half of the bug
     - was also build with same xcode version/ios sdk
     issue did not disappear if deployment target is set back to 11.4
     */
    imageView.backgroundColor = .black
    imageView.contentMode = .scaleAspectFit
    
    contentView.addSubview(imageView)
    imageWidthConstraint = imageView.pinWidth(10, priority: .required)//placeholder width
    imageWidthConstraint?.isActive = false
    pin(imageView, to: contentView).right.priority = .defaultHigh
    
    label.numberOfLines = 0
    contentView.addSubview(label)
    pin(label.leftGuide(), to: imageView.leftGuide())
    pin(label.rightGuide(), to: contentView.rightGuide())
    //Pin the Label outside of the cell simplifies everything!
    pin(label.topGuide(), to: contentView.bottomGuide(), dist: 5.0)
    
    contentView.addSubview(dateLabel)
    
    pin(dateLabel.leftGuide(), to: imageView.rightGuide(), dist: PdfDisplayOptions.Overview.interItemSpacing)
    pin(dateLabel.topGuide(), to: contentView.topGuide(), dist: -2.0)
    dateLabel.numberOfLines = 2
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}
