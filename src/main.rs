#[macro_use]
extern crate log;

extern crate http;
extern crate simple_server;
use std::env;

use http::header;
use simple_server::{Method, Server, StatusCode};
use std::fs;
use std::path::PathBuf;
fn main() {
    let host = "127.0.0.1";
    let port = "5556";

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
    println!("path : {:?}", path);
    let path_text: PathBuf = [path.clone(), PathBuf::from("public/text.txt")]
        .iter()
        .collect();
    let path_sig: PathBuf = [path.clone(), PathBuf::from("public/text.txt.minisig")]
        .iter()
        .collect();
    let path_html: PathBuf = [path.clone(), PathBuf::from("public/index.html")]
        .iter()
        .collect();

    let server = Server::new(move |request, mut response| {
        info!("Request received. {} {}", request.method(), request.uri());

        match (request.method(), request.uri().path()) {
            (&Method::GET, "/object") => {
                response.header(header::CONTENT_TYPE, "application/octet-stream".as_bytes());
                response.header(
                    header::CONTENT_DISPOSITION,
                    "inline; filename=text.txt".as_bytes(),
                );
                let response_body = fs::read(path_text.clone()).unwrap_or(vec![]);
                Ok(response.body(response_body)?)
            }
            (&Method::GET, "/signature") => {
                response.header(header::CONTENT_TYPE, "application/octet-stream".as_bytes());
                response.header(
                    header::CONTENT_DISPOSITION,
                    "inline; filename=text.txt.minisig".as_bytes(),
                );
                let response_body = fs::read(path_sig.clone()).unwrap_or(vec![]);
                Ok(response.body(response_body)?)
            }
            (_, _) => {
                response.status(StatusCode::NOT_FOUND);
                let contents = fs::read_to_string(path_html.clone()).unwrap();
                Ok(response.body(contents.as_bytes().to_vec())?)
            }
        }
    });

    server.listen(host, port);
}
