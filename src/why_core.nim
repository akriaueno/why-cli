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
    ProviderRule(name: "Snap", kind: mkContains, patterns: @[
      "/snap/", "snap/bin"
    ]),
    ProviderRule(name: "asdf", kind: mkContains, patterns: @[
      ".asdf/shims", ".asdf/installs"
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
      "scoop/shims", "scoop/apps", "scoop\\shims", "scoop\\apps"
    ]),
    ProviderRule(name: "Chocolatey", kind: mkContains, patterns: @[
      "chocolatey/bin", "chocolatey/lib", "chocolatey\\bin", "chocolatey\\lib"
    ]),
    ProviderRule(name: "winget", kind: mkContains, patterns: @[
      "WindowsApps", "Microsoft\\WindowsApps"
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
  let checkPaths = @[realPath, originPath]

  for rule in rules:
    for path in checkPaths:
      if path.len == 0:
        continue

      for pattern in rule.patterns:
        case rule.kind
        of mkContains:
          if pattern in path:
            return rule.name
        of mkStartsWith:
          if path.startsWith(pattern):
            return rule.name

  return "Unknown"

proc checkSystemPackageManager*(path: string, ctx: WhyCtx): string =
  if ctx.findExe("dpkg").len > 0:
    let (outp, exitCode) = ctx.execCmd("dpkg -S " & quoteShell(path))
    if exitCode == 0:
      let parts = outp.split(":")
      if parts.len > 0:
        return "apt/dpkg (" & parts[0].strip() & ")"

  if ctx.findExe("zypper").len > 0 and ctx.findExe("rpm").len > 0:
    let (outp, exitCode) = ctx.execCmd("rpm -qf " & quoteShell(path))
    if exitCode == 0:
      return "zypper/rpm (" & outp.strip() & ")"

  if ctx.findExe("rpm").len > 0:
    let (outp, exitCode) = ctx.execCmd("rpm -qf " & quoteShell(path))
    if exitCode == 0:
      return "yum/rpm (" & outp.strip() & ")"

  if ctx.findExe("apk").len > 0:
    let (outp, exitCode) = ctx.execCmd("apk info -W " & quoteShell(path))
    if exitCode == 0:
      let lines = outp.splitLines()
      if lines.len > 0 and lines[0].strip().len > 0:
        return "apk (" & lines[0].strip() & ")"

  if ctx.findExe("pacman").len > 0:
    let (outp, exitCode) = ctx.execCmd("pacman -Qo " & quoteShell(path))
    if exitCode == 0:
      let trimmed = outp.strip()
      let marker = " is owned by "
      if trimmed.contains(marker):
        let parts = trimmed.split(marker)
        if parts.len > 1:
          return "pacman (" & parts[1].strip() & ")"
      if trimmed.len > 0:
        return "pacman (" & trimmed & ")"

  if ctx.findExe("qfile").len > 0:
    let (outp, exitCode) = ctx.execCmd("qfile -qv " & quoteShell(path))
    if exitCode == 0:
      let lines = outp.splitLines()
      if lines.len > 0:
        let tokens = lines[0].splitWhitespace()
        if tokens.len > 0:
          return "portage (" & tokens[0].strip() & ")"

  if ctx.findExe("equery").len > 0:
    let (outp, exitCode) = ctx.execCmd("equery b " & quoteShell(path))
    if exitCode == 0:
      for line in outp.splitLines():
        let idx = line.find(" (")
        if idx > 0:
          let pkg = line[0..<idx].strip()
          if pkg.len > 0 and not pkg.startsWith("*"):
            return "portage (" & pkg & ")"

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
