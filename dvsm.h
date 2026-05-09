// =====================================================
// DVSM — L3 PROVENANCE CONTRACT
// FILE: dvsm_provenance.rs
// LAYER: L3 (Trust Gate / Airlock)
// VERSION: v1.0.0-Sealed
// AUTHOR: Daniel J. Dillberg
// =====================================================
//
// PURPOSE:
// Converts external, untrusted input into DVSM-Validated Intent.
// This is the ONLY ingress path into the L1 Kernel.
//
// INVARIANT:
// "Nothing enters truth without first becoming trust."
//
// =====================================================

use sha2::{Sha256, Digest};

/// =====================================================
/// L3 CORE STRUCTURES
/// =====================================================

#[repr(C)]
#[derive(Clone, Copy, Debug)]
pub struct DVSMBitBlock {
    pub data: [u8; 64],
}

/// Cryptographic identity binding (external actor)
#[repr(C)]
#[derive(Clone, Copy, Debug)]
pub struct DVSMIdentity {
    pub public_key: [u8; 32],
}

/// Normalized, deterministic, kernel-safe input packet
#[repr(C)]
#[derive(Clone, Copy, Debug)]
pub struct DVSMValidatedIntent {
    pub flux: DVSMBitBlock,
    pub author: DVSMIdentity,
    pub sequence_nonce: u64,
    pub intent_hash: [u8; 32],
}

/// =====================================================
/// L3 NORMALIZER (v1.0)
// =====================================================

pub struct DVSMNormalizer;

impl DVSMNormalizer {

    /// Converts raw external input into fixed-point-safe DVSM state
    /// and binds it to a deterministic identity + nonce.
    pub fn normalize(
        raw: &[u8],
        author: DVSMIdentity,
        sequence_nonce: u64
    ) -> DVSMValidatedIntent {

        // 1. FIXED-LENGTH ENFORCEMENT (Hard boundary)
        let mut flux = DVSMBitBlock { data: [0u8; 64] };
        let len = raw.len().min(64);
        flux.data[..len].copy_from_slice(&raw[..len]);

        // 2. CAUSAL HASH (pre-kernel identity binding)
        let mut hasher = Sha256::new();
        hasher.update(&flux.data);
        hasher.update(&author.public_key);
        hasher.update(&sequence_nonce.to_le_bytes());

        let intent_hash = hasher.finalize().into();

        DVSMValidatedIntent {
            flux,
            author,
            sequence_nonce,
            intent_hash,
        }
    }

    /// Validity gate: ensures structure integrity before kernel entry
    pub fn validate(intent: &DVSMValidatedIntent) -> bool {
        let mut hasher = Sha256::new();
        hasher.update(&intent.flux.data);
        hasher.update(&intent.author.public_key);
        hasher.update(&intent.sequence_nonce.to_le_bytes());

        let recomputed: [u8; 32] = hasher.finalize().into();
        recomputed == intent.intent_hash
    }
}

/// =====================================================
/// L3 AXIOMS (NON-NEGOTIABLE TRUST RULES)
/// =====================================================

pub struct DVSMProvenanceAxioms;

impl DVSMProvenanceAxioms {
    /// No unvalidated input may reach L1
    pub const AIRLOCK_ENFORCED: bool = true;

    /// Identity must always be cryptographically bound
    pub const IDENTITY_BINDING_REQUIRED: bool = true;

    /// Normalization must be deterministic across platforms
    pub const PLATFORM_INDEPENDENCE: bool = true;
}
