//
//  Print.swift
//  NorthLib
//
//  Created by Ringo Müller on 25.09.24.
//

import UIKit

/// A utility class for handling print operations in iOS.
public class Print{
  
  /// Initiates the printing of PDF data.
  /// Uses `UIPrintInteractionController` to present the print interface.
  ///
  /// - Parameters:
  ///   - pdfData: The PDF data to be printed.
  ///   - jobName: An optional name for the print job. Defaults is "PDF Print" if not provided.
  public static func print(pdfData: Data, jobName: String? =  nil) {
      let printController = UIPrintInteractionController.shared
      let printInfo = UIPrintInfo(dictionary: nil)
      printInfo.outputType = .general
      printInfo.jobName = jobName ?? "PDF Print"
      printController.printInfo = printInfo
      printController.printingItem = pdfData
      printController.present(animated: true, completionHandler: nil)
  }
}
