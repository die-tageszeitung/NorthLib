//
//  VCTable.swift
//  NorthLibTest
//
//  Created by Norbert Thies on 01.03.22.
//

import UIKit

/// A ptotocol used by VCTable to show a view controller
public protocol VCTableDelegate {
  func showVC(vc: VCDescription) 
}

/// By default a view controller is pushed onto the navigation stack
public extension VCTableDelegate where Self: UIViewController {
  func showVC(vc: VCDescription)  {
    self.navigationController?.pushViewController(vc, animated: true)
  }
}

/// A view controller description
public protocol VCDescription where Self: UIViewController {
  /// Name/Title of view controller
  static var title: String { get }
  /// Description of view controller
  static var description: String { get }
  /// Keep alive after instantiation
  static var keepAlive: Bool { get }
  /// Immediately instantiate VC after adding to the table
  static var immediateStart: Bool { get }
  /// Screenshot to show in table
  static var screenshot: UIImage? { get }
  /// Title for navigation bar
  var title: String? { get set }
}

public extension VCDescription {
  static var title: String { "\(self)" }
  static var description: String { "" }
  static var keepAlive: Bool { false }
  static var immediateStart: Bool { false }
  static var screenshot: UIImage? { UIImage(named: "\(self)") }
}

open class VCCell: UITableViewCell {
  override public init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
    detailTextLabel?.numberOfLines = 2
    detailTextLabel?.adjustsFontSizeToFitWidth = true
  }
  required public init?(coder: NSCoder) { super.init(coder: coder) }
}

open class VCTable: UIViewController, UITableViewDelegate, 
                    UITableViewDataSource, VCTableDelegate {
  public class VC {
    var vcd: VCDescription.Type
    var vc: VCDescription?
    init(vcd: VCDescription.Type, vc: VCDescription? = nil) 
      { self.vcd = vcd; self.vc = vc }
  }
  
  /// Optional title to display in front of the single section
  public var header: String?
  
  /// Array of view controller descriptions
  public var vcDescriptions: [VC] = []
  
  /// Table of view controllers
  public var vcTable: UITableView!
  
  /// Currently selected (running) VC
  private(set) var selected: Int? = nil
  public var vc: UIViewController? { 
    guard let i = selected else { return nil }
    return vcDescriptions[i].vc
  }
  
  /// Has vcTable been initialized
  private var wasInitialized = false
  
  /// Start view controller
  private func start(vcd: VC) {
    var vc: VCDescription
    if vcd.vc != nil { vc = vcd.vc! }
    else { vc = vcd.vcd.init(nibName: nil, bundle: nil) }
    vcd.vc = vc
    vc.title = vcd.vcd.title
  }

  /// Add a view controller to the table
  public func add(vcd: VCDescription.Type) {
    let vc = VC(vcd: vcd)
    vcDescriptions += vc
    if vcd.immediateStart { start(vcd: vc) } 
    if wasInitialized {
      let row = vcDescriptions.count - 1
      let ipath = IndexPath(row: row, section: 0)
      vcTable.insertRows(at: [ipath], with: .fade)
    }
  }
  
  /// Currently displaying menu?
  private var inMenu = false
  
  /// Delegate showing view controllers
  public var delegate: VCTableDelegate!
  
  /// Initialize with optional delegate
  public init(delegate: VCTableDelegate? = nil) {
    self.delegate = delegate
    super.init(nibName: nil, bundle: nil)
    if delegate == nil { self.delegate = self }
  }
  
  required public init?(coder: NSCoder) {
    super.init(coder: coder)
  }
  
  /// Produce screenshot of currently visible VC
  /// Attention: Info.plist must contain a String entry for
  ///            "Privacy - Photo Library Additions Usage Description"
  func makeScreenshot() {
    if let vc = self.vc {
      if let img = vc.view.snapshot {
        UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil)
      }
    }
  }
  
  /// Display 2-finger menu
  @objc func displayMenue() {
    if !inMenu {
      let actions: [UIAlertAction] = [
        Alert.action("Screenshot") { [weak self] _ in self?.makeScreenshot() },
      ]
      self.inMenu = true
      Alert.actionSheet(title: "VCTable", actions: actions) { [weak self] in
        self?.inMenu = false
      }
    }
  }
  
  /// Enable 2-finger long touch to display menu
  func enableMenu() {
    let recog = UILongPressGestureRecognizer(target: self,
        action: #selector(displayMenue))
    recog.numberOfTouchesRequired = 2
    let win = UIWindow.keyWindow
    win?.isUserInteractionEnabled = true
    win?.addGestureRecognizer(recog)
  }
  
  /// Destruct previously created VC
  func destructVC() {
    if let selected = selected {
      let vcd = vcDescriptions[selected]
      if !vcd.vcd.keepAlive { vcd.vc = nil }
      let indexPath = IndexPath(row: selected, section: 0)
      vcTable.deselectRow(at: indexPath, animated: false)
      self.selected = nil
    }
  }
  
  /// Destruct previously created VC in case of single VC on window
  override open func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    self.navigationController?.setNavigationBarHidden(true, animated: false)
  }
  
  /// Create table view and pin it to the safe margins
  override open func viewDidLoad() {
    super.viewDidLoad()
    self.title = "VCTable"
    vcTable = UITableView(frame: CGRect.zero, style: .plain)
    self.view.addSubview(vcTable)
    pin(vcTable, toSafe: self.view)
    vcTable.separatorStyle = .singleLine
    vcTable.sectionHeaderHeight = 60
    vcTable.dataSource = self
    vcTable.delegate = self
    vcTable.allowsSelection = true
    vcTable.allowsMultipleSelection = false
    vcTable.register(VCCell.self, forCellReuseIdentifier: "VCCell")
    enableMenu()
  }
  
  /// Enable navigation bar on pushed VCs
  override open func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    self.navigationController?.setNavigationBarHidden(false, animated: false)
  }
  
  // MARK: - UITableViewDataSource methods
  
  public func numberOfSections(in tableView: UITableView) -> Int { 1 }
  
  public func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    self.header
  }
  
  public func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
    if let view = view as? UITableViewHeaderFooterView {
      view.textLabel?.textColor = UIColor.black
      view.textLabel?.font = UIFont.systemFont(ofSize: 20, weight: .bold)
    }
  }
  
  public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    vcDescriptions.count
  }
  
  public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    if let cell = tableView.dequeueReusableCell(withIdentifier: "VCCell", 
      for: indexPath) as? VCCell {
      let vcd = vcDescriptions[indexPath.row].vcd
      cell.textLabel!.text = vcd.title
      cell.detailTextLabel!.text = vcd.description
      cell.imageView!.image = vcd.screenshot
      cell.accessoryType = .disclosureIndicator
      wasInitialized = true
      return cell
    }
    return UITableViewCell()
  }
  
  // MARK: - UITableViewDelegate methods
  
  public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    // destruct previously created VC
    destructVC()
    self.selected = indexPath.row
    let vcd = vcDescriptions[self.selected!]
    start(vcd: vcd)
    if let vc = vcd.vc { self.delegate.showVC(vc: vc) }
  }
  
}
