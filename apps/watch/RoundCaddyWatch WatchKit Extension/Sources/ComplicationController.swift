import ClockKit
import SwiftUI

/// Provides Watch Face complications showing golf round data
class ComplicationController: NSObject, CLKComplicationDataSource {
    
    // MARK: - Complication Configuration
    
    func getComplicationDescriptors(handler: @escaping ([CLKComplicationDescriptor]) -> Void) {
        let descriptors = [
            CLKComplicationDescriptor(
                identifier: "roundcaddy_distance",
                displayName: "Distance to Green",
                supportedFamilies: [
                    .circularSmall,
                    .modularSmall,
                    .modularLarge,
                    .utilitarianSmall,
                    .utilitarianSmallFlat,
                    .utilitarianLarge,
                    .graphicCorner,
                    .graphicCircular,
                    .graphicRectangular,
                    .graphicExtraLarge
                ]
            ),
            CLKComplicationDescriptor(
                identifier: "roundcaddy_score",
                displayName: "Current Score",
                supportedFamilies: [
                    .circularSmall,
                    .modularSmall,
                    .modularLarge,
                    .utilitarianSmall,
                    .utilitarianSmallFlat,
                    .graphicCorner,
                    .graphicCircular
                ]
            )
        ]
        handler(descriptors)
    }
    
    func handleSharedComplicationDescriptors(_ complicationDescriptors: [CLKComplicationDescriptor]) {
        // Handle shared complications if needed
    }
    
    // MARK: - Timeline Configuration
    
    func getTimelineEndDate(for complication: CLKComplication, withHandler handler: @escaping (Date?) -> Void) {
        // No end date - always current
        handler(nil)
    }
    
    func getPrivacyBehavior(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationPrivacyBehavior) -> Void) {
        // Show placeholder when device is locked
        handler(.showOnLockScreen)
    }
    
    // MARK: - Timeline Population
    
    func getCurrentTimelineEntry(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTimelineEntry?) -> Void) {
        let template = createTemplate(for: complication)
        
        if let template = template {
            let entry = CLKComplicationTimelineEntry(date: Date(), complicationTemplate: template)
            handler(entry)
        } else {
            handler(nil)
        }
    }
    
    func getTimelineEntries(for complication: CLKComplication, after date: Date, limit: Int, withHandler handler: @escaping ([CLKComplicationTimelineEntry]?) -> Void) {
        // Golf data changes unpredictably, so we don't provide future entries
        handler(nil)
    }
    
    // MARK: - Placeholder Templates
    
    func getLocalizableSampleTemplate(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTemplate?) -> Void) {
        let template = createSampleTemplate(for: complication)
        handler(template)
    }
    
    // MARK: - Template Creation
    
    private func createTemplate(for complication: CLKComplication) -> CLKComplicationTemplate? {
        let roundManager = RoundManager.shared
        let isRoundActive = roundManager.isRoundActive
        
        switch complication.identifier {
        case "roundcaddy_distance":
            return createDistanceTemplate(for: complication.family, isActive: isRoundActive)
        case "roundcaddy_score":
            return createScoreTemplate(for: complication.family, isActive: isRoundActive)
        default:
            return createDistanceTemplate(for: complication.family, isActive: isRoundActive)
        }
    }
    
    private func createDistanceTemplate(for family: CLKComplicationFamily, isActive: Bool) -> CLKComplicationTemplate? {
        let roundManager = RoundManager.shared
        let gpsManager = GPSManager.shared
        
        let distanceText: String
        let distanceValue: Int?
        
        let center = gpsManager.distanceToGreenCenter
        if isActive && center > 0 {
            distanceValue = center
            distanceText = "\(center)y"
        } else {
            distanceValue = nil
            distanceText = "---"
        }
        
        let front = gpsManager.distanceToGreenFront
        let back = gpsManager.distanceToGreenBack
        
        switch family {
        case .circularSmall:
            return CLKComplicationTemplateCircularSmallSimpleText(
                textProvider: CLKSimpleTextProvider(text: distanceText, shortText: distanceText)
            )
            
        case .modularSmall:
            return CLKComplicationTemplateModularSmallSimpleText(
                textProvider: CLKSimpleTextProvider(text: distanceText)
            )
            
        case .modularLarge:
            let headerText = isActive ? "Hole \(roundManager.currentHole)" : "RoundCaddy"
            let body1Text = isActive ? "Center: \(distanceText)" : "Tap to start"
            let body2Text = isActive && front > 0 ? "Front: \(front)y" : "a round"
            
            return CLKComplicationTemplateModularLargeStandardBody(
                headerTextProvider: CLKSimpleTextProvider(text: headerText),
                body1TextProvider: CLKSimpleTextProvider(text: body1Text),
                body2TextProvider: CLKSimpleTextProvider(text: body2Text)
            )
            
        case .utilitarianSmall, .utilitarianSmallFlat:
            return CLKComplicationTemplateUtilitarianSmallFlat(
                textProvider: CLKSimpleTextProvider(text: isActive ? "⛳ \(distanceText)" : "⛳ Golf")
            )
            
        case .utilitarianLarge:
            let text = isActive ? "⛳ \(distanceText) to green" : "⛳ Start Round"
            return CLKComplicationTemplateUtilitarianLargeFlat(
                textProvider: CLKSimpleTextProvider(text: text)
            )
            
        case .graphicCorner:
            let gaugeProvider = CLKSimpleGaugeProvider(
                style: .fill,
                gaugeColor: .green,
                fillFraction: isActive ? min(Float(distanceValue ?? 200) / 250.0, 1.0) : 0
            )
            return CLKComplicationTemplateGraphicCornerGaugeText(
                gaugeProvider: gaugeProvider,
                outerTextProvider: CLKSimpleTextProvider(text: distanceText)
            )
            
        case .graphicCircular:
            return CLKComplicationTemplateGraphicCircularStackText(
                line1TextProvider: CLKSimpleTextProvider(text: isActive ? "⛳" : "🏌️"),
                line2TextProvider: CLKSimpleTextProvider(text: distanceText)
            )
            
        case .graphicRectangular:
            let currentPar = roundManager.holeScores.first { $0.holeNumber == roundManager.currentHole }?.par ?? 4
            let headerText = isActive ? "Hole \(roundManager.currentHole) • Par \(currentPar)" : "RoundCaddy"
            let body1Text = isActive ? "Center: \(distanceText)" : "No active round"
            let body2Text = isActive ? "F: \(front > 0 ? "\(front)" : "--") | B: \(back > 0 ? "\(back)" : "--")" : "Tap to start"
            
            return CLKComplicationTemplateGraphicRectangularStandardBody(
                headerTextProvider: CLKSimpleTextProvider(text: headerText),
                body1TextProvider: CLKSimpleTextProvider(text: body1Text),
                body2TextProvider: CLKSimpleTextProvider(text: body2Text)
            )
            
        case .graphicExtraLarge:
            return CLKComplicationTemplateGraphicExtraLargeCircularStackText(
                line1TextProvider: CLKSimpleTextProvider(text: isActive ? "⛳" : "🏌️"),
                line2TextProvider: CLKSimpleTextProvider(text: distanceText)
            )
            
        default:
            return nil
        }
    }
    
    private func createScoreTemplate(for family: CLKComplicationFamily, isActive: Bool) -> CLKComplicationTemplate? {
        let roundManager = RoundManager.shared
        
        let scoreText: String
        let scoreRelativeToPar: Int
        
        if isActive {
            // Calculate from holeScores
            let scores = roundManager.holeScores.compactMap { $0.score }
            let pars = roundManager.holeScores.map { $0.par }
            
            let totalScore = scores.reduce(0, +)
            let holesPlayed = scores.count
            let totalPar = pars.prefix(holesPlayed).reduce(0, +)
            scoreRelativeToPar = totalScore - totalPar
            
            if scoreRelativeToPar == 0 {
                scoreText = "E"
            } else if scoreRelativeToPar > 0 {
                scoreText = "+\(scoreRelativeToPar)"
            } else {
                scoreText = "\(scoreRelativeToPar)"
            }
        } else {
            scoreRelativeToPar = 0
            scoreText = "--"
        }
        
        switch family {
        case .circularSmall:
            return CLKComplicationTemplateCircularSmallSimpleText(
                textProvider: CLKSimpleTextProvider(text: scoreText)
            )
            
        case .modularSmall:
            return CLKComplicationTemplateModularSmallSimpleText(
                textProvider: CLKSimpleTextProvider(text: scoreText)
            )
            
        case .modularLarge:
            let scores = roundManager.holeScores.compactMap { $0.score }
            let totalScore = scores.reduce(0, +)
            let holesPlayed = scores.count
            
            return CLKComplicationTemplateModularLargeStandardBody(
                headerTextProvider: CLKSimpleTextProvider(text: isActive ? "Score" : "RoundCaddy"),
                body1TextProvider: CLKSimpleTextProvider(text: isActive ? "\(totalScore) (\(scoreText))" : "No round"),
                body2TextProvider: CLKSimpleTextProvider(text: isActive ? "Thru \(holesPlayed) holes" : "Tap to start")
            )
            
        case .utilitarianSmall, .utilitarianSmallFlat:
            return CLKComplicationTemplateUtilitarianSmallFlat(
                textProvider: CLKSimpleTextProvider(text: isActive ? "🏌️ \(scoreText)" : "🏌️")
            )
            
        case .graphicCorner:
            return CLKComplicationTemplateGraphicCornerStackText(
                innerTextProvider: CLKSimpleTextProvider(text: isActive ? "Score" : "Golf"),
                outerTextProvider: CLKSimpleTextProvider(text: scoreText)
            )
            
        case .graphicCircular:
            return CLKComplicationTemplateGraphicCircularStackText(
                line1TextProvider: CLKSimpleTextProvider(text: "🏌️"),
                line2TextProvider: CLKSimpleTextProvider(text: scoreText)
            )
            
        default:
            return nil
        }
    }
    
    private func createSampleTemplate(for complication: CLKComplication) -> CLKComplicationTemplate? {
        switch complication.family {
        case .circularSmall:
            return CLKComplicationTemplateCircularSmallSimpleText(
                textProvider: CLKSimpleTextProvider(text: "147y")
            )
            
        case .modularSmall:
            return CLKComplicationTemplateModularSmallSimpleText(
                textProvider: CLKSimpleTextProvider(text: "147y")
            )
            
        case .modularLarge:
            return CLKComplicationTemplateModularLargeStandardBody(
                headerTextProvider: CLKSimpleTextProvider(text: "Hole 7 • Par 4"),
                body1TextProvider: CLKSimpleTextProvider(text: "Center: 147y"),
                body2TextProvider: CLKSimpleTextProvider(text: "Front: 135y")
            )
            
        case .utilitarianSmall, .utilitarianSmallFlat:
            return CLKComplicationTemplateUtilitarianSmallFlat(
                textProvider: CLKSimpleTextProvider(text: "⛳ 147y")
            )
            
        case .utilitarianLarge:
            return CLKComplicationTemplateUtilitarianLargeFlat(
                textProvider: CLKSimpleTextProvider(text: "⛳ 147y to green")
            )
            
        case .graphicCorner:
            return CLKComplicationTemplateGraphicCornerStackText(
                innerTextProvider: CLKSimpleTextProvider(text: "Distance"),
                outerTextProvider: CLKSimpleTextProvider(text: "147y")
            )
            
        case .graphicCircular:
            return CLKComplicationTemplateGraphicCircularStackText(
                line1TextProvider: CLKSimpleTextProvider(text: "⛳"),
                line2TextProvider: CLKSimpleTextProvider(text: "147y")
            )
            
        case .graphicRectangular:
            return CLKComplicationTemplateGraphicRectangularStandardBody(
                headerTextProvider: CLKSimpleTextProvider(text: "Hole 7 • Par 4"),
                body1TextProvider: CLKSimpleTextProvider(text: "Center: 147y"),
                body2TextProvider: CLKSimpleTextProvider(text: "F: 135 | B: 162")
            )
            
        case .graphicExtraLarge:
            return CLKComplicationTemplateGraphicExtraLargeCircularStackText(
                line1TextProvider: CLKSimpleTextProvider(text: "⛳"),
                line2TextProvider: CLKSimpleTextProvider(text: "147y")
            )
            
        default:
            return nil
        }
    }
    
    // MARK: - Refresh Complications
    
    static func reloadComplications() {
        let server = CLKComplicationServer.sharedInstance()
        for complication in server.activeComplications ?? [] {
            server.reloadTimeline(for: complication)
        }
    }
    
    static func extendComplications() {
        let server = CLKComplicationServer.sharedInstance()
        for complication in server.activeComplications ?? [] {
            server.extendTimeline(for: complication)
        }
    }
}

// MARK: - Extension for RoundManager to trigger complication updates

extension RoundManager {
    func updateComplications() {
        ComplicationController.reloadComplications()
    }
}
