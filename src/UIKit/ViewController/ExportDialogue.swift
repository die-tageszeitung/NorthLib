//
//  ExportDialogue.swift
//
//  Created by Norbert Thies on 02.05.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import UIKit
import LinkPresentation

open class ExportDialogue<T>: NSObject, UIActivityItemSource {

  /// The item to export
  var item: T?
  /// The alternate text for Twitter etc.
  var altText: String?
  /// A String describing the item (ie used as Subject in eMails
  var subject: String?
  /// A Image for share dialogue
  var image: UIImage?
  /// Link to share
  var onlineLink: String?

  
  public func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
    if let item = item { return item }
    else { return "Error" }
  }
  
  public func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
    let metadata = LPLinkMetadata()
    metadata.title = subject
    
    if let img = image {
      metadata.iconProvider = NSItemProvider(object: img)
    }
    
    if let s = item as? String {
      metadata.originalURL = URL(string: s)
    }
    else if let onlineLink = onlineLink {
      metadata.originalURL = URL(string: onlineLink)
    }
    else if let altText = altText {
      metadata.originalURL = URL(fileURLWithPath: altText)
    }
    else {
      metadata.originalURL = URL(string: "Dokument teilen")
    }
    
    return metadata
  }
  
  
  public func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
    if activityType == OpenInSafari.OpenInSafariActivity, let link = self.onlineLink {
      return URL(string: link)
    }
    else if let item = item {
      if let activityType = activityType,
         let altText = altText {
        switch activityType {
          case .addToReadingList, .postToFacebook, .postToWeibo,
               .postToVimeo, .postToFlickr, .postToTwitter,
               .postToTencentWeibo: return altText
          default: return item
        }
      }
      else { return item }
    }
    else { return "Error" }
  }
  
  public func activityViewController(_ activityViewController: UIActivityViewController, subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
    if let str = subject { return str }
    else { return "" }
  }
  
  /// Create export dialogue
  public func present(item: T, altText: String?, onlineLink: String?, view: UIView? = nil,
                      subject: String? = nil, image: UIImage? = nil) {
    let customItem = OpenInSafari(title: "In Safari öffnen",
                                  image: UIImage(systemName: "safari")  ) { sharedItems in
      guard let url = sharedItems[0] as? URL else { return }
      UIApplication.shared.open(url)
    }
    self.item = item
    self.altText = altText
    self.onlineLink = onlineLink
    self.subject = subject
    self.image = image
    let additionalItems = onlineLink != nil ? [customItem] : []
    let aController = UIActivityViewController(activityItems: [self],
      applicationActivities: additionalItems)
    aController.presentAt(view)
  }
  
  /// Create export dialogue
  public func present(item: T, view: UIView? = nil, subject: String? = nil, onlineLink: String? = nil) {
    present(item: item, altText: nil, onlineLink: onlineLink, view: view, subject: subject)
  }

} // ExportDialogue

fileprivate class OpenInSafari: UIActivity {
  
  static var OpenInSafariActivity:UIActivity.ActivityType = UIActivity.ActivityType(rawValue: "de.taz.open.in.safari")
  
  var _activityTitle: String
  var _activityImage: UIImage?
  var activityItems = [Any]()
  var action: ([Any]) -> Void
  
  init(title: String, image: UIImage?, performAction: @escaping ([Any]) -> Void) {
    _activityTitle = title
    _activityImage = image
    action = performAction
    super.init()
  }
  override var activityTitle: String? {
    return _activityTitle
  }
  
  override var activityImage: UIImage? {
    return _activityImage
  }
  override var activityType: UIActivity.ActivityType {
    return OpenInSafari.OpenInSafariActivity
  }
  
  override class var activityCategory: UIActivity.Category {
    return .action
  }
  override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
    return true
  }
  override func prepare(withActivityItems activityItems: [Any]) {
    self.activityItems = activityItems
  }
  override func perform() {
    action(activityItems)
    activityDidFinish(true)
  }
}
