//
//  DeviceType.swift
//  PlansApp
//
//  Created by Adrian Rodriguez Llorens on 27/01/26.
//

import Foundation

enum Discipline: String, CaseIterable, Identifiable {
    case alarm = "Alarma"
    case hydraulic = "Hidráulico" // futuro

    var id: String { rawValue }
}

enum DeviceType: String, CaseIterable, Identifiable, Codable {
    // MARK: Alarm / Detection (según tus PDFs)
    case alarm_aborto
    case alarm_anunciador_remoto
    case alarm_control_panel
    case alarm_estacion_manual
    case alarm_flama_ir
    case alarm_flama_uv
    case alarm_flama_uv_ir
    case alarm_gas_ch4
    case alarm_gas_co
    case alarm_gas_co2
    case alarm_luz_pared
    case alarm_luz_techo
    case alarm_modulo_aislador
    case alarm_modulo_control_salida
    case alarm_modulo_entrada_dual
    case alarm_modulo_entrada_monitoreada
    case alarm_modulo_entrada_salida
    case alarm_modulo_liberacion
    case alarm_modulo_relay
    case alarm_multicriterio
    case alarm_photo
    case alarm_photo_duct
    case alarm_sirena_estrobo
    case alarm_supervision_valvula
    case alarm_supresion_control_panel
    case alarm_termico
    case alarm_termico_cable
    case alarm_water_flow

    var id: String { rawValue }

    /// Nombre exacto del asset (como lo tienes en Assets)
    var assetName: String { rawValue }

    var discipline: Discipline {
        switch self {
        default:
            return .alarm
        }
    }

    /// Nombre amigable para el usuario (lo puedes ajustar luego sin romper nada)
    var title: String {
        switch self {
        case .alarm_aborto: return "Aborto"
        case .alarm_anunciador_remoto: return "Anunciador remoto"
        case .alarm_control_panel: return "Panel de control"
        case .alarm_estacion_manual: return "Estación manual"
        case .alarm_flama_ir: return "Detector flama IR"
        case .alarm_flama_uv: return "Detector flama UV"
        case .alarm_flama_uv_ir: return "Detector flama UV/IR"
        case .alarm_gas_ch4: return "Detector gas CH4"
        case .alarm_gas_co: return "Detector gas CO"
        case .alarm_gas_co2: return "Detector gas CO2"
        case .alarm_luz_pared: return "Luz pared"
        case .alarm_luz_techo: return "Luz techo"
        case .alarm_modulo_aislador: return "Módulo aislador"
        case .alarm_modulo_control_salida: return "Módulo control salida"
        case .alarm_modulo_entrada_dual: return "Módulo entrada dual"
        case .alarm_modulo_entrada_monitoreada: return "Módulo entrada monitoreada"
        case .alarm_modulo_entrada_salida: return "Módulo entrada/salida"
        case .alarm_modulo_liberacion: return "Módulo liberación"
        case .alarm_modulo_relay: return "Módulo relay"
        case .alarm_multicriterio: return "Detector multicriterio"
        case .alarm_photo: return "Detector fotoeléctrico"
        case .alarm_photo_duct: return "Detector ducto (foto)"
        case .alarm_sirena_estrobo: return "Sirena/Estrobo"
        case .alarm_supervision_valvula: return "Supervisión válvula"
        case .alarm_supresion_control_panel: return "Panel supresión"
        case .alarm_termico: return "Detector térmico"
        case .alarm_termico_cable: return "Cable térmico"
        case .alarm_water_flow: return "Waterflow"
        }
    }

    /// Lista filtrable por disciplina
    static func items(for discipline: Discipline) -> [DeviceType] {
        switch discipline {
        case .alarm:
            return [
                .alarm_control_panel,
                .alarm_supresion_control_panel,
                .alarm_anunciador_remoto,
                .alarm_estacion_manual,
                .alarm_sirena_estrobo,
                .alarm_luz_pared,
                .alarm_luz_techo,
                .alarm_photo,
                .alarm_photo_duct,
                .alarm_termico,
                .alarm_termico_cable,
                .alarm_multicriterio,
                .alarm_flama_uv,
                .alarm_flama_ir,
                .alarm_flama_uv_ir,
                .alarm_gas_co,
                .alarm_gas_co2,
                .alarm_gas_ch4,
                .alarm_water_flow,
                .alarm_supervision_valvula,
                .alarm_modulo_aislador,
                .alarm_modulo_relay,
                .alarm_modulo_control_salida,
                .alarm_modulo_entrada_monitoreada,
                .alarm_modulo_entrada_dual,
                .alarm_modulo_entrada_salida,
                .alarm_modulo_liberacion,
                .alarm_aborto
            ]
        case .hydraulic:
            return []
        }
    }
}

