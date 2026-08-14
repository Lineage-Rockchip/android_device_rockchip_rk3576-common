/*
 * Copyright (C) 2025 The LineageOS Project
 *
 * SPDX-License-Identifier: Apache-2.0
 */

/*
 * The stock wpa_supplicant references sk_dup, which BoringSSL renamed to
 * OPENSSL_sk_dup. The symbol is GLOBAL UND rather than weak, so the process
 * fails to link the moment Wi-Fi is brought up:
 *
 *     CANNOT LINK EXECUTABLE "/vendor/bin/hw/wpa_supplicant":
 *         cannot locate symbol "sk_dup"
 *
 * Nothing on /vendor or /system defines the old name -- our libcrypto.so only
 * exports OPENSSL_sk_dup -- so forward it. The two have identical semantics and
 * signature; the rename carried no behaviour change.
 */

#include <openssl/stack.h>

extern "C" {

OPENSSL_STACK* sk_dup(const OPENSSL_STACK* sk) {
    return OPENSSL_sk_dup(sk);
}

}
