import UIKit

public final class ShellRunnerViewController: UIViewController {
    private let script_path: String?
    private var initial_command: String?

    private let command_field = UITextField()
    private let root_switch = UISwitch()
    private let root_label = UILabel()
    private let run_button = UIButton(type: .system)
    private let terminal_view = UITextView()
    private let status_badge = UILabel()
    private let activity_indicator = UIActivityIndicatorView(style: .medium)

    public init(script_path: String? = nil, command: String? = nil) {
        self.script_path = script_path
        self.initial_command = command
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        setup_ui()
        if let script = script_path {
            command_field.text = "sh \"\(script)\""
        } else if let cmd = initial_command {
            command_field.text = cmd
        }
    }

    private func setup_ui() {
        view.backgroundColor = MPTheme.background_dark
        title = "Shell Command Runner"

        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(handle_close))

        let clear_item = UIBarButtonItem(title: "Clear", style: .plain, target: self, action: #selector(handle_clear))
        let share_item = UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(handle_share))
        navigationItem.rightBarButtonItems = [share_item, clear_item]

        let top_container = UIView()
        top_container.translatesAutoresizingMaskIntoConstraints = false
        top_container.backgroundColor = MPTheme.surface_dark
        top_container.layer.cornerRadius = 8
        view.addSubview(top_container)

        command_field.translatesAutoresizingMaskIntoConstraints = false
        command_field.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        command_field.textColor = MPTheme.text_primary
        command_field.backgroundColor = MPTheme.background_dark
        command_field.layer.cornerRadius = 6
        command_field.layer.borderWidth = 1
        command_field.layer.borderColor = MPTheme.border_color.cgColor
        command_field.autocorrectionType = .no
        command_field.autocapitalizationType = .none
        command_field.placeholder = "Enter shell command..."
        top_container.addSubview(command_field)

        root_label.translatesAutoresizingMaskIntoConstraints = false
        root_label.text = "Root Privileges"
        root_label.font = .systemFont(ofSize: 13, weight: .medium)
        root_label.textColor = MPTheme.text_secondary
        top_container.addSubview(root_label)

        root_switch.translatesAutoresizingMaskIntoConstraints = false
        root_switch.onTintColor = MPTheme.primary_accent
        root_switch.isOn = PrivilegeManager.shared.is_root_available
        top_container.addSubview(root_switch)

        run_button.translatesAutoresizingMaskIntoConstraints = false
        run_button.setTitle("Run", for: .normal)
        run_button.setTitleColor(.white, for: .normal)
        run_button.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        run_button.backgroundColor = MPTheme.primary_accent
        run_button.layer.cornerRadius = 6
        run_button.addTarget(self, action: #selector(execute_command), for: .touchUpInside)
        top_container.addSubview(run_button)

        terminal_view.translatesAutoresizingMaskIntoConstraints = false
        terminal_view.backgroundColor = UIColor(red: 0.05, green: 0.07, blue: 0.09, alpha: 1.0)
        terminal_view.textColor = UIColor(red: 0.3, green: 0.95, blue: 0.4, alpha: 1.0)
        terminal_view.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        terminal_view.isEditable = false
        terminal_view.layer.cornerRadius = 8
        terminal_view.layer.borderWidth = 1
        terminal_view.layer.borderColor = MPTheme.border_color.cgColor
        view.addSubview(terminal_view)

        status_badge.translatesAutoresizingMaskIntoConstraints = false
        status_badge.font = .monospacedSystemFont(ofSize: 11, weight: .bold)
        status_badge.textColor = .white
        status_badge.backgroundColor = MPTheme.surface_dark
        status_badge.textAlignment = .center
        status_badge.layer.cornerRadius = 4
        status_badge.clipsToBounds = true
        status_badge.text = " READY "
        view.addSubview(status_badge)

        activity_indicator.translatesAutoresizingMaskIntoConstraints = false
        activity_indicator.color = MPTheme.primary_accent
        view.addSubview(activity_indicator)

        NSLayoutConstraint.activate([
            top_container.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            top_container.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            top_container.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            command_field.topAnchor.constraint(equalTo: top_container.topAnchor, constant: 10),
            command_field.leadingAnchor.constraint(equalTo: top_container.leadingAnchor, constant: 10),
            command_field.trailingAnchor.constraint(equalTo: top_container.trailingAnchor, constant: -10),
            command_field.heightAnchor.constraint(equalToConstant: 36),

            root_label.leadingAnchor.constraint(equalTo: command_field.leadingAnchor),
            root_label.centerYAnchor.constraint(equalTo: root_switch.centerYAnchor),

            root_switch.topAnchor.constraint(equalTo: command_field.bottomAnchor, constant: 10),
            root_switch.leadingAnchor.constraint(equalTo: root_label.trailingAnchor, constant: 10),
            root_switch.bottomAnchor.constraint(equalTo: top_container.bottomAnchor, constant: -10),

            run_button.centerYAnchor.constraint(equalTo: root_switch.centerYAnchor),
            run_button.trailingAnchor.constraint(equalTo: command_field.trailingAnchor),
            run_button.widthAnchor.constraint(equalToConstant: 72),
            run_button.heightAnchor.constraint(equalToConstant: 32),

            terminal_view.topAnchor.constraint(equalTo: top_container.bottomAnchor, constant: 12),
            terminal_view.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            terminal_view.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            terminal_view.bottomAnchor.constraint(equalTo: status_badge.topAnchor, constant: -8),

            status_badge.leadingAnchor.constraint(equalTo: terminal_view.leadingAnchor),
            status_badge.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
            status_badge.heightAnchor.constraint(equalToConstant: 22),

            activity_indicator.centerYAnchor.constraint(equalTo: status_badge.centerYAnchor),
            activity_indicator.trailingAnchor.constraint(equalTo: terminal_view.trailingAnchor)
        ])
    }

    @objc private func handle_close() {
        dismiss(animated: true)
    }

    @objc private func handle_clear() {
        terminal_view.text = ""
        status_badge.text = " READY "
        status_badge.backgroundColor = MPTheme.surface_dark
    }

    @objc private func handle_share() {
        let text = terminal_view.text ?? ""
        let ac = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        present(ac, animated: true)
    }

    @objc private func execute_command() {
        guard let cmd = command_field.text?.trimmingCharacters(in: .whitespacesAndNewlines), !cmd.isEmpty else { return }
        command_field.resignFirstResponder()

        activity_indicator.startAnimating()
        run_button.isEnabled = false
        status_badge.text = " RUNNING "
        status_badge.backgroundColor = UIColor.systemOrange

        let as_root = root_switch.isOn

        terminal_view.text = "$ \(cmd)\n\n"

        Task.detached(priority: .userInitiated) {
            let result = await self.run_process(cmd: cmd, as_root: as_root)

            await MainActor.run {
                self.activity_indicator.stopAnimating()
                self.run_button.isEnabled = true
                self.terminal_view.text.append(result.output)
                if !result.output.hasSuffix("\n") {
                    self.terminal_view.text.append("\n")
                }
                self.terminal_view.text.append("\nProcess exited with code \(result.exit_code)")

                if result.exit_code == 0 {
                    self.status_badge.text = " EXIT: 0 "
                    self.status_badge.backgroundColor = UIColor(red: 0.1, green: 0.6, blue: 0.2, alpha: 1.0)
                } else {
                    self.status_badge.text = " EXIT: \(result.exit_code) "
                    self.status_badge.backgroundColor = UIColor(red: 0.8, green: 0.2, blue: 0.2, alpha: 1.0)
                }

                let range = NSRange(location: self.terminal_view.text.count - 1, length: 1)
                self.terminal_view.scrollRangeToVisible(range)
            }
        }
    }

    private func run_process(cmd: String, as_root: Bool) async -> (output: String, exit_code: Int32) {
        var output_str = ""
        var status: Int32 = 0

        let final_cmd: String
        if as_root && PrivilegeManager.shared.is_root_available {
            let helper = RootlessPaths.jb("/Applications/MPManager.app/mpRootHelper")
            if FileManager.default.fileExists(atPath: helper) {
                final_cmd = "\(helper) sh -c '\(cmd.replacingOccurrences(of: "'", with: "'\\''"))'"
            } else {
                final_cmd = cmd
            }
        } else {
            final_cmd = cmd
        }

        var pipe_fds: [Int32] = [0, 0]
        pipe(&pipe_fds)

        var file_actions: posix_spawn_file_actions_t?
        posix_spawn_file_actions_init(&file_actions)
        defer { posix_spawn_file_actions_destroy(&file_actions) }

        posix_spawn_file_actions_adddup2(&file_actions, pipe_fds[1], STDOUT_FILENO)
        posix_spawn_file_actions_adddup2(&file_actions, pipe_fds[1], STDERR_FILENO)
        posix_spawn_file_actions_addclose(&file_actions, pipe_fds[0])

        let sh_path = "/bin/sh"
        let args = [sh_path, "-c", final_cmd]
        var c_args = args.map { strdup($0) }
        c_args.append(nil)
        defer {
            for ptr in c_args where ptr != nil { free(ptr) }
        }

        var pid: pid_t = 0
        let spawn_err = posix_spawnp(&pid, sh_path, &file_actions, nil, &c_args, environ)
        close(pipe_fds[1])

        if spawn_err != 0 {
            close(pipe_fds[0])
            return ("posix_spawn failed: \(spawn_err)", -1)
        }

        var buf = [UInt8](repeating: 0, count: 4096)
        while true {
            let n = read(pipe_fds[0], &buf, buf.count)
            if n <= 0 { break }
            output_str += String(decoding: buf[0..<n], as: UTF8.self)
        }
        close(pipe_fds[0])

        waitpid(pid, &status, 0)
        let exit_code = (status >> 8) & 0xff
        return (output_str, exit_code)
    }
}
