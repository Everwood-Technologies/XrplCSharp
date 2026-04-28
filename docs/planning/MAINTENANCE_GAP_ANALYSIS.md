# XrplCSharp Maintenance Gap Analysis

This document compares the current state of `XrplCSharp` against the actively
maintained reference SDK [`XRPLF/xrpl4j`](https://github.com/XRPLF/xrpl4j) (Java)
and the canonical XRPL specification (sourced from the XRPL documentation /
XRPL-MCP) so that we can plan the work needed to bring `XrplCSharp` back to a
"current standard" state.

The analysis is organized as proposed **GitHub Milestones** with concrete
**Issues** under each. A companion script (`scripts/bootstrap_planning.sh`) can
recreate the milestones, labels, and issues idempotently with a token that has
full `repo` write scope.

---

## 1. Current state snapshot (as of this analysis)

| Aspect | XrplCSharp (this repo) | xrpl4j (HEAD) |
| --- | --- | --- |
| Latest publicly released version | `2.0.0` (NuGet `XrplCSharp`) | `5.x` (Maven BOM) with `v6` and `v7` migration guides published |
| Last commit on `main` | 2024-05-11 (`fix tags (#86)`) | 2026-04 (active, multiple PRs/week) |
| `CHANGES.md` last entry | `1.0.0` (2023-04-30) | `RELEASE.md` describes a documented release process; `Vx_MIGRATION.md` for v3/v5/v6/v7 |
| Target framework | `net6.0` only (out of LTS support since 2024-11-12) | JDK 1.8+, exercised on JDK 8/11/17/21 |
| `rippled` test image pinned to | `rippleci/rippled:2.0.0-b4` | `rippleci/xrpld:develop` |
| Issues enabled on GitHub repo | **No** (just turned on for this work) | Yes |
| Public XRPL methods exposed in client | 26 (`IXrplClient`) | 40+ (`XrplClient` + `XrplAdminClient`) |
| Transaction types modeled | 30 (Enums + classes) | 56 (TransactionType enum) |
| Ledger entry types modeled | 17 (incl. `AMM`) | 25+ (incl. MPT, DID, Oracle, Credential, Bridge, XChain, PermissionedDomain) |
| WebSocket transport | Yes (custom) | No (xrpl4j is JSON-RPC only) |
| JSON-RPC transport | No | Yes |
| Unit + integration tests | Some, only Mainnet-style names; no MPT/DID/XChain/Oracle/Credential coverage | Comprehensive ITs against Devnet / Testnet |

---

## 2. Methodology

1. Walked every directory under `Xrpl/`, `Base/`, and `Tests/` to enumerate
   what is currently modeled, what is signed/serialized, and what tests exist.
2. Cloned `XRPLF/xrpl4j` and enumerated:
   - `xrpl4j-core/.../model/transactions/TransactionType.java`
   - `xrpl4j-core/.../model/client/XrplMethods.java`
   - `xrpl4j-core/.../model/ledger/*Object.java`
   - `xrpl4j-core/.../model/flags/*Flags.java`
   - `xrpl4j-core/.../crypto/{keys,signing}/*`
   - Migration guides `V3_/V5_/V6_/V7_MIGRATION.md`
3. Cross-referenced against the [Known Amendments page](https://xrpl.org/resources/known-amendments)
   and the XRPL-MCP search index for transaction types, methods, and
   `definitions.json` references.

---

## 3. Gap matrix

### 3.1 Transaction types

| Transaction | xrpl4j | XrplCSharp | Status |
| --- | --- | --- | --- |
| AccountSet | yes | yes | OK |
| AccountDelete | yes | yes | OK |
| AMMBid / AMMCreate / AMMDelete / AMMDeposit / AMMVote / AMMWithdraw | yes | yes | OK |
| AMMClawback | yes | **no** | MISSING |
| Batch (XLS-56, currently obsolete amendment) | yes (with `tfInnerBatchTxn`) | **no** | MISSING (track for re-enable) |
| CheckCancel / CheckCash / CheckCreate | yes | yes | OK |
| Clawback | yes | yes (`ClawBack.cs` - typo) | NEEDS RENAME |
| CredentialAccept / CredentialCreate / CredentialDelete (XLS-70) | yes | **no** | MISSING |
| DepositPreauth | yes (incl. credential-based) | yes (no credential support) | PARTIAL |
| DIDSet / DIDDelete | yes | **no** | MISSING |
| EnableAmendment / SetFee / UNLModify (pseudo) | yes | yes | OK |
| EscrowCancel / EscrowCreate / EscrowFinish | yes | yes | OK |
| Token Escrows (XLS-85) | yes (#641) | **no** | MISSING |
| MPTokenIssuanceCreate / Destroy / Set / MPTokenAuthorize (XLS-33) | yes | **no** | MISSING |
| NFTokenAcceptOffer / Burn / CancelOffer / CreateOffer / Mint | yes | yes | OK |
| NFTokenModify (XLS-46d, DynamicNFT) | not yet | **no** | MISSING |
| OfferCancel / OfferCreate | yes | yes | OK |
| OracleSet / OracleDelete (XLS-47) | yes | **no** | MISSING |
| Payment | yes | yes | OK |
| PaymentChannelClaim / Create / Fund | yes | yes | OK |
| PermissionedDomainSet / Delete (XLS-80) | yes | **no** | MISSING |
| SetRegularKey | yes | yes | OK |
| SignerListSet (incl. ExpandedSignerList `WalletLocator`) | yes | partial | PARTIAL |
| TicketCreate | yes | yes | OK |
| TrustSet (incl. DeepFreeze flags) | yes | partial | PARTIAL |
| XChainAccountCreateCommit / AddAccountCreateAttestation / AddClaimAttestation / Claim / Commit / CreateBridge / CreateClaimID / ModifyBridge | yes | **no** | MISSING |

**Total missing transaction types in C#:** 16 (8 of which are on
already-enabled Mainnet amendments).

### 3.2 rippled API methods (`IXrplClient`)

| Method | xrpl4j | XrplCSharp | Status |
| --- | --- | --- | --- |
| account_channels / account_currencies / account_info / account_lines / account_nfts / account_objects / account_offers / account_tx | yes | yes | OK |
| amm_info | yes | yes | OK |
| book_offers | yes | yes | OK |
| channel_authorize / channel_verify | yes | partial (`ChannelAuthorize`/`ChannelVerify` model exist; not exposed on `IXrplClient`) | PARTIAL |
| deposit_authorized | yes | **no** (commented out) | MISSING |
| fee | yes | yes | OK |
| gateway_balances (incl. frozen balances) | yes | yes (no frozen balance support) | PARTIAL |
| get_aggregate_price (XLS-47) | yes | **no** | MISSING |
| ledger / ledger_closed / ledger_current / ledger_data / ledger_entry | yes | yes | OK |
| mpt_holders | yes | **no** | MISSING |
| nft_buy_offers / nft_sell_offers | yes | yes | OK |
| nft_info | yes | **no** | MISSING |
| noripple_check | yes | yes | OK |
| path_find / ripple_path_find | yes | **no** (commented out) | MISSING |
| ping / random | yes | yes | OK |
| server_definitions | not yet | **no** | MISSING (needed for dynamic codec) |
| server_info / server_state | yes | yes | OK |
| sign / sign_for | not on RPC client (offline) | offline only | OK |
| submit / submit_multisigned | yes | partial (`submit_multisigned` not exposed) | PARTIAL |
| subscribe / unsubscribe (WebSocket) | n/a (xrpl4j has no WS) | yes | XrplCSharp better here |
| transaction_entry | yes | **no** (commented out) | MISSING |
| tx (with `binary`, `api_version`) | yes | partial | PARTIAL |

### 3.3 Ledger entry types (state objects)

Missing in C# (present in xrpl4j and on amendments that are enabled on
Mainnet):

- `Bridge`
- `Credential`
- `DID`
- `MPTokenIssuance`
- `MPToken`
- `Oracle`
- `PermissionedDomain`
- `XChainOwnedClaimID`
- `XChainOwnedCreateAccountClaimID`

Also missing C# binding for `XChainBridge` field type and `MPT` amount type
(see codec gap below).

### 3.4 Binary codec / address codec

- `Xrpl.BinaryCodec` does not include encoders for:
  - `STHash192` (used for MPT issuance IDs)
  - `MPT` amount variant of `STAmount`
  - `XChainBridge`
  - `STArray` of `Credential` entries
- `definitions.json` is shipped as a static file; no support for
  `server_definitions` to hot-reload field/transaction codes from the network
  (xrpl4j lands this in #674).
- No support for sidechain network IDs > 1024 in the codec layer (the
  `NetworkID` field flows through `IXrplClient` but is not enforced by the
  binary signer).

### 3.5 Flags

xrpl4j has dedicated typed flag classes; XrplCSharp implements flags via a
loose `[Flags] enum` per transaction. We are missing typed flag classes for:

- `AmmClawbackFlags`, `AmmDepositFlags`, `AmmWithdrawFlags`
- `BatchFlags` (`tfInnerBatchTxn`, etc.)
- `CredentialFlags`
- `MpTokenAuthorizeFlags`, `MpTokenFlags`, `MpTokenIssuanceCreateFlags`,
  `MpTokenIssuanceFlags`, `MpTokenIssuanceSetFlags`
- `XChainModifyBridgeFlags`
- `lsfLowDeepFreeze`/`lsfHighDeepFreeze` on `RippleState`
- `tfSetDeepFreeze`/`tfClearDeepFreeze` on `TrustSet`
- `lsfAllowTrustLineClawback` on `AccountRoot`
- `asfDisallowIncoming*` AccountSet flags (Checks/PayChan/NFTOffer/Trustline)

### 3.6 Cryptography / signing

- xrpl4j separates `crypto/keys`, `crypto/signing`, `SignatureService`,
  `SingleSignedTransaction`, `MultiSignedTransaction` and provides
  `KeyType.SECP256K1` / `KeyType.ED25519` enum support, plus `Seed`,
  `Passphrase`, `Entropy` value types.
- XrplCSharp uses `string`-typed keys/seeds, has no `SignatureService`
  abstraction, and has no offline multi-sign helper that's first-class on the
  client (all signing logic lives inside `Wallet`/`Signer` with magic strings).
- No HSM/KMS extension point. xrpl4j ships an `AbstractSignatureService` so
  external key custodians can plug in.

### 3.7 Sugar / convenience

xrpl4j (and `xrpl.js` in JS) ship many helpers that we are missing or are stubs:

- `isFinal(txHash)` (transaction finality detection across the LastLedgerSequence window)
- `XrpCurrencyAmount.ofXrp(...)` / `.ofDrops(...)` value types (we use raw `string` everywhere)
- `Address` value type with X-Address validation (we use `string`)
- `Hash256`, `LedgerIndex`, `UnsignedInteger32` strong types
- `Memo` builder + UTF8 helpers
- `submitAndWait` (currently `Submit` returns immediately; we don't poll)
- `getOrderBook` is implemented but `Sugar/GetOrderBook.cs` is a partial port
- `CrossChainPayment` exists but is unused by the cross-chain transactions

### 3.8 Tests / CI

- `dotnet.test.yml` pins `rippleci/rippled:2.0.0-b4` (xrpl4j tracks
  `rippleci/xrpld:develop`); standalone container has no amendments enabled
  past v2.0.
- No tests at all for AMM transactions, NFTokenModify, Clawback,
  Credentials, MPT, DID, Oracle, PermissionedDomain, XChain, Token Escrows.
- No matrix on `net6.0` / `net8.0` / `net9.0`; only `6.0.x`. Net 6 is out of
  support; Net 8 is current LTS, Net 9 is current STS.
- No `editorconfig` / lint enforcement (the placeholder is commented out).
- No code coverage report (xrpl4j publishes to codecov).

### 3.9 Documentation

- `README.md` examples reference `XrplWallet.FundWallet`, `AccountInfoRequest`
  but the API surface is partly stale (e.g. `BookOffers` import is aliased,
  `Submit` ambiguity).
- `CHANGES.md` only has the 1.0.0 entry; v2.0.0 release is undocumented.
- No `MIGRATION.md` for v1->v2 (xrpl4j has one per major).
- DocFx output (`docs/`) is a one-shot build; no GitHub Pages workflow that
  republishes it.
- README still points to the old `Transia-RnD` org for `PackageProjectUrl`
  / `PackageLicenseUrl` even though the repo lives under
  `Everwood-Technologies`.

### 3.10 Repository hygiene

- Issues were disabled on the repo (now turned on for this work).
- No `CODEOWNERS`, no `SECURITY.md`, no PR / issue templates.
- `Tests/` directory contains `bin/` and `obj/` checked in (should be
  `.gitignored`).
- `.DS_Store` and `clear-cache.bat` / `clear-obj.bat` artifacts at repo root.
- `LICENSE` is Apache-2.0 (good); `nuget.config` checks in a feed but with no
  authentication notes for contributors.

---

## 4. Proposed milestones

The following are proposed as GitHub milestones (the script in
`scripts/bootstrap_planning.sh` creates them as real Milestones once a
maintainer runs it with a token that has the permission to create
milestones). Sized roughly so each milestone is a coherent shippable bundle.
Each one already has a tracking Epic issue filed by the agent (see the
"Tracking" links).

1. **M1: Core Maintenance & CI Refresh** — toolchain, CI, docs hygiene.
   Tracking: [#5](https://github.com/Everwood-Technologies/XrplCSharp/issues/5)
2. **M2: Transaction & Method Parity (Mainnet-Enabled Amendments)** — MPT,
   Credentials, DID, Oracle, AMMClawback, NFTokenModify, deep freeze,
   ExpandedSignerList, DisallowIncoming.
   Tracking: [#6](https://github.com/Everwood-Technologies/XrplCSharp/issues/6)
3. **M3: Cross-Chain Bridges (XLS-38d)** — XChain* transactions, Bridge
   ledger entries, attestation models.
   Tracking: [#7](https://github.com/Everwood-Technologies/XrplCSharp/issues/7)
4. **M4: Permissioned DEX & Permissioned Domains (XLS-80/XLS-81)** — new
   transactions, ledger entries, `PermissionedDomainLedgerEntryParams`.
   Tracking: [#8](https://github.com/Everwood-Technologies/XrplCSharp/issues/8)
5. **M5: Binary / Address Codec Modernization** — new field types,
   `server_definitions` support, dynamic codec, NetworkID enforcement.
   Tracking: [#9](https://github.com/Everwood-Technologies/XrplCSharp/issues/9)
6. **M6: Client API Hardening** — JSON-RPC client option, `submit_and_wait`,
   `isFinal`, `path_find`, `ripple_path_find`, `mpt_holders`,
   `transaction_entry`, value types (`Address`, `Hash256`, `XrpAmount`).
   Tracking: [#10](https://github.com/Everwood-Technologies/XrplCSharp/issues/10)
7. **M7: Cryptography & Custody Extensibility** — `SignatureService`
   abstraction, KMS/HSM hooks, typed `Seed`/`KeyType`/`Entropy`,
   typed multi-sign workflow.
   Tracking: [#11](https://github.com/Everwood-Technologies/XrplCSharp/issues/11)
8. **M8: Test, Docs, Release Engineering** — coverage upload, multi-target
   matrix, refreshed integration tests against `rippled:develop`, MIGRATION.md
   for 2.x -> 3.x, NuGet release workflow, DocFx publish.
   Tracking: [#12](https://github.com/Everwood-Technologies/XrplCSharp/issues/12)

Umbrella tracking issue: [#4](https://github.com/Everwood-Technologies/XrplCSharp/issues/4).

---

## 5. Issue list (per milestone)

### M1: Core Maintenance & CI Refresh

- M1.1 Multi-target the SDK to `net6.0;net8.0;net9.0` and update CI matrix.
- M1.2 Bump `rippled` test image to `rippleci/xrpld:develop` (and document
  amendment vote configuration).
- M1.3 Add `dotnet format` / Roslyn analyzers; turn on `TreatWarningsAsErrors`.
- M1.4 Add `CODEOWNERS`, `SECURITY.md`, PR + issue templates.
- M1.5 Remove tracked build artifacts (`Tests/**/bin`, `**/obj`, `.DS_Store`)
  and tighten `.gitignore`.
- M1.6 Repoint `Xrpl.csproj` `PackageProjectUrl`/`PackageLicenseUrl` to
  `Everwood-Technologies/XrplCSharp`.
- M1.7 Backfill `CHANGES.md` for `2.0.0` and adopt Conventional Commits +
  Release Drafter.
- M1.8 Add code coverage upload (Coverlet -> Codecov).

### M2: Transaction & Method Parity (Mainnet-Enabled Amendments)

- M2.1 Implement `AMMClawback` transaction + `tfClawTwoAssets` flag + IT.
- M2.2 Add **MPT** support: `MPTokenIssuanceCreate`, `MPTokenIssuanceDestroy`,
  `MPTokenIssuanceSet`, `MPTokenAuthorize`; `MPTokenIssuance` and `MPToken`
  ledger entries; flag classes; `mpt_holders` RPC; codec for STHash192 +
  `MPT` amount.
- M2.3 Add **Credentials** support (XLS-70): `CredentialCreate`,
  `CredentialAccept`, `CredentialDelete`; `Credential` ledger entry; extend
  `DepositPreauth` with `AuthorizeCredentials`/`UnauthorizeCredentials`;
  `CredentialIDs` field on `Payment`, `EscrowFinish`, `PaymentChannelClaim`,
  `AccountDelete`.
- M2.4 Add **DID** support: `DIDSet`, `DIDDelete`, `DID` ledger entry.
- M2.5 Add **Oracle** support (XLS-47): `OracleSet`, `OracleDelete`,
  `Oracle` ledger entry, `get_aggregate_price` RPC, `OracleLedgerEntryParams`.
- M2.6 Add **NFTokenModify** transaction + `tfMutable` flag (DynamicNFT).
- M2.7 Add **Token Escrow** support (extend Escrow to issued / MPT amounts).
- M2.8 Add **Deep Freeze** flags and behaviour on `TrustSet` / `RippleState`.
- M2.9 Add **ExpandedSignerList**: `WalletLocator` field on `SignerEntry`,
  raise the limit, update `SignerListSet`.
- M2.10 Add **DisallowIncoming** AccountSet flags (Check / PayChan / NFTOffer
  / Trustline).
- M2.11 Add **frozenBalances** support to `gateway_balances` response model.
- M2.12 Re-enable `deposit_authorized`, `transaction_entry`, `nft_info`,
  `submit_multisigned`, `path_find`, `ripple_path_find` on `IXrplClient`.

### M3: Cross-Chain Bridges (XLS-38d)

- M3.1 Add `Bridge` ledger entry + `XChainBridge` field type to codec.
- M3.2 Add `XChainCreateBridge`, `XChainModifyBridge` transactions + flags.
- M3.3 Add `XChainCommit`, `XChainClaim`, `XChainCreateClaimID`
  transactions and `XChainOwnedClaimID` ledger entry.
- M3.4 Add `XChainAccountCreateCommit` and
  `XChainOwnedCreateAccountClaimID` ledger entry.
- M3.5 Add `XChainAddClaimAttestation` /
  `XChainAddAccountCreateAttestation` transactions and attestation models.
- M3.6 Add cross-chain payment helper (re-use `Utils/CreateCrossChainPayment`)
  and integration tests against a sidechain devnet.

### M4: Permissioned DEX & Permissioned Domains

- M4.1 Add `PermissionedDomainSet`, `PermissionedDomainDelete` transactions
  + `PermissionedDomain` ledger entry (XLS-80).
- M4.2 Extend `OfferCreate` and AMM transactions with `DomainID` field
  (XLS-81 Permissioned DEX).
- M4.3 Add `PermissionedDomainLedgerEntryParams` to `ledger_entry`.

### M5: Binary / Address Codec Modernization

- M5.1 Implement `STHash192` type.
- M5.2 Implement `MPT` variant of `STAmount`.
- M5.3 Implement `XChainBridge` and `Issue` field types.
- M5.4 Add `server_definitions` RPC and a `DefinitionsLoader` that can hot-load
  a `definitions.json` from a node (xrpl4j #674).
- M5.5 Refresh the bundled `definitions.json` to the latest from
  `XRPLF/xrpl.js` ripple-binary-codec.
- M5.6 Enforce `NetworkID` in the binary signer for chains with id > 1024.
- M5.7 Add fuzz tests cross-checking C# encode/decode against `rippled`'s
  golden vectors.

### M6: Client API Hardening

- M6.1 Add a JSON-RPC transport (`XrplJsonRpcClient`) alongside WebSocket so
  consumers can pick the cheaper transport like xrpl4j does.
- M6.2 Implement `SubmitAndWait` (poll `tx` against `LastLedgerSequence`).
- M6.3 Implement `IsFinal` / `Finality` enum.
- M6.4 Implement `Address`, `Hash256`, `XrpCurrencyAmount`,
  `IssuedCurrencyAmount`, `LedgerIndex` value types and migrate models off
  `string`.
- M6.5 Implement `ChangeServer` with proper subscription replay.
- M6.6 Document and stabilize the `OnError`/`OnConnected`/`OnTransaction`
  event surface (currently commented out).
- M6.7 Implement retry / backoff on connection drop with jitter.

### M7: Cryptography & Custody Extensibility

- M7.1 Introduce `KeyType` enum (replace `DEFAULT_ALGORITHM = "ed25519"`).
- M7.2 Introduce `Seed`, `Passphrase`, `Entropy`, `PrivateKey`, `PublicKey`
  value types.
- M7.3 Introduce `SingleSignedTransaction` / `MultiSignedTransaction` and an
  `ISignatureService` abstraction.
- M7.4 Provide a BouncyCastle implementation
  (`BcSignatureService`).
- M7.5 Provide a sample `IRemoteSignatureService` (e.g., AWS KMS or
  Azure Key Vault) to demonstrate the pattern.
- M7.6 Add canonical multi-sign integration tests with mixed
  `secp256k1`/`ed25519` signers.

### M8: Test, Docs, Release Engineering

- M8.1 Add unit + integration tests for every transaction added in M2 / M3 /
  M4.
- M8.2 Add a Devnet matrix to `dotnet.test.yml` (TestNet, Devnet, AMM-Devnet).
- M8.3 Re-publish DocFx site to GitHub Pages on every `main` push.
- M8.4 Add `MIGRATION_2_to_3.md` once breaking changes from M5/M6/M7 land.
- M8.5 Add a NuGet release workflow that auto-tags from `CHANGES.md`.
- M8.6 Add a `make release` / `dotnet pack` parity check across `net6/8/9`.
- M8.7 Run `dotnet outdated` weekly via Dependabot for `Newtonsoft.Json`,
  `Portable.BouncyCastle`, etc.

---

## 6. Notes on the bootstrap script

`scripts/bootstrap_planning.sh` requires a token with `repo` write scope (a
classic PAT, GitHub App installation token, or a fine-grained PAT with
**Issues: Read & write** + **Pull requests: Read & write** + **Metadata: Read**).
The Cursor Cloud Agent app token only has Issues: Read & write but cannot
create labels or milestones; if you run the script under that token it will
skip those steps and only create issues, prefixing each title with the target
milestone.

Run from repo root:

```
REPO=Everwood-Technologies/XrplCSharp \
GH_TOKEN=ghp_xxx \
bash scripts/bootstrap_planning.sh
```
