import std/[unittest, tables]
import ../src/why_core

suite "whyCore":
  test "finds origin in PATH and detects provider":
    var files = {"/usr/bin/node": true}.toTable

    let ctx = WhyCtx(
      getEnv: proc(key: string): string =
        if key == "PATH": "/usr/bin:/bin" else: "",
      getCurrentDir: proc(): string = "/work",
      getHomeDir: proc(): string = "/home/test",
      fileExists: proc(p: string): bool = files.getOrDefault(p, false),
      symlinkExists: proc(p: string): bool = false,
      expandSymlink: proc(p: string): string = "",
      dirExists: proc(p: string): bool = false,
      listDir: proc(dir: string): seq[(DirEntryKind, string)] = @[],
      findExe: proc(name: string): string = "",
      execCmd: proc(cmd: string): ExecResult = ("", 1),
      paramStr0: proc(): string = "/usr/bin/why"
    )

    let (ok, res, err) = whyCore("node", ctx)
    check ok
    check err.msg.len == 0
    check res.originPath == "/usr/bin/node"
    check res.provider == "System"

  test "flatpak fallback returns hint and path":
    let flatpakDir = "/var/lib/flatpak/exports/bin"
    let flatpakExe = flatpakDir & "/org.test.Foo"

    let ctx = WhyCtx(
      getEnv: proc(key: string): string = "",
      getCurrentDir: proc(): string = "/work",
      getHomeDir: proc(): string = "/home/test",
      fileExists: proc(p: string): bool = false,
      symlinkExists: proc(p: string): bool = false,
      expandSymlink: proc(p: string): string = "",
      dirExists: proc(p: string): bool = p == flatpakDir,
      listDir: proc(dir: string): seq[(DirEntryKind, string)] =
        if dir == flatpakDir: @[(dekFile, flatpakExe)] else: @[],
      findExe: proc(name: string): string = "",
      execCmd: proc(cmd: string): ExecResult = ("", 1),
      paramStr0: proc(): string = "/usr/bin/why"
    )

    let (ok, res, err) = whyCore("foo", ctx)
    check ok
    check err.msg.len == 0
    check res.hint.len > 0
    check res.originPath == flatpakExe
    check res.provider == "Flatpak"

  test "system package manager detection via dpkg":
    var files = {"/usr/bin/bash": true}.toTable

    let ctx = WhyCtx(
      getEnv: proc(key: string): string =
        if key == "PATH": "/usr/bin:/bin" else: "",
      getCurrentDir: proc(): string = "/work",
      getHomeDir: proc(): string = "/home/test",
      fileExists: proc(p: string): bool = files.getOrDefault(p, false),
      symlinkExists: proc(p: string): bool = false,
      expandSymlink: proc(p: string): string = "",
      dirExists: proc(p: string): bool = false,
      listDir: proc(dir: string): seq[(DirEntryKind, string)] = @[],
      findExe: proc(name: string): string =
        if name == "dpkg": "/usr/bin/dpkg" else: "",
      execCmd: proc(cmd: string): ExecResult = ("bash: /usr/bin/bash\n", 0),
      paramStr0: proc(): string = "/usr/bin/why"
    )

    let (ok, res, err) = whyCore("bash", ctx)
    check ok
    check err.msg.len == 0
    check res.provider == "apt/dpkg (bash)"

  test "system package manager detection via zypper":
    var files = {"/usr/bin/ls": true}.toTable

    let ctx = WhyCtx(
      getEnv: proc(key: string): string =
        if key == "PATH": "/usr/bin:/bin" else: "",
      getCurrentDir: proc(): string = "/work",
      getHomeDir: proc(): string = "/home/test",
      fileExists: proc(p: string): bool = files.getOrDefault(p, false),
      symlinkExists: proc(p: string): bool = false,
      expandSymlink: proc(p: string): string = "",
      dirExists: proc(p: string): bool = false,
      listDir: proc(dir: string): seq[(DirEntryKind, string)] = @[],
      findExe: proc(name: string): string =
        if name == "zypper": "/usr/bin/zypper"
        elif name == "rpm": "/usr/bin/rpm"
        else: "",
      execCmd: proc(cmd: string): ExecResult = ("coreutils-9.2-1\n", 0),
      paramStr0: proc(): string = "/usr/bin/why"
    )

    let (ok, res, err) = whyCore("ls", ctx)
    check ok
    check err.msg.len == 0
    check res.provider == "zypper/rpm (coreutils-9.2-1)"

  test "detectProviderByPath prefers real path":
    let rules = defaultRules("/home/test")
    let provider = detectProviderByPath(
      "/home/test/.local/bin/thing",
      "/usr/bin/thing",
      rules
    )
    check provider == "System"

  test "detects common version managers by path":
    let rules = defaultRules("/home/test")
    let cases = {
      "asdf": ("/home/test/.asdf/shims/node", "/home/test/.asdf/installs/nodejs/20.0.0/bin/node"),
      "SDKMAN!": ("/home/test/.sdkman/candidates/java/current/bin/java", "/home/test/.sdkman/candidates/java/17.0.9/bin/java"),
      "nvm": ("/home/test/.nvm/versions/node/v20.2.0/bin/node", "/home/test/.nvm/versions/node/v20.2.0/bin/node"),
      "fnm": ("/home/test/.local/share/fnm/node-versions/v20.2.0/installation/bin/node", "/home/test/.local/share/fnm/node-versions/v20.2.0/installation/bin/node"),
      "pyenv": ("/home/test/.pyenv/shims/python", "/home/test/.pyenv/versions/3.11.4/bin/python"),
      "rbenv": ("/home/test/.rbenv/shims/ruby", "/home/test/.rbenv/versions/3.2.2/bin/ruby"),
      "rvm": ("/home/test/.rvm/rubies/ruby-3.2.2/bin/ruby", "/home/test/.rvm/rubies/ruby-3.2.2/bin/ruby"),
      "Rustup": ("/home/test/.cargo/bin/rustc", "/home/test/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/bin/rustc"),
      "Conda": ("/home/test/miniconda3/bin/python", "/home/test/miniconda3/bin/python")
    }.toTable

    for expected, paths in cases:
      let provider = detectProviderByPath(paths[0], paths[1], rules)
      check provider == expected

  test "detects package managers by path":
    let rules = defaultRules("/home/test")
    let cases = {
      "MacPorts": ("/opt/local/bin/port", "/opt/local/bin/port"),
      "Nix": ("/nix/store/abc123/bin/nix", "/nix/store/abc123/bin/nix"),
      "Scoop": ("C:\\Users\\bob\\scoop\\shims\\node.exe", "C:\\Users\\bob\\scoop\\apps\\nodejs\\current\\node.exe"),
      "Chocolatey": ("C:\\ProgramData\\chocolatey\\bin\\git.exe", "C:\\ProgramData\\chocolatey\\lib\\git\\tools\\git.exe"),
      "winget": ("C:\\Program Files\\WindowsApps\\Microsoft.WindowsTerminal_1.20.0.0_x64__8wekyb3d8bbwe\\wt.exe",
                 "C:\\Program Files\\WindowsApps\\Microsoft.WindowsTerminal_1.20.0.0_x64__8wekyb3d8bbwe\\wt.exe")
    }.toTable

    for expected, paths in cases:
      let provider = detectProviderByPath(paths[0], paths[1], rules)
      check provider == expected

  test "system package manager detection via apk":
    var files = {"/usr/bin/ls": true}.toTable

    let ctx = WhyCtx(
      getEnv: proc(key: string): string =
        if key == "PATH": "/usr/bin:/bin" else: "",
      getCurrentDir: proc(): string = "/work",
      getHomeDir: proc(): string = "/home/test",
      fileExists: proc(p: string): bool = files.getOrDefault(p, false),
      symlinkExists: proc(p: string): bool = false,
      expandSymlink: proc(p: string): string = "",
      dirExists: proc(p: string): bool = false,
      listDir: proc(dir: string): seq[(DirEntryKind, string)] = @[],
      findExe: proc(name: string): string =
        if name == "apk": "/sbin/apk" else: "",
      execCmd: proc(cmd: string): ExecResult = ("busybox-1.36.1-r0\n", 0),
      paramStr0: proc(): string = "/usr/bin/why"
    )

    let (ok, res, err) = whyCore("ls", ctx)
    check ok
    check err.msg.len == 0
    check res.provider == "apk (busybox-1.36.1-r0)"

  test "system package manager detection via pacman":
    var files = {"/usr/bin/ls": true}.toTable

    let ctx = WhyCtx(
      getEnv: proc(key: string): string =
        if key == "PATH": "/usr/bin:/bin" else: "",
      getCurrentDir: proc(): string = "/work",
      getHomeDir: proc(): string = "/home/test",
      fileExists: proc(p: string): bool = files.getOrDefault(p, false),
      symlinkExists: proc(p: string): bool = false,
      expandSymlink: proc(p: string): string = "",
      dirExists: proc(p: string): bool = false,
      listDir: proc(dir: string): seq[(DirEntryKind, string)] = @[],
      findExe: proc(name: string): string =
        if name == "pacman": "/usr/bin/pacman" else: "",
      execCmd: proc(cmd: string): ExecResult = ("/usr/bin/ls is owned by coreutils 9.2-1\n", 0),
      paramStr0: proc(): string = "/usr/bin/why"
    )

    let (ok, res, err) = whyCore("ls", ctx)
    check ok
    check err.msg.len == 0
    check res.provider == "pacman (coreutils 9.2-1)"

  test "system package manager detection via portage qfile":
    var files = {"/usr/bin/ls": true}.toTable

    let ctx = WhyCtx(
      getEnv: proc(key: string): string =
        if key == "PATH": "/usr/bin:/bin" else: "",
      getCurrentDir: proc(): string = "/work",
      getHomeDir: proc(): string = "/home/test",
      fileExists: proc(p: string): bool = files.getOrDefault(p, false),
      symlinkExists: proc(p: string): bool = false,
      expandSymlink: proc(p: string): string = "",
      dirExists: proc(p: string): bool = false,
      listDir: proc(dir: string): seq[(DirEntryKind, string)] = @[],
      findExe: proc(name: string): string =
        if name == "qfile": "/usr/bin/qfile" else: "",
      execCmd: proc(cmd: string): ExecResult = ("sys-apps/coreutils-9.2 /usr/bin/ls\n", 0),
      paramStr0: proc(): string = "/usr/bin/why"
    )

    let (ok, res, err) = whyCore("ls", ctx)
    check ok
    check err.msg.len == 0
    check res.provider == "portage (sys-apps/coreutils-9.2)"
