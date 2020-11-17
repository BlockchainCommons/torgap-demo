#[macro_use]
extern crate log;

extern crate http;
extern crate simple_server;

use http::header;
use simple_server::{Method, Server, StatusCode};
use std::fs;
fn main() {
    let host = "127.0.0.1";
    let port = "5555";

    let server = Server::new(|request, mut response| {
        info!("Request received. {} {}", request.method(), request.uri());

        match (request.method(), request.uri().path()) {
            (&Method::GET, "/object") => {
                response.header(header::CONTENT_TYPE, "application/octet-stream".as_bytes());
                response.header(
                    header::CONTENT_DISPOSITION,
                    "inline; filename=text.txt".as_bytes(),
                );
                let response_body = fs::read("public/text.txt").unwrap_or(vec![]);
                Ok(response.body(response_body)?)
            }
            (&Method::GET, "/signature") => {
                response.header(header::CONTENT_TYPE, "application/octet-stream".as_bytes());
                response.header(
                    header::CONTENT_DISPOSITION,
                    "inline; filename=text.txt.minisig".as_bytes(),
                );
                let response_body = fs::read("public/text.txt.minisig").unwrap_or(vec![]);
                Ok(response.body(response_body)?)
            }
            (_, _) => {
                response.status(StatusCode::NOT_FOUND);
                let contents = fs::read_to_string("public/index.html").unwrap();
                Ok(response.body(contents.as_bytes().to_vec())?)
            }
        }
    });

    server.listen(host, port);
}
