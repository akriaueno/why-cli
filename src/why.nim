import os
import strutils
import cligen
import why_core
import why_os

proc showResult(res: WhyResult) =
  echo "Command:     ", res.commandName
  echo "Provider:    ", res.provider
  echo "Origin Path: ", res.originPath
  echo "Real Path:   ", res.realPath

proc why(commandName: string) =
  if commandName == "why":
    echo "Checking self-identity..."

  let ctx = defaultCtx()
  let (ok, res, err) = whyCore(commandName, ctx)

  if not ok:
    stderr.writeLine err.msg
    quit err.code

  if res.hint.len > 0:
    echo res.hint

  showResult(res)

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
