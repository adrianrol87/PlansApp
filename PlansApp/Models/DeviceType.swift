//
//  DeviceType.swift
//  PlansApp
//
//  Created by Adrian Rodriguez Llorens on 27/01/26.
//

import Foundation

enum DeviceType: String, Codable, CaseIterable, Identifiable {
    var id: String { rawValue }

    case smokeDetector
    case heatDetector
    case manualStation
    case hornStrobe
    case strobe
    case speaker

    var title: String {
        switch self {
        case .smokeDetector: return "Smoke"
        case .heatDetector: return "Heat"
        case .manualStation: return "Manual"
        case .hornStrobe: return "Horn/Strobe"
        case .strobe: return "Strobe"
        case .speaker: return "Speaker"
        }
    }

    // MVP con SF Symbols (luego cambias a iconos propios estilo NFPA)
    var systemImageName: String {
        switch self {
        case .smokeDetector: return "sensor"
        case .heatDetector: return "thermometer"
        case .manualStation: return "hand.tap"
        case .hornStrobe: return "speaker.wave.3"
        case .strobe: return "light.beacon.max"
        case .speaker: return "speaker"
        }
    }

    var shortCode: String {
        switch self {
        case .manualStation: return "MS"
        case .smokeDetector: return "SD"
        case .heatDetector: return "HD"
        case .hornStrobe: return "HS"
        case .strobe: return "ST"
        case .speaker: return "SP"
        }
    }
}
