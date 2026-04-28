#!/usr/bin/env bash
# Bootstrap the GitHub milestones, labels, and issues described in
# docs/planning/MAINTENANCE_GAP_ANALYSIS.md.
#
# Usage:
#   REPO=Everwood-Technologies/XrplCSharp \
#   GH_TOKEN=ghp_xxx \
#   bash scripts/bootstrap_planning.sh
#
# The script is idempotent: if a milestone/label/issue with the same
# title already exists it is reused. If the supplied token cannot
# create labels or milestones (e.g. a GitHub App installation that
# only has Issues: write), the script logs a warning and creates the
# issues with the milestone name prefixed in the title instead.

set -euo pipefail

REPO=${REPO:-Everwood-Technologies/XrplCSharp}
: "${GH_TOKEN:?Set GH_TOKEN to a token with repo:write scope}"

API="https://api.github.com/repos/${REPO}"
AUTH=( -H "Authorization: Bearer ${GH_TOKEN}" -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" )

log()  { printf '[bootstrap] %s\n' "$*" >&2; }
warn() { printf '[bootstrap][WARN] %s\n' "$*" >&2; }

api() {
  local method=$1; shift
  local path=$1;   shift
  curl -sS -X "$method" "${AUTH[@]}" "${API}${path}" "$@"
}

ensure_label() {
  local name=$1 color=$2 desc=$3
  local existing
  existing=$(api GET "/labels/${name// /%20}" -o /dev/null -w '%{http_code}' || true)
  if [[ "$existing" == "200" ]]; then
    return 0
  fi
  local body
  body=$(printf '{"name":"%s","color":"%s","description":"%s"}' "$name" "$color" "$desc")
  if ! api POST "/labels" -d "$body" >/dev/null 2>&1; then
    warn "Could not create label '$name' (token lacks permission?). Continuing without it."
  fi
}

ensure_milestone() {
  local title=$1 desc=$2
  local number
  number=$(api GET "/milestones?state=all&per_page=100" | python3 -c "
import json,sys
title=sys.argv[1]
for m in json.load(sys.stdin):
    if m['title']==title:
        print(m['number'])
        break" "$title")
  if [[ -n "$number" ]]; then
    echo "$number"
    return
  fi
  local body
  body=$(python3 -c "import json,sys; print(json.dumps({'title':sys.argv[1],'description':sys.argv[2],'state':'open'}))" "$title" "$desc")
  local resp
  resp=$(api POST "/milestones" -d "$body")
  number=$(printf '%s' "$resp" | python3 -c 'import json,sys;d=json.load(sys.stdin); print(d.get("number",""))')
  if [[ -z "$number" ]]; then
    warn "Could not create milestone '$title' (token lacks permission?). Will fall back to title prefix."
    echo ""
    return
  fi
  echo "$number"
}

ensure_issue() {
  local title=$1 body=$2 milestone_number=$3 labels_csv=$4
  local existing
  existing=$(api GET "/issues?state=all&per_page=100" | python3 -c "
import json,sys
title=sys.argv[1]
for i in json.load(sys.stdin):
    if i.get('pull_request'): continue
    if i['title']==title:
        print(i['number'])
        break" "$title")
  if [[ -n "$existing" ]]; then
    log "issue '$title' already exists (#$existing); skipping create"
    return
  fi
  local payload
  payload=$(python3 -c '
import json,sys
title, body, milestone, labels = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
out = {"title": title, "body": body}
if milestone:
    out["milestone"] = int(milestone)
if labels:
    out["labels"] = [l for l in labels.split(",") if l]
print(json.dumps(out))' "$title" "$body" "$milestone_number" "$labels_csv")
  api POST "/issues" -d "$payload" >/dev/null
  log "created issue '$title'"
}

# ---------- Labels ----------
ensure_label "type:gap"       "5319e7" "Tracks parity gap vs xrpl4j / XRPL spec"
ensure_label "type:tx"        "1d76db" "New or updated transaction type"
ensure_label "type:method"    "0e8a16" "rippled API method coverage"
ensure_label "type:codec"     "fbca04" "Binary or address codec change"
ensure_label "type:crypto"    "b60205" "Signing / keys / custody"
ensure_label "type:ci"        "5319e7" "CI / build / release engineering"
ensure_label "type:docs"      "0075ca" "Documentation"
ensure_label "amendment:mpt"        "c5def5" ""
ensure_label "amendment:credentials" "c5def5" ""
ensure_label "amendment:did"        "c5def5" ""
ensure_label "amendment:oracle"     "c5def5" ""
ensure_label "amendment:xchain"     "c5def5" ""
ensure_label "amendment:ammclawback" "c5def5" ""
ensure_label "amendment:permissioned-domain" "c5def5" ""
ensure_label "amendment:permissioned-dex"    "c5def5" ""
ensure_label "amendment:dynamic-nft"         "c5def5" ""
ensure_label "amendment:deep-freeze"         "c5def5" ""
ensure_label "amendment:expanded-signer-list" "c5def5" ""

# ---------- Milestones ----------
M1=$(ensure_milestone "M1: Core Maintenance & CI Refresh"            "Toolchain refresh, CI hygiene, repo metadata.")
M2=$(ensure_milestone "M2: Transaction & Method Parity"              "Bring transaction/method surface up to xrpl4j for already-enabled Mainnet amendments.")
M3=$(ensure_milestone "M3: Cross-Chain Bridges (XLS-38d)"            "XChain* transactions, Bridge ledger entries, attestation models.")
M4=$(ensure_milestone "M4: Permissioned DEX & Permissioned Domains"  "XLS-80 / XLS-81 support across transactions, ledger entries, and ledger_entry params.")
M5=$(ensure_milestone "M5: Binary / Address Codec Modernization"     "STHash192, MPT amount, XChainBridge, server_definitions, NetworkID enforcement.")
M6=$(ensure_milestone "M6: Client API Hardening"                     "JSON-RPC client, submit_and_wait, isFinal, value types, missing methods.")
M7=$(ensure_milestone "M7: Cryptography & Custody Extensibility"     "SignatureService abstraction, KMS/HSM hooks, typed seeds/keys/multi-sign.")
M8=$(ensure_milestone "M8: Test, Docs, Release Engineering"          "Coverage upload, multi-target matrix, ITs against rippled:develop, MIGRATION docs.")

# ---------- Issues ----------
add() {
  local m=$1 title=$2 labels=$3 body=$4
  local effective_title=$title
  if [[ -z "$m" ]]; then
    # Fallback when milestone creation was not permitted.
    effective_title="${title}"
  fi
  ensure_issue "$effective_title" "$body" "$m" "type:gap,${labels}"
}

# M1
add "$M1" "M1.1 Multi-target SDK to net6.0;net8.0;net9.0 + CI matrix" "type:ci" \
"Update Xrpl.csproj and Test projects to TargetFrameworks=net6.0;net8.0;net9.0. Update .github/workflows/dotnet.test.yml job matrix accordingly. Justification: net6.0 left LTS support on 2024-11-12; xrpl4j tests on JDK 8/11/17/21."
add "$M1" "M1.2 Bump rippled test image to rippleci/xrpld:develop" "type:ci" \
"dotnet.test.yml currently pins rippleci/rippled:2.0.0-b4 which lacks every amendment after v2.0 (MPT, Credentials, DID, Oracle, AMMClawback, DynamicNFT, DeepFreeze, ExpandedSignerList, DisallowIncoming). Move to rippleci/xrpld:develop and document amendment vote configuration in .ci-config/."
add "$M1" "M1.3 Enable analyzers + dotnet format with TreatWarningsAsErrors" "type:ci" \
"Add dotnet-format check, enable Microsoft.CodeAnalysis.NetAnalyzers, set TreatWarningsAsErrors=true on Release builds. Replace commented-out 'dotnet lint' step in CI."
add "$M1" "M1.4 Add CODEOWNERS, SECURITY.md, PR + issue templates" "type:docs" \
"xrpl4j has CODEOWNERS, SECURITY.md, and templates that route triage. Mirror that structure under .github/."
add "$M1" "M1.5 Stop tracking build artifacts and OS junk" "type:ci" \
"Tests/**/bin and Tests/**/obj are committed to the repo. Remove them, add to .gitignore, and remove .DS_Store + clear-cache.bat / clear-obj.bat (or move to scripts/)."
add "$M1" "M1.6 Repoint Xrpl.csproj package URLs to Everwood-Technologies" "type:docs" \
"PackageProjectUrl/PackageLicenseUrl currently point to Transia-RnD; update to https://github.com/Everwood-Technologies/XrplCSharp."
add "$M1" "M1.7 Backfill CHANGES.md (2.0.0) and adopt Release Drafter" "type:docs" \
"CHANGES.md only has the 1.0.0 entry. Backfill the 2.0.0 release, then automate future entries with .github/release-drafter.yml + Conventional Commits."
add "$M1" "M1.8 Coverlet + Codecov upload" "type:ci" \
"Add coverlet.collector to test projects and a Codecov upload step in CI for parity with xrpl4j (which publishes a codecov badge on README)."

# M2
add "$M2" "M2.1 Add AMMClawback transaction (XLS-73)" "type:tx,amendment:ammclawback" \
"Implement Models/Transactions/AMMClawback.cs and tfClawTwoAssets flag. Write unit + integration tests modeled after Tests/Xrpl.Tests/Models/TestAMMBid.cs. Spec: https://github.com/XRPLF/XRPL-Standards/discussions/212"
add "$M2" "M2.2 Add MPT transactions, ledger entries, codec, mpt_holders RPC (XLS-33)" "type:tx,type:method,type:codec,amendment:mpt" \
"Add MPTokenIssuanceCreate/Destroy/Set, MPTokenAuthorize transactions; MPTokenIssuance + MPToken ledger entries; MpToken* flag classes; mpt_holders RPC with Models/Methods/MptHolders.cs; binary codec support for STHash192 and the MPT variant of STAmount; update Xrpl.BinaryCodec definitions.json."
add "$M2" "M2.3 Add Credentials (XLS-70) end-to-end" "type:tx,type:method,amendment:credentials" \
"Add CredentialCreate/Accept/Delete transactions, Credential ledger entry, AuthorizeCredentials/UnauthorizeCredentials on DepositPreauth, CredentialIDs field on Payment / EscrowFinish / PaymentChannelClaim / AccountDelete. Extend deposit_authorized response to carry credentials; add ledger_entry credential lookup."
add "$M2" "M2.4 Add DID support (XLS-40)" "type:tx,amendment:did" \
"Implement DIDSet, DIDDelete transactions and DID ledger entry."
add "$M2" "M2.5 Add Oracle support (XLS-47) + get_aggregate_price" "type:tx,type:method,amendment:oracle" \
"Implement OracleSet, OracleDelete transactions, Oracle ledger entry, get_aggregate_price RPC, and OracleLedgerEntryParams for ledger_entry."
add "$M2" "M2.6 Add NFTokenModify (DynamicNFT)" "type:tx,amendment:dynamic-nft" \
"Implement NFTokenModify transaction and tfMutable flag on NFTokenMint."
add "$M2" "M2.7 Token Escrow support" "type:tx" \
"Allow EscrowCreate / EscrowFinish to carry issued / MPT amounts, mirroring xrpl4j #641."
add "$M2" "M2.8 Deep Freeze flags" "type:tx,amendment:deep-freeze" \
"Add tfSetDeepFreeze/tfClearDeepFreeze on TrustSet and lsfLowDeepFreeze/lsfHighDeepFreeze on RippleState."
add "$M2" "M2.9 ExpandedSignerList: WalletLocator + raised limit" "type:tx,amendment:expanded-signer-list" \
"Add WalletLocator field to SignerEntry and raise SignerList max to 32 entries."
add "$M2" "M2.10 DisallowIncoming AccountSet flags" "type:tx" \
"Add asfDisallowIncomingCheck, asfDisallowIncomingPayChan, asfDisallowIncomingNFTOffer, asfDisallowIncomingTrustline."
add "$M2" "M2.11 Add frozenBalances to gateway_balances response" "type:method" \
"Mirror xrpl4j #637; surface frozen balances in Models/Methods/GatewayBalances.cs."
add "$M2" "M2.12 Re-enable deposit_authorized, transaction_entry, nft_info, submit_multisigned, path_find, ripple_path_find on IXrplClient" "type:method" \
"All commented-out methods in IXrplClient.cs need real implementations + tests + docs."

# M3
add "$M3" "M3.1 Bridge ledger entry + XChainBridge codec field type" "type:codec" "Mirror Models/Ledger/* to add LOBridge.cs and a binary codec encoder for the XChainBridge field type."
add "$M3" "M3.2 XChainCreateBridge + XChainModifyBridge transactions" "type:tx,amendment:xchain" "Add transactions, XChainModifyBridgeFlags, and IT against a sidechain devnet."
add "$M3" "M3.3 XChainCommit, XChainClaim, XChainCreateClaimID transactions" "type:tx,amendment:xchain" "Add transactions and XChainOwnedClaimID ledger entry."
add "$M3" "M3.4 XChainAccountCreateCommit + XChainOwnedCreateAccountClaimID" "type:tx,amendment:xchain" "Add transactions and ledger entry."
add "$M3" "M3.5 XChainAddClaimAttestation + XChainAddAccountCreateAttestation" "type:tx,amendment:xchain" "Add transactions and attestation models (mirror xrpl4j XChainClaimProofSig / XChainCreateAccountProofSig)."
add "$M3" "M3.6 Sugar: CrossChainPayment helper + sidechain ITs" "type:tx,amendment:xchain" "Wire Utils/CreateCrossChainPayment.cs to the new transactions and add ITs against a sidechain devnet."

# M4
add "$M4" "M4.1 PermissionedDomainSet/Delete + PermissionedDomain ledger entry" "type:tx,amendment:permissioned-domain" "Implement transactions, ledger entry, ledger_entry params."
add "$M4" "M4.2 OfferCreate / AMM* DomainID field (Permissioned DEX)" "type:tx,amendment:permissioned-dex" "Add DomainID to OfferCreate, AMMCreate, AMMDeposit, AMMWithdraw transactions per XLS-81."
add "$M4" "M4.3 PermissionedDomainLedgerEntryParams in ledger_entry" "type:method,amendment:permissioned-domain" ""

# M5
add "$M5" "M5.1 Implement STHash192 in Xrpl.BinaryCodec" "type:codec" "Required for MPT issuance IDs."
add "$M5" "M5.2 Implement MPT variant of STAmount" "type:codec,amendment:mpt" ""
add "$M5" "M5.3 Implement XChainBridge and Issue field types" "type:codec,amendment:xchain" ""
add "$M5" "M5.4 server_definitions + DefinitionsLoader" "type:method,type:codec" \
"Add Models/Methods/ServerDefinitions.cs and a runtime loader so the codec can pick up new fields/transactions from the network without a library upgrade. Reference: xrpl4j #674 / xrpl.js definitions.json."
add "$M5" "M5.5 Refresh bundled definitions.json" "type:codec" \
"Sync Base/Xrpl.BinaryCodec/Resources/definitions.json with the latest from XRPLF/xrpl.js packages/ripple-binary-codec."
add "$M5" "M5.6 Enforce NetworkID in binary signer for chain id > 1024" "type:codec" \
"IXrplClient.SetNetworkId already exists; the binary signer must include NetworkID in the signing payload when required."
add "$M5" "M5.7 Add codec round-trip vectors against rippled" "type:codec" \
"Generate golden vectors with rippled --conf and assert XrplCSharp encode/decode parity."

# M6
add "$M6" "M6.1 Add JSON-RPC transport (XrplJsonRpcClient)" "type:method" \
"Provide a JSON-RPC alternative to the existing WebSocket client (xrpl4j is JSON-RPC only)."
add "$M6" "M6.2 SubmitAndWait sugar" "type:method" \
"Submit + poll tx until LastLedgerSequence elapses or the tx is validated."
add "$M6" "M6.3 IsFinal helper + Finality enum" "type:method" "Mirror xrpl4j XrplClient.isFinal(...)."
add "$M6" "M6.4 Strong value types: Address, Hash256, XrpCurrencyAmount, IssuedCurrencyAmount, LedgerIndex" "type:codec" \
"Replace ad-hoc strings in Models/* with strong value types and converters."
add "$M6" "M6.5 ChangeServer with subscription replay" "type:method" \
"After ChangeServer, automatically resubscribe to streams the caller had subscribed to."
add "$M6" "M6.6 Stabilize OnError / OnConnected / OnTransaction events" "type:method" \
"All five event delegates in IXrplClient are commented out; expose them with proper async semantics."
add "$M6" "M6.7 Connection retry/backoff with jitter" "type:method" ""

# M7
add "$M7" "M7.1 Introduce KeyType enum" "type:crypto" \
"Replace the magic string XrplWallet.DEFAULT_ALGORITHM=ed25519 with a typed KeyType enum."
add "$M7" "M7.2 Introduce Seed/Passphrase/Entropy/PrivateKey/PublicKey value types" "type:crypto" ""
add "$M7" "M7.3 Introduce SingleSignedTransaction + MultiSignedTransaction" "type:crypto" ""
add "$M7" "M7.4 ISignatureService abstraction + BouncyCastle implementation" "type:crypto" ""
add "$M7" "M7.5 Sample remote signature service (KMS/Key Vault) + docs" "type:crypto,type:docs" ""
add "$M7" "M7.6 Multi-sign integration tests with mixed key types" "type:crypto,type:ci" ""

# M8
add "$M8" "M8.1 Test coverage for every new tx in M2/M3/M4" "type:ci" ""
add "$M8" "M8.2 Devnet/AMM-Devnet matrix in CI" "type:ci" ""
add "$M8" "M8.3 Publish DocFx site to GitHub Pages on push to main" "type:docs" ""
add "$M8" "M8.4 Write MIGRATION_2_to_3.md" "type:docs" ""
add "$M8" "M8.5 NuGet release workflow auto-tagged from CHANGES.md" "type:ci" ""
add "$M8" "M8.6 Cross-target dotnet pack parity check (net6/8/9)" "type:ci" ""
add "$M8" "M8.7 Dependabot weekly run for NuGet packages" "type:ci" ""

log "done."
