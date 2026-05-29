//
//  SensitiveTextVisionService.swift
//  Blurrify
//
//  Vision text recognition + on-device heuristics for text that is often worth redacting.
//

import CoreGraphics
import UIKit
import Vision

fileprivate extension CGImagePropertyOrientation {
    init(_ uiOrientation: UIImage.Orientation) {
        switch uiOrientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}

/// Categories of text the auto-redactor looks for (on-device pattern checks only; not proof of real PII).
enum SensitiveRedactionKind: String, CaseIterable, Sendable {
    case emailAddress
    case usTelephoneNumber
    case internationalTelephoneNumber
    case socialSecurityNumber
    case paymentCardNumber
    case cvvCode
    case expirationDate
    case personName
    case zipCode
    case streetAddress
    case poBox
    case cityAndState
    case ipAddress
    case bankRoutingNumber
    case apartmentOrSuiteLine
    case longDigitCluster
}

enum SensitiveTextHeuristics {

    /// Ordered rules: first matching kind wins for `primaryRedactionKind`.
    private static let regexRules: [(kind: SensitiveRedactionKind, pattern: String, options: NSRegularExpression.Options)] = [
        (.emailAddress, #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#, [.caseInsensitive]),
        (.usTelephoneNumber, #"\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}\b"#, []),
        (.internationalTelephoneNumber, #"(?:\+|00)\d{1,3}[\s.-]?(?:\(?\d{2,4}\)?[\s.-]?){1,4}\d{2,8}\b"#, []),
        (.socialSecurityNumber, #"\b\d{3}[-\s]?\d{2}[-\s]?\d{4}\b"#, []),
        (
            .expirationDate,
            #"(?i)(?:(?:exp|expiry|expiration|expires)(?:\s*date)?|valid(?:\s*thru|\s*through)|good\s+through|exp\s*\.?)\s*[:#.]?\s*(?:0?[1-9]|1[0-2])\s*[/\-.]\s*\d{2,4}\b"#,
            []
        ),
        (
            .cvvCode,
            #"(?i)(?:\b(?:cvv|cvc)2?\b|\bcid\b|\bcsc\b|\bcv2\b|security\s*code|card\s*(?:security|verification)(?:\s*code)?|verification\s*code)\s*[:#.*]?\s*\d{3,4}\b|\b\d{3,4}\s+(?:\b(?:cvv|cvc)2?\b|\bcid\b|\bcsc\b|\bcv2\b)\b"#,
            []
        ),
        (
            .personName,
            #"(?i)\b(?:mr|mrs|ms|miss|dr|prof)\.?\s+[A-Z][a-z]{1,22}(?:\s+[A-Z][a-z]{1,22}){0,2}\b"#,
            []
        ),
        (
            .personName,
            #"\b[A-Z][a-z]{1,22},\s*(?!\s*(?i:january|february|march|april|may|june|july|august|september|october|november|december)\b)[A-Z][a-z]{1,22}\b"#,
            []
        ),
        (.zipCode, #"\b\d{5}(?:-\d{4})?\b"#, []),
        (
            .streetAddress,
            #"\b\d{1,6}\s+[A-Za-z0-9'.-]+(?:\s+[A-Za-z0-9'.-]+){0,6}\s+(?:Street|St\.?|Avenue|Ave\.?|Road|Rd\.?|Boulevard|Blvd\.?|Lane|Ln\.?|Drive|Dr\.?|Court|Ct\.?|Way|Place|Pl\.?|Circle|Cir\.?|Terrace|Ter\.?|Highway|Hwy\.?|Route|Rt\.?|Parkway|Pkwy\.?)\b"#,
            [.caseInsensitive]
        ),
        (.poBox, #"P\.?\s*O\.?\s*Box\s+\d+"#, [.caseInsensitive]),
        (
            .cityAndState,
            #"\b[A-Za-z][A-Za-z'.-]*(?:\s+[A-Za-z][A-Za-z'.-]*){0,3},\s*[A-Z]{2}\b"#,
            []
        ),
        (
            .ipAddress,
            #"\b(?:(?:25[0-5]|2[0-4]\d|[01]?\d\d?)\.){3}(?:25[0-5]|2[0-4]\d|[01]?\d\d?)\b"#,
            []
        ),
        (.bankRoutingNumber, #"\b\d{9}\b"#, []),
        (
            .apartmentOrSuiteLine,
            #"(?:Apt\.?|Apartment|Suite|Ste\.?|Unit|Bldg\.?|Building)\s*#?\s*[A-Za-z0-9-]+"#,
            [.caseInsensitive]
        )
    ]

    /// Evaluated after payment-card logic so PANs are not mislabeled only as digit clusters.
    private static let longDigitClusterRegex: NSRegularExpression? = try? NSRegularExpression(pattern: #"\d{10,}"#, options: [])

    private static let compiledRules: [(SensitiveRedactionKind, NSRegularExpression)] = {
        regexRules.compactMap { rule in
            guard let rx = try? NSRegularExpression(pattern: rule.pattern, options: rule.options) else {
                return nil
            }
            return (rule.kind, rx)
        }
    }()

    /// `true` if any redaction kind matches.
    static func looksSensitive(_ raw: String) -> Bool {
        !matchingKinds(in: raw).isEmpty
    }

    /// All detector kinds that match this string (can be multiple overlaps).
    static func matchingKinds(in raw: String) -> [SensitiveRedactionKind] {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return [] }

        var found: Set<SensitiveRedactionKind> = []
        let full = NSRange(location: 0, length: (text as NSString).length)

        if kindForPaymentCard(text) != nil {
            found.insert(.paymentCardNumber)
        }

        for (kind, regex) in compiledRules {
            if regex.firstMatch(in: text, options: [], range: full) != nil {
                found.insert(kind)
            }
        }

        if matchesStandaloneExpiryDate(text) {
            found.insert(.expirationDate)
        }

        if matchesLikelyPersonName(text) {
            found.insert(.personName)
        }

        if !found.contains(.paymentCardNumber),
           let clusterRx = longDigitClusterRegex,
           clusterRx.firstMatch(in: text, options: [], range: full) != nil {
            found.insert(.longDigitCluster)
        }

        return SensitiveRedactionKind.allCases.filter { found.contains($0) }
    }

    /// First match in rule order (useful for debugging or UI labels).
    static func primaryRedactionKind(in raw: String) -> SensitiveRedactionKind? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        let full = NSRange(location: 0, length: (text as NSString).length)

        if kindForPaymentCard(text) != nil {
            return .paymentCardNumber
        }

        for (kind, regex) in compiledRules {
            if regex.firstMatch(in: text, options: [], range: full) != nil {
                return kind
            }
        }

        if matchesStandaloneExpiryDate(text) {
            return .expirationDate
        }

        if matchesLikelyPersonName(text) {
            return .personName
        }

        if let clusterRx = longDigitClusterRegex,
           clusterRx.firstMatch(in: text, options: [], range: full) != nil {
            return .longDigitCluster
        }
        return nil
    }

    /// Card-style `MM/YY` or `MM/YYYY` on a short line (no “EXP …” label).
    private static func matchesStandaloneExpiryDate(_ text: String) -> Bool {
        text.range(
            of: #"^\s*(?:0[1-9]|1[0-2])\s*/\s*(?:\d{2}|\d{4})\s*$"#,
            options: .regularExpression
        ) != nil && text.count <= 14
    }

    private static let nameFirstTokenBlocklist: Set<String> = [
        "the", "and", "for", "new", "san", "los", "las", "old", "fort", "lake",
        "north", "south", "east", "west", "credit", "debit", "bank", "total",
        "amount", "balance", "phone", "email", "street", "avenue", "united",
        "internal", "revenue", "social", "security", "american", "express",
        "visa", "mastercard", "discover", "january", "february", "march", "april",
        "june", "july", "august", "september", "october", "november", "december",
        "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday",
        "order", "ship", "billing", "payment", "account", "customer", "invoice",
        "receipt", "subtotal", "tax", "shipping", "return", "policy", "sales",
        "service", "support", "contact", "please", "thank", "sign", "here",
        "card", "holder", "name", "address", "city", "state", "zip", "country",
        "driver", "license", "passport", "national", "federal", "irs", "taxpayer",
        "university", "college", "school", "hospital", "medical", "pacific",
        "atlantic", "international", "global", "digital", "mobile", "home",
        "business", "office", "suite", "building", "floor", "room", "unit"
    ]

    private static let nameSecondTokenBlocklist: Set<String> = [
        "street", "st", "avenue", "ave", "road", "rd", "drive", "dr", "lane", "ln",
        "boulevard", "blvd", "court", "ct", "place", "pl", "way", "circle", "cir",
        "terrace", "ter", "highway", "hwy", "route", "rt", "parkway", "pkwy",
        "state", "union", "city", "york", "angeles", "francisco", "mexico", "jersey",
        "hampshire", "virginia", "carolina", "dakota", "island", "rica", "kingdom",
        "kong", "zealand", "africa", "europe", "asia", "america", "canada",
        "university", "college", "school", "hospital", "center", "centre", "plaza",
        "mall", "store", "shop", "market", "bank", "branch", "federal", "national",
        "january", "february", "march", "april", "may", "june", "july", "august",
        "september", "october", "november", "december"
    ]

    private static func matchesLikelyPersonName(_ text: String) -> Bool {
        if text.contains(where: \.isNumber) { return false }

        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (5...56).contains(t.count) else { return false }

        let full = NSRange(location: 0, length: (t as NSString).length)

        for (kind, regex) in compiledRules where kind == .personName {
            if regex.firstMatch(in: t, options: [], range: full) != nil {
                return false
            }
        }

        let parts = t.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard parts.count == 2 || parts.count == 3 else { return false }

        if parts.count == 3 {
            let middle = parts[1]
            guard middle.count <= 2 else { return false }
            guard middle.first?.isLetter == true, middle.first?.isUppercase == true else { return false }
            let rest = middle.dropFirst()
            guard rest.allSatisfy({ $0 == "." || $0.isLetter == false }) else { return false }
            return nameTokensPassBlocklist([parts[0], parts[2]])
        }

        return nameTokensPassBlocklist(parts)
    }

    private static func normalizedNameTokenKey(_ token: String) -> String {
        let head = token.split(separator: "-", omittingEmptySubsequences: false).first.map(String.init) ?? token
        return String(head.filter { $0.isLetter || $0 == "'" }).lowercased()
    }

    private static func nameTokensPassBlocklist(_ tokens: [String]) -> Bool {
        guard tokens.count == 2 else { return false }
        let a = tokens[0]
        let b = tokens[1]
        guard a.first?.isUppercase == true, b.first?.isUppercase == true else { return false }
        if looksLikeAcronymToken(a) || looksLikeAcronymToken(b) { return false }

        let aKey = normalizedNameTokenKey(a)
        let bKey = normalizedNameTokenKey(b)

        guard aKey.count >= 2, bKey.count >= 2 else { return false }
        guard !nameFirstTokenBlocklist.contains(aKey) else { return false }
        guard !nameFirstTokenBlocklist.contains(bKey) else { return false }
        guard !nameSecondTokenBlocklist.contains(aKey) else { return false }
        guard !nameSecondTokenBlocklist.contains(bKey) else { return false }
        return true
    }

    private static func looksLikeAcronymToken(_ s: String) -> Bool {
        let letters = s.filter(\.isLetter)
        return letters.count > 1 && letters.allSatisfy(\.isUppercase)
    }

    private static func kindForPaymentCard(_ text: String) -> SensitiveRedactionKind? {
        let digits = text.filter(\.isNumber)
        guard (13...19).contains(digits.count) else { return nil }

        if luhnCheck(digits) {
            return .paymentCardNumber
        }

        if text.range(of: #"\b(?:\d{4}[-\s]?){3}\d{4}\b"#, options: .regularExpression) != nil {
            return .paymentCardNumber
        }

        return nil
    }

    /// Luhn check for primary account numbers (reduces accidental matches on arbitrary digit runs).
    private static func luhnCheck(_ number: String) -> Bool {
        var sum = 0
        var alternate = false
        for ch in number.reversed() {
            guard let digit = ch.wholeNumberValue else { return false }
            var n = digit
            if alternate {
                n *= 2
                if n > 9 { n -= 9 }
            }
            sum += n
            alternate.toggle()
        }
        return sum % 10 == 0
    }
}

enum SensitiveTextVisionService {

    /// All sensitive text regions in **canvas** coordinates (reading order: top → bottom, left → right).
    /// Near-duplicate boxes from Vision are dropped using overlap on the smaller area.
    static func allSensitiveCanvasRects(in image: UIImage, canvasSize: CGSize) -> [CGRect] {
        guard canvasSize.width > 1, canvasSize.height > 1 else { return [] }
        guard let cgImage = image.cgImage else { return [] }

        let pixelWidth = CGFloat(cgImage.width)
        let pixelHeight = CGFloat(cgImage.height)

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])

        do {
            try handler.perform([request])
        } catch {
            return []
        }

        guard let observations = request.results as? [VNRecognizedTextObservation] else { return [] }

        let sorted = observations.sorted { a, b in
            let ay = a.boundingBox.maxY
            let by = b.boundingBox.maxY
            if abs(ay - by) > 0.02 {
                return ay > by
            }
            return a.boundingBox.minX < b.boundingBox.minX
        }

        var rects: [CGRect] = []
        for obs in sorted {
            guard let candidate = obs.topCandidates(1).first?.string else { continue }
            guard SensitiveTextHeuristics.looksSensitive(candidate) else { continue }

            let box = obs.boundingBox
            let pixelRect = CGRect(
                x: box.origin.x * pixelWidth,
                y: (1.0 - box.origin.y - box.size.height) * pixelHeight,
                width: box.size.width * pixelWidth,
                height: box.size.height * pixelHeight
            )

            let canvasRect = scalePixelRectToCanvas(
                pixelRect,
                pixelWidth: pixelWidth,
                pixelHeight: pixelHeight,
                canvasSize: canvasSize
            )
            rects.append(canvasRect)
        }

        return dedupeOverlappingRects(rects, overlapOnSmallerMin: 0.88)
    }

    /// First match only (same ordering as ``allSensitiveCanvasRects``).
    static func firstSensitiveCanvasRect(in image: UIImage, canvasSize: CGSize) -> CGRect? {
        allSensitiveCanvasRects(in: image, canvasSize: canvasSize).first
    }

    /// Intersection area divided by the smaller box’s area (1.0 when identical).
    private static func overlapRatioOnSmaller(_ a: CGRect, _ b: CGRect) -> CGFloat {
        let inter = a.intersection(b)
        guard inter.width > 1, inter.height > 1 else { return 0 }
        let interArea = inter.width * inter.height
        let aArea = max(a.width * a.height, 1)
        let bArea = max(b.width * b.height, 1)
        return interArea / min(aArea, bArea)
    }

    /// Keeps earlier (reading-order) rect when another is almost the same region.
    private static func dedupeOverlappingRects(_ rects: [CGRect], overlapOnSmallerMin: CGFloat) -> [CGRect] {
        var out: [CGRect] = []
        for r in rects {
            let isDup = out.contains { overlapRatioOnSmaller($0, r) >= overlapOnSmallerMin }
            if !isDup {
                out.append(r)
            }
        }
        return out
    }

    private static func scalePixelRectToCanvas(
        _ rect: CGRect,
        pixelWidth: CGFloat,
        pixelHeight: CGFloat,
        canvasSize: CGSize
    ) -> CGRect {
        let sx = canvasSize.width / pixelWidth
        let sy = canvasSize.height / pixelHeight
        return CGRect(
            x: rect.origin.x * sx,
            y: rect.origin.y * sy,
            width: rect.size.width * sx,
            height: rect.size.height * sy
        )
    }
}
