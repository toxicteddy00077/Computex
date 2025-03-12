use clap::{Parser, Subcommand};
use std::fs;
use std::io;
use std::process::Command;

#[derive(Parser)]
#[command(name = "Computex CLI")]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    ListProviders,
    Register,
    RequestTask {
        cuda_file: String,
    },
}

fn compile_and_run_cuda(cuda_source: &str) -> io::Result<String> {
    // Write the CUDA source to a temporary file.
    let cuda_file = "job.cu";
    fs::write(cuda_file, cuda_source)?;

    let compile_status = Command::new("nvcc")
        .arg(cuda_file)
        .arg("-o")
        .arg("x")
        .status()?;
    if !compile_status.success() {
        return Err(io::Error::new(
            io::ErrorKind::Other,
            "failed",
        ));
    }

    let output = Command::new("./x").output()?;
    if !output.status.success() {
        return Err(io::Error::new(
            io::ErrorKind::Other,
            "failed",
        ));
    }
    let stdout = String::from_utf8_lossy(&output.stdout).to_string();
    Ok(stdout)
}

fn main() -> io::Result<()> {
    let cli = Cli::parse();

    match cli.command {
        Commands::ListProviders => {
            println!("Listing all provider");
            Command::new("sh")
                .arg("-c")
                .arg("aptos move run --function 0x1::ComputeDApp::get_providers")
                .status()?;
        }
        Commands::Register => {
            println!("Registering");
            Command::new("sh")
                .arg("-c")
                .arg("aptos move run --function 0x1::ComputeDApp::register_provider")
                .status()?;
        }
        Commands::RequestTask { cuda_file } => {
            println!("Requesting task");
            let cuda_source = fs::read_to_string(&cuda_file)?;
            match compile_and_run_cuda(&cuda_source) {
                Ok(result) => {
                    println!("Ouput:\n{}", result);
                    Command::new("sh")
                        .arg("-c")
                        .arg(&format!("aptos move run --function 0x1::ComputeDApp::submit_result --args '{}'", result))
                        .status()?;
                }
                Err(e) => {
                    eprintln!("Error during CUDA task execution: {}", e);
                }
            }
        }
    }
    Ok(())
}
