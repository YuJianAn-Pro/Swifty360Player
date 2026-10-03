//

//  ViewController.swift

//  Sample

//

//  Created by Selek, Abdullah on 23.10.17.

//  Copyright © 2017 Abdullah Selek. All rights reserved.

//



import UIKit

import PhotosUI

import UniformTypeIdentifiers

import Swifty360Player



class ViewController: UIViewController, PHPickerViewControllerDelegate, UIDocumentPickerDelegate {



    override func viewDidLoad() {

        super.viewDidLoad()



        view.backgroundColor = UIColor.black

        title = "Swifty360 Player"



        let stackView = UIStackView()

        stackView.axis = .vertical

        stackView.spacing = 16.0

        stackView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stackView)



        stackView.addArrangedSubview(makeButton(title: "播放相册中的视频", action: #selector(pickFromPhotoLibrary)))

        stackView.addArrangedSubview(makeButton(title: "播放文件 App 中的视频", action: #selector(pickFromFiles)))



        let hint = UILabel()

        hint.text = "支持 360° 全景视频（等距柱状投影 2:1），普通视频会变形\n点按画面重置视角，双指捏合变焦\n看 NAS/SMB：先在 文件 App 连接服务器（浏览 → ⋯ → 连接服务器），\n再用第二个入口选择视频，边下边播"

        hint.textColor = UIColor(white: 0.7, alpha: 1.0)

        hint.textAlignment = .center

        hint.numberOfLines = 0

        hint.font = UIFont.systemFont(ofSize: 12.0)



        stackView.addArrangedSubview(hint)



        NSLayoutConstraint.activate([

            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            stackView.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),

            stackView.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor)

        ])

    }



    private func makeButton(title: String, action: Selector) -> UIButton {

        let button = UIButton(type: .system)

        button.setTitle(title, for: .normal)

        button.setTitleColor(UIColor.white, for: .normal)

        button.backgroundColor = UIColor(white: 0.2, alpha: 1.0)

        button.layer.cornerRadius = 8.0

        button.heightAnchor.constraint(equalToConstant: 48.0).isActive = true

        button.addTarget(self, action: action, for: .touchUpInside)

        return button

    }



    // MARK: - Photo library



    @objc private func pickFromPhotoLibrary() {

        var configuration = PHPickerConfiguration(photoLibrary: .shared())

        configuration.filter = .videos

        configuration.selectionLimit = 1

        let picker = PHPickerViewController(configuration: configuration)

        picker.delegate = self

        present(picker, animated: true)

    }



    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {

        picker.dismiss(animated: true)

        guard let provider = results.first?.itemProvider, provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) else { return }

        provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { [weak self] url, error in

            guard let url = url else {

                self?.showError("无法读取所选视频" + (error.map { ": \($0.localizedDescription)" } ?? ""))

                return

            }

            let target = FileManager.default.temporaryDirectory

                .appendingPathComponent(UUID().uuidString)

                .appendingPathExtension(url.pathExtension.isEmpty ? "mp4" : url.pathExtension)

            do {

                try FileManager.default.copyItem(at: url, to: target)

            } catch {

                self?.showError("复制视频失败: \(error.localizedDescription)")

                return

            }

            DispatchQueue.main.async {

                self?.play(url: target, securityScoped: false)

            }

        }

    }



    // MARK: - Files app



    @objc private func pickFromFiles() {

        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.movie, .mpeg4Movie], asCopy: false)

        picker.delegate = self

        present(picker, animated: true)

    }



    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {

        guard let url = urls.first else { return }

        play(url: url, securityScoped: true)

    }



    // MARK: - Playback



    private func play(url: URL, securityScoped: Bool) {

        let playerViewController = PlayerViewController(videoURL: url, securityScoped: securityScoped)

        playerViewController.modalPresentationStyle = .fullScreen

        present(playerViewController, animated: true)

    }



    private func showError(_ message: String) {

        DispatchQueue.main.async {

            let alert = UIAlertController(title: "出错了", message: message, preferredStyle: .alert)

            alert.addAction(UIAlertAction(title: "好", style: .default))

            self.present(alert, animated: true)

        }

    }

}

