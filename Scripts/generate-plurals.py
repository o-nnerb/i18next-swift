#!/usr/bin/env python3
"""Generates the CLDR plural tables used by PluralResolver.

    Scripts/generate-plurals.py --tag release-49
    Scripts/generate-plurals.py --plurals plurals.xml --ordinals ordinals.xml --version 49

Writes:
    Sources/I18next/CLDRPluralData.swift      the rule functions and locale tables
    Tests/I18nextTests/CLDRPluralSamples.swift  CLDR's own samples, to check the generated rules against

Rule syntax: https://unicode.org/reports/tr35/tr35-numbers.html#Language_Plural_Rules
"""

import argparse
import re
import sys
import tempfile
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RAW = "https://raw.githubusercontent.com/unicode-org/cldr/{tag}/common/supplemental/{name}.xml"

CATEGORIES = ["zero", "one", "two", "few", "many"]  # `other` is the default, evaluated last
INT_OPERANDS = {"i", "v", "w", "f", "t", "c", "e"}
OPERANDS = INT_OPERANDS | {"n"}

LICENSE = """\
// Copyright © 1991-{year} Unicode, Inc.
// SPDX-License-Identifier: Unicode-3.0
//
// Derived from the Unicode CLDR data (common/supplemental/{files}).
// See https://www.unicode.org/license.txt for the terms of use.
"""


# MARK: - Rule parsing

TOKEN = re.compile(r"\s*(\.\.|!=|=|%|,|[a-z]+|\d+)")


def tokenize(text):
    tokens, position = [], 0
    text = text.strip()
    while position < len(text):
        match = TOKEN.match(text, position)
        if not match:
            raise ValueError(f"cannot tokenize {text!r} at {position}")
        tokens.append(match.group(1))
        position = match.end()
    return tokens


class Parser:
    """condition = and ('or' and)* ; and = relation ('and' relation)* ;
    relation = operand ['%' int] ('=' | '!=') range (',' range)* ; range = int ['..' int]"""

    def __init__(self, tokens):
        self.tokens, self.index = tokens, 0

    def peek(self):
        return self.tokens[self.index] if self.index < len(self.tokens) else None

    def take(self, expected=None):
        token = self.peek()
        if token is None or (expected is not None and token != expected):
            raise ValueError(f"expected {expected!r}, got {token!r} in {self.tokens}")
        self.index += 1
        return token

    def condition(self):
        terms = [self.and_condition()]
        while self.peek() == "or":
            self.take()
            terms.append(self.and_condition())
        return " || ".join(terms) if len(terms) == 1 else " || ".join(f"({t})" if " && " in t else t for t in terms)

    def and_condition(self):
        relations = [self.relation()]
        while self.peek() == "and":
            self.take()
            relations.append(self.relation())
        return " && ".join(relations)

    def relation(self):
        operand = self.take()
        if operand not in OPERANDS:
            raise ValueError(f"unsupported operand {operand!r} in {self.tokens}")
        modulus = None
        if self.peek() == "%":
            self.take()
            modulus = int(self.take())
        operator = self.take()
        if operator not in ("=", "!="):
            raise ValueError(f"unsupported operator {operator!r} in {self.tokens}")

        ranges = [self.range()]
        while self.peek() == ",":
            self.take()
            ranges.append(self.range())

        expression = swift_operand(operand, modulus)
        terms = []
        for low, high in ranges:
            if low == high:
                terms.append(f"{expression} == {low}")
            elif operand == "n":
                terms.append(f"isInteger({expression}, in: {low}...{high})")
            else:
                terms.append(f"({low}...{high}).contains({expression})")

        if operator == "=":
            return terms[0] if len(terms) == 1 else "(" + " || ".join(terms) + ")"
        if len(terms) == 1 and terms[0].count("==") == 1 and "contains" not in terms[0] and "isInteger" not in terms[0]:
            return terms[0].replace("==", "!=")
        return "!(" + " || ".join(terms) + ")"

    def range(self):
        low = int(self.take())
        if self.peek() == "..":
            self.take()
            return low, int(self.take())
        return low, low


def swift_operand(operand, modulus):
    if operand == "n":
        base = "operands.n"
        return base if modulus is None else f"{base}.truncatingRemainder(dividingBy: {modulus})"
    base = f"operands.{operand}"
    return base if modulus is None else f"{base} % {modulus}"


def parse_condition(text):
    parser = Parser(tokenize(text))
    result = parser.condition()
    if parser.peek() is not None:
        raise ValueError(f"trailing tokens in {text!r}")
    return result


# MARK: - XML

def split_rule(text):
    match = re.match(r"^(.*?)(?:@integer(.*?))?(?:@decimal(.*))?$", text or "", re.S)
    condition, integer, decimal = (part.strip() if part else "" for part in match.groups())
    return condition, integer, decimal


def read_rules(path, kind):
    """-> list of (locales, [(category, condition_swift, integer_samples, decimal_samples)])"""
    root = ET.parse(path).getroot()
    groups = []
    for plurals in root.iter("plurals"):
        if plurals.get("type") != kind:
            continue
        for rules in plurals.iter("pluralRules"):
            locales = [code.replace("_", "-") for code in rules.get("locales").split()]
            parsed = []
            for rule in rules.iter("pluralRule"):
                condition, integer, decimal = split_rule(rule.text)
                swift = parse_condition(condition) if condition else None
                parsed.append((rule.get("count"), swift, integer, decimal))
            groups.append((locales, parsed))
    if not groups:
        raise SystemExit(f"no {kind} rules in {path}")
    return groups


# MARK: - Swift output

def function_body(rules):
    lines = []
    for category in CATEGORIES:
        for count, condition, _, _ in rules:
            if count == category:
                lines.append(f"        if {condition} { '{' } return .{category} {'}'}")
    uses_operands = bool(lines)
    lines.append("        return .other")
    return uses_operands, "\n".join(lines)


def generate_table(kind, groups):
    functions, by_body, table = [], {}, {}
    for locales, rules in groups:
        uses_operands, body = function_body(rules)
        if body not in by_body:
            name = f"{kind}{len(by_body)}"
            categories = ", ".join(c for c, *_ in rules)
            parameter = "operands" if uses_operands else "_"
            functions.append(
                f"    // {categories}\n"
                f"    private static func {name}(_ {parameter}: PluralOperands) -> PluralCategory {{\n{body}\n    }}\n"
            )
            by_body[body] = name
        for locale in locales:
            if locale != "root":
                table[locale] = by_body[body]

    entries = ",\n".join(f'        "{locale}": {table[locale]}' for locale in sorted(table))
    return "\n".join(functions), f"    static let {kind}: [String: PluralRule] = [\n{entries},\n    ]\n", len(by_body), len(table)


def write_data(version, year, cardinal, ordinal, out):
    card_fns, card_table, card_n, card_locales = generate_table("cardinal", cardinal)
    ord_fns, ord_table, ord_n, ord_locales = generate_table("ordinal", ordinal)

    source = (
        LICENSE.format(year=year, files="plurals.xml, ordinals.xml")
        + f"""//
// GENERATED by Scripts/generate-plurals.py from CLDR {version}. Do not edit.
// swift-format-ignore-file

enum CLDRPluralData {{
    /// CLDR release the tables were generated from.
    static let version = "{version}"

    /// `n` is an integer inside `range` (CLDR's `n = 2..4` never matches 2.5).
    private static func isInteger(_ value: Double, in range: ClosedRange<Int>) -> Bool {{
        value == value.rounded() && value >= Double(range.lowerBound) && value <= Double(range.upperBound)
    }}

    // MARK: Cardinal ({card_n} rule sets, {card_locales} locales)

{card_table}
{card_fns}
    // MARK: Ordinal ({ord_n} rule sets, {ord_locales} locales)

{ord_table}
{ord_fns}}}
"""
    )
    out.write_text(source)
    print(f"{out.relative_to(ROOT)}: cardinal {card_n} rule sets / {card_locales} locales, "
          f"ordinal {ord_n} rule sets / {ord_locales} locales")


# MARK: - Samples

def expand_samples(text, decimal):
    """CLDR sample list -> concrete values. Integer ranges (`2~17`) expand when short; decimal ranges and long
    integer ranges contribute their endpoints. Ellipses and compact-notation samples (`1c3`) are skipped."""
    values = []
    for token in (part.strip() for part in text.split(",")):
        if not token or token == "…" or re.search(r"[ce]", token):
            continue
        if "~" in token:
            low, high = token.split("~")
            if not decimal and int(high) - int(low) <= 40:
                values += [str(v) for v in range(int(low), int(high) + 1)]
            else:
                values += [low, high]
        else:
            values.append(token)
    return values


def write_samples(version, year, cardinal, ordinal, out):
    def lines(groups):
        rows = []
        for locales, rules in groups:
            for locale in locales:
                if locale == "root":
                    continue
                for count, _, integer, decimal in rules:
                    for value in expand_samples(integer, False) + expand_samples(decimal, True):
                        rows.append(f"{locale} {count} {value}")
        return "\n".join(rows)

    source = (
        LICENSE.format(year=year, files="plurals.xml, ordinals.xml")
        + f"""//
// GENERATED by Scripts/generate-plurals.py from CLDR {version}. Do not edit.
// swift-format-ignore-file
// One sample per line: `locale category value`, `value` being a decimal string with its visible fraction digits.

enum CLDRPluralSamples {{
    static let cardinal = \"\"\"
{lines(cardinal)}
\"\"\"

    static let ordinal = \"\"\"
{lines(ordinal)}
\"\"\"
}}
"""
    )
    out.write_text(source)
    print(f"{out.relative_to(ROOT)}: {source.count(chr(10))} lines")


# MARK: - Main

def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--tag", help="CLDR git tag to download, e.g. release-49")
    parser.add_argument("--plurals", type=Path)
    parser.add_argument("--ordinals", type=Path)
    parser.add_argument("--version", help="label for local files, e.g. 49")
    arguments = parser.parse_args()

    if arguments.tag:
        version = arguments.tag.removeprefix("release-").replace("-", ".")
        cache = Path(tempfile.mkdtemp(prefix="cldr-"))
        paths = {}
        for name in ("plurals", "ordinals"):
            target = cache / f"{name}.xml"
            with urllib.request.urlopen(RAW.format(tag=arguments.tag, name=name)) as response:
                target.write_bytes(response.read())
            paths[name] = target
        plurals_path, ordinals_path = paths["plurals"], paths["ordinals"]
    elif arguments.plurals and arguments.ordinals and arguments.version:
        version, plurals_path, ordinals_path = arguments.version, arguments.plurals, arguments.ordinals
    else:
        parser.error("pass --tag, or --plurals, --ordinals and --version")

    year = re.search(r"1991-(\d{4})", plurals_path.read_text()).group(1)
    cardinal = read_rules(plurals_path, "cardinal")
    ordinal = read_rules(ordinals_path, "ordinal")

    write_data(version, year, cardinal, ordinal, ROOT / "Sources/I18next/CLDRPluralData.swift")
    write_samples(version, year, cardinal, ordinal, ROOT / "Tests/I18nextTests/CLDRPluralSamples.swift")


if __name__ == "__main__":
    sys.exit(main())
