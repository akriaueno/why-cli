import os, strutils, sets, osproc
import cligen

type
  MatchKind = enum
    mkContains
    mkStartsWith

  ProviderRule = object
    name: string
    kind: MatchKind
    patterns: seq[string]

# --- Rules Configuration ---
proc getRules(): seq[ProviderRule] =
  return @[
    ProviderRule(name: "Homebrew", kind: mkContains, patterns: @[
      "/opt/homebrew", "/usr/local/cellar",
      "/home/linuxbrew/.linuxbrew", "/.linuxbrew/cellar", "/.linuxbrew/caskroom"
    ]),
    ProviderRule(name: "Flatpak", kind: mkStartsWith, patterns: @[
      "/var/lib/flatpak/exports/bin",
      getHomeDir() / ".local/share/flatpak/exports/bin"
    ]),
    ProviderRule(name: "Mise", kind: mkContains, patterns: @[
      "mise/shims", ".local/share/mise"
    ]),
    ProviderRule(name: "Snap", kind: mkContains, patterns: @[
      "/snap/", "snap/bin"
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
    ProviderRule(name: "Volta", kind: mkContains, patterns: @[
      ".volta"
    ]),
    ProviderRule(name: "Go", kind: mkContains, patterns: @[
      "go/bin"
    ]),
    ProviderRule(name: "System", kind: mkStartsWith, patterns: @[
      "/bin", "/usr/bin", "/sbin", "/usr/sbin"
    ])
  ]

proc absoluteNormalized(path: string): string =
  if path.len == 0: return path
  return normalizedPath(absolutePath(path))

proc resolveSymlinkChain(path: string): string =
  var current = path
  var visited = initHashSet[string]()
  while symlinkExists(current):
    if visited.contains(current): break
    visited.incl(current)
    var target = expandSymlink(current)
    if not isAbsolute(target):
      target = joinPath(parentDir(current), target)
    current = normalizedPath(target)
  return current

proc detectProviderByPath(originPath, realPath: string): string =
  let checkPaths = @[realPath.toLowerAscii(), originPath.toLowerAscii()]
  let rules = getRules()
  
  for rule in rules:
    for path in checkPaths:
      if path.len == 0: continue
      
      for pattern in rule.patterns:
        case rule.kind
        of mkContains:
          if pattern in path: return rule.name
        of mkStartsWith:
          if path.startsWith(pattern): 
            return rule.name
            
  return "Unknown"

proc checkSystemPackageManager(path: string): string =
  if findExe("dpkg").len > 0:
    let (outp, exitCode) = execCmdEx("dpkg -S " & quoteShell(path))
    if exitCode == 0:
      let parts = outp.split(":")
      if parts.len > 0:
        return "apt/dpkg (" & parts[0].strip() & ")"

  if findExe("rpm").len > 0:
    let (outp, exitCode) = execCmdEx("rpm -qf " & quoteShell(path))
    if exitCode == 0:
      return "yum/rpm (" & outp.strip() & ")"
  
  return ""

proc findFlatpakFallback(shortName: string): string =
  let searchDirs = @[
    "/var/lib/flatpak/exports/bin",
    getHomeDir() / ".local/share/flatpak/exports/bin"
  ]
  let query = shortName.toLowerAscii()

  for dir in searchDirs:
    if not dirExists(dir): continue
    
    for kind, path in walkDir(dir):
      if kind == pcFile or kind == pcLinkToFile:
        let filename = extractFilename(path).toLowerAscii()
        if query in filename:
          return path
  return ""

proc showResult(commandName, originPath, realPath, provider: string) =
  echo "Command:     ", commandName
  echo "Provider:    ", provider
  echo "Origin Path: ", originPath
  echo "Real Path:   ", realPath

proc why(commandName: string) =
  var originPath: string
  
  if commandName == "why":
    echo "Checking self-identity..."
    originPath = absoluteNormalized(getAppFilename())
  else:
    originPath = findExe(commandName)
    
    if originPath.len == 0:
      let flatpakPath = findFlatpakFallback(commandName)
      if flatpakPath.len > 0:
        echo "Hint: Command '" & commandName & "' not found in PATH, but found '" & extractFilename(flatpakPath) & "' in Flatpak."
        originPath = flatpakPath
      else:
        stderr.writeLine "Error: command '" & commandName & "' not found."
        quit 1
        
    originPath = absoluteNormalized(originPath)

  let realPath = resolveSymlinkChain(originPath)
  var provider = detectProviderByPath(originPath, realPath)

  if provider == "System" or provider == "Unknown":
    let sysInfo = checkSystemPackageManager(realPath)
    if sysInfo.len > 0:
      provider = sysInfo

  showResult(commandName, originPath, realPath, provider)

when isMainModule:
  let rawArgs = commandLineParams()
  var patchedArgs = rawArgs
  if rawArgs.len > 0 and not rawArgs[0].startsWith("-"):
    patchedArgs = @["--commandName=" & rawArgs[0]]
    if rawArgs.len > 1:
      patchedArgs.add(rawArgs[1..^1])

  dispatchCf(why, help = {
    "commandName": "The command to investigate (e.g. 'node', 'ls')"
  }, cmdLine = patchedArgs)