mod core;

use std::env;
use std::fs;
use std::path::Path;
use std::process::{Command, ExitCode};

use clap::{Parser, ValueEnum, ValueHint};

use crate::core::{DirEntryKind, ExecResult, WhyCtx, why_core};

#[derive(Parser, Debug)]
#[command(
    name = "why",
    version,
    about = "Identify why a command is installed on your system"
)]
struct Args {
    /// Print a shell completion script.
    #[arg(long, value_enum, value_name = "SHELL", conflicts_with = "command")]
    completion: Option<CompletionShell>,

    /// The command to investigate, for example 'node' or 'ls'.
    #[arg(value_hint = ValueHint::CommandName, required_unless_present = "completion")]
    command: Option<String>,
}

#[derive(Copy, Clone, Debug, Eq, PartialEq, ValueEnum)]
enum CompletionShell {
    Bash,
    Zsh,
    Fish,
}

struct DefaultCtx;

impl WhyCtx for DefaultCtx {
    fn get_env(&self, key: &str) -> String {
        env::var(key).unwrap_or_default()
    }

    fn get_current_dir(&self) -> String {
        env::current_dir()
            .map(|path| path.to_string_lossy().into_owned())
            .unwrap_or_default()
    }

    fn get_home_dir(&self) -> String {
        env::var("HOME")
            .or_else(|_| env::var("USERPROFILE"))
            .unwrap_or_default()
    }

    fn file_exists(&self, path: &str) -> bool {
        Path::new(path).is_file()
    }

    fn symlink_exists(&self, path: &str) -> bool {
        fs::symlink_metadata(path)
            .map(|meta| meta.file_type().is_symlink())
            .unwrap_or(false)
    }

    fn expand_symlink(&self, path: &str) -> String {
        fs::read_link(path)
            .map(|target| target.to_string_lossy().into_owned())
            .unwrap_or_default()
    }

    fn dir_exists(&self, path: &str) -> bool {
        Path::new(path).is_dir()
    }

    fn list_dir(&self, dir: &str) -> Vec<(DirEntryKind, String)> {
        let Ok(entries) = fs::read_dir(dir) else {
            return Vec::new();
        };

        entries
            .filter_map(Result::ok)
            .map(|entry| {
                let kind = entry
                    .file_type()
                    .map(|file_type| {
                        if file_type.is_file() {
                            DirEntryKind::File
                        } else if file_type.is_symlink() {
                            DirEntryKind::LinkToFile
                        } else {
                            DirEntryKind::Other
                        }
                    })
                    .unwrap_or(DirEntryKind::Other);
                (kind, entry.path().to_string_lossy().into_owned())
            })
            .collect()
    }

    fn find_exe(&self, name: &str) -> String {
        let path = env::var("PATH").unwrap_or_default();
        let separator = if cfg!(windows) { ';' } else { ':' };
        for dir in path.split(separator).filter(|dir| !dir.is_empty()) {
            let candidate = if dir.ends_with('/') || dir.ends_with('\\') {
                format!("{dir}{name}")
            } else {
                format!("{dir}/{name}")
            };
            if Path::new(&candidate).is_file() {
                return candidate;
            }
        }
        String::new()
    }

    fn exec_cmd(&self, cmd: &str) -> ExecResult {
        let output = if cfg!(windows) {
            Command::new("cmd").args(["/C", cmd]).output()
        } else {
            Command::new("sh").args(["-c", cmd]).output()
        };

        match output {
            Ok(output) => ExecResult {
                output: String::from_utf8_lossy(&output.stdout).into_owned(),
                exit_code: output.status.code().unwrap_or(1),
            },
            Err(_) => ExecResult {
                output: String::new(),
                exit_code: 1,
            },
        }
    }

    fn param_str0(&self) -> String {
        env::args().next().unwrap_or_default()
    }
}

fn main() -> ExitCode {
    let args = Args::parse();
    if let Some(shell) = args.completion {
        print!("{}", completion_script(shell));
        return ExitCode::SUCCESS;
    }

    let Some(command) = args.command else {
        return ExitCode::from(2);
    };

    let ctx = DefaultCtx;

    match why_core(&command, &ctx) {
        Ok(result) => {
            if !result.hint.is_empty() {
                println!("{}", result.hint);
            }
            println!("Command:     {}", result.command_name);
            println!("Provider:    {}", result.provider);
            println!("Origin Path: {}", result.origin_path);
            println!("Real Path:   {}", result.real_path);
            ExitCode::SUCCESS
        }
        Err(err) => {
            eprintln!("Error: {}", err.msg);
            ExitCode::from(err.code as u8)
        }
    }
}

fn completion_script(shell: CompletionShell) -> &'static str {
    match shell {
        CompletionShell::Bash => BASH_COMPLETION,
        CompletionShell::Zsh => ZSH_COMPLETION,
        CompletionShell::Fish => FISH_COMPLETION,
    }
}

const BASH_COMPLETION: &str = include_str!("../completions/why.bash");
const ZSH_COMPLETION: &str = include_str!("../completions/_why");
const FISH_COMPLETION: &str = include_str!("../completions/why.fish");

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_completion_without_command() {
        let args = Args::try_parse_from(["why", "--completion", "bash"]).unwrap();

        assert_eq!(args.completion, Some(CompletionShell::Bash));
        assert_eq!(args.command, None);
    }

    #[test]
    fn requires_command_without_completion() {
        assert!(Args::try_parse_from(["why"]).is_err());
    }

    #[test]
    fn completion_conflicts_with_command() {
        assert!(Args::try_parse_from(["why", "--completion", "bash", "ls"]).is_err());
    }

    #[test]
    fn completion_scripts_use_shell_native_command_completion() {
        assert!(completion_script(CompletionShell::Bash).contains("compgen -c"));
        assert!(completion_script(CompletionShell::Zsh).contains("_path_commands"));
        assert!(completion_script(CompletionShell::Fish).contains("__fish_complete_command"));
    }
}
