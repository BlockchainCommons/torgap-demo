#![deny(warnings)]
extern crate pretty_env_logger;

#[tokio::main]
async fn main() {
    pretty_env_logger::init();

    warp::serve(warp::fs::dir("public"))
        .run(([127, 0, 0, 1], 5557))
        .await;
}
