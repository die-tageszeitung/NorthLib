//
//  AudioPlayer.swift
//
//  Created by Norbert Thies on 10.05.19.
//  Copyright © 2019 Norbert Thies. All rights reserved.
//

import Foundation
import AVFoundation
import MediaPlayer

#if canImport(UIKit)

import UIKit

extension CGSize {
  var isPortrait: Bool {
    return height > width
  }
}

/// UIImage extension to resize an image:
public extension UIImage {

  func resized(to size: CGSize, withLogo: UIImage?, logoSize: CGSize? = CGSize(width: 110, height: 110), dist: CGFloat? = 20.0) -> UIImage? {
    UIGraphicsBeginImageContextWithOptions(size, false, UIScreen.main.scale)
    self.draw(in: CGRect(origin: CGPoint.zero, size: size))
    if let logo = withLogo, logo.size.height > 0.0 {
      let logoLongSide = max(logo.size.width, logo.size.height, 1)
      let logoFactor
      = size.isPortrait
      ? 0.12*size.height/logoLongSide
      : 0.12*size.width/logoLongSide
      let logoSize = CGSize(width: logo.size.width*logoFactor,
                            height: logo.size.height*logoFactor)
      let dist = logoSize.width*0.3
      let rect = CGRect(x: dist,
                        y: dist,
                        width: logoSize.width,
                        height: logoSize.height)
      UIBezierPath(roundedRect: rect, cornerRadius: logoSize.width * 0.15).addClip()
      logo.draw(in: rect)
    }
    let newImage = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    return newImage ?? self.resize(to: size)
  }
  
  func resize(to size: CGSize) -> UIImage {
    let renderer = UIGraphicsImageRenderer(size: size)
    let image = renderer.image { _ in
      self.draw(in: CGRect.init(origin: CGPoint.zero, size: size))
    }
    return image.withRenderingMode(self.renderingMode)
  }
}

#endif

/// A very simple audio player utilizing AVPlayer
open class AudioPlayer: NSObject, DoesLog {
  
  @Default("playbackRate")
  public var playbackRate: Double
  
  private var _file: String? = nil
  
  /// file or String url to play
  public var file: String? {
    get { return _file }
    set {
      if newValue != _file { close() }
      _file = newValue
    }
  }
  
  /// Title of the track being played
  public var title:String?
  
  ///should reset NowPlayingInfo here or outside?
  ///prevent apering of latest played in other app after every article
  public var resetNowPlayingInfo:Bool = true
  
  /// Name of the album being played
  public var album:String?
  
  /// Artist of the track being played
  public var artist:String?
  
  /// Artist of the track being played
  public var addLogo:Bool = false
  
#if canImport(UIKit)
  public var logoToAdd: UIImage?

  // The resized image for the lock screen player UI
  private var resizedImage: UIImage?
  
  /// The image to display while playing
  public var image: UIImage? { didSet { resizedImage = nil } }
#endif
  
  /// current playback position
  public var currentTime: CMTime {
    get { return player?.currentTime() ?? CMTime(seconds: 0, preferredTimescale: 0) }
    set { player?.seek(to: newValue) }
  }
  
  /// current playback position
  public var currentItem: AVPlayerItem? { player?.currentItem }
  
  // the player
  public private(set) var player: AVPlayer? = nil
  
  
  
  // The timer updating the playing info
  private var timer: Timer? {
    didSet {
      oldValue?.invalidate()
    }
  }
  
  private var childTimerClosure: (()->())?
  
  public func onTimer(closure: @escaping ()->()) {
    childTimerClosure = closure
  }
  
  // Are we playing a stream?
  private var isStream = false
  
  // Should we be playing
  private var wasPlaying = false
  
  /// closure to call in case of error
  public func onStateChange(closure:  (()->())?) { _stateChangeHandler = closure }
  private var _stateChangeHandler: (()->())?
  
  
  private var lastRate: Float? {
    didSet {
      if abs((oldValue ?? 0.0) - (lastRate ?? 0.0)) > 0.1 {
        _stateChangeHandler?()
      }
    }
  }
      
  /// returns true if the player is currently playing
  public var isPlaying: Bool { return (player?.rate ?? 0.0) > 0.001 }
  
  /// closure to call in case of error
  public func onError(closure:  ((String,Error)->())?) { _onError = closure }
  private var _onError: ((String,Error)->())?
  
  /// closure to call when playing has ended
  public func onEnd(closure: ((Error?)->())?) { _onEnd = closure }
  private var _onEnd: ((Error?)->())?
  
  public func onStatusChange(closure: ((AVPlayerItem.Status)->())?) { _onStatusChange = closure }
  private var _onStatusChange: ((AVPlayerItem.Status)->())?
  
  // the observation object (in case of errors)
  private var observation: NSKeyValueObservation?
    
  private func open() {
    guard player == nil else { return }
    guard let file = self.file else { return }
    openRemoteCommands()
    var url = file.starts(with: "/") ? URL(fileURLWithPath: file) : URL(string: file)
    if url == nil {
      url = URL(fileURLWithPath: file)
      isStream = false
    }
    else { isStream = true }
    let item = AVPlayerItem(url: url!)
    observation = item.observe(\.status) { [weak self] (item, change) in
      if item.status == .failed {
        if let closure = self?._onError { closure(item.error!.localizedDescription, item.error!) }
        else { self?.error(item.error!.localizedDescription) }
        self?._onEnd?(item.error)
        self?.close()
      }
      else if item.status == .readyToPlay {}
      self?._onStatusChange?(item.status)
    }
    self.player = AVPlayer(playerItem: item)
    if #available(iOS 15.0, macOS 12, *) {
      self.player?.audiovisualBackgroundPlaybackPolicy = .continuesIfPossible
    }
    onThread {[weak self] in
      self?.updatePlayingInfo()
    }
    
    NotificationCenter.default.addObserver(self, selector: #selector(playerHasFinished),
      name: .AVPlayerItemDidPlayToEndTime, object: item)
    NotificationCenter.default.addObserver(self, selector:
      #selector(playerHasFinishedWithError(notification:)),
      name: .AVPlayerItemFailedToPlayToEndTime, object: item)
    #if canImport(UIKit)
    NotificationCenter.default.addObserver(self, selector: #selector(playerIsInterrupted),
      name: AVAudioSession.interruptionNotification, object: nil)
    #endif
    timer = every(seconds: 0.5) { [weak self] _ in
      self?.updatePlayingInfo()
      self?.childTimerClosure?()
      self?.lastRate = self?.player?.rate
    }
  }
  
  // player has finished playing medium
  @objc private func playerHasFinished() {
    guard let endHandler = _onEnd else { close(); return }
    endHandler(nil)
  }
  
  // player has finished with error
  @objc private func playerHasFinishedWithError(notification: Notification) {
    let err = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey]
    if let err = err as? Error { _onEnd?(err) }
    else { _onEnd?(error("Player couldn't finish successfully")) }
    close()
  }
  
  #if canImport(UIKit)
  // player is beeing interrupted
  @objc private func playerIsInterrupted(notification: Notification) {
    guard let userInfo = notification.userInfo,
          let typeInt = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
          let type = AVAudioSession.InterruptionType(rawValue: typeInt) 
    else { return }
    switch type {
      case .began:
        print("Interrupt received")
        if isPlaying {
          stop()
          wasPlaying = true
        }
      case .ended:
        if let optionInt = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
          let options = AVAudioSession.InterruptionOptions(rawValue: optionInt)
          if options.contains(.shouldResume) {
            print("Resume after interrupt")
            if wasPlaying { play() }
          }
        }
      default: print("unknown AV interrupt notification")
    }
  }
  #endif
  
  // defines playing info on lock/status screen
  private func updatePlayingInfo() {
    if let player = self.player {
      var info = [String:Any]()
      #if canImport(UIKit)
      if let image = image {
        info[MPMediaItemPropertyArtwork] =
        MPMediaItemArtwork(boundsSize: image.size) { [weak self] s in 
          guard let self = self else { return UIImage() }
          if self.resizedImage == nil,
             logoToAdd != image {///not add logo to same file!
            self.resizedImage
            = addLogo && gt_iOS16
            ? image.resized(to: s, withLogo: logoToAdd)
            : image.resize(to: s)
            if self.resizedImage == nil {
              self.error("Can't resize image from \(image.size) to \(s)")
            }
          }
          return self.resizedImage ?? UIImage()
        }
      }
      else {
        info.removeValue(forKey: MPMediaItemPropertyArtwork)
      }
      
      #endif
      if let title = title {
        info[MPMediaItemPropertyTitle] = title
      }
      if let album = album {
        info[MPMediaItemPropertyAlbumTitle] = album
      }
      if let artist = artist {
        info[MPMediaItemPropertyArtist] = artist
      }
      info[MPNowPlayingInfoPropertyIsLiveStream] = false
      //WARNING THIS IS SLOW & BLOCKES UI MULTIPLE TIMES; MAYBE MOVE TO BG PROCESS!?
      //Test with bad internet!
      #warning("Blocks UI")
      info[MPMediaItemPropertyPlaybackDuration] = player.currentItem!.asset.duration.seconds
      info[MPNowPlayingInfoPropertyPlaybackRate] = player.rate
      info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = player.currentItem!.currentTime().seconds
      MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
    else if resetNowPlayingInfo {
      MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
  }
  
  /// play plays the currently defined audio file
  public func play() {
    open()
    guard let player = self.player else { return }
    wasPlaying = true
    player.play()
    player.rate = Float(playbackRate)
  }
  
  /// stop stops the current playback (pauses it)
  public func stop() {
    guard let player = self.player else { return }
    wasPlaying = false
    player.pause()  
  }
  
  /// toggle either (re-)starts or stops the current playback
  public func toggle() {
    if self.player != nil {
      if isPlaying { self.stop(); return }
    }
    self.play()
  }
  
  /// close stops the player (if playing) and deactivates the audio session
  public func close() {
    do {
      timer?.invalidate()
      timer = nil
      closeRemoteCommands()
      self.stop()
      self.player = nil
      updatePlayingInfo()
      NotificationCenter.default.removeObserver(self)
      #if canImport(UIKit)
        try AVAudioSession.sharedInstance().setActive(false)
      #endif
    }
    catch let err {
      error(err)
    }      
  }

  // remote commands
  private var playCommand: Any?
  private var pauseCommand: Any?
  private var seekCommand: Any?
  
  public var setupRemoteCommands = true
  public var setupCloseRemoteCommands = true
  
  // enable remote commands
  private func openRemoteCommands() {
    if setupRemoteCommands == false { return }
    let commandCenter = MPRemoteCommandCenter.shared()
    // Add handler for Play Command
    playCommand = commandCenter.playCommand.addTarget { [unowned self] event in
      self.play()
      self.updatePlayingInfo()
      return .success
    }    
    // Add handler for Pause Command
    pauseCommand = commandCenter.pauseCommand.addTarget { [unowned self] event in
      self.stop()
      self.updatePlayingInfo()
      return .success
    }
    // Add handler for Seek Command
    seekCommand = commandCenter.changePlaybackPositionCommand.addTarget { [unowned self] event in
      let pos = (event as! MPChangePlaybackPositionCommandEvent).positionTime
      self.currentTime = CMTime(seconds: pos, preferredTimescale: 600)
      return .success
    }
  }
  
  // disable remote commands
  private func closeRemoteCommands() {
    if setupRemoteCommands == false || setupCloseRemoteCommands == false { return }
    let commandCenter = MPRemoteCommandCenter.shared()
    commandCenter.playCommand.removeTarget(playCommand)
    commandCenter.pauseCommand.removeTarget(pauseCommand)
    commandCenter.changePlaybackPositionCommand.removeTarget(seekCommand)
  } 
  
  public override init() {
    do {
      super.init()
      #if canImport(UIKit)
      try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
//      try AVAudioSession.sharedInstance().setActive(true) //Stops Background Audio Playback e.g. from Apple Music on enter Issue
      #endif
    }
    catch let err {
      error(err)
      close()
    }
  }
  
}  // AudioPlayer

fileprivate extension AVPlayer.Status {
  var string: String {
    switch self {
      case .failed: return "failed"
      case .readyToPlay: return "readyToPlay"
      case .unknown: return "unknown"
      default: return "unknown new"
    }
  }
}
