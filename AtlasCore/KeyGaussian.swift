import Foundation
import CoreGraphics

/// A 2D Gaussian distribution representing where a user's taps tend to fall
/// when they mean to press a specific key.
///
/// In plain English: this is one letter's "cloud" — the average tap location
/// (`meanX`, `meanY`) plus how spread out the taps are (`varX`, `varY`, `covXY`).
///
/// The Gaussian is updated online via exponential moving average (EMA) so it
/// adapts to the user without storing every historical tap.
struct KeyGaussian: Codable {
    /// Average tap X position for this key, in keyboard-local coordinates (points).
    var meanX: Double
    /// Average tap Y position for this key.
    var meanY: Double
    /// Original visible key center. Used as a prior so learned means cannot drift forever.
    var initialCenterX: Double
    var initialCenterY: Double
    var keyWidth: Double
    var keyHeight: Double
    /// Variance in X (how spread out horizontally the taps are).
    var varX: Double
    /// Variance in Y.
    var varY: Double
    /// Covariance between X and Y. Captures diagonal spread
    /// (e.g. a right-handed thumb naturally tilts taps along a diagonal).
    var covXY: Double
    /// Number of taps observed for this key. Used to pick an adaptation rate
    /// that's faster when we have little data and slower once we have a lot.
    var sampleCount: Int

    /// Initialize centered on the visible key with sensible default spread.
    /// `keyWidth` and `keyHeight` are the visible key dimensions in points.
    init(centerX: Double, centerY: Double, keyWidth: Double, keyHeight: Double) {
        self.meanX = centerX
        self.meanY = centerY
        self.initialCenterX = centerX
        self.initialCenterY = centerY
        self.keyWidth = keyWidth
        self.keyHeight = keyHeight
        // Initial spread: ~half the key dimensions in each direction.
        // This says "I expect taps within roughly one key's width of the center."
        self.varX = (keyWidth * 0.5) * (keyWidth * 0.5)
        self.varY = (keyHeight * 0.5) * (keyHeight * 0.5)
        self.covXY = 0.0
        self.sampleCount = 0
    }

    private enum CodingKeys: String, CodingKey {
        case meanX
        case meanY
        case initialCenterX
        case initialCenterY
        case keyWidth
        case keyHeight
        case varX
        case varY
        case covXY
        case sampleCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        meanX = try container.decode(Double.self, forKey: .meanX)
        meanY = try container.decode(Double.self, forKey: .meanY)
        varX = try container.decode(Double.self, forKey: .varX)
        varY = try container.decode(Double.self, forKey: .varY)
        covXY = try container.decode(Double.self, forKey: .covXY)
        sampleCount = try container.decode(Int.self, forKey: .sampleCount)

        // Older saved models did not have anchor fields. Use the decoded mean as
        // a temporary fallback; TouchModel repairs this from the current layout.
        initialCenterX = try container.decodeIfPresent(Double.self, forKey: .initialCenterX) ?? meanX
        initialCenterY = try container.decodeIfPresent(Double.self, forKey: .initialCenterY) ?? meanY
        keyWidth = try container.decodeIfPresent(Double.self, forKey: .keyWidth) ?? max(sqrt(max(varX, 1)) * 2, 1)
        keyHeight = try container.decodeIfPresent(Double.self, forKey: .keyHeight) ?? max(sqrt(max(varY, 1)) * 2, 1)
        enforceBoundsAndVariance()
    }

    /// Log-likelihood that a tap at (x, y) was meant for this key.
    /// We return log-probability (not probability) because:
    ///   1. Numerical stability — probabilities get tiny, logs stay reasonable.
    ///   2. Combining multiple sources of evidence is just addition in log space.
    /// Higher = more likely.
    func logLikelihood(x: Double, y: Double) -> Double {
        let dx = x - meanX
        let dy = y - meanY

        // Determinant of the 2x2 covariance matrix.
        let det = varX * varY - covXY * covXY
        // Guard against degenerate covariance (would happen only with corrupt data).
        let safeDet = max(det, 1e-6)

        // Inverse covariance matrix entries:
        //   [ varY/det   -covXY/det ]
        //   [-covXY/det   varX/det  ]
        let invXX =  varY / safeDet
        let invYY =  varX / safeDet
        let invXY = -covXY / safeDet

        // Mahalanobis squared distance: (p - mu)^T * Sigma^-1 * (p - mu).
        // This is the "how many standard deviations away is this tap, accounting
        // for the cloud's tilt and stretch."
        let mahalanobis = dx * dx * invXX + 2.0 * dx * dy * invXY + dy * dy * invYY

        // Log of the multivariate Gaussian PDF, dropping the 2*pi constant
        // (which cancels out when comparing keys to each other).
        return -0.5 * mahalanobis - 0.5 * log(safeDet)
    }

    /// Update the Gaussian with one new observed tap, using exponential moving average.
    /// `alpha` controls how aggressively we adapt:
    ///   - Higher = adapt faster but jumpier
    ///   - Lower  = adapt slower but smoother
    /// We auto-scale alpha by sample count so the first few taps move the mean a lot
    /// and later taps only nudge it.
    mutating func update(x: Double, y: Double, baseAlpha: Double = 0.05) {
        // Effective alpha: high when sampleCount is low, settles to baseAlpha later.
        // For the first few taps we adapt faster; after that, smoothly.
        let warmupBoost = max(1.0, 5.0 / Double(sampleCount + 1))
        let alpha = min(0.25, baseAlpha * warmupBoost)

        let newMeanX = (1 - alpha) * meanX + alpha * x
        let newMeanY = (1 - alpha) * meanY + alpha * y

        // Variance/covariance update: EMA on the squared deviations from the new mean.
        let dx = x - newMeanX
        let dy = y - newMeanY
        let newVarX  = (1 - alpha) * varX  + alpha * (dx * dx)
        let newVarY  = (1 - alpha) * varY  + alpha * (dy * dy)
        let newCovXY = (1 - alpha) * covXY + alpha * (dx * dy)

        self.meanX = newMeanX
        self.meanY = newMeanY
        self.varX = newVarX
        self.varY = newVarY
        self.covXY = newCovXY
        self.sampleCount += 1
        enforceBoundsAndVariance()
    }

    mutating func repairLayoutAnchor(centerX: Double, centerY: Double, keyWidth: Double, keyHeight: Double) {
        self.initialCenterX = centerX
        self.initialCenterY = centerY
        self.keyWidth = keyWidth
        self.keyHeight = keyHeight
        enforceBoundsAndVariance()
    }

    private mutating func enforceBoundsAndVariance() {
        let anchorStrength = 0.005
        meanX = (1 - anchorStrength) * meanX + anchorStrength * initialCenterX
        meanY = (1 - anchorStrength) * meanY + anchorStrength * initialCenterY

        meanX = Self.clamp(meanX, min: initialCenterX - keyWidth * 0.5, max: initialCenterX + keyWidth * 0.5)
        meanY = Self.clamp(meanY, min: initialCenterY - keyHeight * 0.5, max: initialCenterY + keyHeight * 0.5)

        let minVarX = max((keyWidth * 0.25) * (keyWidth * 0.25), 16)
        let minVarY = max((keyHeight * 0.25) * (keyHeight * 0.25), 16)
        varX = max(varX, minVarX)
        varY = max(varY, minVarY)

        let maxCovariance = sqrt(varX * varY) * 0.95
        covXY = Self.clamp(covXY, min: -maxCovariance, max: maxCovariance)
    }

    private static func clamp(_ value: Double, min minimum: Double, max maximum: Double) -> Double {
        Swift.min(Swift.max(value, minimum), maximum)
    }
}
