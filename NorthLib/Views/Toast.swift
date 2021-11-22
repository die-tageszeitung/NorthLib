//
//
// Toast.swift
//
// Created by Ringo Müller-Gromes on 24.07.20.
// Copyright © 2020 Ringo Müller-Gromes for "taz" digital newspaper. All rights reserved.
// 

import UIKit

public class Toast {
  
  public enum ToastType{ case info, alert}
  
  var alertBackgroundColor = UIColor.red.withAlphaComponent(0.9)
  
  public static var alertBackgroundColor : UIColor{
    get { return Toast.sharedInstance.alertBackgroundColor}
    set { Toast.sharedInstance.alertBackgroundColor = newValue.withAlphaComponent(0.9) }
    
  }
  
  // MARK: Public
  public static func show(_ text: String, _ type: ToastType = .info) {
    if !Thread.isMainThread {
      onMainAfter {
        Self.show(text,type)
      }
      return;
    }
    let dist : CGFloat = 10 //|-Screen-10-AlertBG-10-Text-10-AlertBG-10-Screen-|
    let duration = 2 + text.count/40
    var appFrame = CGRect(origin: .zero, size: UIWindow.size)
    let tip = UIView(frame: appFrame)
    
    var lbFrame = CGRect(x: dist,
                         y: dist,
                         width: appFrame.size.width - dist*4,
                         height: dist*2)
    
    let label = UILabel(frame: lbFrame)
    label.text = text
    label.numberOfLines = 0
    label.textAlignment = .center
    label.textColor = UIColor.white
    label.backgroundColor = UIColor.clear
    tip.addSubview(label)
    
    label.sizeToFit()
    
    lbFrame = label.frame
    appFrame = CGRect(x: appFrame.size.width/2 - lbFrame.size.width/2 - dist,
                      y: appFrame.size.height/2 - lbFrame.size.height/2 - 80,
                      width: lbFrame.size.width + dist*2,
                      height: lbFrame.size.height + dist*2)
    
    tip.frame = appFrame
    switch type {
      case .alert:
        tip.backgroundColor = Toast.sharedInstance.alertBackgroundColor
      case .info: fallthrough
      default:
        tip.backgroundColor = UIColor(displayP3Red: 0.1, green: 0.1, blue: 0.1, alpha: 0.9)
    }
    
    tip.layer.cornerRadius = 3
    tip.isUserInteractionEnabled = false
    tip.alpha = 0.0
    
    DispatchQueue.main.async {
      let appDelegate = UIApplication.shared.delegate
      let window = appDelegate?.window
      
      if window == nil { return}
      
      window!?.addSubview(tip)
      Toast.addTip(tip)
      UIView.animate(withDuration: 1.0,
                     delay: 0,
                     options: UIView.AnimationOptions.curveEaseInOut,
                     animations: {
                      tip.alpha = 1.0
      }, completion: { (_) in
        UIView.animate(withDuration: 1.0,
                       delay: TimeInterval(duration),
                       options: UIView.AnimationOptions.curveEaseInOut,
                       animations: {
                        tip.alpha = 0.0
        }, completion: { (_) in
          Toast.removeTip(tip)
        })
      })
    }
  }
  
  // MARK: Private
  private static let sharedInstance = Toast()
  
  private var tips = [UIView]()
  
  private static func addTip(_ tipToAdd: UIView) {
    var lastTipFrame: CGRect = CGRect()
    for tip in Toast.sharedInstance.tips {
      lastTipFrame = tip.frame
      UIView.animate(withDuration: 0.5, animations: {
        var center = tip.center
        center.y -= tip.frame.size.height
        tip.center = center
      })
    }
    
    if Toast.sharedInstance.tips.count > 0 {
      var frame = tipToAdd.frame
      frame.origin.y = lastTipFrame.origin.y + 10
      tipToAdd.frame = frame
    }
    
    Toast.sharedInstance.tips.append(tipToAdd)
  }
  
  private static func removeTip(_ tipToRemove: UIView) {
    
    if let index = Toast.sharedInstance.tips.firstIndex(of: tipToRemove) {
      Toast.sharedInstance.tips.remove(at: index)
    }
    tipToRemove.removeFromSuperview()
  }
  
}
