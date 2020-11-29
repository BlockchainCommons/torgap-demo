#![deny(warnings)]
extern crate pretty_env_logger;
use std::env;
use std::path::PathBuf;

#[tokio::main]
async fn main() {
    pretty_env_logger::init();

    let mut path = PathBuf::new();

    match env::current_exe() {
        Ok(exe_path) => {
            path.push(exe_path.clone());
            println!("Path of this executable is: {}", exe_path.display())
        }
        Err(e) => {
            println!("failed to get current exe path: {}", e);
            return;
        }
    };

    path.pop();
    path.pop();
    path.pop();

    let path_public: PathBuf = [path.clone(), PathBuf::from("public")].iter().collect();

    warp::serve(warp::fs::dir(path_public))
        .run(([127, 0, 0, 1], 5557))
        .await;
}
