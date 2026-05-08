// =====================================================
// DVSM v21.x — OPTIONAL EXTENSION
// Author: Daniel J. Dillberg
// File: DVSMSpectralObserver.swift
// Layer: 2.5 (Observational Augmentation)
// =====================================================
//
// AUTHORSHIP & PROVENANCE:
// Author: Daniel J. Dillberg
// Status: Operational Reference Standard [Hardened]
// Identifier: [DVSM-SIGNAL-v21-B]
//
// PURPOSE:
// This extension provides the sensory apparatus for the
// self-stabilizing monolith. It transforms the kernel
// from a passive manifold into an active listener,
// capable of deconstructing the spectral signature of
// adversity in real-time.
//
// DESIGN PRINCIPLES:
// 1. DAMPING OVER REJECTION: Noise is attenuated, not discarded.
// 2. SPECTRAL INSPECTION: FFT-based oscillatory energy detection.
// 3. TEMPORAL STABILITY: EMA smoothing prevents trust spikes.
// 4. OPTIONALITY: Detachable and non-mutating to L1 core.
// =====================================================

import Foundation
import Accelerate
import CryptoKit
import OSLog

// =====================================================
// MARK: - CLASSIFICATION & SETTINGS
// =====================================================

public enum DVSMNoiseClass: String, Sendable {
    case stableSignal      // High trust, low oscillation
    case thermalNoise      // Low trust, distributed energy
    case adversarialSpike  // Concentrated spectral attack
    case manifoldInstability // Unstable resonance detected
}

public struct DVSMNoiseSettings: Sendable {
    public var enableSpectralInspection: Bool = true
    public var persistenceFloor: Double = 0.10
    public var spectralSpikeThreshold: Double = 12.0
    public var emaAlpha: Double = 0.12
    public var spectralWindow: Int = 128
    
    public static let standard = DVSMNoiseSettings()
}

// =====================================================
// MARK: - SIGNAL CONDITIONING ENGINE
// =====================================================

public final class DVSMSpectralObserver: Sendable {
    
    private let log = OSLog(subsystem: "com.dvsm.noise", category: "Conditioning")
    private let settings: DVSMNoiseSettings
    
    public init(settings: DVSMNoiseSettings = .standard) {
        self.settings = settings
    }
    
    /// Ingests signal samples to produce a conditioned diagnostic pulse.
    /// This is a Layer 2.5 interpretation of post-kernel truth.
    public func condition(samples: [Double], persistence: Double) -> DVSMConditionedPulse {
        
        // 1. Spectral Analysis (FFT)
        let energy = computeSpectralEnergy(from: samples)
        
        // 2. Classification Logic
        let classification = classify(
            persistence: persistence,
            energy: energy
        )
        
        return DVSMConditionedPulse(
            truth: Data(), // Reference to Kernel Hash would be mapped here
            persistence: persistence,
            emaPersistence: 0.0, // Calculated by the orchestrator
            spectralEnergy: energy,
            classification: classification
        )
    }
    
    // =====================================================
    // MARK: - INTERNAL INSPECTION (NON-AUTHORITATIVE)
    // =====================================================
    
    private func computeSpectralEnergy(from samples: [Double]) -> Double {
        guard settings.enableSpectralInspection, samples.count >= 8 else { return 0.0 }
        
        let count = samples.count
        let log2n = vDSP_Length(log2(Double(count)))
        
        guard let fft = vDSP_create_fftsetupD(log2n, FFTRadix(kFFTRadix2)) else {
            return 0.0
        }
        defer { vDSP_destroy_fftsetupD(fft) }
        
        var real = samples
        var imag = [Double](repeating: 0.0, count: count)
        
        real.withUnsafeMutableBufferPointer { rPtr in
            imag.withUnsafeMutableBufferPointer { iPtr in
                var split = DSPDoubleSplitComplex(realp: rPtr.baseAddress!, imagp: iPtr.baseAddress!)
                vDSP_fft_zipD(fft, &split, 1, log2n, FFTDirection(FFT_FORWARD))
            }
        }
        
        var magnitudes = [Double](repeating: 0.0, count: count / 2)
        real.withUnsafeMutableBufferPointer { rPtr in
            imag.withUnsafeMutableBufferPointer { iPtr in
                var split = DSPDoubleSplitComplex(realp: rPtr.baseAddress!, imagp: iPtr.baseAddress!)
                vDSP_zvmagsD(&split, 1, &magnitudes, 1, vDSP_Length(count / 2))
            }
        }
        
        return magnitudes.reduce(0.0, +) / Double(count)
    }
    
    private func classify(persistence: Double, energy: Double) -> DVSMNoiseClass {
        if energy >= settings.spectralSpikeThreshold {
            return .adversarialSpike
        }
        if persistence < settings.persistenceFloor {
            return .thermalNoise
        }
        if persistence < 0.25 && energy > 2.0 {
            return .manifoldInstability
        }
        return .stableSignal
    }
}

// =====================================================
// MARK: - DATA STRUCTURES
// =====================================================

public struct DVSMConditionedPulse: Sendable {
    public let truth: Data
    public let persistence: Double
    public let emaPersistence: Double
    public let spectralEnergy: Double
    public let classification: DVSMNoiseClass
}

public struct DVSMPersistenceEMA: Sendable {
    private(set) public var current: Double = 1.0
    private let alpha: Double

    public init(alpha: Double) {
        self.alpha = max(0.001, min(alpha, 1.0))
    }

    public mutating func ingest(_ value: Double) {
        current = (alpha * value) + ((1.0 - alpha) * current)
    }
}
