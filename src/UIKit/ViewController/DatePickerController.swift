//
//  DatePickerController.swift
//  NorthLib
//
//  Created by Ringo on 23.09.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import Foundation
import UIKit


/// A component to select a date between min and maximum with 3 wheels (day, month, year),
/// wich also fixes wond dates e.g. 31.2. which never exists
/// @see: note also the git history to see changes made for selection with day or not
open class DatePickerController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource {
  
  public var doneHandler: (() -> ())?
  var initialSelectedDate : Date?
  public var pickerFont : UIFont?
  public var isMonthly = false
  
  public var selectedDate : Date {
    get {
      let selected = _selectedDate
      if selected > data.maximumDate { return data.maximumDate }
      if selected < data.minimumDate { return data.minimumDate }
      return selected
    }
  }
  
  /// generates Date from picker selected rows/columns and fix if Date is invalid
  /// e.g. user selects 31.4 will be fixed to 30.4.
  var _selectedDate : Date {
    get {
      var day: Int
      var base: Int
      if isMonthly {
        day = 14
        base = -1
      }
      else { 
        day = self.picker.selectedRow(inComponent: 0) + 1
        base = 0
      }
      var dc = DateComponents(calendar: Calendar.current,
                              year: self.picker.selectedRow(inComponent: base + 2) + data.minimumYear,
                              month: self.picker.selectedRow(inComponent: base + 1) + 1,
                              day: day, hour: 12)
      var changed = false
      
      while !dc.isValidDate {
        guard let day = dc.day else { break }
        if day == 1 { break }
        dc.day = day - 1
        changed = true
      }
      
      if changed, let newDate = dc.date {
        self.setDate(newDate, animated: true)
      }
     
      return dc.date ?? data.maximumDate
    }
  }
  
  public init(minimumDate:Date, maximumDate:Date, selectedDate:Date, isMonthly: Bool = false) {
    data = DatePickerData(minimumDate: minimumDate, maximumDate: maximumDate)
    initialSelectedDate = selectedDate
    self.isMonthly = isMonthly
    super.init(nibName: nil, bundle: nil)
  }
  
  required public init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  let data : DatePickerData
  
  let picker = UIPickerView()
  public let content = UIView()
  let applyButton = UIButton()
  public var bottomOffset:CGFloat = -Toolbar.ContentToolbarHeight
  
  open override func viewDidLoad() {
    picker.delegate = self
    picker.dataSource = self
    
    content.addSubview(picker)
    pin(picker.bottomGuide(), to: content.bottomGuide())
    pin(picker.topGuide(), to: content.topGuide())
    let dist = UIScreen.main.scale * 30
    pin(picker.leftGuide(), to: content.leftGuide(), dist: dist)
    pin(picker.rightGuide(), to: content.rightGuide(), dist: -dist)
    
    applyButton.setImage(UIImage(name: "arrow.2.circlepath"), for: .normal)
    applyButton.imageView?.tintColor = textColor
    
    applyButton.pinSize(CGSize(width: 70, height: 70))
    applyButton.backgroundColor = .clear
    applyButton.addTarget(self, action: #selector(donedatePicker), for: .touchUpInside)
    
    content.addSubview(applyButton)
    pin(picker.rightGuide(), to: applyButton.leftGuide(), dist: 10)
    pin(picker.centerY, to: applyButton.centerY)
    
    self.view.addSubview(content)
    pin(content.topGuide(), to: self.view.topGuide(), priority: .fittingSizeLevel)
    content.pinHeight(130, priority:.required)
    
    pin(content.bottom, to: self.view.bottomGuide(), dist: bottomOffset)
    pin(content.width, to: self.view.width, priority: .defaultHigh)
    content.pinWidth(500.0, relation: .lessThanOrEqual, priority: .required)
    content.centerX()
    
    
    if let dateToSet = self.initialSelectedDate {
      self.setDate(dateToSet, animated: false)
      self.initialSelectedDate = nil //disable on re-use
    }
  }
  
  /// The currently selected index
  open var index: Int {
    get { return self.picker.selectedRow(inComponent: 0) }
    set { self.picker.selectRow(newValue, inComponent: 0, animated: false) }
  }
  
  /// The color to use for text
  open var textColor = UIColor.white
  
  // The closure to call upon selection
  var selectionClosure: ((Int)->())?
  
  /// Define the closure to call upon selection
  open func onSelection(closure: ((Int)->())?) { selectionClosure = closure }
  
  @objc func donedatePicker(){
    doneHandler?()
  }
}

// MARK: - UIPickerViewDelegate protocol
extension DatePickerController {
  
  public func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
    var label = view as? UILabel
    if label == nil {
      label = UILabel()
      label?.textAlignment = .center
      label?.font = pickerFont ?? UIFont.preferredFont(forTextStyle: .headline)
    }
    label!.textColor = textColor
    let base: Int = isMonthly ? 1 : 0
    switch base + component {
      case 0: label!.text = data.dayLabel(idx: row)
      case 1: label!.text = data.monthLabel(idx: row)
      case 2: label!.text = data.yearLabel(idx: row)
      default: label!.text = "*"
    }
    return label!
  }
  
  public func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
    let kRotationAnimationKey = "rotationanimationkey"
    if self.applyButton.layer.animation(forKey: kRotationAnimationKey) == nil {
      let rotationAnimation = CABasicAnimation(keyPath: "transform.rotation")
      rotationAnimation.fromValue = 0.0
      rotationAnimation.toValue = Float.pi * 2.0
      rotationAnimation.duration = 0.9
      rotationAnimation.repeatCount = 1
      
      self.applyButton.imageView?.layer.add(rotationAnimation, forKey: kRotationAnimationKey)
    }
    
    let date = self._selectedDate

    if date < self.data.minimumDate {
      self.setDate(self.data.minimumDate, animated : true)
      return;
    }
    else if date > self.data.maximumDate {
      self.setDate(self.data.maximumDate, animated : true)
      return;
    }
    
    self.selectionClosure?(row)
  }
  
  func setDate(_ date:Date, animated:Bool){
    let base: Int = isMonthly ? -1 : 0
    if !isMonthly {
      self.picker.selectRow((date.components().day ?? 1) - 1, inComponent: 0, animated: animated)
    }
    self.picker.selectRow((date.components().month ?? 1) - 1, inComponent: base + 1, animated: animated)
    self.picker.selectRow((date.components().year ?? 0) - data.minimumYear, inComponent: base + 2, animated: animated)
  }
}

// MARK: - UIPickerViewDataSource protocol
extension DatePickerController{
  
  public func numberOfComponents(in pickerView: UIPickerView) -> Int { isMonthly ? 2 : 3 }
  
  public func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
    let base: Int = isMonthly ? 1 : 0
    switch base + component {
      case 0: return data.dayIniciesCount
      case 1: return data.monthIniciesCount
      case 2: return data.yearIniciesCount
      default: return 0 
    }
  }
}

// MARK: - ext:MPC DatePickerData
/// Data Helper as inner class
extension DatePickerController {
  class DatePickerData {
    
    var germanMonthNames : [String] = ["Januar", "Februar", "März", "April", "Mai", "Juni", "Juli", "August", "September", "Oktober", "November", "Dezember"]
    let minimumDate : Date
    let maximumDate : Date
    let minimumYear : Int
    let dayIniciesCount : Int
    let monthIniciesCount : Int
    let yearIniciesCount : Int
    
    init(minimumDate : Date, maximumDate : Date) {
      self.minimumDate = minimumDate
      self.maximumDate = maximumDate
      
      var yearCount = 0
      
      if let minYear = minimumDate.components().year,
         let maxYear = maximumDate.components().year {
        minimumYear = minYear
        yearCount = maxYear - minYear
      }
      else {
        minimumYear = 0
      }
      
      yearIniciesCount = 1 + yearCount
      monthIniciesCount = 12
      dayIniciesCount = 31
    }
    
    func monthLabel(idx:Int) -> String {
      return "\(germanMonthNames.valueAt(idx) ?? "")"
    }
    
    func yearLabel(idx:Int) -> String {
      return "\(minimumYear + idx)"
    }
    
    func dayLabel(idx:Int) -> String {
      return "\(1 + idx)"
    }
  }
}
