use crate::{
    taker::{SwapParams, Taker, amount_to_sats, validate_wallet_file_name},
    types::{create_default_rpc_config, restore_wallet_gui_app},
};
use std::convert::TryFrom;

#[test]
fn swap_params_accepts_valid_protocol_names() {
    for protocol in ["Legacy", "legacy", "Taproot", "taproot"] {
        let params = SwapParams {
            protocol: Some(protocol.to_string()),
            send_amount: 50_000,
            maker_count: 2,
            tx_count: None,
            required_confirms: None,
            manually_selected_outpoints: None,
            preferred_makers: None,
        };

        assert!(coinswap::taker::api::SwapParams::try_from(params).is_ok());
    }
}

#[test]
fn swap_params_rejects_unknown_protocol_names() {
    let params = SwapParams {
        protocol: Some("Unified".to_string()),
        send_amount: 50_000,
        maker_count: 2,
        tx_count: None,
        required_confirms: None,
        manually_selected_outpoints: None,
        preferred_makers: None,
    };

    let err = coinswap::taker::api::SwapParams::try_from(params).unwrap_err();
    assert!(
        err.to_string().contains("Invalid protocol"),
        "unexpected error: {err}"
    );
}

#[test]
fn send_amount_conversion_rejects_negative_values() {
    let err = amount_to_sats(-1).unwrap_err();
    assert!(
        err.to_string().contains("amount") && err.to_string().contains("non-negative"),
        "unexpected error: {err}"
    );
    assert_eq!(amount_to_sats(0).unwrap(), 0);
    assert_eq!(amount_to_sats(21_000_000).unwrap(), 21_000_000);
}

#[test]
fn wallet_file_name_must_be_a_basename() {
    for valid in ["wallet", "wallet.dat", "wallet_01"] {
        assert!(
            validate_wallet_file_name(valid).is_ok(),
            "valid basename rejected: {valid}"
        );
    }

    for invalid in ["", "../wallet", "subdir/wallet", "/tmp/wallet", "~/wallet"] {
        let err = validate_wallet_file_name(invalid).unwrap_err();
        assert!(
            err.to_string().contains("wallet_file_name"),
            "unexpected error for {invalid:?}: {err}"
        );
    }
}

#[test]
fn taker_init_rejects_wallet_path_components_before_io() {
    let err = match Taker::init(
        Some("/tmp/coinswap-ffi-contract-test".to_string()),
        Some("../outside-wallet".to_string()),
        Some(create_default_rpc_config()),
        Some(9051),
        Some("coinswap".to_string()),
        "tcp://127.0.0.1:28332".to_string(),
        None,
    ) {
        Ok(_) => panic!("Taker::init accepted a wallet name containing path traversal"),
        Err(err) => err,
    };

    assert!(
        err.to_string().contains("wallet_file_name"),
        "unexpected error: {err}"
    );
}

#[test]
fn restore_wallet_rejects_wallet_path_components_before_backup_io() {
    let result = restore_wallet_gui_app(
        Some("/tmp/coinswap-ffi-contract-test".to_string()),
        Some("../outside-wallet".to_string()),
        create_default_rpc_config(),
        "/definitely/missing/backup.json".to_string(),
        None,
    );

    let err = result.unwrap_err();
    assert!(
        err.to_string().contains("wallet_file_name"),
        "unexpected error: {err}"
    );
}
