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

  test "detectProviderByPath prefers real path":
    let rules = defaultRules("/home/test")
    let provider = detectProviderByPath(
      "/home/test/.local/bin/thing",
      "/usr/bin/thing",
      rules
    )
    check provider == "System"
