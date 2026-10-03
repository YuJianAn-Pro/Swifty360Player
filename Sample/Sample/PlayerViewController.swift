//
//  PlayerViewController.swift
//  Sample
//
//  Created for Swifty360Player sample on 2026.
//

import UIKit
import AVKit
import Swifty360Player

final class PlayerViewController: UIViewController {

    private let videoURL: URL
    private let securityScoped: Bool
    private var player: AVPlayer?
    private var swifty360ViewController: Swifty360ViewController?
    private var accessing = false
    private var currentZoom: CGFloat = 1.0

    init(videoURL: URL, securityScoped: Bool) {
        self.videoURL = videoURL
        self.securityScoped = securityScoped
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        player?.pause()
        if accessing {
            videoURL.stopAccessingSecurityScopedResource()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = UIColor.black

        if securityScoped {
            accessing = videoURL.startAccessingSecurityScopedResource()
        }

        let player = AVPlayer(url: videoURL)
        self.player = player

        let motionManager = Swifty360MotionManager.shared
        // set motionManager nil to skip motion changes
        let swifty360ViewController = Swifty360ViewController(withAVPlayer: player, motionManager: motionManager)
        self.swifty360ViewController = swifty360ViewController

        addChild(swifty360ViewController)
        view.addSubview(swifty360ViewController.view)
        swifty360ViewController.didMove(toParent: self)

        player.play()

        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(reorientVerticalCameraAngle))
        swifty360ViewController.view.addGestureRecognizer(tapGestureRecognizer)

        let pinchGestureRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        swifty360ViewController.view.addGestureRecognizer(pinchGestureRecognizer)

        let closeButton = UIButton(type: .system)
        closeButton.setTitle("关闭", for: .normal)
        closeButton.setTitleColor(UIColor.white, for: .normal)
        closeButton.backgroundColor = UIColor(white: 0.0, alpha: 0.6)
        closeButton.layer.cornerRadius = 6.0
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        view.addSubview(closeButton)

        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12.0),
            closeButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -12.0),
            closeButton.widthAnchor.constraint(equalToConstant: 72.0),
            closeButton.heightAnchor.constraint(equalToConstant: 36.0)
        ])
    }

    @objc private func reorientVerticalCameraAngle() {
        swifty360ViewController?.reorientVerticalCameraAngleToHorizon(animated: true)
    }

    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        switch gesture.state {
        case .began, .changed:
            currentZoom *= gesture.scale
            gesture.scale = 1.0
            if currentZoom < 1.0 { currentZoom = 1.0 }
            if currentZoom > 8.0 { currentZoom = 8.0 }
            swifty360ViewController?.zoomScale = currentZoom
        default:
            break
        }
    }

    @objc private func closeTapped() {
        player?.pause()
        dismiss(animated: true)
    }
}
