//
//  ProfileAudioPlayerService.swift
//  WorkSurvivalGuide
//
//  档案卡片音频播放：使用 AVPlayer 播放 profile.audioUrl
//

import AVFoundation
import Combine
import Foundation

final class ProfileAudioPlayerService: ObservableObject {
    static let shared = ProfileAudioPlayerService()
    
    @Published private(set) var currentPlayingProfileId: String?
    
    private var player: AVPlayer?
    private var endObserver: NSObjectProtocol?
    
    private init() {}
    
    /// 点击播放/暂停。若档案无 audioUrl 则不播放。
    func togglePlayback(for profile: Profile) {
        guard let urlString = profile.audioUrl,
              !urlString.isEmpty,
              urlString.hasPrefix("http") else {
            return
        }
        guard let url = URL(string: urlString) else { return }
        
        if currentPlayingProfileId == profile.id {
            stop()
            return
        }
        
        stop()
        player = AVPlayer(url: url)
        player?.play()
        currentPlayingProfileId = profile.id
        
        if let item = player?.currentItem {
            endObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: item,
                queue: .main
            ) { [weak self] _ in
                self?.currentPlayingProfileId = nil
            }
        }
    }
    
    func stop() {
        if let o = endObserver {
            NotificationCenter.default.removeObserver(o)
            endObserver = nil
        }
        player?.pause()
        player = nil
        currentPlayingProfileId = nil
    }
}
