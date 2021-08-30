//
//  BasicPlayerViewController.swift
//  trim-crop-video
//
//  Created by Walter Tyree on 8/30/21.
//

import UIKit
import AVKit

class BasicPlayerViewController: AVPlayerViewController, AVPlayerViewControllerDelegate {

  fileprivate func cropVideo(item: AVPlayerItem) {
    let cropRect = CGRect(x: 0.0, y: 200.0, width: 600.0, height: 600.0)
    //Set the start time to 5 seconds.
    let cropScaleComposition = AVMutableVideoComposition(asset: item.asset, applyingCIFiltersWithHandler: {request in

      let cropFilter = CIFilter(name: "CICrop")!
      cropFilter.setValue(request.sourceImage, forKey: kCIInputImageKey)
      cropFilter.setValue(CIVector(cgRect: cropRect), forKey: "inputRectangle")


      let imageAtOrigin = cropFilter.outputImage!.transformed(by: CGAffineTransform(translationX: -cropRect.origin.x, y: -cropRect.origin.y))
      request.finish(with: imageAtOrigin, context: nil)
    })
    cropScaleComposition.renderSize = cropRect.size
    item.videoComposition = cropScaleComposition
  }

  override func viewDidLoad() {
        super.viewDidLoad()
    let trainAsset = AVAsset(url: Bundle.main.url(forResource: "grocery-train", withExtension: "mov")!)
    let trainItem = AVPlayerItem(asset: trainAsset, automaticallyLoadedAssetKeys: ["duration"])



    trainItem.reversePlaybackEndTime = CMTimeMakeWithSeconds(5, preferredTimescale: 600)

    trainItem.seek(to: CMTimeMakeWithSeconds(5, preferredTimescale: 600), completionHandler: nil)

    let itemDuration = trainAsset.duration

    trainItem.forwardPlaybackEndTime = CMTimeMakeWithSeconds(itemDuration.seconds - 5, preferredTimescale: 600)

    self.cropVideo(item: trainItem)

    self.player = AVPlayer(playerItem: trainItem)


  }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
