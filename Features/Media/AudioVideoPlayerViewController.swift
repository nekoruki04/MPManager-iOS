import UIKit
import AVFoundation

public final class AudioVideoPlayerViewController: UIViewController {
    private let media_path: String
    private let is_video: Bool

    private var player: AVPlayer?
    private var player_layer: AVPlayerLayer?
    private var time_observer_token: Any?

    private let container_view = UIView()
    private let video_view = UIView()
    private let audio_icon_view = UIImageView()
    private let title_label = UILabel()
    private let time_slider = UISlider()
    private let current_time_label = UILabel()
    private let total_time_label = UILabel()
    private let play_pause_button = UIButton(type: .system)
    private let backward_button = UIButton(type: .system)
    private let forward_button = UIButton(type: .system)
    private let close_button = UIButton(type: .system)

    private var is_seeking = false

    public init(media_path: String) {
        self.media_path = media_path
        let ext = (media_path as NSString).pathExtension.lowercased()
        self.is_video = ["mp4", "mov", "m4v", "mkv", "avi", "webm"].contains(ext)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        cleanup_player()
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        setup_ui()
        setup_player()
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        player_layer?.frame = video_view.bounds
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        player?.pause()
    }

    private func setup_ui() {
        view.backgroundColor = MPTheme.background_dark

        container_view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(container_view)

        video_view.translatesAutoresizingMaskIntoConstraints = false
        video_view.backgroundColor = .black
        video_view.layer.cornerRadius = 8
        video_view.clipsToBounds = true
        container_view.addSubview(video_view)

        audio_icon_view.translatesAutoresizingMaskIntoConstraints = false
        audio_icon_view.contentMode = .scaleAspectFit
        audio_icon_view.tintColor = MPTheme.primary_accent
        audio_icon_view.image = UIImage(systemName: "music.note.list")
        container_view.addSubview(audio_icon_view)

        title_label.translatesAutoresizingMaskIntoConstraints = false
        title_label.font = .systemFont(ofSize: 16, weight: .semibold)
        title_label.textColor = MPTheme.text_primary
        title_label.textAlignment = .center
        title_label.text = (media_path as NSString).lastPathComponent
        title_label.numberOfLines = 2
        container_view.addSubview(title_label)

        time_slider.translatesAutoresizingMaskIntoConstraints = false
        time_slider.minimumTrackTintColor = MPTheme.primary_accent
        time_slider.maximumTrackTintColor = MPTheme.border_color
        time_slider.thumbTintColor = MPTheme.primary_accent
        time_slider.addTarget(self, action: #selector(slider_value_changed(_:)), for: .valueChanged)
        time_slider.addTarget(self, action: #selector(slider_touch_down(_:)), for: .touchDown)
        time_slider.addTarget(self, action: #selector(slider_touch_up(_:)), for: [.touchUpInside, .touchUpOutside])
        container_view.addSubview(time_slider)

        current_time_label.translatesAutoresizingMaskIntoConstraints = false
        current_time_label.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        current_time_label.textColor = MPTheme.text_secondary
        current_time_label.text = "00:00"
        container_view.addSubview(current_time_label)

        total_time_label.translatesAutoresizingMaskIntoConstraints = false
        total_time_label.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        total_time_label.textColor = MPTheme.text_secondary
        total_time_label.text = "00:00"
        container_view.addSubview(total_time_label)

        play_pause_button.translatesAutoresizingMaskIntoConstraints = false
        play_pause_button.setImage(UIImage(systemName: "play.circle.fill"), for: .normal)
        play_pause_button.tintColor = MPTheme.primary_accent
        play_pause_button.contentVerticalAlignment = .fill
        play_pause_button.contentHorizontalAlignment = .fill
        play_pause_button.addTarget(self, action: #selector(toggle_play_pause), for: .touchUpInside)
        container_view.addSubview(play_pause_button)

        backward_button.translatesAutoresizingMaskIntoConstraints = false
        backward_button.setImage(UIImage(systemName: "gobackward.10"), for: .normal)
        backward_button.tintColor = MPTheme.text_primary
        backward_button.contentVerticalAlignment = .fill
        backward_button.contentHorizontalAlignment = .fill
        backward_button.addTarget(self, action: #selector(skip_backward), for: .touchUpInside)
        container_view.addSubview(backward_button)

        forward_button.translatesAutoresizingMaskIntoConstraints = false
        forward_button.setImage(UIImage(systemName: "goforward.10"), for: .normal)
        forward_button.tintColor = MPTheme.text_primary
        forward_button.contentVerticalAlignment = .fill
        forward_button.contentHorizontalAlignment = .fill
        forward_button.addTarget(self, action: #selector(skip_forward), for: .touchUpInside)
        container_view.addSubview(forward_button)

        close_button.translatesAutoresizingMaskIntoConstraints = false
        close_button.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        close_button.tintColor = MPTheme.text_secondary
        close_button.contentVerticalAlignment = .fill
        close_button.contentHorizontalAlignment = .fill
        close_button.addTarget(self, action: #selector(handle_close), for: .touchUpInside)
        view.addSubview(close_button)

        video_view.isHidden = !is_video
        audio_icon_view.isHidden = is_video

        NSLayoutConstraint.activate([
            close_button.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            close_button.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            close_button.widthAnchor.constraint(equalToConstant: 32),
            close_button.heightAnchor.constraint(equalToConstant: 32),

            container_view.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            container_view.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            container_view.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            video_view.topAnchor.constraint(equalTo: container_view.topAnchor),
            video_view.leadingAnchor.constraint(equalTo: container_view.leadingAnchor),
            video_view.trailingAnchor.constraint(equalTo: container_view.trailingAnchor),
            video_view.heightAnchor.constraint(equalTo: container_view.widthAnchor, multiplier: 0.5625),

            audio_icon_view.topAnchor.constraint(equalTo: container_view.topAnchor, constant: 20),
            audio_icon_view.centerXAnchor.constraint(equalTo: container_view.centerXAnchor),
            audio_icon_view.widthAnchor.constraint(equalToConstant: 96),
            audio_icon_view.heightAnchor.constraint(equalToConstant: 96),

            title_label.topAnchor.constraint(equalTo: is_video ? video_view.bottomAnchor : audio_icon_view.bottomAnchor, constant: 20),
            title_label.leadingAnchor.constraint(equalTo: container_view.leadingAnchor),
            title_label.trailingAnchor.constraint(equalTo: container_view.trailingAnchor),

            time_slider.topAnchor.constraint(equalTo: title_label.bottomAnchor, constant: 20),
            time_slider.leadingAnchor.constraint(equalTo: container_view.leadingAnchor),
            time_slider.trailingAnchor.constraint(equalTo: container_view.trailingAnchor),

            current_time_label.topAnchor.constraint(equalTo: time_slider.bottomAnchor, constant: 6),
            current_time_label.leadingAnchor.constraint(equalTo: container_view.leadingAnchor),

            total_time_label.topAnchor.constraint(equalTo: time_slider.bottomAnchor, constant: 6),
            total_time_label.trailingAnchor.constraint(equalTo: container_view.trailingAnchor),

            play_pause_button.topAnchor.constraint(equalTo: current_time_label.bottomAnchor, constant: 24),
            play_pause_button.centerXAnchor.constraint(equalTo: container_view.centerXAnchor),
            play_pause_button.widthAnchor.constraint(equalToConstant: 54),
            play_pause_button.heightAnchor.constraint(equalToConstant: 54),
            play_pause_button.bottomAnchor.constraint(equalTo: container_view.bottomAnchor, constant: -10),

            backward_button.centerYAnchor.constraint(equalTo: play_pause_button.centerYAnchor),
            backward_button.trailingAnchor.constraint(equalTo: play_pause_button.leadingAnchor, constant: -36),
            backward_button.widthAnchor.constraint(equalToConstant: 36),
            backward_button.heightAnchor.constraint(equalToConstant: 36),

            forward_button.centerYAnchor.constraint(equalTo: play_pause_button.centerYAnchor),
            forward_button.leadingAnchor.constraint(equalTo: play_pause_button.trailingAnchor, constant: 36),
            forward_button.widthAnchor.constraint(equalToConstant: 36),
            forward_button.heightAnchor.constraint(equalToConstant: 36)
        ])
    }

    private func setup_player() {
        let url = URL(fileURLWithPath: media_path)
        let player_item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: player_item)
        self.player = player

        if is_video {
            let layer = AVPlayerLayer(player: player)
            layer.videoGravity = .resizeAspect
            video_view.layer.addSublayer(layer)
            self.player_layer = layer
        }

        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        time_observer_token = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self, !self.is_seeking else { return }
            self.update_playback_progress(time: time)
        }

        NotificationCenter.default.addObserver(self, selector: #selector(player_did_finish_playing), name: .AVPlayerItemDidPlayToEndTime, object: player_item)

        player.play()
        play_pause_button.setImage(UIImage(systemName: "pause.circle.fill"), for: .normal)
    }

    private func cleanup_player() {
        if let token = time_observer_token {
            player?.removeTimeObserver(token)
            time_observer_token = nil
        }
        NotificationCenter.default.removeObserver(self)
        player?.pause()
        player = nil
    }

    private func update_playback_progress(time: CMTime) {
        guard let item = player?.currentItem else { return }
        let current_seconds = CMTimeGetSeconds(time)
        let total_seconds = CMTimeGetSeconds(item.duration)

        if total_seconds.isFinite && total_seconds > 0 {
            time_slider.value = Float(current_seconds / total_seconds)
            current_time_label.text = format_time(seconds: current_seconds)
            total_time_label.text = format_time(seconds: total_seconds)
        } else {
            current_time_label.text = format_time(seconds: current_seconds)
        }
    }

    private func format_time(seconds: Double) -> String {
        guard seconds.isFinite && !seconds.isNaN else { return "00:00" }
        let total = Int(seconds)
        let m = total / 60
        let s = total % 60
        return String(format: "%02d:%02d", m, s)
    }

    @objc private func toggle_play_pause() {
        guard let p = player else { return }
        if p.rate > 0 {
            p.pause()
            play_pause_button.setImage(UIImage(systemName: "play.circle.fill"), for: .normal)
        } else {
            p.play()
            play_pause_button.setImage(UIImage(systemName: "pause.circle.fill"), for: .normal)
        }
    }

    @objc private func skip_backward() {
        guard let p = player else { return }
        let current = CMTimeGetSeconds(p.currentTime())
        let target = max(0, current - 10)
        p.seek(to: CMTime(seconds: target, preferredTimescale: 600))
    }

    @objc private func skip_forward() {
        guard let p = player, let item = p.currentItem else { return }
        let current = CMTimeGetSeconds(p.currentTime())
        let total = CMTimeGetSeconds(item.duration)
        let target = min(total, current + 10)
        p.seek(to: CMTime(seconds: target, preferredTimescale: 600))
    }

    @objc private func slider_touch_down(_ slider: UISlider) {
        is_seeking = true
    }

    @objc private func slider_value_changed(_ slider: UISlider) {
        guard let item = player?.currentItem else { return }
        let total = CMTimeGetSeconds(item.duration)
        if total.isFinite && total > 0 {
            let target = Double(slider.value) * total
            current_time_label.text = format_time(seconds: target)
        }
    }

    @objc private func slider_touch_up(_ slider: UISlider) {
        guard let p = player, let item = p.currentItem else {
            is_seeking = false
            return
        }
        let total = CMTimeGetSeconds(item.duration)
        if total.isFinite && total > 0 {
            let target = Double(slider.value) * total
            p.seek(to: CMTime(seconds: target, preferredTimescale: 600)) { [weak self] _ in
                self?.is_seeking = false
            }
        } else {
            is_seeking = false
        }
    }

    @objc private func player_did_finish_playing() {
        player?.seek(to: .zero)
        play_pause_button.setImage(UIImage(systemName: "play.circle.fill"), for: .normal)
    }

    @objc private func handle_close() {
        dismiss(animated: true)
    }
}
