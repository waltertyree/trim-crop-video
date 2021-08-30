//
//  ViewController.swift
//  trim-crop-video
//
//

import UIKit
import AVKit
import CoreImage
import CoreImage.CIFilterBuiltins

class ViewController: UIViewController {

  @IBOutlet var croppingView: UIView!
  @IBOutlet var playButton: UIButton!
  @IBOutlet var resetButton: UIButton!
  @IBOutlet var exportButton: UIButton!
  @IBOutlet var playerView: UIView!
  var player: AVPlayer? {
    didSet {
      guard let duration = player?.currentItem?.duration else { return }
      endTime = duration
    }
  }
  var cropScaleComposition: AVVideoComposition? {
    didSet {
      self.exportButton.isEnabled = (cropScaleComposition != nil)
    }
  }
  var startTime: CMTime = .zero
  var endTime: CMTime = .zero
  var endTimeObserver: Any?

  @IBOutlet var startTimeSlider: UISlider!
  @IBOutlet var endTimeSlider: UISlider!

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    loadCleanVideo()
  }

  @IBAction func startTimeUpdated(_ sender: UISlider) {
    guard let videoDuration = self.player?.currentItem?.duration else { return }
    self.startTime = CMTimeMakeWithSeconds(Double(sender.value) * videoDuration.seconds, preferredTimescale: 600)
    self.player?.seek(to: self.startTime)
  }

  @IBAction func endTimeUpdated(_ sender: UISlider) {
    guard let videoDuration = self.player?.currentItem?.duration else { return }
    self.endTime = CMTimeMakeWithSeconds(Double(sender.value) * videoDuration.seconds, preferredTimescale: 600)
    self.player?.seek(to: self.endTime)
  }

  @IBAction func croppingViewZoom(_ sender: UIPinchGestureRecognizer) {
    let touch = sender.location(in: sender.view?.superview)

    if sender.numberOfTouches < 2 { return }
    self.croppingView.transform = CGAffineTransform(scaleX: sender.scale, y: sender.scale)
    self.croppingView.center = CGPoint(x: touch.x, y: touch.y)

  }
  @IBAction func croppingViewDrag(_ sender: UIPanGestureRecognizer) {
    let touch = sender.location(in: sender.view?.superview)

    self.croppingView.center = CGPoint(x: touch.x, y: touch.y)
  }



  fileprivate func configureCroppingView() {
    self.croppingView.frame = CGRect(x: 0, y: 0, width: 250, height: 250)
    self.croppingView.center = playerView.center
    self.croppingView.layer.borderWidth = 2
    self.croppingView.layer.borderColor = UIColor.red.cgColor
  }

  fileprivate func loadCleanVideo() {
    self.player = AVPlayer(url: Bundle.main.url(forResource: "grocery-train", withExtension: "mov")!)
    self.cropScaleComposition = nil

    let playerLayer = AVPlayerLayer(player: player)
    playerLayer.frame = playerView.layer.bounds
    playerLayer.videoGravity = .resizeAspect

    playerView.layer.addSublayer(playerLayer)

    configureCroppingView()

    self.playerView.addSubview(self.croppingView)
  }

  func prepareForCropping() {
    guard let playerItem = self.player?.currentItem else { return }
    let renderingSize = playerItem.presentationSize

    let xFactor = renderingSize.width / playerView.bounds.size.width
    let yFactor = renderingSize.height / playerView.bounds.size.height

    let newX = croppingView.frame.origin.x * xFactor
    let newW = croppingView.frame.width * xFactor
    let newY = croppingView.frame.origin.y * yFactor
    let newH = croppingView.frame.height * yFactor
    var cropRect = CGRect(x: newX, y: newY, width: newW, height: newH)

    let originFlipTransform = CGAffineTransform(scaleX: 1, y: -1)
    let frameTranslateTransform = CGAffineTransform(translationX: 0, y: renderingSize.height)
    cropRect = cropRect.applying(originFlipTransform)
    cropRect = cropRect.applying(frameTranslateTransform)

    self.transformVideo(item: playerItem, cropRect: cropRect)
  }

  @IBAction func resetTapped(_ sender: Any) {
    self.croppingView.isHidden = false
    self.croppingView.removeFromSuperview()

    self.startTimeSlider.setValue(0, animated: true)
    self.endTimeSlider.setValue(1, animated: true)

    self.playerView.layer.sublayers?.removeAll()
    self.loadCleanVideo()
  }

  @IBAction func playTapped(_ sender: UIButton) {
    self.croppingView.isHidden = true
    self.prepareForCropping()
    player?.seek(to: startTime)
    self.endTimeObserver = player?.addBoundaryTimeObserver(forTimes: [NSValue(time: endTime)], queue: .main, using: {
      [weak self] in
      guard let self = self else { return }
      self.player?.pause()
      self.player?.removeTimeObserver(self.endTimeObserver!)
      self.croppingView.isHidden = false
    })
    player?.play()
  }

  fileprivate func addSpinner() {
    //Disable controls because this is a long process
    let spinner = UIActivityIndicatorView(style: .large)
    spinner.backgroundColor = .white
    spinner.tag = 10
    self.playerView.addSubview(spinner)
    spinner.center = self.playerView.center
    spinner.startAnimating()
  }

  fileprivate func removeSpinner() {
    let spinner = self.playerView.viewWithTag(10)
    spinner?.removeFromSuperview()
  }

  fileprivate func updateControlStatus(enabled: Bool) {
    if !enabled {
    addSpinner()
    } else {
      removeSpinner()
    }
    self.playButton.isEnabled = enabled
    self.startTimeSlider.isEnabled = enabled
    self.endTimeSlider.isEnabled = enabled
    self.resetButton.isEnabled = enabled
    self.exportButton.isEnabled = enabled
  }

  @IBAction func exportvideo(_ sender: UIButton) {
    guard let assetToExport = self.player?.currentItem?.asset else { return }
    guard let composition = self.cropScaleComposition else { return }
    guard let outputMovieURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("exported.mov") else { return }

    updateControlStatus(enabled: false)

    export(assetToExport, to: outputMovieURL, startTime: self.startTime, endTime: self.endTime, composition: composition)


  }

  func export(_ asset: AVAsset, to outputMovieURL: URL, startTime: CMTime, endTime: CMTime, composition: AVVideoComposition) {

    //Create trim range
    let timeRange = CMTimeRangeFromTimeToTime(start: startTime, end: endTime)

    //delete any old file
    do {
      try FileManager.default.removeItem(at: outputMovieURL)
    } catch {
      print("Could not remove file \(error.localizedDescription)")
    }

    //create exporter
    let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality)

    //configure exporter
    exporter?.videoComposition = composition
    exporter?.outputURL = outputMovieURL
    exporter?.outputFileType = .mov
    exporter?.timeRange = timeRange

    //export!
    exporter?.exportAsynchronously(completionHandler: { [weak exporter] in
      DispatchQueue.main.async {
        if let error = exporter?.error {
          print("failed \(error.localizedDescription)")
        } else {
          print("Video saved to \(outputMovieURL)")
        }
      }

    })
  }
  fileprivate func calculateFilterIntensity(_ duration: CMTime, _ currentTime: CMTime) -> Float {
    let timeDiff = CMTimeGetSeconds(CMTimeSubtract(duration, currentTime))
    if timeDiff < 5 {
      return Float((5 - timeDiff) / 5.0)
    }
    return 0.0
  }

  func transformVideo(item: AVPlayerItem, cropRect: CGRect) {

    let cropScaleComposition = AVMutableVideoComposition(asset: item.asset, applyingCIFiltersWithHandler: { [weak self] request in

      guard let self = self else { return }

      let sepiaToneFilter = CIFilter.sepiaTone()
      let currentTime = request.compositionTime
      sepiaToneFilter.intensity = self.calculateFilterIntensity(self.endTime, currentTime)
      sepiaToneFilter.inputImage = request.sourceImage

      let cropFilter = CIFilter(name: "CICrop")!
      cropFilter.setValue(sepiaToneFilter.outputImage!, forKey: kCIInputImageKey)
      cropFilter.setValue(CIVector(cgRect: cropRect), forKey: "inputRectangle")


      let imageAtOrigin = cropFilter.outputImage!.transformed(by: CGAffineTransform(translationX: -cropRect.origin.x, y: -cropRect.origin.y))
      request.finish(with: imageAtOrigin, context: nil)
    })
    cropScaleComposition.renderSize = cropRect.size
    item.videoComposition = cropScaleComposition
    self.cropScaleComposition = cropScaleComposition
  }

  func shareVideoFile(_ file:URL) {

    updateControlStatus(enabled: true)

    // Create the Array which includes the files you want to share
    var filesToShare = [Any]()

    // Add the path of the file to the Array
    filesToShare.append(file)

    // Make the activityViewContoller which shows the share-view
    let activityViewController = UIActivityViewController(activityItems: filesToShare, applicationActivities: nil)

    // Show the share-view
    self.present(activityViewController, animated: true, completion: nil)
  }
}

