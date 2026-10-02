#!/usr/bin/env python3
"""Resolve the finite filename declarations used by the Dart golden tests.

This is deliberately a source-contract reader, not a Dart interpreter. Unknown
expressions fail closed. Templates, their case declarations and their golden
matcher must belong to the same test file; record profiles retain their paired
id, Size and Brightness instead of mixing values from unrelated test files.
"""

import argparse
import json
import re
import struct
from pathlib import Path


def closing(source, start):
    pairs = {"(": ")", "[": "]", "{": "}"}
    expected = pairs[source[start]]
    i = start + 1
    while i < len(source):
        if source[i] in "'\"":
            i = string_end(source, i)
        elif source[i] in pairs:
            i = closing(source, i) + 1
        elif source[i] == expected:
            return i
        else:
            i += 1
    raise ValueError("Unclosed Dart expression")


def string_end(source, start):
    quote = source[start]
    i = start + 1
    while i < len(source):
        if source[i] == "\\":
            i += 2
        elif source.startswith("${", i):
            i = closing(source, i + 1) + 1
        elif source[i] == quote:
            return i + 1
        else:
            i += 1
    raise ValueError("Unclosed Dart string")


def clean_comments(source):
    result = list(source)
    i = 0
    while i < len(source):
        if source[i] in "'\"":
            i = string_end(source, i)
        elif source.startswith("//", i) or source.startswith("/*", i):
            end = source.find("\n", i) if source.startswith("//", i) else source.find("*/", i) + 2
            if end < i:
                end = len(source)
            result[i:end] = ["\n" if c == "\n" else " " for c in source[i:end]]
            i = end
        else:
            i += 1
    return "".join(result)


def strings(source):
    result = []
    i = 0
    while i < len(source):
        if source[i] in "'\"":
            end = string_end(source, i)
            value = source[i + 1:end - 1]
            if result and not source[result[-1][2]:i].strip():
                previous = result.pop()
                result.append((previous[0], previous[1] + value, end))
            else:
                result.append((i, value, end))
            i = end
        else:
            i += 1
    return result


def slots(value):
    result = []
    i = 0
    start = 0
    while i < len(value):
        if value[i] != "$":
            i += 1
            continue
        result.append((False, value[start:i]))
        if value.startswith("${", i):
            end = closing(value, i + 1)
            result.append((True, value[i + 2:end]))
            i = end + 1
        else:
            match = re.match(r"\$([A-Za-z_]\w*)", value[i:])
            if not match:
                raise ValueError("Unsupported interpolation")
            result.append((True, match[1]))
            i += len(match[0])
        start = i
    result.append((False, value[start:]))
    return result


def literals(source):
    return {value for _, value, _ in strings(source) if "$" not in value}


def arguments(source):
    result = []
    start = i = 0
    while i < len(source):
        if source[i] in "'\"":
            i = string_end(source, i)
        elif source[i] in "([{":
            i = closing(source, i) + 1
        elif source[i] == ",":
            result.append((start, source[start:i].strip()))
            start = i = i + 1
        else:
            i += 1
    if source[start:].strip():
        result.append((start, source[start:].strip()))
    return result


def initializer(source, name, before=None):
    matches = list(re.finditer(r"\b(?:final|const)\s+(?:\w+(?:<[^;=]+>)?\s+)?" + re.escape(name) + r"\s*=", source))
    if before is not None:
        local = [m for m in matches if m.start() < before]
        matches = local or matches
    if not matches:
        return None
    start = matches[-1].end()
    i = start
    while i < len(source):
        if source[i] in "'\"":
            i = string_end(source, i)
        elif source[i] in "([{":
            i = closing(source, i) + 1
        elif source[i] == ";":
            return source[start:i].strip()
        else:
            i += 1
    return None


def loop_expression(source, variable, position):
    candidates = []
    for match in re.finditer(r"for\s*\(\s*final\s+" + re.escape(variable) + r"\s+in\s+", source):
        start = match.end()
        i = start
        while i < len(source) and source[i] != ")":
            if source[i] in "'\"":
                i = string_end(source, i)
            elif source[i] in "([{":
                i = closing(source, i) + 1
            else:
                i += 1
        body = i + 1
        while body < len(source) and source[body].isspace():
            body += 1
        end = closing(source, body) if source[body:body + 1] == "{" else source.find(";", body)
        if match.start() < position < end:
            candidates.append((match.start(), source[start:i].strip()))
    return candidates[-1][1] if candidates else None


class Source:
    def __init__(self, path):
        self.path = path
        self.text = clean_comments(path.read_text())
        self.templates = [(p, v) for p, v, _ in strings(self.text)
                          if v.startswith("goldens/") and v.endswith(".png")]
        self.has_matcher = bool(re.search(r"\b(?:matchesGoldenFile|expectGoldenOrClubAssertions)\s*\(", self.text))
        self._enum_cache = {}
        self._value_cache = {}
        self._pattern_cache = {}

    def parameter_values(self, parameter, position, captures, depth):
        # Bind helper parameters to that helper's invocations, including
        # positional state parameters. An unrelated record's id is insufficient.
        function = None
        base_parameter, _, member = parameter.partition(".")
        for match in re.finditer(r"\b(?:Future<[^>]+>|void|String)\s+(\w+)\s*\(", self.text):
            begin = match.end() - 1
            end = closing(self.text, begin)
            body = re.match(r"\s*(?:async\s*)?\{", self.text[end + 1:])
            if body:
                body_start = end + 1 + body.end() - 1
                if body_start < position < closing(self.text, body_start):
                    function = (match[1], self.text[begin + 1:end])
            elif re.match(r"\s*=>", self.text[end + 1:]):
                body_end = self.text.find(";", end + 1)
                if end < position < body_end:
                    function = (match[1], self.text[begin + 1:end])
        if not function:
            return set()
        name, signature = function
        positional = [re.findall(r"\b(\w+)\s*(?:=.*)?$", value)[0] for _, value in arguments(signature.split("{")[0]) if re.findall(r"\b(\w+)\s*(?:=.*)?$", value)]
        index = positional.index(base_parameter) if base_parameter in positional else None
        result = set()
        for match in re.finditer(r"\b" + re.escape(name) + r"\s*\(", self.text):
            begin = match.end() - 1
            end = closing(self.text, begin)
            args = arguments(self.text[begin + 1:end])
            for n, (offset, value) in enumerate(args):
                named = re.match(r"(\w+):\s*(.*)", value, re.S)
                if named and named[1] == base_parameter:
                    argument = named[2] + ("." + member if member else "")
                    result |= self.values(argument, begin + 1 + offset, captures, depth + 1)
                elif not named and n == index:
                    argument = value + ("." + member if member else "")
                    result |= self.values(argument, begin + 1 + offset, captures, depth + 1)
        return result

    def collection(self, variable, position):
        expression = loop_expression(self.text, variable, position)
        if not expression:
            return None
        name = re.fullmatch(r"(\w+)(?:\.entries)?", expression)
        return initializer(self.text, name[1]) if name else expression

    def profiles(self, variable, position):
        collection = self.collection(variable, position)
        if not collection:
            return None
        records = []
        for match in re.finditer(r"\bid:\s*(['\"])([^'\"]+)\1\s*,\s*size:\s*(?:const\s+)?Size\(\s*([\d.]+)\s*,\s*([\d.]+)\s*\)\s*,\s*brightness:\s*Brightness\.(dark|light)", collection):
            records.append({"id": match[2], "width": int(float(match[3])), "height": int(float(match[4])), "theme": match[5]})
        return records or None

    def constructor_field_values(self, collection, field, captures, depth):
        result = set()
        for constructor in re.finditer(r"\b(\w+)\s*\([^;{}]*\bthis\." + re.escape(field) + r"\b", self.text):
            name = constructor[1]
            opening = self.text.index("(", constructor.start())
            signature = self.text[opening + 1:closing(self.text, opening)]
            params = arguments(signature.split("{")[0])
            indexes = [i for i, (_, p) in enumerate(params) if re.search(r"\bthis\." + re.escape(field) + r"\b", p)]
            if not indexes:
                continue
            for call in re.finditer(r"\b" + re.escape(name) + r"\s*\(", collection):
                opening = call.end() - 1
                args = arguments(collection[opening + 1:closing(collection, opening)])
                if indexes[0] < len(args):
                    result |= self.values(args[indexes[0]][1], 0, captures, depth + 1)
        return result

    def enum_names(self, name):
        if name == "Brightness":
            return {"dark", "light"}
        if name in self._enum_cache:
            return self._enum_cache[name]
        source = self.text
        package = self.path
        while package.name != "test" and package != package.parent:
            package = package.parent
        if package.name == "test":
            for path in (package.parent / "lib").rglob("*.dart"):
                text = path.read_text()
                if re.search(r"\benum\s+" + re.escape(name) + r"\b", text):
                    source += "\n" + clean_comments(text)
        match = re.search(r"\benum\s+" + re.escape(name) + r"\s*\{([^}]+)\}", source)
        values = set(re.findall(r"\b(\w+)\s*(?:,|$)", match[1].split(";")[0])) if match else set()
        self._enum_cache[name] = values
        return values

    def values(self, expression, position, captures, depth=0):
        key = (expression, position, tuple(sorted(captures.items())), depth)
        if key not in self._value_cache:
            self._value_cache[key] = self._values(expression, position, captures, depth)
        return self._value_cache[key]

    def _values(self, expression, position, captures, depth):
        expression = expression.strip()
        if depth > 8:
            return set()
        if expression in captures:
            return {captures[expression]}
        if expression.startswith(("'", '"')) and string_end(expression, 0) == len(expression):
            pieces = slots(expression[1:-1])
            result = {""}
            for dynamic, value in pieces:
                options = self.values(value, position, captures, depth + 1) if dynamic else {value}
                result = {a + b for a in result for b in options}
            return result
        conditional = re.fullmatch(r"(.+?)\s*\?\s*(['\"].*?['\"])\s*:\s*(['\"].*?['\"])", expression, re.S)
        if conditional:
            condition, yes, no = conditional.groups()
            equality = re.fullmatch(r"(.+?)\s*==\s*(.+)", condition.strip())
            if equality:
                left = self.values(equality[1], position, captures, depth + 1)
                right = self.values(equality[2], position, captures, depth + 1)
                choices = ({yes} if left and left == right else {no} if left and right and not left & right else {yes, no})
            else:
                assigned = initializer(self.text, condition.strip(), position)
                if assigned and assigned != condition:
                    return self.values(assigned + " ? " + yes + " : " + no, position, captures, depth + 1)
                collection = self.collection(condition.strip(), position)
                if collection and re.search(r"\b(?:true|false)\b", collection):
                    choices = {yes, no}
                else:
                    return set()
            return set().union(*(self.values(choice, position, captures, depth + 1) for choice in choices))
        if expression in {"Brightness.dark", "Brightness.light"}:
            return {expression.rsplit(".", 1)[1]}
        dimension = re.fullmatch(r"(\w+)\.(width|height)\.toInt\(\)", expression)
        if dimension:
            field = 0 if dimension[2] == "width" else 1
            return {str(int(float(pair[field]))) for pair in re.findall(r"\bSize\(\s*([\d.]+)\s*,\s*([\d.]+)\s*\)", self.text)}
        transform = re.fullmatch(r"(\w+)\.toLowerCase\(\)\.replaceAll\(['\"] ['\"],\s*['\"]_['\"]\)", expression)
        if transform:
            return {v.lower().replace(" ", "_") for v in self.values(transform[1], position, captures, depth + 1)}
        member = re.fullmatch(r"(\w+)\.(id|key|name|slug|fileKey)", expression)
        if member:
            variable, field = member.groups()
            collection = self.collection(variable, position)
            if field == "id" and collection:
                ids = set(re.findall(r"\bid:\s*['\"]([^'\"]+)['\"]", collection))
                if ids:
                    return ids
                enum = re.fullmatch(r"(\w+)\.values", collection)
                if enum:
                    declaration = re.search(r"\benum\s+" + re.escape(enum[1]) + r"\s*\{", self.text)
                    block = self.text[declaration.end():closing(self.text, declaration.end() - 1)] if declaration else ""
                    getter = re.search(r"String\s+get\s+id\s*=>\s*switch\s*\(this\)\s*\{([^}]+)\}", block)
                    return set(re.findall(r"\b\w+\s*=>\s*['\"]([^'\"]+)['\"]", getter[1])) if getter else set()
            if field == "key" and collection:
                # Map entry keys are declarations, not arbitrary strings in its values.
                keys = set(re.findall(r"(?:^|[,{])\s*['\"]([^'\"]+)['\"]\s*:", collection))
                loop = loop_expression(self.text, variable, position)
                map_name = re.fullmatch(r"(\w+)\.entries", loop or "")
                if map_name:
                    keys |= set(re.findall(r"\b" + re.escape(map_name[1]) + r"\[['\"]([^'\"]+)['\"]\]\s*=", self.text[:position]))
                for loop in re.finditer(r"for\s*\(\s*final\s+(\w+)\s+in\s+", collection):
                    start = loop.end()
                    end = start
                    while end < len(collection) and collection[end] != ")":
                        if collection[end] in "[{(":
                            end = closing(collection, end) + 1
                        elif collection[end] in "'\"":
                            end = string_end(collection, end)
                        else:
                            end += 1
                    if re.match(r"\s*" + re.escape(loop[1]) + r"\s*:", collection[end + 1:]):
                        keys |= literals(collection[start:end])
                return keys
            if field == "name":
                enum_value = re.fullmatch(r"(\w+)\.(\w+)\.name", expression)
                if enum_value:
                    return {enum_value[2]} if enum_value[2] in self.enum_names(enum_value[1]) else set()
                expression = loop_expression(self.text, variable, position) or ""
                enum = re.fullmatch(r"(\w+)\.values", expression)
                if enum:
                    return self.enum_names(enum[1])
                if "Brightness" in expression:
                    return set(re.findall(r"Brightness\.(dark|light)", expression))
                if collection and ".states" not in collection:
                    return set(re.findall(r"\w+\.(\w+)", collection))
                if variable == "brightness":
                    return set(re.findall(r"Brightness\.(dark|light)", self.text))
                enum_types = re.findall(r"\b(?:final\s+)?(\w+)\s+" + re.escape(variable) + r"\s*[;,]", self.text)
                enums = set().union(*(self.enum_names(t) for t in enum_types)) if enum_types else set()
                if not enums and variable == "state":
                    for enum_type in re.findall(r"\benum\s+(\w+)", self.text):
                        enums |= self.enum_names(enum_type)
                return enums or self.parameter_values(expression, position, captures, depth)
            if field == "slug" and collection:
                return self.constructor_field_values(collection, field, captures, depth)
            if field == "fileKey" and collection:
                if not re.search(r"String\s+get\s+fileKey\s*=>\s*componentKey\.replaceAll\(['\"]\|['\"],\s*['\"]_['\"]\)", self.text):
                    return set()
                keys = set()
                for match in re.finditer(r"componentKey:\s*", collection):
                    offset = match.end()
                    if collection[offset:offset + 1] in "'\"":
                        end = string_end(collection, offset)
                        value = collection[offset:end]
                        # Nested collection-for declarations supply the component kind.
                        for p, v, _ in strings(self.text):
                            if self.text[p:p + len(value)] == value:
                                keys |= {k.replace("|", "_") for k in self.values(value, p, captures, depth + 1)}
                return keys
            return self.parameter_values(expression, position, captures, depth)
        enum_member_name = re.fullmatch(r"(\w+)\.(\w+)\.name", expression)
        if enum_member_name:
            return {enum_member_name[2]} if enum_member_name[2] in self.enum_names(enum_member_name[1]) else set()
        simple = re.fullmatch(r"\w+", expression)
        if simple:
            collection = self.collection(expression, position)
            if collection:
                return literals(collection)
            assigned = initializer(self.text, expression, position)
            if assigned:
                if re.search(r"\}\s*\[\w+\]!$", assigned):
                    return literals(assigned)
                if "_snakeCase(" in assigned:
                    inner = re.search(r"_snakeCase\(([^)]+)\)", assigned)[1]
                    return {re.sub(r"(?<!^)(?=[A-Z])", "_", v).lower() for v in self.values(inner, position, captures, depth + 1)}
                return self.values(assigned, position, captures, depth + 1)
            return self.parameter_values(expression, position, captures, depth)
        return set()

    def matches(self, relative, viewport, theme):
        if not self.has_matcher:
            return False
        for position, template in self.templates:
            if "$" not in template:
                if relative == template:
                    return True
                continue
            pieces = slots(template)
            if not relative.startswith(pieces[0][1]) or not relative.endswith(pieces[-1][1]):
                continue
            expressions = [value for dynamic, value in pieces if dynamic]
            if position not in self._pattern_cache:
                domains = {expression: self.values(expression, position, {}) for expression in expressions}
                pattern = None
                if all(domains.values()):
                    pattern = re.compile("".join("(" + "|".join(re.escape(v) for v in sorted(domains[value], key=len, reverse=True)) + ")" if dynamic else re.escape(value) for dynamic, value in pieces))
                self._pattern_cache[position] = pattern
            pattern = self._pattern_cache[position]
            if pattern is None:
                continue
            match = pattern.fullmatch(relative)
            if not match:
                continue
            captures = dict(zip(expressions, match.groups()))
            valid = True
            for expression, captured in captures.items():
                profile = re.fullmatch(r"(\w+)\.id", expression)
                records = self.profiles(profile[1], position) if profile else None
                if records is not None:
                    if not any(r["id"] == captured and (r["width"], r["height"]) == viewport and r["theme"] == theme for r in records):
                        valid = False
                        break
                elif re.fullmatch(r"\w+\.(?:width|height)\.toInt\(\)", expression):
                    sizes = {(int(float(w)), int(float(h))) for w, h in re.findall(r"\bSize\(\s*([\d.]+)\s*,\s*([\d.]+)\s*\)", self.text)}
                    if viewport not in sizes:
                        valid = False
                        break
                else:
                    # Do not let a candidate supply its own expression domain.
                    domain_captures = {k: v for k, v in captures.items() if k != expression}
                    if captured not in self.values(expression, position, domain_captures):
                        valid = False
                        break
            if valid:
                return True
        return False


def find_reference(root, baseline, cache):
    path = root / baseline["path"]
    test_root = next((p for p in path.parents if p.name == "test"), None)
    if test_root is None or root not in test_root.parents:
        return None
    relative = path.relative_to(test_root).as_posix()
    if test_root not in cache:
        cache[test_root] = [Source(p) for p in sorted(test_root.rglob("*_test.dart"))]
    viewport = (baseline["viewport"]["width"], baseline["viewport"]["height"])
    with path.open("rb") as image:
        header = image.read(24)
    if header[:8] != b"\x89PNG\r\n\x1a\n" or struct.unpack(">II", header[16:24]) != viewport:
        return None
    filename_themes = re.findall(r"(?:^|_)(dark|light)(?=_|\.)", path.name)
    if baseline["theme"] != "high_contrast" and filename_themes and baseline["theme"] != filename_themes[-1]:
        return None
    for source in cache[test_root]:
        if source.matches(relative, viewport, baseline["theme"]):
            return source.path
    return None


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, required=True)
    args = parser.parse_args()
    cache = {}
    missing = []
    for baseline in json.loads(args.manifest.read_text())["baselines"]:
        if find_reference(args.root, baseline, cache) is None:
            missing.append(baseline["path"])
    if missing:
        for path in missing:
            print("Golden has no declared test case reference: " + path)
        raise SystemExit(1)
    print("Golden test references resolve from declared source cases.")


if __name__ == "__main__":
    main()
