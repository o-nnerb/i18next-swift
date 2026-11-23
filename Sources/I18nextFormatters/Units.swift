// Copyright (c) 2026 Brenno Giovanini de Moura
// SPDX-License-Identifier: MIT

import Foundation

/// The `unit` of `{{v, number(style: unit; unit: kilometer)}}`: the units `Intl.NumberFormat` accepts, formatted by
/// Foundation's `Measurement` (the same ICU data), for the ones that have a `Unit` there.
enum Units {
    /// What Foundation can't do: `day`, `week`, `month` and `year` (`UnitDuration` stops at hours), `percent`,
    /// `mile-scandinavian`, compound units such as `kilometer-per-day` that `Unit` has no case for, and the sub-second
    /// units, whose names Foundation doesn't translate for every locale (`ms` where Intl has "ملي ث").
    static func format(
        _ value: Double,
        unit name: String,
        display: String,
        locale: Locale,
        number: FloatingPointFormatStyle<Double>
    ) throws -> String {
        guard let unit = units[name] else {
            throw FormatFailure(
                sanctioned.contains(name)
                    ? "Foundation has no unit for \(name)" : "invalid unit \(name)"
            )
        }
        return unit(value, display, locale, number)
    }

    private typealias Formatter = @Sendable (Double, String, Locale, FloatingPointFormatStyle<Double>) -> String

    private static func measure<Unit: Dimension>(_ unit: Unit) -> Formatter {
        { value, display, locale, number in
            let width: Measurement<Unit>.FormatStyle.UnitWidth =
                switch display {
                case "long": .wide
                case "narrow": .narrow
                default: .abbreviated
                }
            let style = Measurement<Unit>.FormatStyle(
                width: width,
                locale: locale,
                usage: .asProvided,
                numberFormatStyle: number
            )
            return style.format(Measurement(value: value, unit: unit))
        }
    }

    /// ECMA-402's sanctioned unit identifiers, `X-per-Y` aside.
    private static let sanctioned: Set<String> = [
        "acre", "bit", "byte", "celsius", "centimeter", "day", "degree", "fahrenheit", "fluid-ounce", "foot", "gallon",
        "gigabit", "gigabyte", "gram", "hectare", "hour", "inch", "kilobit", "kilobyte", "kilogram", "kilometer",
        "liter", "megabit", "megabyte", "meter", "microsecond", "mile", "mile-scandinavian", "milliliter",
        "millimeter", "millisecond", "minute", "month", "nanosecond", "ounce", "percent", "petabyte", "pound",
        "second", "stone", "terabit", "terabyte", "week", "yard", "year",
    ]

    private static let units: [String: Formatter] = [
        "acre": measure(UnitArea.acres),
        "bit": measure(UnitInformationStorage.bits),
        "byte": measure(UnitInformationStorage.bytes),
        "celsius": measure(UnitTemperature.celsius),
        "centimeter": measure(UnitLength.centimeters),
        "degree": measure(UnitAngle.degrees),
        "fahrenheit": measure(UnitTemperature.fahrenheit),
        "fluid-ounce": measure(UnitVolume.fluidOunces),
        "foot": measure(UnitLength.feet),
        "gallon": measure(UnitVolume.gallons),
        "gigabit": measure(UnitInformationStorage.gigabits),
        "gigabyte": measure(UnitInformationStorage.gigabytes),
        "gram": measure(UnitMass.grams),
        "hectare": measure(UnitArea.hectares),
        "hour": measure(UnitDuration.hours),
        "inch": measure(UnitLength.inches),
        "kilobit": measure(UnitInformationStorage.kilobits),
        "kilobyte": measure(UnitInformationStorage.kilobytes),
        "kilogram": measure(UnitMass.kilograms),
        "kilometer": measure(UnitLength.kilometers),
        "kilometer-per-hour": measure(UnitSpeed.kilometersPerHour),
        "liter": measure(UnitVolume.liters),
        "megabit": measure(UnitInformationStorage.megabits),
        "megabyte": measure(UnitInformationStorage.megabytes),
        "meter": measure(UnitLength.meters),
        "meter-per-second": measure(UnitSpeed.metersPerSecond),
        "mile": measure(UnitLength.miles),
        "mile-per-hour": measure(UnitSpeed.milesPerHour),
        "milliliter": measure(UnitVolume.milliliters),
        "millimeter": measure(UnitLength.millimeters),
        "minute": measure(UnitDuration.minutes),
        "ounce": measure(UnitMass.ounces),
        "petabyte": measure(UnitInformationStorage.petabytes),
        "pound": measure(UnitMass.pounds),
        "second": measure(UnitDuration.seconds),
        "stone": measure(UnitMass.stones),
        "terabit": measure(UnitInformationStorage.terabits),
        "terabyte": measure(UnitInformationStorage.terabytes),
        "yard": measure(UnitLength.yards),
    ]
}
