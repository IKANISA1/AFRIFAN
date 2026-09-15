"""Create a tiny synthetic, codeless AAB for the release validator tests.

The protobuf field layout is from the Android AAPT2 Resources and bundletool
Config schemas. Tests pass the resulting bytes to the real pinned bundletool
validator; this fixture is never evidence of a compiled club application.
"""
import json
import sys
import zipfile


def varint(value):
    encoded = bytearray()
    while value > 127:
        encoded.append((value & 127) | 128)
        value >>= 7
    encoded.append(value)
    return bytes(encoded)


def integer(number, value):
    return varint(number << 3) + varint(value)


def field(number, value):
    value = value.encode() if isinstance(value, str) else value
    return varint((number << 3) | 2) + varint(len(value)) + value


ANDROID = "http://schemas.android.com/apk/res/android"


def attribute(name, value, resource_id=None, kind=None):
    result = field(1, ANDROID if resource_id else "") + field(2, name) + field(3, str(value))
    if resource_id:
        result += integer(5, resource_id)
    if kind == "int":
        result += field(6, field(7, integer(6, int(value))))
    if kind == "bool":
        result += field(6, field(7, integer(8, value == "true")))
    if kind == "str":
        result += field(6, field(2, field(1, value)))
    return result


def element(name, attributes=(), children=()):
    namespace = field(1, field(1, "android") + field(2, ANDROID)) if name == "manifest" else b""
    return field(1, namespace + field(3, name)
                 + b"".join(field(4, value) for value in attributes)
                 + b"".join(field(5, child) for child in children))


options = json.load(sys.stdin)
manifest = element("manifest", [
    attribute("package", options["applicationId"]),
    attribute("versionCode", options["versionCode"], 0x101021B, "int"),
    attribute("versionName", options["versionName"], 0x101021C, "str"),
], [
    element("uses-sdk", [attribute("minSdkVersion", "26", 0x101020C, "int")]),
    element("application", [attribute("hasCode", "false", 0x101000C, "bool")]),
])
with zipfile.ZipFile(options["artifactPath"], "w", compression=zipfile.ZIP_DEFLATED) as archive:
    for name, payload in [("BundleConfig.pb", field(1, field(2, "1.18.1"))),
                          ("base/manifest/AndroidManifest.xml", manifest)]:
        entry = zipfile.ZipInfo(name, (2026, 9, 14, 0, 0, 0))
        entry.compress_type = zipfile.ZIP_DEFLATED
        archive.writestr(entry, payload)
