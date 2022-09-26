// Derived from https://github.com/salishseasoftware/LocationFormatter with the following license:
//
// This is free and unencumbered software released into the public domain.
//
// Anyone is free to copy, modify, publish, use, compile, sell, or
// distribute this software, either in source code form or as a compiled
// binary, for any purpose, commercial or non-commercial, and by any
// means.
//
// In jurisdictions that recognize copyright laws, the author or authors
// of this software dedicate any and all copyright interest in the
// software to the public domain. We make this dedication for the benefit
// of the public at large and to the detriment of our heirs and
// successors. We intend this dedication to be an overt act of
// relinquishment in perpetuity of all present and future rights to this
// software under copyright law.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
// IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
// OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
// ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.
//
// For more information, please refer to <https://unlicense.org>


import Foundation


#if canImport(ObjectiveC)
public typealias RefPtr = AutoreleasingUnsafeMutablePointer
#else
public typealias RefPtr = UnsafeMutablePointer
#endif


/// The format uses to represent a `Coordinate` value as a string.
public enum CoordinateFormat: String {

    /// Decimal Degrees (DD).
    ///
    /// Commonly used on the web and computer systems.
    case decimalDegrees

    /// Degrees and Decimal Minutes (DDM).
    ///
    /// Commonly used by electronic navigation equipment.
    case degreesDecimalMinutes

     /// Degrees, Minutes, Seconds (DMS).
     ///
     /// This is the format commonly used on printed charts and maps.
    case degreesMinutesSeconds

    /// Universal Transverse Mercator (UTM).
    case utm
}

extension CoordinateFormat: CustomStringConvertible {
    public var description: String {
        rawValue
    }
}

/// The hemisphere of either a latitude or longitude.
public enum CoordinateHemisphere: String {
    case north = "N"
    case south = "S"
    case east  = "E"
    case west  = "W"

    /// The orientation (latitude or longitude) of a hemisphere.
    var orientation: CoordinateOrientation {
        switch self {
        case .north, .south:
            return .latitude
        case .east, .west:
            return .longitude
        }
    }

    /// The range of degrees for a hemisphere.
    var range: ClosedRange<Degrees> {
        switch self {
        case .north:
            return 0.0 ... 90.0
        case .south:
            return -90.0 ... 0.0
        case .east:
            return 0.0 ... 180.0
        case .west:
            return -180.0 ... 0.0
        }
    }


    /// Returns the ``CoordinateOrientation`` of a given ``Degrees`` value.
    func orientation(for _: Degrees) -> CoordinateOrientation {
        switch self {
        case .north, .south:
            return .latitude
        case .east, .west:
            return .longitude
        }
    }
}


/// Defines whether a `Degrees` is intended to represent latitude or longitude.
public enum CoordinateOrientation {
    /// Unspecified.
    case none
    /// The coordinate represents a latitude.
    case latitude
    /// The coordinate represents a longitude.
    case longitude

    /// Range of degrees supported by the ``CoordinateOrientation``.
    var range: ClosedRange<Degrees> {
        switch self {
        case .latitude:
            return -90.0 ... 90.0
        case .longitude, .none:
            return -180.0 ... 180.0
        }
    }

    /// The hemisphere of the supplied degrees for this orientation.
    /// - Parameter degrees: A `Degrees` value.
    /// - Returns: The corresponding ``CoordinateHemisphere`` value, or `nil` if the degrees is outside the range of the ``CoordinateOrientation``.
    func hemisphere(for degrees: Degrees) -> CoordinateHemisphere? {
        switch self {
        case .latitude:
            guard (-90.0 ... 90.0).contains(degrees) else { return nil }
            return degrees >= 0.0 ? .north : .south

        case .longitude:
            guard (-180.0 ... 180.0).contains(degrees) else { return nil }
            return degrees >= 0.0 ? .east : .west
        case .none:
            return nil
        }
    }
}


/// Character symbols, or glyphs, used to annotate coordinate components.
enum CoordinateSymbol: Character, CaseIterable {
    /// Degree symbol `°`.
    case degree = "\u{000B0}"

    /// Apostrophe symbol `'`.
    ///
    /// The symbol commonly used to annotate minutes on the web and computer applications.
    case apostrophe = "\u{0027}"

    /// Quote symbol `"`.
    ///
    /// The symbol commonly used to annotate seconds on the web and computer applications.
    case quote = "\u{0022}"

    /// Prime symbol `′` (DiacriticalAcute).
    ///
    /// The symbol commonly used to annotate minutes on printed charts and maps.
    case prime = "\u{02032}"

    /// Double prime symbol `″` (DiacriticalDoubleAcute).
    ///
    /// The symbol commonly used to annotate seconds on printed charts and maps.
    case doublePrime = "\u{2033}"
}

extension CoordinateSymbol: CustomStringConvertible {
    var description: String {
        String(describing: rawValue)
    }
}

internal extension String {
    /// Replaces all symbols in string with a space character, and compacts multiple spaces.
    func desymbolized() -> Self {

        let symbols = CoordinateSymbol
            .allCases
            .map { String(describing:$0) }
            .joined(separator: "|")

        guard let regex = try? NSRegularExpression(pattern: "[\(symbols)]") else {
            return self
        }

        return regex
            .stringByReplacingMatches(in: self,
                                      range: NSRange(location: 0, length: self.count),
                                      withTemplate: " ")
            .replacingOccurrences(of: #"\s{2,}"#,
                                  with: " ",
                                  options: .regularExpression)
    }
}


/// The format uses to represent a `Degrees` value as a string.
enum DegreesFormat: String {

    /// Decimal Degrees (DD).
    case decimalDegrees

    /// Degrees and Decimal Minutes (DDM).
    case degreesDecimalMinutes

    /// Degrees, Minutes, Seconds (DMS).
    case degreesMinutesSeconds

    var regexPattern: String {
        switch self {
        case .decimalDegrees:
            return #"""
            (?x)
            (?# one of N, S, E, or W, optional)
            (?<PREFIX>[NSEW]?)
            \h?+
            (?# 1 to 3 digits, and 1 or more decimal places)
            (?<DEGREES>\-?\d{1,3}\.\d+)
            \h?+
            (?# one of N, S, E, or W, optional)
            (?<SUFFIX>[NSEW]?)
            \b
            """#

        case .degreesDecimalMinutes:
            return #"""
            (?x)
            (?# one of N, S, E, or W, optional)
            (?<PREFIX>[NSEW]?)
            \h?+
            (?# optional negative sign, then 1 to 3 digits)
            (?<DEGREES>\-?\d{1,3})
            \h
            (?# 1-2 digits, and 1 or more decimal places)
            (?<MINUTES>\d{1,2}\.\d+)
            \h?+
            (?# one of N, S, E, or W, optional)
            (?<SUFFIX>[NSEW]?)
            \b
            """#

        case .degreesMinutesSeconds:
            return #"""
            (?x)
            (?# One of N, S, E, or W, optional)
            (?<PREFIX>[NSEW]?)
            \h?+
            (?# Optional negative sign, then 1 to 3 digits)
            (?<DEGREES>\-?\d{1,3})
            \h
            (?# 1 -2 digits)
            (?<MINUTES>\d{1,2})
            \h
            (?# 1 to 2 digits)
            (?<SECONDS>\d{1,2}\.?\d*)
            \h?+
            (?# One of N, S, E, or W, optional)
            (?<SUFFIX>[NSEW]?)
            \b
            """#
        }
    }
}

// MARK: - CoordinateFormat support
extension DegreesFormat {
    init?(coordinateFormat: CoordinateFormat) {
        switch coordinateFormat {
        case .decimalDegrees:
            self = .decimalDegrees
        case .degreesDecimalMinutes:
            self = .degreesDecimalMinutes
        case .degreesMinutesSeconds:
            self = .degreesMinutesSeconds
        case .utm:
            return nil
        }
    }

    var coordinateFormat: CoordinateFormat {
        switch self {
        case .decimalDegrees:
            return .decimalDegrees
        case .degreesDecimalMinutes:
            return .degreesDecimalMinutes
        case .degreesMinutesSeconds:
            return .degreesMinutesSeconds
        }
    }
}


/// Display options
public struct DisplayOptions: OptionSet {
    /// Use a suffix to to represent the cardinal direction of the coordinate.
    ///
    /// E.G. "122.77527 W" instead of  "-122.77527"
    public static let suffix = Self(rawValue: 1 << 0)

    /// If present, spaces will be omitted.
    ///
    /// E.G. "122.77527W" instead of  "-122.77527"
    ///
    /// - Important: Only applies if the SymbolStyle is not `.none`.
    public static let compact = Self(rawValue: 1 << 1)

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public let rawValue: Int
}

/// An error encountered when parsing a `Coordinate`
/// or `Degrees` value from a string.
public enum ParsingError: Error, Equatable {
    /// The suffix and prefix of the coordinate string contradict each other.
    case conflict

    /// The matched coordinate is not valid.
    case invalidCoordinate

    /// The expected orientation does not match the parsed direction.
    case invalidDirection

    /// The matched degrees is outside the expected range.
    case invalidRangeDegrees

    /// The matched minutes are outside the expected range.
    case invalidRangeMinutes

    /// The matched seconds are outside the expected range.
    case invalidRangeSeconds

    /// The parsed `UTMGridZone` is invalid.
    case invalidZone

    /// The parsed `UTMLatitudeBand` is invalid.
    case invalidLatitudeBand

    /// No match found
    case noMatch

    /// The named string was not found.
    case notFound(name: String)
}



/// Options affecting how a coordinate is parsed from a string.
public struct ParsingOptions: OptionSet {
    /// Disregard case when matching strings.
    public static let caseInsensitive = Self(rawValue: 1 << 0)
    /// Ignore whitespace at the beginning and end of the string.
    public static let trimmed = Self(rawValue: 1 << 1)

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public let rawValue: Int
}



/// Defines the characters used to annotate coordinate components.
public enum SymbolStyle {
    /// Uses no symbols, components must be space delimited.
    ///
    /// Example:
    /// ```
    /// 48 6 59 N, 122 46 31 W
    /// ```
    case none
    /// Commonly used on the web and computer systems.
    ///
    /// It uses the degree `°` symbol for degrees, the apostrophe `'` for minutes, and the quote `"` symbol for seconds.
    ///
    /// Example:
    /// ```
    /// 48° 6' 59" N, 122° 46' 31" W
    /// ```
    case simple
    /// The typographically correct format commonly used on paper charts and maps.
    ///
    /// It uses the degree `°` symbol for degrees, the prime `′` symbol for minutes, and the double prime `″` symbol for seconds.
    ///
    /// Example:
    /// ```
    /// 48° 6′ 59″ N, 122° 46′ 31″ W
    /// ```
    case traditional

    /// The symbol use to annotate degrees.
    var degrees: String {
        switch self {
        case .none:
            return ""
        case .simple, .traditional:
            return String(describing: CoordinateSymbol.degree)
        }
    }

    /// The symbol use to annotate minutes.
    var minutes: String {
        switch self {
        case .none:
            return ""
        case .simple:
            return String(describing: CoordinateSymbol.apostrophe)
        case .traditional:
            return String(describing: CoordinateSymbol.prime)
        }
    }

    /// The symbol use to annotate seconds.
    var seconds: String {
        switch self {
        case .none:
            return ""
        case .simple:
            return String(describing: CoordinateSymbol.quote)
        case .traditional:
            return String(describing: CoordinateSymbol.doublePrime)
        }
    }
}



/**
 A formatter that converts between `Degrees` values and their textual representations.

 Instances of LocationDegreesFormatter create string representations of `Degrees` values,
 and convert textual representations of degrees into `Degrees` values.

 Formatting a degree using a format and symbol style:
 ```swift
 let formatter = LocationDegreesFormatter()
 formatter.format = .decimalDegrees
 formatter.symbolStyle = .simple
 format.displayOptions = [.suffix]

 formatter.string(from: -122.77527)
 // "122.77527° W"
 ```
 */
public final class LocationDegreesFormatter: Formatter {

    override public init() {
        self.degreesFormat = .decimalDegrees
        super.init()
    }

    public init?(format: CoordinateFormat, displayOptions: DisplayOptions = []) {
        guard let degreeFormat = DegreesFormat(coordinateFormat: format) else {
            assertionFailure("Unsupported coordinate format: '\(String(describing: format))'")
            return nil
        }

        self.degreesFormat = degreeFormat
        self.displayOptions = displayOptions
        super.init()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Configuration
    /// Defines whether a coordinate is expected to represent latitude or longitude.
    ///
    /// Default value is `.none`.
    public var orientation: CoordinateOrientation = .none

    /// The coordinate format used by the receiver.
    public var format: CoordinateFormat {
        get {
            return degreesFormat.coordinateFormat
        }
        set {
            guard let degreeFormat = DegreesFormat(coordinateFormat: newValue) else {
                assertionFailure("Unsupported coordinate format: '\(String(describing: newValue))'")
                return
            }
            self.degreesFormat = degreeFormat
        }
    }

    /// The minimum number of digits after the decimal separator for degrees.
    ///
    /// Default value is 1.
    ///
    /// - Important: Only applicable if `format` is `DegreesFormat.decimalDegrees`.
    public var minimumDegreesFractionDigits = 1

    /// The maximum number of digits after the decimal separator for degrees.
    ///
    /// The default value is 5, which is accurate to 1.1132 meters (3.65 feet).
    ///
    /// - Important: Only applicable if `format` is `DegreesFormat.decimalDegrees`.
    public var maximumDegreesFractionDigits = 5

    /// Defines the characters used to annotate coordinate components.
    ///
    /// The default value is `SymbolStyle.simple`.
    public var symbolStyle: SymbolStyle = .simple

    /// Options for display
    ///
    /// Default options include `DisplayOptions.suffx`.`
    public var displayOptions: DisplayOptions = [.suffix]

    /// Options for parsing degree values from strings.
    ///
    /// Default options include `ParsingOptions.caseInsensitive`.`
    public var parsingOptions: ParsingOptions = [.caseInsensitive]

    // MARK: - Public
    /// Returns a string containing the formatted value of the provided `Degrees`.
    public func string(from: Degrees) -> String? {
        var degrees = from

        guard orientation.range.contains(degrees) else { return nil }

        let hemisphere = orientation.hemisphere(for: degrees)

        if displayOptions.contains(.suffix), hemisphere != nil { degrees = abs(degrees) }

        let minutes = (abs(degrees) * 60.0).truncatingRemainder(dividingBy: 60.0)
        let seconds = (abs(degrees) * 3600.0).truncatingRemainder(dividingBy: 60.0)

        var components: [String] = []

        switch degreesFormat {
        case .decimalDegrees:
            let deg = degreesFormatter.string(from: NSNumber(value: degrees)) ?? "\(degrees)"
            components = ["\(deg)\(symbolStyle.degrees)"]

        case .degreesDecimalMinutes:
            let deg = Int(degrees >= 0 ? floor(degrees) : ceil(degrees))
            let min = minutesFormatter.string(from: NSNumber(value: minutes)) ?? "\(minutes)"
            components = ["\(deg)\(symbolStyle.degrees)",
                          "\(min)\(symbolStyle.minutes)"]

        case .degreesMinutesSeconds:
            let deg = Int(degrees >= 0 ? floor(degrees) : ceil(degrees))
            let min = Int(floor(minutes))
            let sec = Int(round(seconds))
            components = ["\(deg)\(symbolStyle.degrees)",
                          "\(min)\(symbolStyle.minutes)",
                          "\(sec)\(symbolStyle.seconds)"]
        }

        if displayOptions.contains(.suffix), let suffix = hemisphere?.rawValue {
            components.append(suffix)
        }

        return components.joined(separator: isCompact ? "" : " ")
    }

    /// Parse a Degrees for a given string.
    /// - Parameters:
    ///   - str: The string to be parsed.
    ///   - orientation: Expected orientation (latitude or longitude). Optional, default is none.
    /// - Returns: a `Degrees`.
    public func locationDegrees(from str: String, orientation: CoordinateOrientation? = nil) throws -> Degrees {
        if let orientation = orientation {
            self.orientation = orientation
        }

        let degrees = try number(for: str).doubleValue
        guard self.orientation.range.contains(degrees) else { throw ParsingError.invalidRangeDegrees }
        return degrees
    }

    // MARK: - Formatter
    override public func string(for obj: Any?) -> String? {
        guard let degrees = obj as? Degrees else { return nil }
        return string(from: degrees)
    }

    override public func getObjectValue(_ obj: RefPtr<AnyObject?>?,
                                        for string: String,
                                        errorDescription error: RefPtr<NSString?>?) -> Bool {
        do {
            obj?.pointee = try number(for: string)
            return obj?.pointee != nil
        } catch let err {
            error?.pointee = err.localizedDescription as NSString
            return false
        }
    }

    // MARK: - Private

    private var degreesFormat: DegreesFormat

    private var isCompact: Bool {
        // cant be compact if not using symbols
        displayOptions.contains(.compact) && symbolStyle != .none
    }

    private func degrees(inResult result: NSTextCheckingResult, for string: String) throws -> Double {
        let degrees = try doubleValue(forName: "DEGREES", inResult: result, for: string)
        guard orientation.range.contains(degrees) else { throw ParsingError.invalidRangeDegrees }
        return degrees
    }

    private func minutes(inResult result: NSTextCheckingResult, for string: String) throws -> Double {
        let minutes = try doubleValue(forName: "MINUTES", inResult: result, for: string)
        guard (0.0 ..< 60.0).contains(minutes) else { throw ParsingError.invalidRangeMinutes }
        return minutes
    }

    private func seconds(inResult result: NSTextCheckingResult, for string: String) throws -> Double {
        let seconds = try doubleValue(forName: "SECONDS", inResult: result, for: string)
        guard (0.0 ..< 60.0).contains(seconds) else { throw ParsingError.invalidRangeSeconds }
        return seconds
    }

    private func directionPrefix(inResult result: NSTextCheckingResult,
                                 for string: String) throws -> CoordinateHemisphere {
        return try direction(inResult: result, forName: "PREFIX", inString: string)
    }

    private func directionSuffix(inResult result: NSTextCheckingResult,
                                 for string: String) throws -> CoordinateHemisphere {
        return try direction(inResult: result, forName: "SUFFIX", inString: string)
    }

    private func direction(inResult result: NSTextCheckingResult,
                           forName name: String,
                           inString string: String) throws -> CoordinateHemisphere {
        let val = try value(forName: name, inResult: result, for: string)
        guard let direction = CoordinateHemisphere(rawValue: val.uppercased()) else {
            throw ParsingError.notFound(name: name)
        }
        return direction
    }

    private func resolveDirection(inResult result: NSTextCheckingResult,
                                  for string: String) throws -> CoordinateHemisphere? {
        let directions = (try? directionPrefix(inResult: result, for: string),
                          try? directionSuffix(inResult: result, for: string))

        switch directions {
        case let (.some(prefix), .some(suffix)):
            guard prefix == suffix else { throw ParsingError.conflict }
            return suffix
        case let (.some(prefix), .none):
            return prefix
        case let (.none, .some(suffix)):
            return suffix
        case (.none, .none):
            return nil
        }
    }

    /// Returns a number object representing the location degrees recognized in the supplied string.
    private func number(for string: String) throws -> NSNumber {
        let str = string.desymbolized()

        var options: NSRegularExpression.Options = [.useUnicodeWordBoundaries]
        if parsingOptions.contains(.caseInsensitive) { options.insert(.caseInsensitive) }
        let regex = try NSRegularExpression(pattern: degreesFormat.regexPattern, options: options)

        let nsRange = NSRange(str.startIndex ..< str.endIndex, in: str)
        guard let match = regex.firstMatch(in: str, options: [.anchored], range: nsRange) else {
            throw ParsingError.noMatch
        }

        var degrees = try self.degrees(inResult: match, for: str)
        var actualOrientation = orientation
        let direction: CoordinateHemisphere? = try resolveDirection(inResult: match, for: str)

        if let direction = direction {
            switch direction {
            case .south, .west:
                if degrees > 0 { degrees.negate() }
            case .north, .east:
                if degrees < 0 { degrees.negate() }
            }

            if orientation != .none {
                // Expected orientation does not match parsed direction
                guard orientation == direction.orientation else { throw ParsingError.invalidDirection }
            }

            actualOrientation = direction.orientation
        }

        if [DegreesFormat.degreesDecimalMinutes, DegreesFormat.degreesMinutesSeconds].contains(degreesFormat) {
            let minutes = try self.minutes(inResult: match, for: str)
            let minutesAsDegrees = (minutes / 60)
            degrees += degrees < 0 ? -minutesAsDegrees : minutesAsDegrees
        }

        if format == .degreesMinutesSeconds {
            let seconds = try self.seconds(inResult: match, for: str)
            let secondsAsDegrees = (seconds / 3600)
            degrees += degrees < 0 ? -secondsAsDegrees : secondsAsDegrees
        }

        guard actualOrientation.range.contains(degrees) else { throw ParsingError.invalidRangeDegrees }

        return NSNumber(value: degrees.roundedTo(places: maximumDegreesFractionDigits))
    }

    // MARK: - Formatters
    lazy var degreesFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale.current
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = minimumDegreesFractionDigits
        formatter.maximumFractionDigits = maximumDegreesFractionDigits
        return formatter
    }()

    lazy var minutesFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale.current
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 3
        formatter.maximumFractionDigits = 3
        formatter.paddingCharacter = "0"
        formatter.paddingPosition = .afterPrefix
        formatter.minimumIntegerDigits = 2
        formatter.maximumIntegerDigits = 2
        return formatter
    }()
}



/**
 A formatter that converts between Coordinate values and their textual representations.

 Instances of LocationCoordinateFormatter create string representations of `Coordinate` values,
 and convert textual representations of coordinates into `Coordinate` values.

 Formatting a coordinate using a format and symbol style:
 ```swift
 let formatter = LocationCoordinateFormatter()
 formatter.format = .decimalDegrees
 formatter.symbolStyle = .simple
 format.displayOptions = [.suffix]

 let coordinate = Coordinate(latitude: 48.11638, longitude: -122.77527)
 formatter.string(from: coordinate)
 // "48.11638° N, 122.77527° W"
 ```
 */
public final class LocationCoordinateFormatter: Formatter {

    public init(format: CoordinateFormat = .decimalDegrees,
                displayOptions: DisplayOptions = [.suffix],
                parsingOptions: ParsingOptions = [.caseInsensitive]) {
        self.format = format
        self.displayOptions = displayOptions
        self.parsingOptions = parsingOptions

        super.init()

        updateFormat()
        updateDisplayOptions()
        updateParsingOptions()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private lazy var degreesFormatter = LocationDegreesFormatter()
    private lazy var utmFormatter = UTMCoordinateFormatter()

    // MARK: - Configuration
    /// The coordinate format used by the receiver.
    public var format: CoordinateFormat {
        didSet { updateFormat() }
    }

    /// Options for the string representation.
    public var displayOptions: DisplayOptions = [] {
        didSet { updateDisplayOptions() }
    }

    /// Options that control the parsing behavior.
    public var parsingOptions: ParsingOptions = [] {
        didSet { updateParsingOptions() }
    }

    /// The minimum number of digits after the decimal separator for degrees.
    ///
    /// Default value is 1.
    ///
    /// - Important: Only applicable if `format` is `CoordinateFormat.decimalDegrees`.
    public var minimumDegreesFractionDigits: Int {
        get { degreesFormatter.minimumDegreesFractionDigits }
        set { degreesFormatter.minimumDegreesFractionDigits = newValue }
    }

    /// The maximum number of digits after the decimal separator for degrees.
    ///
    /// Default is 5, which is accurate to 1.1132 meters (3.65 feet).
    ///
    ///  - Important: Only applicable if `format` is `CoordinateFormat.decimalDegrees`.
    public var maximumDegreesFractionDigits: Int {
        get { degreesFormatter.maximumDegreesFractionDigits }
        set { degreesFormatter.maximumDegreesFractionDigits = newValue }
    }

    /// Defines the characters used to annotate coordinate components.
    public var symbolStyle: SymbolStyle {
        get { degreesFormatter.symbolStyle }
        set { degreesFormatter.symbolStyle = newValue }
    }

//    /// The datum to use for UTM coordinates.
//    ///
//    /// Default value is WGS84.
//    ///
//    /// - Important: Only used when the ``format`` is `utm`.
//    public var utmDatum: UTMDatum {
//        get { utmFormatter.datum }
//        set { utmFormatter.datum = newValue }
//    }

    // MARK: - Public API

    /// Returns a string containing the formatted value of the provided coordinate.
    public func string(from coordinate: Coordinate) -> String? {
        guard coordinate.isValid else { return nil }

        switch format {
        case .decimalDegrees, .degreesDecimalMinutes, .degreesMinutesSeconds:
            return degreeString(from: coordinate)
        case .utm:
            return utmFormatter.string(from: coordinate)
        }
    }

    /// Returns a coordinate created by parsing a given string.
    public func coordinate(from string: String) throws -> Coordinate {
        switch format {
        case .decimalDegrees, .degreesDecimalMinutes, .degreesMinutesSeconds:
            return try coordinateFrom(degreesString: string)
        case .utm:
            return try utmFormatter.coordinate(from: string)
        }
    }

    /// Returns a string containing the formatted latitude of the provided coordinate.
    public func latitudeString(from coordinate: Coordinate) -> String? {
        guard coordinate.isValid else { return nil }
        degreesFormatter.orientation = .latitude
        return degreesFormatter.string(from: coordinate.latitude)
    }

    /// Returns a string containing the formatted longitude of the provided coordinate.
    public func longitudeString(from coordinate: Coordinate) -> String? {
        guard coordinate.isValid else { return nil }
        degreesFormatter.orientation = .longitude
        return degreesFormatter.string(from: coordinate.longitude)
    }

    /// Returns an CLLocation object created by parsing a given string.
    public func location(from str: String) throws -> Location {
        let coord = try coordinate(from: str)
        return Location(latitude: coord.latitude, longitude: coord.longitude)
    }

    // MARK: - Private

    private func updateFormat() {
        switch format {
        case .decimalDegrees:
            degreesFormatter.format = .decimalDegrees
        case .degreesDecimalMinutes:
            degreesFormatter.format = .degreesDecimalMinutes
        case .degreesMinutesSeconds:
            degreesFormatter.format = .degreesMinutesSeconds
        case .utm:
            break
        }
    }

    private func updateDisplayOptions() {
        var options: DisplayOptions = []
        if displayOptions.contains(.suffix) { options.insert(.suffix) }
        if displayOptions.contains(.compact) { options.insert(.compact) }

        switch format {
        case .decimalDegrees, .degreesDecimalMinutes, .degreesMinutesSeconds:
            degreesFormatter.displayOptions = options
        case .utm:
            utmFormatter.displayOptions = options
        }
    }

    private func updateParsingOptions() {
        var options: ParsingOptions = []
        if parsingOptions.contains(.caseInsensitive) { options.insert(.caseInsensitive) }
        if parsingOptions.contains(.trimmed) { options.insert(.trimmed) }

        switch format {
        case .decimalDegrees, .degreesDecimalMinutes, .degreesMinutesSeconds:
            degreesFormatter.parsingOptions = options
        case .utm:
            utmFormatter.parsingOptions = options
        }
    }

    private func degreeString(from coordinate: Coordinate) -> String? {
        guard let lat = latitudeString(from: coordinate), let lon = longitudeString(from: coordinate) else {
            return nil
        }
        return "\(lat), \(lon)"
    }

    private func coordinateFrom(degreesString string: String) throws -> Coordinate {
        let comma: Character = "\u{002C}"
        let space: Character = "\u{0020}"

        // Prefer comma if we have one
        let separator: Character = string.contains(comma) ? comma : space

        let components = string
            .split(separator: separator)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        guard components.count == 2 else { throw ParsingError.noMatch }

        let lat = try degreesFormatter.locationDegrees(from: components[0], orientation: .latitude)
        let lon = try degreesFormatter.locationDegrees(from: components[1], orientation: .longitude)

        let coord = Coordinate(latitude: lat, longitude: lon)

        guard coord.isValid else {
            throw ParsingError.invalidCoordinate
        }

        return coord
    }

    // MARK: - Formatter
    override public func string(for obj: Any?) -> String? {
        guard let coordinate = obj as? Coordinate else { return nil }
        return string(from: coordinate)
    }

    override public func getObjectValue(_ obj: RefPtr<AnyObject?>?,
                                        for string: String,
                                        errorDescription error: RefPtr<NSString?>?) -> Bool {
        do {
            obj?.pointee = try location(from: string)
            return true
        } catch let err {
            error?.pointee = err.localizedDescription as NSString
            return false
        }
    }
}

public extension LocationCoordinateFormatter {
    /// Simple decimal format (46.853063, -114.012122)
    static let decimalFormatter: LocationCoordinateFormatter = {
        let formatter = LocationCoordinateFormatter()
        formatter.format = .decimalDegrees
        formatter.symbolStyle = .none
        formatter.displayOptions = []
        return formatter
    }()

    /**
     A LocationCoordinateFormatter configured to use decimal degrees (DD) format.

    ```swift
    let coordinate = Coordinate(latitude: 48.11638, longitude: -122.77527)
    let formatter = LocationCoordinateFormatter.decimalDegreesFormatter
    formatter.string(from: coordinate)
    // "48.11638° N, 122.77527° W"
    ```
     */
    static let decimalDegreesFormatter = LocationCoordinateFormatter(format: .decimalDegrees)

    /**
     A LocationCoordinateFormatter configured to use degrees decimal minutes (DDM) format.

    ```swift
    let coordinate = Coordinate(latitude: 48.11638, longitude: -122.77527)
    let formatter = LocationCoordinateFormatter.degreesDecimalMinutesFormatter
    formatter.string(from: coordinate)
    // "48° 06.983' N, 122° 46.516' W"
    ```
     */
    static let degreesDecimalMinutesFormatter = LocationCoordinateFormatter(format: .degreesDecimalMinutes)

    /**
     A LocationCoordinateFormatter configured to use degrees minutes seconds (DMS) format.

    ```swift
    let coordinate = Coordinate(latitude: 48.11638, longitude: -122.77527)
    let formatter = LocationCoordinateFormatter.degreesMinutesSecondsFormatter
    formatter.string(from: coordinate)
    // "48° 6' 59" N, 122° 46' 31" W"
    ```
     */
    static let degreesMinutesSecondsFormatter = LocationCoordinateFormatter(format: .degreesMinutesSeconds)

    /**
     A LocationCoordinateFormatter configured to use universal trans mercator (UTM) format.

   ```swift
   let coordinate = Coordinate(latitude: 48.11638, longitude: -122.77527)
   let formatter = LocationCoordinateFormatter.utmFormatter
   formatter.string(from: coordinate)
   // "10U 516726m E 5329260m N"
   ```
    */
    static let utmFormatter = LocationCoordinateFormatter(format: .utm)
}




public extension String {
    /// Parses a coordinate value from a string.
    ///
    /// Attempts to recognize a valid coordinate in Decimal Degrees, Degrees Decimal Minutes,
    /// Degrees Minutes Seconds, or UTM formats.
    ///
    /// - Returns: the recognized coordinate value.
    func coordinate() -> Coordinate? {
        var coordinate: Coordinate?

        let formatters: [LocationCoordinateFormatter] = [LocationCoordinateFormatter.decimalDegreesFormatter,
                                                         LocationCoordinateFormatter.degreesDecimalMinutesFormatter,
                                                         LocationCoordinateFormatter.degreesMinutesSecondsFormatter,
                                                         LocationCoordinateFormatter.utmFormatter]

        for formatter in formatters {
            if let coord = try? formatter.coordinate(from: self) {
                coordinate = coord
                break
            }
        }

        return coordinate
    }
}


internal extension Formatter {

    func doubleValue(forName name: String,
                     inResult result: NSTextCheckingResult,
                     for string: String) throws -> Double {
        let val = try value(forName: name, inResult: result, for: string)
        guard let double = Double(val) else { throw ParsingError.notFound(name: name) }
        return double
    }

    func intValue(forName name: String,
                  inResult result: NSTextCheckingResult,
                  for string: String) throws -> Int {
        let val = try value(forName: name, inResult: result, for: string)
        guard let intVal = Int(val) else { throw ParsingError.notFound(name: name) }
        return intVal
    }

    func stringValue(forName name: String,
                     inResult result: NSTextCheckingResult,
                     for string: String) throws -> String {
        return try value(forName: name, inResult: result, for: string)
    }

    func value(forName name: String,
               inResult result: NSTextCheckingResult,
               for string: String) throws -> String {
        let matchedRange = result.range(withName: name)
        guard matchedRange.location != NSNotFound, let range = Range(matchedRange, in: string) else {
            throw ParsingError.notFound(name: name)
        }
        return String(string[range])
    }
}



internal extension Double {
    /// Rounds a Double to a number of places. Probably not very accurately.
    func roundedTo(places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}



public extension Coordinate {

    /// A Coordinate with both a latitude and longitude of 0.0.
    static let zero = Self(latitude: Double.zero, longitude: Double.zero)

    /**
     Null Island is the point on the Earth's surface at zero degrees latitude and zero degrees
     longitude (0°N 0°E), i.e., where the prime meridian and the equator intersect.

     Null Island is located in international waters in the Atlantic Ocean, roughly 600 km off the coast of West Africa, in the Gulf of Guinea.

     The exact point, using the WGS84 datum, is marked by the Soul buoy (named after the musical genre), a permanently-moored weather buoy.
     The term "Null Island" jokingly refers to the suppositional existence of an island at
     that location, and to a common cartographic placeholder name to which coordinates
     erroneously set to 0,0 are assigned in place-name databases in order to more easily find
     and fix them. The nearest land (4°45′30″N 1°58′33″W) is 570 km (354 mi; 307.8 nm) to the
     north – a small Ghanaian islet offshore from Achowa Point between Akwidaa and Dixcove.
     The depth of the seabed beneath the Soul buoy is around 4,940 meters (16,210 ft).
     */
    static let nullIsland = Self.zero

    /**
     Point Nemo (A.K.A. The oceanic pole of inaccessibility) is the place in the ocean that is farthest from land.

     It lies in the South Pacific Ocean, 2,704.8 km (1,680.7 mi) from the nearest lands: Ducie
     Island (part of the Pitcairn Islands) to the north, Motu Nui (part of the Easter Islands)
     to the northeast, and Maher Island (near the larger Siple Island, off the coast of Marie
     Byrd Land, Antarctica) to the south.

     The area is so remote that — as with any location more than 400 kilometers (about 250
     miles) from an inhabited area — sometimes the closest human beings are astronauts aboard
     the International Space Station when it passes overhead.
    */
    static let pointNemo = Self(latitude: -49.0273, longitude: -123.4345)
}

extension Coordinate: Equatable {
    public static func == (lhs: Coordinate, rhs: Coordinate) -> Bool {
        return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}

//extension Coordinate: Hashable {
//    public func hash(into hasher: inout Hasher) {
//        hasher.combine(latitude)
//        hasher.combine(longitude)
//    }
//}

extension Coordinate: CustomStringConvertible {
    public var description: String {
        LocationCoordinateFormatter.decimalFormatter.string(from: self) ?? ""
    }
}



/// Each UTM longitude zone is segmented into 20 latitude bands.
public enum UTMLatitudeBand: String, CaseIterable, Comparable {
    case C, D, E, F, G, H, J, K, L, M, N, P, Q, R, S, T, U, V, W, X

    /// The hemisphere the latitude band is in.
    var hemisphere: UTMHemisphere {
        self < .N ? .southern : .northern
    }

    init?(coordinate: Coordinate) {
        guard coordinate.isValid else { return nil }

        switch coordinate.latitude {
        // Southern hemisphere
        case -80 ..< -72: self = .C
        case -72 ..< -64: self = .D
        case -64 ..< -56: self = .E
        case -56 ..< -48: self = .F
        case -48 ..< -40: self = .G
        case -40 ..< -32: self = .H
        case -32 ..< -24: self = .J
        case -24 ..< -16: self = .K
        case -16 ..< -8: self = .L
        case -8 ..< 0: self = .M

        // Northern hemisphere
        case 0 ..< 8: self = .N
        case 8 ..< 16: self = .P
        case 16 ..< 24: self = .Q
        case 24 ..< 32: self = .R
        case 32 ..< 40: self = .S
        case 40 ..< 48: self = .T
        case 48 ..< 56: self = .U
        case 56 ..< 64: self = .V
        case 64 ..< 72: self = .W
        case 72 ... 84: self = .X // NOTE: 'X' is 12° not 8°
        default:
            return nil
        }
    }

    public static func < (lhs: UTMLatitudeBand, rhs: UTMLatitudeBand) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public extension Coordinate {
    /// The latitude band of the coordinate.
    var latitudeBand: UTMLatitudeBand? {
        return UTMLatitudeBand(coordinate: self)
    }
}




/**
 A formatter that converts between `Coordinate` values and their string representations using the Universal Transverse Mercator (UTM) coordinate system.

 Instances of UTMCoordinateFormatter create UTM string representations of `Coordinate` values, and convert UTM textual representations of coordinates into `Coordinate` values.

Formatting a coordinate with the suffix display option:

 ```swift
 let formatter = UTMCoordinateFormatter()
 formatter.displayOptions =  [.suffix]

 let coordinate = Coordinate(latitude: 48.11638, longitude: -122.77527)
 formatter.string(from: coordinate)
 // "10U 516726m E 5329260m N"
 ```
 */
public final class UTMCoordinateFormatter: Formatter {

    /// The datum to use.
    ///
    /// Default value is WGS84.
    public var datum: UTMDatum = .wgs84

    /// Options for displaying UTM coordinates.
    ///
    /// Default options include `DisplayOptions.suffx`.`
    public var displayOptions: DisplayOptions = [.suffix]

    /// Options for parsing coordinates strings
    ///
    /// Default options include `ParsingOptions.caseInsensitive`.`
    public var parsingOptions: ParsingOptions = [.caseInsensitive]

    /// Returns a string containing the UTM formatted value of the provided `Degrees`.
    public func string(from coordinate: Coordinate) -> String? {
        guard coordinate.isValid else { return nil }

        let utmCoordinate = coordinate.utmCoordinate(datum: datum)

        var gridZone = "\(utmCoordinate.zone)"
        if let latitudeBand = coordinate.latitudeBand { gridZone += latitudeBand.rawValue }

        guard let easting = utmCoordinate.formattedEasting, let northing = utmCoordinate.formattedNorthing else {
            return nil
        }

        let eastingSuffix = displayOptions.contains(.suffix) ? (isCompact ? "E" : " E") : ""
        let northingSuffix = displayOptions.contains(.suffix) ? (isCompact ? "N" : " N") : ""

        return "\(gridZone) \(easting)\(eastingSuffix) \(northing)\(northingSuffix)"
    }

    /// Returns a `Coordinate` created by parsing a UTM string.
    public func coordinate(from string: String) throws -> Coordinate {
        let str = parsingOptions.contains(.trimmed) ? string.trimmingCharacters(in: .whitespacesAndNewlines) : string

        var regexOptions: NSRegularExpression.Options = [.useUnicodeWordBoundaries]
        if parsingOptions.contains(.caseInsensitive) { regexOptions.insert(.caseInsensitive) }

        let regex = try NSRegularExpression(pattern: regexPattern, options: regexOptions)

        let nsRange = NSRange(str.startIndex ..< str.endIndex, in: str)
        guard let match = regex.firstMatch(in: str, options: [.anchored], range: nsRange) else {
            throw ParsingError.noMatch
        }

        let zoneString = try stringValue(forName: "ZONE", inResult: match, for: str)
        guard let zone = UTMGridZone(zoneString), (1 ... 60).contains(zone) else { throw ParsingError.invalidZone }

        var bandString = try stringValue(forName: "BAND", inResult: match, for: str)
        if parsingOptions.contains(.caseInsensitive) { bandString = bandString.uppercased() }
        guard let band = UTMLatitudeBand(rawValue: bandString) else { throw ParsingError.invalidLatitudeBand }

        let easting = try doubleValue(forName: "EASTING", inResult: match, for: str)
        let northing = try doubleValue(forName: "NORTHING", inResult: match, for: str)

        let utmCoord = UTMCoordinate(northing: northing, easting: easting, zone: zone, hemisphere: band.hemisphere)

        let coordinate = utmCoord.coordinate(datum: datum)

        // parsed latitude band should match the derived band, which is based on the actual coordinates
        guard coordinate.latitudeBand == band else { throw ParsingError.invalidLatitudeBand }

        guard coordinate.isValid else { throw ParsingError.invalidCoordinate }

        return coordinate
    }

    private var isCompact: Bool {
        displayOptions.contains(.compact)
    }

    // MARK: - Formatter
    override public func string(for obj: Any?) -> String? {
        guard let coordinate = obj as? Coordinate else { return nil }
        return string(from: coordinate)
    }

    override public func getObjectValue(_ obj: RefPtr<AnyObject?>?,
                                        for string: String,
                                        errorDescription error: RefPtr<NSString?>?) -> Bool {
        do {
            let coord = try coordinate(from: string)
            obj?.pointee = Location(latitude: coord.latitude, longitude: coord.longitude)
            return obj?.pointee != nil
        } catch let err {
            error?.pointee = err.localizedDescription as NSString
            return false
        }
    }

    let regexPattern: String = #"""
    (?x)
    (?# UTM Zone 1-60)
    (?<ZONE>(0?[1-9]|1[0-9]|2[0-9]|3[0-9]|4[0-9]|5[0-9]|60))
    (?# Latitude band)
    (?<BAND>[C|D|E|F|G|H|J|K|L|MN|P|Q|R|S|T|U|V|W|X])
    \h+
    (?# Easting, 6 or more digits)
    (?<EASTING>\d{6,})m\h?E?
    \h+
    (?# Northing, 6 or more digits)
    (?<NORTHING>\d{6,})m\h?N?
    \b
    """#
}

private extension UTMCoordinate {
    var formattedEasting: String? {
        return Self.numberFormatter.string(from: NSNumber(value: easting))
    }

    var formattedNorthing: String? {
        return Self.numberFormatter.string(from: NSNumber(value: northing))
    }

    static var numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale.current
        formatter.numberStyle = .none
        formatter.paddingCharacter = "0"
        formatter.paddingPosition = .beforeSuffix
        formatter.minimumIntegerDigits = 6
        formatter.positiveSuffix = "m"
        return formatter
    }()
}
