//
//  PlayerViewController.swift
//  trim-crop-video
//
//  Created by Walter Tyree on 8/24/21.
//

import UIKit
import AVKit

class PlayerViewController: AVPlayerViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

      self.player = AVPlayer(url: Bundle.main.url(forResource: "grocery-train", withExtension: "mov")!)
        // Do any additional setup after loading the view.
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
