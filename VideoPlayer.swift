//
//  VideoPlayer.swift
//  SwiftBoilerPlate
//
//  Created by AKASH BOGHANI on 01/07/24.
//

import UIKit
import AVFoundation

class VideoPlayerView: UIView {
    // Override the layerClass property to make the layer type AVPlayerLayer
    override class var layerClass: AnyClass {
        return AVPlayerLayer.self
    }
    
    // Convenience property to access the AVPlayerLayer
    var playerLayer: AVPlayerLayer {
        return layer as! AVPlayerLayer
    }
    
    // Property to set the AVPlayer
    var player: AVPlayer? {
        get {
            return playerLayer.player
        }
        set {
            playerLayer.player = newValue
        }
    }
}

protocol VideoPlayerDelegate: AnyObject {
    func videoPlayerDidFinishPlaying(_ player: VideoPlayer)
    func videoPlayerDidUpdateProgress(_ player: VideoPlayer, currentTime: CMTime, remainingTime: CMTime)
    func videoPlayerDidUpdateMetadata(_ player: VideoPlayer, metadata: [String: String])
    func videoPlayerDidEncounterError(_ player: VideoPlayer, error: Error)
}

class VideoPlayer: NSObject {
    // MARK: - Properties
    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var timeObserverToken: Any?
    private let queue = DispatchQueue(label: "com.example.VideoPlayer")
    
    var hasBeenPaused = false
    weak var delegate: VideoPlayerDelegate?

    var isPlaying: Bool {
        return player?.rate != 0 && player?.error == nil
    }
    
    var isVideoLoaded: Bool {
        return player != nil
    }

    var volume: Float {
        get {
            return player?.volume ?? 0.0
        }
        set {
            player?.volume = newValue
        }
    }

    var isMuted: Bool = false {
        didSet {
            player?.isMuted = isMuted
        }
    }

    // MARK: - Functions
    public func loadVideo(url: URL) {
        let asset = AVAsset(url: url)
        playerItem = AVPlayerItem(asset: asset)
        player = AVPlayer(playerItem: playerItem)
        
        extractMetadata(from: asset)
        
        addPeriodicTimeObserver()
        addObserverForPlayerItem()
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playback, mode: .moviePlayback)
            try audioSession.setActive(true)
        } catch {
            delegate?.videoPlayerDidEncounterError(self, error: error)
        }
    }

    public func playVideo() {
        guard let player = player else { return }
        
        queue.sync {
            player.play()
        }
    }

    public func pauseVideo() {
        guard let player = player else { return }

        queue.sync {
            if isPlaying {
                player.pause()
                hasBeenPaused = true
            } else {
                hasBeenPaused = false
            }
        }
    }

    public func stopVideo() {
        guard let player = player else { return }

        queue.sync {
            player.pause()
            player.seek(to: .zero)
        }
    }

    public func seek(to time: CMTime) {
        guard let player = player else { return }

        queue.sync {
            player.seek(to: time)
        }
    }

    public func backward(by seconds: Float64) {
        guard let player = player else { return }

        queue.sync {
            let currentTime = player.currentTime()
            let newTime = CMTimeSubtract(currentTime, CMTimeMakeWithSeconds(seconds, preferredTimescale: currentTime.timescale))
            player.seek(to: newTime)
        }
    }

    public func forward(by seconds: Float64) {
        guard let player = player else { return }

        queue.sync {
            let currentTime = player.currentTime()
            let newTime = CMTimeAdd(currentTime, CMTimeMakeWithSeconds(seconds, preferredTimescale: currentTime.timescale))
            player.seek(to: newTime)
        }
    }

    public func getCurrentTime() -> CMTime? {
        return queue.sync {
            return player?.currentTime()
        }
    }

    public func getDuration() -> CMTime? {
        return queue.sync {
            return playerItem?.duration
        }
    }

    private func addPeriodicTimeObserver() {
        guard let player = player else { return }
        
        let interval = CMTime(seconds: 1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] currentTime in
            guard let self = self, let playerItem = self.playerItem else { return }
            let remainingTime = CMTimeSubtract(playerItem.duration, currentTime)
            self.delegate?.videoPlayerDidUpdateProgress(self, currentTime: currentTime, remainingTime: remainingTime)
        }
    }

    private func addObserverForPlayerItem() {
        NotificationCenter.default.addObserver(self, selector: #selector(playerItemDidReachEnd(notification:)), name: .AVPlayerItemDidPlayToEndTime, object: playerItem)
    }

    @objc private func playerItemDidReachEnd(notification: Notification) {
        delegate?.videoPlayerDidFinishPlaying(self)
    }

    private func extractMetadata(from asset: AVAsset) {
        var metadata: [String: String] = [:]
        
        for item in asset.commonMetadata {
            if let key = item.commonKey?.rawValue, let value = item.stringValue {
                metadata[key] = value
            }
        }
        
        delegate?.videoPlayerDidUpdateMetadata(self, metadata: metadata)
    }

    deinit {
        if let timeObserverToken = timeObserverToken {
            player?.removeTimeObserver(timeObserverToken)
        }
        NotificationCenter.default.removeObserver(self)
    }
}

