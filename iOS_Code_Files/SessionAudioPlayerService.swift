//
//  SessionAudioPlayerService.swift
//  WorkSurvivalGuide
//
//  录音详情页音频播放：支持播放/暂停/重头播放，使用 AVPlayer + JWT 鉴权头
//

import AVFoundation
import Combine
import Foundation

@MainActor
final class SessionAudioPlayerService: ObservableObject {
    @Published private(set) var isPlaying = false
    /// true = AVPlayer 正在缓冲/等待，此时按钮显示 loading 动画
    @Published private(set) var isBuffering = false

    private var player: AVPlayer?
    private var endObserver: NSObjectProtocol?
    private var statusObserver: NSKeyValueObservation?
    private var audioUrl: String?

    func setAudioUrl(_ url: String?) {
        // URL 变更时停止当前播放
        if url != audioUrl {
            stop()
        }
        audioUrl = url
    }

    func togglePlayback() {
        guard let urlString = audioUrl, !urlString.isEmpty else { return }

        if isPlaying {
            player?.pause()
            isPlaying = false
        } else {
            if player != nil {
                // 已有播放器实例（暂停状态）→ 继续
                player?.play()
                isPlaying = true
            } else {
                // 首次播放 → 新建
                startPlayer(urlString: urlString)
            }
        }
    }

    func restartFromBeginning() {
        guard let urlString = audioUrl, !urlString.isEmpty else { return }
        if let p = player {
            p.seek(to: .zero)
            p.play()
            isPlaying = true
        } else {
            startPlayer(urlString: urlString)
        }
    }

    func stop() {
        if let o = endObserver {
            NotificationCenter.default.removeObserver(o)
            endObserver = nil
        }
        statusObserver?.invalidate()
        statusObserver = nil
        player?.pause()
        player = nil
        isPlaying = false
        isBuffering = false
    }

    // MARK: - Private

    private func startPlayer(urlString: String) {
        guard let url = URL(string: urlString) else { return }

        let token = KeychainManager.shared.getToken() ?? ""
        var options: [String: Any] = [:]
        if !token.isEmpty {
            options["AVURLAssetHTTPHeaderFieldsKey"] = ["Authorization": "Bearer \(token)"]
        }
        let asset = AVURLAsset(url: url, options: options)
        let playerItem = AVPlayerItem(asset: asset)

        let newPlayer = AVPlayer(playerItem: playerItem)
        player = newPlayer
        isPlaying = true
        isBuffering = true  // 首次播放必定需要缓冲

        // 监听 timeControlStatus：waiting = 缓冲中，playing = 已开始实际播放
        statusObserver = newPlayer.observe(\.timeControlStatus, options: [.new]) { [weak self] p, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch p.timeControlStatus {
                case .waitingToPlayAtSpecifiedRate:
                    self.isBuffering = true
                case .playing:
                    self.isBuffering = false
                case .paused:
                    self.isBuffering = false
                @unknown default:
                    self.isBuffering = false
                }
            }
        }

        newPlayer.play()

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.isPlaying = false
                self?.isBuffering = false
            }
        }
    }
}
