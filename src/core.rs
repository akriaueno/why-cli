use std::collections::HashSet;
use std::path::{Component, Path, PathBuf};

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum MatchKind {
    Contains,
    StartsWith,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ProviderRule {
    pub name: &'static str,
    pub kind: MatchKind,
    pub patterns: Vec<String>,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ExecResult {
    pub output: String,
    pub exit_code: i32,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum DirEntryKind {
    File,
    LinkToFile,
    Other,
}

pub trait WhyCtx {
    fn get_env(&self, key: &str) -> String;
    fn get_current_dir(&self) -> String;
    fn get_home_dir(&self) -> String;
    fn file_exists(&self, path: &str) -> bool;
    fn symlink_exists(&self, path: &str) -> bool;
    fn expand_symlink(&self, path: &str) -> String;
    fn dir_exists(&self, path: &str) -> bool;
    fn list_dir(&self, dir: &str) -> Vec<(DirEntryKind, String)>;
    fn find_exe(&self, name: &str) -> String;
    fn exec_cmd(&self, cmd: &str) -> ExecResult;
    fn param_str0(&self) -> String;
}

#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct WhyResult {
    pub command_name: String,
    pub origin_path: String,
    pub real_path: String,
    pub provider: String,
    pub hint: String,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct WhyError {
    pub msg: String,
    pub code: i32,
}

pub type WhyCoreResult = Result<WhyResult, WhyError>;

pub fn default_rules(home_dir: &str) -> Vec<ProviderRule> {
    vec![
        ProviderRule {
            name: "Homebrew",
            kind: MatchKind::Contains,
            patterns: strings(&[
                "/opt/homebrew",
                "/usr/local/Cellar",
                "/home/linuxbrew/.linuxbrew",
                "/.linuxbrew/Cellar",
                "/.linuxbrew/Caskroom",
            ]),
        },
        ProviderRule {
            name: "MacPorts",
            kind: MatchKind::StartsWith,
            patterns: strings(&["/opt/local/"]),
        },
        ProviderRule {
            name: "Nix",
            kind: MatchKind::StartsWith,
            patterns: strings(&[
                "/nix/store",
                "/run/current-system/sw",
                "/nix/var/nix/profiles",
            ]),
        },
        ProviderRule {
            name: "Flatpak",
            kind: MatchKind::StartsWith,
            patterns: vec![
                "/var/lib/flatpak/exports/bin".to_string(),
                join_path(home_dir, ".local/share/flatpak/exports/bin"),
            ],
        },
        ProviderRule {
            name: "Mise",
            kind: MatchKind::Contains,
            patterns: strings(&["mise/shims", ".local/share/mise"]),
        },
        ProviderRule {
            name: "asdf",
            kind: MatchKind::Contains,
            patterns: strings(&[".asdf/shims", ".asdf/installs"]),
        },
        ProviderRule {
            name: "Snap",
            kind: MatchKind::Contains,
            patterns: strings(&["/snap/", "snap/bin"]),
        },
        ProviderRule {
            name: "SDKMAN!",
            kind: MatchKind::Contains,
            patterns: strings(&[".sdkman"]),
        },
        ProviderRule {
            name: "Volta",
            kind: MatchKind::Contains,
            patterns: strings(&[".volta"]),
        },
        ProviderRule {
            name: "nvm",
            kind: MatchKind::Contains,
            patterns: strings(&[".nvm"]),
        },
        ProviderRule {
            name: "fnm",
            kind: MatchKind::Contains,
            patterns: strings(&[".fnm", ".local/share/fnm", "fnm_multishells"]),
        },
        ProviderRule {
            name: "pyenv",
            kind: MatchKind::Contains,
            patterns: strings(&[".pyenv", "pyenv/shims"]),
        },
        ProviderRule {
            name: "rbenv",
            kind: MatchKind::Contains,
            patterns: strings(&[".rbenv", "rbenv/shims"]),
        },
        ProviderRule {
            name: "rvm",
            kind: MatchKind::Contains,
            patterns: strings(&[".rvm", "/usr/local/rvm"]),
        },
        ProviderRule {
            name: "Rustup",
            kind: MatchKind::Contains,
            patterns: strings(&[".rustup", "rustup/toolchains"]),
        },
        ProviderRule {
            name: "Conda",
            kind: MatchKind::Contains,
            patterns: strings(&[
                ".conda",
                "/miniconda",
                "/anaconda",
                "/mambaforge",
                "/miniforge",
            ]),
        },
        ProviderRule {
            name: "Scoop",
            kind: MatchKind::Contains,
            patterns: strings(&["scoop/shims", "scoop/apps"]),
        },
        ProviderRule {
            name: "Chocolatey",
            kind: MatchKind::Contains,
            patterns: strings(&["chocolatey/bin", "chocolatey/lib"]),
        },
        ProviderRule {
            name: "winget",
            kind: MatchKind::Contains,
            patterns: strings(&["WindowsApps", "Microsoft/WindowsApps"]),
        },
        ProviderRule {
            name: "Cargo",
            kind: MatchKind::Contains,
            patterns: strings(&[".cargo/bin"]),
        },
        ProviderRule {
            name: "npm",
            kind: MatchKind::Contains,
            patterns: strings(&["node_modules", "/npm", "npm/"]),
        },
        ProviderRule {
            name: "pip",
            kind: MatchKind::Contains,
            patterns: strings(&[
                "site-packages",
                "dist-packages",
                "/pipx/",
                ".local/bin/pipx",
                "/bin/pip",
                "/bin/pip3",
            ]),
        },
        ProviderRule {
            name: "Go",
            kind: MatchKind::Contains,
            patterns: strings(&["go/bin"]),
        },
        ProviderRule {
            name: "System",
            kind: MatchKind::StartsWith,
            patterns: strings(&["/bin", "/usr/bin", "/sbin", "/usr/sbin"]),
        },
    ]
}

pub fn find_origin_path(command_name: &str, ctx: &dyn WhyCtx) -> String {
    if is_explicit_command_path(command_name) {
        if ctx.file_exists(command_name) || ctx.symlink_exists(command_name) {
            return absolute_normalized_no_symlink(command_name, &ctx.get_current_dir());
        }
        return String::new();
    }

    for dir in split_path_env(&ctx.get_env("PATH")) {
        if dir.is_empty() {
            continue;
        }
        let candidate = join_path(&dir, command_name);
        if ctx.file_exists(&candidate) || ctx.symlink_exists(&candidate) {
            return absolute_normalized_no_symlink(&candidate, &ctx.get_current_dir());
        }
    }

    String::new()
}

pub fn resolve_symlink_chain(path: &str, ctx: &dyn WhyCtx) -> String {
    let mut current = path.to_string();
    let mut visited = HashSet::new();

    while ctx.symlink_exists(&current) {
        if !visited.insert(current.clone()) {
            break;
        }

        let target = ctx.expand_symlink(&current);
        current = if is_absolute_path(&target) {
            normalize_path_string(&target)
        } else {
            normalize_path_string(&join_path(&parent_dir(&current), &target))
        };
    }

    current
}

pub fn detect_provider_by_path(
    origin_path: &str,
    real_path: &str,
    rules: &[ProviderRule],
) -> String {
    let normalized_real = normalize_separators(real_path);
    let normalized_origin = normalize_separators(origin_path);
    let check_paths = [normalized_real, normalized_origin];

    for rule in rules {
        for path in &check_paths {
            if path.is_empty() {
                continue;
            }

            for pattern in &rule.patterns {
                let normalized_pattern = normalize_separators(pattern);
                match rule.kind {
                    MatchKind::Contains if path.contains(&normalized_pattern) => {
                        return rule.name.to_string();
                    }
                    MatchKind::StartsWith if path.starts_with(&normalized_pattern) => {
                        return rule.name.to_string();
                    }
                    _ => {}
                }
            }
        }
    }

    "Unknown".to_string()
}

pub fn check_system_package_manager(path: &str, ctx: &dyn WhyCtx) -> String {
    for check in [
        check_pkg_manager_dpkg,
        check_pkg_manager_rpm,
        check_pkg_manager_apk,
        check_pkg_manager_pacman,
        check_pkg_manager_portage_qfile,
        check_pkg_manager_portage_equery,
    ] {
        let detected = check(path, ctx);
        if !detected.is_empty() {
            return detected;
        }
    }

    String::new()
}

pub fn find_flatpak_fallback(short_name: &str, ctx: &dyn WhyCtx, home_dir: &str) -> String {
    let search_dirs = [
        "/var/lib/flatpak/exports/bin".to_string(),
        join_path(home_dir, ".local/share/flatpak/exports/bin"),
    ];
    let query = short_name.to_ascii_lowercase();

    for dir in search_dirs {
        if !ctx.dir_exists(&dir) {
            continue;
        }

        for (kind, path) in ctx.list_dir(&dir) {
            if matches!(kind, DirEntryKind::File | DirEntryKind::LinkToFile) {
                let filename = file_name(&path).to_ascii_lowercase();
                if filename == query || filename.ends_with(&format!(".{query}")) {
                    return path;
                }
            }
        }
    }

    String::new()
}

pub fn why_core(command_name: &str, ctx: &dyn WhyCtx) -> WhyCoreResult {
    let mut result = WhyResult {
        command_name: command_name.to_string(),
        ..WhyResult::default()
    };

    let mut origin_path;

    if command_name == "why" {
        origin_path = find_origin_path(command_name, ctx);
        if origin_path.is_empty() {
            let invoked = ctx.param_str0();
            if !invoked.is_empty() && (ctx.file_exists(&invoked) || ctx.symlink_exists(&invoked)) {
                origin_path = absolute_normalized_no_symlink(&invoked, &ctx.get_current_dir());
            }
        }
    } else {
        origin_path = find_origin_path(command_name, ctx);

        let use_flatpak_fallback = !is_explicit_command_path(command_name)
            && (origin_path.is_empty() || file_name(&origin_path) != command_name);

        if use_flatpak_fallback {
            let flatpak_path = find_flatpak_fallback(command_name, ctx, &ctx.get_home_dir());
            if flatpak_path.is_empty() {
                return Err(WhyError {
                    msg: format!("command '{command_name}' was not found"),
                    code: 1,
                });
            }

            result.hint = format!(
                "Hint: command '{command_name}' was not found in PATH, but found '{}' in Flatpak.",
                file_name(&flatpak_path)
            );
            origin_path = absolute_normalized_no_symlink(&flatpak_path, &ctx.get_current_dir());
        } else if origin_path.is_empty() {
            return Err(WhyError {
                msg: format!("command '{command_name}' was not found"),
                code: 1,
            });
        } else {
            origin_path = absolute_normalized_no_symlink(&origin_path, &ctx.get_current_dir());
        }
    }

    result.origin_path = origin_path;
    result.real_path = resolve_symlink_chain(&result.origin_path, ctx);

    let rules = default_rules(&ctx.get_home_dir());
    result.provider = detect_provider_by_path(&result.origin_path, &result.real_path, &rules);

    if result.provider == "System" || result.provider == "Unknown" {
        let sys_info = check_system_package_manager(&result.real_path, ctx);
        if !sys_info.is_empty() {
            result.provider = sys_info;
        }
    }

    Ok(result)
}

fn check_pkg_manager_dpkg(path: &str, ctx: &dyn WhyCtx) -> String {
    if ctx.find_exe("dpkg").is_empty() {
        return String::new();
    }
    let result = ctx.exec_cmd(&format!("dpkg -S {}", shell_quote(path)));
    if result.exit_code != 0 {
        return String::new();
    }
    match result
        .output
        .split(':')
        .next()
        .map(str::trim)
        .filter(|pkg| !pkg.is_empty())
    {
        Some(pkg) => format!("apt/dpkg ({pkg})"),
        None => String::new(),
    }
}

fn check_pkg_manager_rpm(path: &str, ctx: &dyn WhyCtx) -> String {
    let has_rpm = !ctx.find_exe("rpm").is_empty();
    let has_zypper = !ctx.find_exe("zypper").is_empty();
    if !has_rpm {
        return String::new();
    }
    let result = ctx.exec_cmd(&format!("rpm -qf {}", shell_quote(path)));
    if result.exit_code != 0 {
        return String::new();
    }
    let output = result.output.trim();
    if output.is_empty() {
        return String::new();
    }
    if has_zypper {
        format!("zypper/rpm ({output})")
    } else {
        format!("yum/rpm ({output})")
    }
}

fn check_pkg_manager_apk(path: &str, ctx: &dyn WhyCtx) -> String {
    if ctx.find_exe("apk").is_empty() {
        return String::new();
    }
    let result = ctx.exec_cmd(&format!("apk info -W {}", shell_quote(path)));
    if result.exit_code != 0 {
        return String::new();
    }
    let Some(pkg) = result
        .output
        .lines()
        .next()
        .map(str::trim)
        .filter(|pkg| !pkg.is_empty())
    else {
        return String::new();
    };
    format!("apk ({pkg})")
}

fn check_pkg_manager_pacman(path: &str, ctx: &dyn WhyCtx) -> String {
    if ctx.find_exe("pacman").is_empty() {
        return String::new();
    }
    let result = ctx.exec_cmd(&format!("pacman -Qo {}", shell_quote(path)));
    if result.exit_code != 0 {
        return String::new();
    }
    let trimmed = result.output.trim();
    if let Some((_, owned_by)) = trimmed.split_once(" is owned by ") {
        return format!("pacman ({})", owned_by.trim());
    }
    if trimmed.is_empty() {
        String::new()
    } else {
        format!("pacman ({trimmed})")
    }
}

fn check_pkg_manager_portage_qfile(path: &str, ctx: &dyn WhyCtx) -> String {
    if ctx.find_exe("qfile").is_empty() {
        return String::new();
    }
    let result = ctx.exec_cmd(&format!("qfile -qv {}", shell_quote(path)));
    if result.exit_code != 0 {
        return String::new();
    }
    let Some(pkg) = result
        .output
        .lines()
        .next()
        .and_then(|line| line.split_whitespace().next())
        .map(str::trim)
        .filter(|pkg| !pkg.is_empty())
    else {
        return String::new();
    };
    format!("portage ({pkg})")
}

fn check_pkg_manager_portage_equery(path: &str, ctx: &dyn WhyCtx) -> String {
    if ctx.find_exe("equery").is_empty() {
        return String::new();
    }
    let result = ctx.exec_cmd(&format!("equery b {}", shell_quote(path)));
    if result.exit_code != 0 {
        return String::new();
    }
    for line in result.output.lines() {
        if let Some(idx) = line.find(" (") {
            let pkg = line[..idx].trim();
            if !pkg.is_empty() && !pkg.starts_with('*') {
                return format!("portage ({pkg})");
            }
        }
    }
    String::new()
}

fn strings(values: &[&str]) -> Vec<String> {
    values.iter().map(|value| (*value).to_string()).collect()
}

fn split_path_env(path: &str) -> Vec<String> {
    path.split(if cfg!(windows) { ';' } else { ':' })
        .map(str::to_string)
        .collect()
}

fn absolute_normalized_no_symlink(path: &str, cwd: &str) -> String {
    if path.is_empty() {
        return String::new();
    }
    if is_absolute_path(path) {
        normalize_path_string(path)
    } else {
        normalize_path_string(&join_path(cwd, path))
    }
}

fn normalize_path_string(path: &str) -> String {
    let normalized = normalize_path(Path::new(path));
    normalized.to_string_lossy().into_owned()
}

fn normalize_path(path: &Path) -> PathBuf {
    let mut normalized = PathBuf::new();
    for component in path.components() {
        match component {
            Component::CurDir => {}
            Component::ParentDir => {
                normalized.pop();
            }
            Component::Normal(part) => normalized.push(part),
            Component::RootDir | Component::Prefix(_) => normalized.push(component.as_os_str()),
        }
    }
    normalized
}

fn normalize_separators(path: &str) -> String {
    path.replace('\\', "/")
}

fn join_path(base: &str, child: &str) -> String {
    if base.is_empty() {
        return child.to_string();
    }
    if child.is_empty() {
        return base.to_string();
    }
    if base.ends_with('/') || base.ends_with('\\') {
        format!("{base}{child}")
    } else {
        format!("{base}/{child}")
    }
}

fn parent_dir(path: &str) -> String {
    Path::new(path)
        .parent()
        .map(|parent| parent.to_string_lossy().into_owned())
        .unwrap_or_default()
}

fn file_name(path: &str) -> String {
    Path::new(path)
        .file_name()
        .map(|name| name.to_string_lossy().into_owned())
        .unwrap_or_default()
}

fn is_absolute_path(path: &str) -> bool {
    Path::new(path).is_absolute() || path.starts_with('/')
}

fn is_explicit_command_path(command_name: &str) -> bool {
    command_name.starts_with('.') || command_name.contains('/') || command_name.contains('\\')
}

fn shell_quote(value: &str) -> String {
    if value.is_empty() {
        return "''".to_string();
    }
    format!("'{}'", value.replace('\'', "'\\''"))
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::collections::HashMap;

    #[derive(Default)]
    struct FakeCtx {
        env: HashMap<String, String>,
        current_dir: String,
        home_dir: String,
        files: HashSet<String>,
        symlinks: HashMap<String, String>,
        dirs: HashSet<String>,
        dir_entries: HashMap<String, Vec<(DirEntryKind, String)>>,
        exes: HashMap<String, String>,
        commands: HashMap<String, ExecResult>,
        arg0: String,
    }

    impl FakeCtx {
        fn base() -> Self {
            Self {
                current_dir: "/work".to_string(),
                home_dir: "/home/test".to_string(),
                arg0: "/usr/bin/why".to_string(),
                ..Self::default()
            }
        }

        fn with_path(mut self, path: &str) -> Self {
            self.env.insert("PATH".to_string(), path.to_string());
            self
        }

        fn with_file(mut self, path: &str) -> Self {
            self.files.insert(path.to_string());
            self
        }

        fn with_exe(mut self, name: &str, path: &str) -> Self {
            self.exes.insert(name.to_string(), path.to_string());
            self
        }

        fn with_command(mut self, cmd: &str, output: &str, exit_code: i32) -> Self {
            self.commands.insert(
                cmd.to_string(),
                ExecResult {
                    output: output.to_string(),
                    exit_code,
                },
            );
            self
        }
    }

    impl WhyCtx for FakeCtx {
        fn get_env(&self, key: &str) -> String {
            self.env.get(key).cloned().unwrap_or_default()
        }

        fn get_current_dir(&self) -> String {
            self.current_dir.clone()
        }

        fn get_home_dir(&self) -> String {
            self.home_dir.clone()
        }

        fn file_exists(&self, path: &str) -> bool {
            self.files.contains(path)
        }

        fn symlink_exists(&self, path: &str) -> bool {
            self.symlinks.contains_key(path)
        }

        fn expand_symlink(&self, path: &str) -> String {
            self.symlinks.get(path).cloned().unwrap_or_default()
        }

        fn dir_exists(&self, path: &str) -> bool {
            self.dirs.contains(path)
        }

        fn list_dir(&self, dir: &str) -> Vec<(DirEntryKind, String)> {
            self.dir_entries.get(dir).cloned().unwrap_or_default()
        }

        fn find_exe(&self, name: &str) -> String {
            self.exes.get(name).cloned().unwrap_or_default()
        }

        fn exec_cmd(&self, cmd: &str) -> ExecResult {
            self.commands.get(cmd).cloned().unwrap_or(ExecResult {
                output: String::new(),
                exit_code: 1,
            })
        }

        fn param_str0(&self) -> String {
            self.arg0.clone()
        }
    }

    #[test]
    fn finds_origin_in_path_and_detects_provider() {
        let ctx = FakeCtx::base()
            .with_path("/usr/bin:/bin")
            .with_file("/usr/bin/node");

        let result = why_core("node", &ctx).unwrap();
        assert_eq!(result.origin_path, "/usr/bin/node");
        assert_eq!(result.provider, "System");
    }

    #[test]
    fn flatpak_fallback_returns_hint_and_path() {
        let flatpak_dir = "/var/lib/flatpak/exports/bin";
        let flatpak_exe = "/var/lib/flatpak/exports/bin/org.test.Foo";
        let mut ctx = FakeCtx::base();
        ctx.dirs.insert(flatpak_dir.to_string());
        ctx.dir_entries.insert(
            flatpak_dir.to_string(),
            vec![(DirEntryKind::File, flatpak_exe.to_string())],
        );

        let result = why_core("foo", &ctx).unwrap();
        assert!(!result.hint.is_empty());
        assert_eq!(result.origin_path, flatpak_exe);
        assert_eq!(result.provider, "Flatpak");
    }

    #[test]
    fn explicit_path_uses_that_path_without_flatpak_fallback() {
        let flatpak_dir = "/var/lib/flatpak/exports/bin";
        let mut ctx = FakeCtx::base();
        ctx.dirs.insert(flatpak_dir.to_string());
        ctx.dir_entries.insert(
            flatpak_dir.to_string(),
            vec![(
                DirEntryKind::File,
                "/var/lib/flatpak/exports/bin/org.test.Ls".to_string(),
            )],
        );
        ctx.files.insert("/usr/bin/ls".to_string());

        let result = why_core("/usr/bin/ls", &ctx).unwrap();
        assert_eq!(result.origin_path, "/usr/bin/ls");
        assert_eq!(result.provider, "System");

        let err = why_core("/usr/bin/missing", &ctx).unwrap_err();
        assert_eq!(err.code, 1);
        assert!(err.msg.contains("/usr/bin/missing"));
    }

    #[test]
    fn system_package_manager_detection_via_dpkg() {
        let ctx = FakeCtx::base()
            .with_path("/usr/bin:/bin")
            .with_file("/usr/bin/bash")
            .with_exe("dpkg", "/usr/bin/dpkg")
            .with_command("dpkg -S '/usr/bin/bash'", "bash: /usr/bin/bash\n", 0);

        let result = why_core("bash", &ctx).unwrap();
        assert_eq!(result.provider, "apt/dpkg (bash)");
    }

    #[test]
    fn system_package_manager_detection_via_zypper() {
        let ctx = FakeCtx::base()
            .with_path("/usr/bin:/bin")
            .with_file("/usr/bin/ls")
            .with_exe("zypper", "/usr/bin/zypper")
            .with_exe("rpm", "/usr/bin/rpm")
            .with_command("rpm -qf '/usr/bin/ls'", "coreutils-9.2-1\n", 0);

        let result = why_core("ls", &ctx).unwrap();
        assert_eq!(result.provider, "zypper/rpm (coreutils-9.2-1)");
    }

    #[test]
    fn detect_provider_by_path_prefers_real_path() {
        let provider = detect_provider_by_path(
            "/home/test/.local/bin/thing",
            "/usr/bin/thing",
            &default_rules("/home/test"),
        );
        assert_eq!(provider, "System");
    }

    #[test]
    fn asdf_shim_takes_precedence_over_system_path() {
        let provider = detect_provider_by_path(
            "/home/test/.asdf/shims/node",
            "/usr/bin/node",
            &default_rules("/home/test"),
        );
        assert_eq!(provider, "asdf");
    }

    #[test]
    fn detects_common_version_managers_by_path() {
        let cases = [
            (
                "asdf",
                "/home/test/.asdf/shims/node",
                "/home/test/.asdf/installs/nodejs/20.0.0/bin/node",
            ),
            (
                "SDKMAN!",
                "/home/test/.sdkman/candidates/java/current/bin/java",
                "/home/test/.sdkman/candidates/java/17.0.9/bin/java",
            ),
            (
                "nvm",
                "/home/test/.nvm/versions/node/v20.2.0/bin/node",
                "/home/test/.nvm/versions/node/v20.2.0/bin/node",
            ),
            (
                "fnm",
                "/home/test/.local/share/fnm/node-versions/v20.2.0/installation/bin/node",
                "/home/test/.local/share/fnm/node-versions/v20.2.0/installation/bin/node",
            ),
            (
                "pyenv",
                "/home/test/.pyenv/shims/python",
                "/home/test/.pyenv/versions/3.11.4/bin/python",
            ),
            (
                "rbenv",
                "/home/test/.rbenv/shims/ruby",
                "/home/test/.rbenv/versions/3.2.2/bin/ruby",
            ),
            (
                "rvm",
                "/home/test/.rvm/rubies/ruby-3.2.2/bin/ruby",
                "/home/test/.rvm/rubies/ruby-3.2.2/bin/ruby",
            ),
            (
                "Rustup",
                "/home/test/.cargo/bin/rustc",
                "/home/test/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/bin/rustc",
            ),
            (
                "Conda",
                "/home/test/miniconda3/bin/python",
                "/home/test/miniconda3/bin/python",
            ),
        ];

        let rules = default_rules("/home/test");
        for (expected, origin, real) in cases {
            assert_eq!(detect_provider_by_path(origin, real, &rules), expected);
        }
    }

    #[test]
    fn detects_package_managers_by_path() {
        let cases = [
            (
                "Homebrew",
                "/usr/local/bin/node",
                "/usr/local/Cellar/node/25.2.1/bin/node",
            ),
            (
                "Homebrew",
                "/home/linuxbrew/.linuxbrew/bin/node",
                "/home/linuxbrew/.linuxbrew/Cellar/node/25.2.1/bin/node",
            ),
            (
                "Homebrew",
                "/home/test/.linuxbrew/bin/firefox",
                "/home/test/.linuxbrew/Caskroom/firefox/145.0/firefox",
            ),
            ("MacPorts", "/opt/local/bin/port", "/opt/local/bin/port"),
            (
                "Nix",
                "/nix/store/abc123/bin/nix",
                "/nix/store/abc123/bin/nix",
            ),
            (
                "Scoop",
                r"C:\Users\bob\scoop\shims\node.exe",
                r"C:\Users\bob\scoop\apps\nodejs\current\node.exe",
            ),
            (
                "Chocolatey",
                r"C:\ProgramData\chocolatey\bin\git.exe",
                r"C:\ProgramData\chocolatey\lib\git\tools\git.exe",
            ),
            (
                "winget",
                r"C:\Program Files\WindowsApps\Microsoft.WindowsTerminal_1.20.0.0_x64__8wekyb3d8bbwe\wt.exe",
                r"C:\Program Files\WindowsApps\Microsoft.WindowsTerminal_1.20.0.0_x64__8wekyb3d8bbwe\wt.exe",
            ),
        ];

        let rules = default_rules("/home/test");
        for (expected, origin, real) in cases {
            assert_eq!(detect_provider_by_path(origin, real, &rules), expected);
        }
    }

    #[test]
    fn system_package_manager_detection_via_apk() {
        let ctx = FakeCtx::base()
            .with_path("/usr/bin:/bin")
            .with_file("/usr/bin/ls")
            .with_exe("apk", "/sbin/apk")
            .with_command("apk info -W '/usr/bin/ls'", "busybox-1.36.1-r0\n", 0);

        let result = why_core("ls", &ctx).unwrap();
        assert_eq!(result.provider, "apk (busybox-1.36.1-r0)");
    }

    #[test]
    fn system_package_manager_detection_via_pacman() {
        let ctx = FakeCtx::base()
            .with_path("/usr/bin:/bin")
            .with_file("/usr/bin/ls")
            .with_exe("pacman", "/usr/bin/pacman")
            .with_command(
                "pacman -Qo '/usr/bin/ls'",
                "/usr/bin/ls is owned by coreutils 9.2-1\n",
                0,
            );

        let result = why_core("ls", &ctx).unwrap();
        assert_eq!(result.provider, "pacman (coreutils 9.2-1)");
    }

    #[test]
    fn system_package_manager_detection_via_portage_qfile() {
        let ctx = FakeCtx::base()
            .with_path("/usr/bin:/bin")
            .with_file("/usr/bin/ls")
            .with_exe("qfile", "/usr/bin/qfile")
            .with_command(
                "qfile -qv '/usr/bin/ls'",
                "sys-apps/coreutils-9.2 /usr/bin/ls\n",
                0,
            );

        let result = why_core("ls", &ctx).unwrap();
        assert_eq!(result.provider, "portage (sys-apps/coreutils-9.2)");
    }

    #[test]
    fn system_package_manager_detection_via_portage_equery() {
        let ctx = FakeCtx::base()
            .with_path("/usr/bin:/bin")
            .with_file("/usr/bin/ls")
            .with_exe("equery", "/usr/bin/equery")
            .with_command(
                "equery b '/usr/bin/ls'",
                "sys-apps/coreutils-9.2 (/usr/bin/ls)\n",
                0,
            );

        let result = why_core("ls", &ctx).unwrap();
        assert_eq!(result.provider, "portage (sys-apps/coreutils-9.2)");
    }

    #[test]
    fn resolves_relative_symlink_chain() {
        let mut ctx = FakeCtx::base();
        ctx.symlinks.insert(
            "/home/test/.cargo/bin/rustc".to_string(),
            "../.rustup/toolchains/stable/bin/rustc".to_string(),
        );
        let resolved = resolve_symlink_chain("/home/test/.cargo/bin/rustc", &ctx);
        assert_eq!(
            resolved,
            "/home/test/.cargo/.rustup/toolchains/stable/bin/rustc"
        );
    }

    #[test]
    fn stops_on_symlink_loop() {
        let mut ctx = FakeCtx::base();
        ctx.symlinks
            .insert("/tmp/a".to_string(), "/tmp/b".to_string());
        ctx.symlinks
            .insert("/tmp/b".to_string(), "/tmp/a".to_string());

        let resolved = resolve_symlink_chain("/tmp/a", &ctx);
        assert_eq!(resolved, "/tmp/a");
    }

    #[test]
    fn command_not_found_returns_error() {
        let ctx = FakeCtx::base();
        let err = why_core("missing", &ctx).unwrap_err();
        assert_eq!(err.code, 1);
        assert!(err.msg.contains("missing"));
    }
}
