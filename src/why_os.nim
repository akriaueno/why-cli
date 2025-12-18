import os
import osproc
import why_core

proc listDirImpl(dir: string): seq[(DirEntryKind, string)] =
  var entries: seq[(DirEntryKind, string)] = @[]
  for kind, path in walkDir(dir):
    let entryKind =
      case kind
      of pcFile:
        dekFile
      of pcLinkToFile:
        dekLinkToFile
      else:
        dekOther
    entries.add((entryKind, path))
  return entries

proc execCmdImpl(cmd: string): ExecResult =
  let (outp, exitCode) = execCmdEx(cmd)
  return (outp, exitCode)

proc defaultCtx*(): WhyCtx =
  WhyCtx(
    getEnv: proc(key: string): string = getEnv(key),
    getCurrentDir: proc(): string = getCurrentDir(),
    getHomeDir: proc(): string = getHomeDir(),
    fileExists: proc(path: string): bool = fileExists(path),
    symlinkExists: proc(path: string): bool = symlinkExists(path),
    expandSymlink: proc(path: string): string = expandSymlink(path),
    dirExists: proc(path: string): bool = dirExists(path),
    listDir: listDirImpl,
    findExe: proc(name: string): string = findExe(name),
    execCmd: execCmdImpl,
    paramStr0: proc(): string = paramStr(0)
  )
