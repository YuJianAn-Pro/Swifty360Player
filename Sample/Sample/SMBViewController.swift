//
//  SMBViewController.swift
//  Sample
//
//  Created for Swifty360Player sample on 2026.
//

import UIKit
import AMSMB2

private enum SMBEntry {
    case directory(path: String, name: String)
    case video(path: String, name: String)
    case other(name: String)

    var isDirectory: Bool {
        if case .directory = self { return true }
        return false
    }

    var name: String {
        switch self {
        case .directory(_, let name): return name
        case .video(_, let name): return name
        case .other(let name): return name
        }
    }
}

final class SMBViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate {

    private var client: SMB2Manager?
    private var shareName = ""
    private var currentPath = ""
    private var entries: [SMBEntry] = []
    private var connecting = false
    private var downloading = false

    private let closeButton = UIButton(type: .system)
    private let upButton = UIButton(type: .system)
    private let pathLabel = UILabel()
    private let formStack = UIStackView()
    private let hostField = UITextField()
    private let shareField = UITextField()
    private let userField = UITextField()
    private let passwordField = UITextField()
    private let connectButton = UIButton(type: .system)
    private let tableView = UITableView()
    private let activityIndicator = UIActivityIndicatorView(style: .medium)

    private static let supportedExtensions: Set<String> = ["mp4", "m4v", "mov", "3gp", "insv", "360"]

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = UIColor.black
        buildInterface()
        restorePreferences()
    }

    // MARK: - Interface

    private func buildInterface() {
        let topBar = UIStackView()
        topBar.axis = .horizontal
        topBar.alignment = .center
        topBar.spacing = 8.0
        topBar.translatesAutoresizingMaskIntoConstraints = false

        closeButton.setTitle("关闭", for: .normal)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)

        pathLabel.textColor = UIColor.lightGray
        pathLabel.textAlignment = .center
        pathLabel.font = UIFont.systemFont(ofSize: 13.0)
        pathLabel.numberOfLines = 1
        pathLabel.lineBreakMode = .byTruncatingHead

        upButton.setTitle("上一级", for: .normal)
        upButton.addTarget(self, action: #selector(upTapped), for: .touchUpInside)
        upButton.isHidden = true

        topBar.addArrangedSubview(closeButton)
        topBar.addArrangedSubview(pathLabel)
        topBar.addArrangedSubview(upButton)

        formStack.axis = .vertical
        formStack.spacing = 10.0
        formStack.translatesAutoresizingMaskIntoConstraints = false

        hostField.placeholder = "服务器地址，如 192.168.1.10 或 smb://nas:445"
        shareField.placeholder = "共享名称，如 media"
        userField.placeholder = "用户名（可留空尝试游客访问）"
        passwordField.placeholder = "密码（可留空）"
        passwordField.isSecureTextEntry = true
        for field in [hostField, shareField, userField, passwordField] {
            field.borderStyle = .roundedRect
            field.delegate = self
            field.autocorrectionType = .no
            field.autocapitalizationType = .none
            field.textColor = UIColor.white
            field.backgroundColor = UIColor(white: 0.15, alpha: 1.0)
        }
        hostField.keyboardType = .URL
        connectButton.setTitle("连接", for: .normal)
        connectButton.setTitleColor(UIColor.white, for: .normal)
        connectButton.backgroundColor = UIColor(red: 0.2, green: 0.45, blue: 0.9, alpha: 1.0)
        connectButton.layer.cornerRadius = 8.0
        connectButton.heightAnchor.constraint(equalToConstant: 44.0).isActive = true
        connectButton.addTarget(self, action: #selector(connectTapped), for: .touchUpInside)
        connectButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16.0)

        formStack.addArrangedSubview(hostField)
        formStack.addArrangedSubview(shareField)
        formStack.addArrangedSubview(userField)
        formStack.addArrangedSubview(passwordField)
        formStack.addArrangedSubview(connectButton)

        tableView.dataSource = self
        tableView.delegate = self
        tableView.backgroundColor = UIColor.black
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")

        activityIndicator.hidesWhenStopped = true
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(topBar)
        view.addSubview(formStack)
        view.addSubview(tableView)
        view.addSubview(activityIndicator)

        NSLayoutConstraint.activate([
            topBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8.0),
            topBar.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),

            formStack.topAnchor.constraint(equalTo: topBar.bottomAnchor, constant: 12.0),
            formStack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            formStack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),

            tableView.topAnchor.constraint(equalTo: formStack.bottomAnchor, constant: 12.0),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func restorePreferences() {
        let defaults = UserDefaults.standard
        hostField.text = defaults.string(forKey: "smb_host")
        shareField.text = defaults.string(forKey: "smb_share")
        userField.text = defaults.string(forKey: "smb_user")
        passwordField.text = defaults.string(forKey: "smb_password")
    }

    private func savePreferences() {
        let defaults = UserDefaults.standard
        defaults.set(hostField.text, forKey: "smb_host")
        defaults.set(shareField.text, forKey: "smb_share")
        defaults.set(userField.text, forKey: "smb_user")
        defaults.set(passwordField.text, forKey: "smb_password")
    }

    // MARK: - Actions

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    @objc private func upTapped() {
        guard !connecting, client != nil, !downloading else { return }
        let parent = parentPath(of: currentPath)
        Task { await load(path: parent) }
    }

    @objc private func connectTapped() {
        guard !connecting, !downloading else { return }
        var host = (hostField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let share = (shareField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if host.isEmpty || share.isEmpty {
            showError("请填写服务器地址和共享名称")
            return
        }
        if !host.lowercased().hasPrefix("smb://") {
            host = "smb://" + host
        }
        guard let url = URL(string: host), url.host != nil else {
            showError("服务器地址格式不正确")
            return
        }
        let user = (userField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let password = passwordField.text ?? ""
        let credential = URLCredential(user: user, password: password, persistence: .forSession)
        guard let manager = SMB2Manager(url: url, domain: "", credential: credential) else {
            showError("无法创建 SMB 连接")
            return
        }
        client = manager
        shareName = share
        connecting = true
        connectButton.isEnabled = false
        activityIndicator.startAnimating()
        Task { [weak self] in
            guard let self = self else { return }
            do {
                try await manager.connectShare(name: share)
                self.savePreferences()
                await self.load(path: "")
                self.formStack.isHidden = true
            } catch {
                self.showError("连接失败: \(error.localizedDescription)")
            }
            self.connecting = false
            self.connectButton.isEnabled = true
            self.activityIndicator.stopAnimating()
        }
    }

    private func parentPath(of path: String) -> String {
        guard let range = path.range(of: "/", options: .backwards) else { return "" }
        return String(path[..<range.lowerBound])
    }

    // MARK: - Directory loading

    private func load(path: String) async {
        guard let client = client else { return }
        activityIndicator.startAnimating()
        do {
            let listing = try await client.contentsOfDirectory(atPath: path)
            var parsed: [SMBEntry] = []
            for item in listing {
                guard let name = item[.nameKey] as? String, !name.hasPrefix(".") else { continue }
                let itemPath = (item[.pathKey] as? String) ?? (path.isEmpty ? name : path + "/" + name)
                let type = item[.fileResourceTypeKey] as? URLFileResourceType
                if type == .typeDirectory {
                    parsed.append(.directory(path: itemPath, name: name))
                } else if Self.supportedExtensions.contains(URL(fileURLWithPath: name).pathExtension.lowercased()) {
                    parsed.append(.video(path: itemPath, name: name))
                } else {
                    parsed.append(.other(name: name))
                }
            }
            parsed.sort { lhs, rhs in
                if lhs.isDirectory != rhs.isDirectory { return lhs.isDirectory }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            entries = parsed
            currentPath = path
            refreshList()
        } catch {
            showError("读取目录失败: \(error.localizedDescription)")
        }
        activityIndicator.stopAnimating()
    }

    private func refreshList() {
        if currentPath.isEmpty {
            pathLabel.text = "/（共享根目录）"
        } else {
            pathLabel.text = "/" + currentPath
        }
        upButton.isHidden = currentPath.isEmpty
        tableView.reloadData()
    }

    // MARK: - Download and play

    private func downloadAndPlay(entry: SMBEntry) {
        guard !downloading, let client = client else { return }
        guard case let .video(path, name) = entry else { return }
        downloading = true
        let targetURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("smb-" + UUID().uuidString)
            .appendingPathExtension(URL(fileURLWithPath: name).pathExtension)
        let alert = UIAlertController(title: "正在下载", message: name, preferredStyle: .alert)
        let progressView = UIProgressView(progressViewStyle: .default)
        progressView.translatesAutoresizingMaskIntoConstraints = false
        alert.view.addSubview(progressView)
        NSLayoutConstraint.activate([
            progressView.leadingAnchor.constraint(equalTo: alert.view.leadingAnchor, constant: 20.0),
            progressView.trailingAnchor.constraint(equalTo: alert.view.trailingAnchor, constant: -20.0),
            progressView.topAnchor.constraint(equalTo: alert.view.topAnchor, constant: 70.0),
            alert.view.heightAnchor.constraint(equalToConstant: 110.0)
        ])
        present(alert, animated: true)
        Task { [weak self] in
            guard let self = self else { return }
            do {
                try await client.downloadItem(atPath: path, to: targetURL, progress: { bytes, total in
                    DispatchQueue.main.async {
                        if total > 0 {
                            progressView.progress = Float(bytes) / Float(total)
                        }
                    }
                    return true
                })
                alert.dismiss(animated: true) {
                    let playerViewController = PlayerViewController(videoURL: targetURL, securityScoped: false)
                    playerViewController.modalPresentationStyle = .fullScreen
                    self.present(playerViewController, animated: true)
                }
            } catch {
                alert.dismiss(animated: true) {
                    self.showError("下载失败: \(error.localizedDescription)")
                }
            }
            self.downloading = false
        }
    }

    private func showError(_ message: String) {
        let alert = UIAlertController(title: "出错了", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "好", style: .default))
        present(alert, animated: true)
    }

    // MARK: - Table view

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        entries.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let entry = entries[indexPath.row]
        switch entry {
        case .directory(_, let name):
            cell.textLabel?.text = "📁 " + name
            cell.textLabel?.textColor = UIColor.white
            cell.accessoryType = .disclosureIndicator
        case .video(_, let name):
            cell.textLabel?.text = "🎬 " + name
            cell.textLabel?.textColor = UIColor.white
            cell.accessoryType = .disclosureIndicator
        case .other(let name):
            cell.textLabel?.text = "📄 " + name
            cell.textLabel?.textColor = UIColor.darkGray
            cell.accessoryType = .none
        }
        cell.backgroundColor = UIColor.black
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch entries[indexPath.row] {
        case .directory(let path, _):
            if !connecting, !downloading {
                Task { await load(path: path) }
            }
        case .video:
            downloadAndPlay(entry: entries[indexPath.row])
        case .other:
            break
        }
    }

    // MARK: - Text field

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
