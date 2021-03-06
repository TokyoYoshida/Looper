//
//  ViewController.swift
//  Looper
//
//  Created by 冨田 直希 on 2016/04/09.
//  Copyright © 2016年 冨田 直希. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

  let btPlay: UIButton = UIButton();
  var playing = false;
  let looper: Looper = Looper();

  override func viewDidLoad() {
    super.viewDidLoad()

    // 再生ボタン
    btPlay.setTitle("PLAY", for: [])
    btPlay.setTitle("PLAY", for: UIControlState.highlighted);
    btPlay.setTitleColor(UIColor.black, for: []);
    btPlay.setTitleColor(UIColor.lightGray , for: UIControlState.highlighted);
    btPlay.addTarget(self, action: #selector(onClickedPlay), for: UIControlEvents.touchUpInside);
    btPlay.sizeToFit();
    btPlay.center.x = (self.view.frame.width / 2);
    btPlay.center.y = (self.view.frame.height / 2);
    self.view.addSubview(btPlay);

    looper.initialize();

  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }

  @objc func onClickedPlay( sender: UIButton ) {
    if ( playing ) {
        btPlay.setTitle("PLAY", for: []);
        btPlay.setTitle("PLAY", for: UIControlState.highlighted);
      btPlay.sizeToFit();
      playing = false;

      looper.end();
    } else {
      btPlay.setTitle("STOP", for: []);
        btPlay.setTitle("STOP", for: UIControlState.highlighted);
      btPlay.sizeToFit();
      playing = true;

      looper.begin();
    }
  }


}

