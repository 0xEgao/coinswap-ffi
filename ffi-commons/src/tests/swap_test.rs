//! FFI taker integration test: one taker × 2 makers per process.
//!
//! CI invokes this test four times with `OPENSWAP_SWAP_CASE`, once for each
//! backend × protocol scenario. A fresh test process prevents completed
//! takers from retaining Tor connections needed by a later scenario.

use crate::tests::docker_helpers::{Backend, Swap, run_swap};
/// Amount swapped by each taker, in sats. The taker is funded with 2×.
const SWAP_AMOUNT: u64 = 500_000;

// This test uses the production Tor transport and fidelity verification, but
// polls the current Docker stack's makers directly. Public Nostr discovery
// cannot isolate independent CI regtest chains. Run with a plain `cargo test`
// (no --features integration-test). CI sets `OPENSWAP_SWAP_CASE` so each
// invocation runs exactly one scenario.
#[test]
fn main() {
    openswap::utill::setup_taker_logger(log::LevelFilter::Info, true, None);

    let swaps = [
        Swap {
            name: "legacy_rpc",
            wallet: "test-legacy-rpc",
            backend: Backend::Rpc,
            protocol: "Legacy",
            addr_type: "P2WPKH",
        },
        Swap {
            name: "taproot_rpc",
            wallet: "test-taproot-rpc",
            backend: Backend::Rpc,
            protocol: "Taproot",
            addr_type: "P2TR",
        },
        Swap {
            name: "legacy_electrum",
            wallet: "test-legacy-electrum",
            backend: Backend::Electrum,
            protocol: "Legacy",
            addr_type: "P2WPKH",
        },
        Swap {
            name: "taproot_electrum",
            wallet: "test-taproot-electrum",
            backend: Backend::Electrum,
            protocol: "Taproot",
            addr_type: "P2TR",
        },
    ];

    let requested = std::env::var("OPENSWAP_SWAP_CASE")
        .expect("OPENSWAP_SWAP_CASE must select one swap scenario");
    let swap = swaps
        .iter()
        .find(|swap| swap.name == requested)
        .unwrap_or_else(|| {
            panic!(
                "unknown OPENSWAP_SWAP_CASE={requested:?}; expected one of: {}",
                swaps
                    .iter()
                    .map(|swap| swap.name)
                    .collect::<Vec<_>>()
                    .join(", ")
            )
        });

    run_swap(swap, SWAP_AMOUNT);
}
