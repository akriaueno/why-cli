import os
import strutils
import sets
import osproc

type
  MatchKind* = enum
    mkContains
    mkStartsWith

  ProviderRule* = object
    name*: string
    kind*: MatchKind
    patterns*: seq[string]

  ExecResult* = tuple[outp: string, exitCode: int]

  DirEntryKind* = enum
    dekFile
    dekLinkToFile
    dekOther

  WhyCtx* = object
    getEnv*: proc(key: string): string
    getCurrentDir*: proc(): string
    getHomeDir*: proc(): string
    fileExists*: proc(path: string): bool
    symlinkExists*: proc(path: string): bool
    expandSymlink*: proc(path: string): string
    dirExists*: proc(path: string): bool
    listDir*: proc(dir: string): seq[(DirEntryKind, string)]
    findExe*: proc(name: string): string
    execCmd*: proc(cmd: string): ExecResult
    paramStr0*: proc(): string

  WhyResult* = object
    commandName*: string
    originPath*: string
    realPath*: string
    provider*: string
    hint*: string

  WhyError* = object
    msg*: string
    code*: int

proc defaultRules*(homeDir: string): seq[ProviderRule] =
  return @[
    ProviderRule(name: "Homebrew", kind: mkContains, patterns: @[
      "/opt/homebrew", "/usr/local/cellar",
      "/home/linuxbrew/.linuxbrew", "/.linuxbrew/cellar", "/.linuxbrew/caskroom"
    ]),
    ProviderRule(name: "MacPorts", kind: mkStartsWith, patterns: @[
      "/opt/local/"
    ]),
    ProviderRule(name: "Nix", kind: mkStartsWith, patterns: @[
      "/nix/store", "/run/current-system/sw", "/nix/var/nix/profiles"
    ]),
    ProviderRule(name: "Flatpak", kind: mkStartsWith, patterns: @[
      "/var/lib/flatpak/exports/bin",
      homeDir / ".local/share/flatpak/exports/bin"
    ]),
    ProviderRule(name: "Mise", kind: mkContains, patterns: @[
      "mise/shims", ".local/share/mise"
    ]),
    ProviderRule(name: "asdf", kind: mkContains, patterns: @[
      ".asdf/shims", ".asdf/installs"
    ]),
    ProviderRule(name: "Snap", kind: mkContains, patterns: @[
      "/snap/", "snap/bin"
    ]),
    ProviderRule(name: "SDKMAN!", kind: mkContains, patterns: @[
      ".sdkman"
    ]),
    ProviderRule(name: "Volta", kind: mkContains, patterns: @[
      ".volta"
    ]),
    ProviderRule(name: "nvm", kind: mkContains, patterns: @[
      ".nvm"
    ]),
    ProviderRule(name: "fnm", kind: mkContains, patterns: @[
      ".fnm", ".local/share/fnm", "fnm_multishells"
    ]),
    ProviderRule(name: "pyenv", kind: mkContains, patterns: @[
      ".pyenv", "pyenv/shims"
    ]),
    ProviderRule(name: "rbenv", kind: mkContains, patterns: @[
      ".rbenv", "rbenv/shims"
    ]),
    ProviderRule(name: "rvm", kind: mkContains, patterns: @[
      ".rvm", "/usr/local/rvm"
    ]),
    ProviderRule(name: "Rustup", kind: mkContains, patterns: @[
      ".rustup", "rustup/toolchains"
    ]),
    ProviderRule(name: "Conda", kind: mkContains, patterns: @[
      ".conda", "/miniconda", "/anaconda", "/mambaforge", "/miniforge"
    ]),
    ProviderRule(name: "Scoop", kind: mkContains, patterns: @[
      "scoop/shims", "scoop/apps"
    ]),
    ProviderRule(name: "Chocolatey", kind: mkContains, patterns: @[
      "chocolatey/bin", "chocolatey/lib"
    ]),
    ProviderRule(name: "winget", kind: mkContains, patterns: @[
      "WindowsApps", "Microsoft/WindowsApps"
    ]),
    ProviderRule(name: "Cargo", kind: mkContains, patterns: @[
      ".cargo/bin"
    ]),
    ProviderRule(name: "npm", kind: mkContains, patterns: @[
      "node_modules", "/npm", "npm/"
    ]),
    ProviderRule(name: "pip", kind: mkContains, patterns: @[
      "site-packages", "dist-packages", "/pipx/", ".local/bin/pipx",
      "/bin/pip", "/bin/pip3"
    ]),
    ProviderRule(name: "Go", kind: mkContains, patterns: @[
      "go/bin"
    ]),
    ProviderRule(name: "System", kind: mkStartsWith, patterns: @[
      "/bin", "/usr/bin", "/sbin", "/usr/sbin"
    ])
  ]

proc absoluteNormalizedNoSymlink(path: string, cwd: string): string =
  if path.len == 0:
    return path
  if isAbsolute(path):
    return normalizedPath(path)
  return normalizedPath(cwd / path)

proc findOriginPath*(commandName: string, ctx: WhyCtx): string =
  if commandName.contains(DirSep):
    if ctx.fileExists(commandName) or ctx.symlinkExists(commandName):
      return absoluteNormalizedNoSymlink(commandName, ctx.getCurrentDir())
    return ""

  for dir in ctx.getEnv("PATH").split(PathSep):
    if dir.len == 0:
      continue
    let candidate = dir / commandName
    if ctx.fileExists(candidate) or ctx.symlinkExists(candidate):
      return absoluteNormalizedNoSymlink(candidate, ctx.getCurrentDir())

  ""

proc resolveSymlinkChain*(path: string, ctx: WhyCtx): string =
  var current = path
  var visited = initHashSet[string]()
  while ctx.symlinkExists(current):
    if visited.contains(current):
      break
    visited.incl(current)
    var target = ctx.expandSymlink(current)
    if not isAbsolute(target):
      target = joinPath(parentDir(current), target)
    current = normalizedPath(target)
  return current

proc detectProviderByPath*(originPath, realPath: string, rules: seq[ProviderRule]): string =
  let normalizedReal = realPath.replace('\\', '/')
  let normalizedOrigin = originPath.replace('\\', '/')
  let checkPaths = @[normalizedReal, normalizedOrigin]

  for rule in rules:
    for path in checkPaths:
      if path.len == 0:
        continue

      for pattern in rule.patterns:
        let normalizedPattern = pattern.replace('\\', '/')
        case rule.kind
        of mkContains:
          if normalizedPattern in path:
            return rule.name
        of mkStartsWith:
          if path.startsWith(normalizedPattern):
            return rule.name

  return "Unknown"

type
  PkgManagerStrategy = object
    name: string
    cmd: proc(path: string, ctx: WhyCtx): string {.nimcall.}

proc checkPkgManagerDpkg(path: string, ctx: WhyCtx): string =
  if ctx.findExe("dpkg").len == 0:
    return ""
  let (outp, exitCode) = ctx.execCmd("dpkg -S " & quoteShell(path))
  if exitCode != 0:
    return ""
  let parts = outp.split(":")
  if parts.len == 0:
    return ""
  return "apt/dpkg (" & parts[0].strip() & ")"

proc checkPkgManagerRpm(path: string, ctx: WhyCtx): string =
  let hasRpm = ctx.findExe("rpm").len > 0
  let hasZypper = ctx.findExe("zypper").len > 0
  if not hasRpm:
    return ""
  let (outp, exitCode) = ctx.execCmd("rpm -qf " & quoteShell(path))
  if exitCode != 0:
    return ""
  if hasZypper:
    return "zypper/rpm (" & outp.strip() & ")"
  return "yum/rpm (" & outp.strip() & ")"

proc checkPkgManagerApk(path: string, ctx: WhyCtx): string =
  if ctx.findExe("apk").len == 0:
    return ""
  let (outp, exitCode) = ctx.execCmd("apk info -W " & quoteShell(path))
  if exitCode != 0:
    return ""
  let lines = outp.splitLines()
  if lines.len == 0:
    return ""
  let pkg = lines[0].strip()
  if pkg.len == 0:
    return ""
  return "apk (" & pkg & ")"

proc checkPkgManagerPacman(path: string, ctx: WhyCtx): string =
  if ctx.findExe("pacman").len == 0:
    return ""
  let (outp, exitCode) = ctx.execCmd("pacman -Qo " & quoteShell(path))
  if exitCode != 0:
    return ""
  let trimmed = outp.strip()
  let marker = " is owned by "
  if trimmed.contains(marker):
    let parts = trimmed.split(marker)
    if parts.len > 1:
      return "pacman (" & parts[1].strip() & ")"
  if trimmed.len > 0:
    return "pacman (" & trimmed & ")"
  return ""

proc checkPkgManagerPortageQfile(path: string, ctx: WhyCtx): string =
  if ctx.findExe("qfile").len == 0:
    return ""
  let (outp, exitCode) = ctx.execCmd("qfile -qv " & quoteShell(path))
  if exitCode != 0:
    return ""
  let lines = outp.splitLines()
  if lines.len == 0:
    return ""
  let tokens = lines[0].splitWhitespace()
  if tokens.len == 0:
    return ""
  return "portage (" & tokens[0].strip() & ")"

proc checkPkgManagerPortageEquery(path: string, ctx: WhyCtx): string =
  if ctx.findExe("equery").len == 0:
    return ""
  let (outp, exitCode) = ctx.execCmd("equery b " & quoteShell(path))
  if exitCode != 0:
    return ""
  for line in outp.splitLines():
    let idx = line.find(" (")
    if idx > 0:
      let pkg = line[0..<idx].strip()
      if pkg.len > 0 and not pkg.startsWith("*"):
        return "portage (" & pkg & ")"
  return ""

proc checkSystemPackageManager*(path: string, ctx: WhyCtx): string =
  let checks = @[
    PkgManagerStrategy(name: "dpkg", cmd: checkPkgManagerDpkg),
    PkgManagerStrategy(name: "rpm", cmd: checkPkgManagerRpm),
    PkgManagerStrategy(name: "apk", cmd: checkPkgManagerApk),
    PkgManagerStrategy(name: "pacman", cmd: checkPkgManagerPacman),
    PkgManagerStrategy(name: "qfile", cmd: checkPkgManagerPortageQfile),
    PkgManagerStrategy(name: "equery", cmd: checkPkgManagerPortageEquery),
  ]
  for check in checks:
    let detected = check.cmd(path, ctx)
    if detected.len > 0:
      return detected

  return ""

proc findFlatpakFallback*(shortName: string, ctx: WhyCtx, homeDir: string): string =
  let searchDirs = @[
    "/var/lib/flatpak/exports/bin",
    homeDir / ".local/share/flatpak/exports/bin"
  ]
  let query = shortName.toLowerAscii()

  for dir in searchDirs:
    if not ctx.dirExists(dir):
      continue

    for entry in ctx.listDir(dir):
      let kind = entry[0]
      let path = entry[1]
      if kind == dekFile or kind == dekLinkToFile:
        let filename = extractFilename(path).toLowerAscii()
        if filename == query or filename.endsWith("." & query):
          return path
  return ""

proc whyCore*(commandName: string, ctx: WhyCtx): tuple[ok: bool, res: WhyResult, err: WhyError] =
  var res: WhyResult
  res.commandName = commandName

  var originPath = ""

  if commandName == "why":
    originPath = findOriginPath(commandName, ctx)
    if originPath.len == 0:
      let invoked = ctx.paramStr0()
      if invoked.len > 0 and (ctx.fileExists(invoked) or ctx.symlinkExists(invoked)):
        originPath = absoluteNormalizedNoSymlink(invoked, ctx.getCurrentDir())
  else:
    originPath = findOriginPath(commandName, ctx)

    if originPath.len == 0 or extractFilename(originPath) != commandName:
      let flatpakPath = findFlatpakFallback(commandName, ctx, ctx.getHomeDir())
      if flatpakPath.len > 0:
        res.hint = "Hint: Command '" & commandName & "' not found in PATH, but found '" &
          extractFilename(flatpakPath) & "' in Flatpak."
        originPath = absoluteNormalizedNoSymlink(flatpakPath, ctx.getCurrentDir())
      else:
        return (false, WhyResult(), WhyError(msg: "Error: command '" & commandName & "' not found.", code: 1))

    originPath = absoluteNormalizedNoSymlink(originPath, ctx.getCurrentDir())

  res.originPath = originPath
  res.realPath = resolveSymlinkChain(originPath, ctx)

  let rules = defaultRules(ctx.getHomeDir())
  res.provider = detectProviderByPath(res.originPath, res.realPath, rules)

  if res.provider == "System" or res.provider == "Unknown":
    let sysInfo = checkSystemPackageManager(res.realPath, ctx)
    if sysInfo.len > 0:
      res.provider = sysInfo

  return (true, res, WhyError())
