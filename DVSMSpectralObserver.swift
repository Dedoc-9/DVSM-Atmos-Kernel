// =====================================================
// DVSM v21.x — OPTIONAL EXTENSION
// File: DVSMSpectralObserver.swift
// Layer: 2.5 (Observational Augmentation)
// =====================================================
// 
// PURPOSE:
// Provides high-fidelity signal conditioning and spectral
// inspection for the DVSM monolith. 
//
// DESIGN PRINCIPLES:
// 1. NON-AUTHORITATIVE: Strictly observational.
// 2. DETACHABLE: Operates as a companion to Layer 2.
// 3. HARDENED: Uses Accelerate/vDSP for stable FFT logic.
//
// AUTHOR: Daniel J. Dillberg
// RECURSIVE IDENTIFIER: [DVSM-SIGNAL-v21-B]
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
    case manifoldDrift     // Unstable resonance detected
}

public struct DVSMNoiseSettings: Sendable {
    public var persistenceFloor: Double = 0.10
    public var spectralSpikeThreshold: Double = 12.0
    public var emaAlpha: Double = 0.12
    public var windowSize: Int = 128
    
    public static let standard = DVSMNoiseSettings()
}

// =====================================================
// MARK: - SPECTRAL OBSERVER
// =====================================================

public final class DVSMSpectralObserver: Sendable {
    
    private let log = OSLog(subsystem: "com.dvsm.noise", category: "Spectral")
    private let settings: DVSMNoiseSettings
    
    public init(settings: DVSMNoiseSettings = .standard) {
        self.settings = settings
    }
    
    /// Entry point for Layer 2.5 observation.
    /// Ingests post-pulse data to generate diagnostic clarity.
    public func inspect(samples: [Double], persistence: Double) -> DVSMConditionedPulse {
        
        let energy = computeSpectralEnergy(from: samples)
        
        let classification = classify(
            persistence: persistence,
            energy: energy
        )
        
        return DVSMConditionedPulse(
            spectralEnergy: energy,
            classification: classification,
            timestamp: Date().timeIntervalSince1970
        )
    }
    
    // =====================================================
    // MARK: - INTERNAL PROCESSING (NON-AUTHORITATIVE)
    // =====================================================
    
    private func computeSpectralEnergy(from samples: [Double]) -> Double {
        guard samples.count >= 8 else { return 0.0 }
        
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
            return .manifoldDrift
        }
        return .stableSignal
    }
}

// =====================================================
// MARK: - DATA STRUCTURES
// =====================================================

public struct DVSMConditionedPulse: Sendable {
    public let spectralEnergy: Double
    public let classification: DVSMNoiseClass
    public let timestamp: Double
}

public struct DVSMPersistenceEMA: Sendable {
    private(set) public var current: Double = 1.0
    private let alpha: Double

    public init(alpha: Double) {
        self.alpha = max(0.001, min(alpha, 1.0))
    }

    public mutating func update(with value: Double) {
        current = (alpha * value) + ((1.0 - alpha) * current)
    }
}
