import os, strutils, sets
import cligen

type
  MatchKind = enum
    mkContains
    mkStartsWith

  ProviderRule = object
    name: string
    kind: MatchKind
    patterns: seq[string]

const rules: seq[ProviderRule] = @[
  ProviderRule(name: "Homebrew", kind: mkContains, patterns: @[
    "/opt/homebrew", "/usr/local/cellar",
    "/home/linuxbrew/.linuxbrew", "/.linuxbrew/cellar", "/.linuxbrew/caskroom"
  ]),
  ProviderRule(name: "Mise", kind: mkContains, patterns: @[
    "mise/shims", ".local/share/mise"
  ]),
  ProviderRule(name: "Cargo", kind: mkContains, patterns: @[
    ".cargo/bin"
  ]),
  ProviderRule(name: "npm (Global)", kind: mkContains, patterns: @[
    "node_modules", "/npm", "npm/"
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

proc detectProvider(originPath, realPath: string): string =
  let checkPaths = @[realPath.toLowerAscii(), originPath.toLowerAscii()]
  
  for rule in rules:
    for path in checkPaths:
      if path.len == 0: continue
      
      for pattern in rule.patterns:
        case rule.kind
        of mkContains:
          if pattern in path: return rule.name
        of mkStartsWith:
          if path.startsWith(pattern & "/") or path == pattern:
            return rule.name
            
  return "Unknown"

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
      stderr.writeLine "Error: command '" & commandName & "' not found."
      quit 1
    originPath = absoluteNormalized(originPath)

  let realPath = resolveSymlinkChain(originPath)
  let provider = detectProvider(originPath, realPath)
  showResult(commandName, originPath, realPath, provider)

# --- Entry Point ---

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
