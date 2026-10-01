#!/usr/bin/env python3
"""Apply authenticated publisher license evidence and already built plugin outputs.

No fetching, dependency resolution, application build, waiver, or version change.
"""
from __future__ import annotations
import argparse
import base64
import copy
import hashlib
import json
from pathlib import Path
import re
import tarfile
import xml.etree.ElementTree as ET
import zipfile
import local_dependency_inventory as d

DEFAULT_MANIFEST = 'docs/release/dependency-license-evidence-2026-10-01/manifest.json'


def require(condition, message):
    if not condition:
        raise d.InventoryError(message)


def class_source(raw):
    """Read the JVM SourceFile attribute without executing the class."""
    require(raw[:4] == b'\xca\xfe\xba\xbe', 'Not a Java class')
    offset = 8
    def number(size):
        nonlocal offset
        require(offset + size <= len(raw), 'Truncated Java class')
        value = int.from_bytes(raw[offset:offset + size], 'big'); offset += size
        return value
    def skip(size):
        nonlocal offset
        require(offset + size <= len(raw), 'Truncated class attribute')
        offset += size
    count = number(2); pool = {}; index = 1
    while index < count:
        tag = number(1)
        if tag == 1:
            length = number(2)
            require(offset + length <= len(raw), 'Truncated class UTF8')
            pool[index] = raw[offset:offset + length].decode('utf-8', errors='replace'); offset += length
        elif tag in (3, 4): number(4)
        elif tag in (5, 6): number(8); index += 1
        elif tag in (7, 8, 16, 19, 20): number(2)
        elif tag in (9, 10, 11, 12, 17, 18): number(4)
        elif tag == 15: number(3)
        else: raise d.InventoryError('Unknown class constant tag')
        index += 1
    number(6); number(2 * number(2))
    def attributes():
        for _ in range(number(2)):
            name = pool.get(number(2)); length = number(4)
            require(offset + length <= len(raw), 'Truncated class attribute')
            # Only SourceFile has a scalar value; skip executable bytecode.
            if name == 'SourceFile':
                value = number(length)
            else:
                value = None
                skip(length)
            yield name, value, length
    for _ in range(2):
        for _ in range(number(2)):
            number(6); list(attributes())
    source = None
    for name, value, length in attributes():
        if name == 'SourceFile':
            require(length == 2 and source is None, 'Invalid SourceFile attribute')
            source = pool.get(value)
    require(offset == len(raw) and source, 'Missing class source provenance')
    return source


def apache_grant(raw):
    text = raw[:5000].decode(errors='replace')
    text = re.sub(r'\s+', ' ', text.replace('*', ' '))
    return bool(re.search(r'Apache License,? (?:Version|version) 2\.0', text))


def class_coverage(jar, sources):
    with zipfile.ZipFile(jar) as z:
        require(z.testzip() is None, 'Corrupt published JAR')
        classes = {name: class_source(z.read(name)) for name in z.namelist() if name.endswith('.class')}
    require(classes and set(classes.values()) <= set(sources), 'Compiled classes lack licensed source coverage')
    return classes


def tar_files(path):
    with tarfile.open(path, 'r:*') as t:
        return {member.name: t.extractfile(member).read() for member in t if member.isfile()}


def verify_sri(path, metadata):
    raw = Path(path).read_bytes(); dist = metadata['dist']
    require(hashlib.sha1(raw).hexdigest() == dist['shasum'], 'npm archive SHA1 differs')
    entries = dist.get('integrity', '').split()
    require(entries, 'npm publisher integrity absent')
    for entry in entries:
        algorithm, value = entry.split('-', 1)
        require(algorithm in ('sha256', 'sha384', 'sha512'), 'Unsupported npm integrity')
        require(base64.b64encode(hashlib.new(algorithm, raw).digest()).decode() == value, 'npm archive SRI differs')


def verify_license(row, component, root, evidence):
    require(all(row[k] == component[k] for k in ('ref', 'ecosystem', 'name', 'version')), 'Publisher component identity differs')
    require(row['source'] == component['source'], 'Selected source differs')
    paths = {}
    for record in row['files']:
        path = Path(record['path'])
        require(not path.is_absolute() and '..' not in path.parts, 'Publisher path escapes repository')
        target = root / path
        require(not target.is_symlink() and target.resolve().is_relative_to(root), 'Publisher symlink escapes repository')
        require(target.stat().st_size == record['bytes'] and d.digest_file(target) == record['sha256'], 'Publisher evidence hash differs')
        require(record['path'] not in paths, 'Duplicate publisher evidence')
        paths[record['path']] = target
    def file(field):
        require(row[field] in paths, 'Unbound publisher evidence file')
        return paths[row[field]]
    method = row['method']; license_id = row['license']
    if method in ('exact-npm-release', 'identical-debian-upstream'):
        metadata = d.load_json(file('metadata'))
        name = row['upstreamName']
        require(metadata['name'] == name and metadata['version'] == component['version'], 'npm release name/version differs')
        if component['ecosystem'] == 'deno-remote':
            match = re.match(r'https://esm\.sh/(@[^/]+/[^/@]+|[^/@]+)@([^/?]+)(?:[/\?]|$)', component['name'])
            require(match and match.groups() == (name, component['version']), 'CDN upstream identity differs')
        else:
            require(component['name'] == name, 'npm selected identity differs')
        verify_sri(file('archive'), metadata)
        package = tar_files(file('archive'))
        require(json.loads(package['package/package.json'])['name'] == name, 'npm archive package differs')
        require(json.loads(package['package/package.json'])['version'] == component['version'], 'npm archive version differs')
        if method == 'exact-npm-release':
            require(metadata.get('license') == license_id == 'MIT', 'npm declaration differs')
            require(package[row['licenseMember']] == file('licenseText').read_bytes(), 'npm license text differs')
        else:
            require(name == 'buffers' and component['version'] == '0.1.1' and license_id == 'MIT', 'Unsupported licensed distribution binding')
            alternate = tar_files(file('licensedArchive'))
            normalized = {key.split('/', 1)[1]: value for key, value in alternate.items()}
            selected = {key.split('/', 1)[1]: value for key, value in package.items()}
            require(normalized == selected and len(selected) == 6, 'Licensed Debian source differs from selected npm package')
            grant = file('licenseText').read_text()
            require('Upstream-Name: buffers' in grant and 'Files: *' in grant and 'License: MIT' in grant and 'Permission is hereby granted' in grant, 'Debian package-wide grant absent')
            for integrity in component['integrities']:
                if integrity['algorithm'] == 'sha512':
                    require(d.digest_file(file('archive'), 'sha512') == integrity['value'], 'Selected npm archive integrity differs')
    elif method == 'locked-jsr-declaration':
        metadata = d.load_json(file('metadata')); declaration = d.load_json(file('declaration'))
        require(declaration['name'] == component['name'] and declaration['version'] == component['version'] and declaration['license'] == license_id == 'MIT', 'JSR declaration identity differs')
        checksum = metadata['manifest']['/jsr.json']
        require(checksum['checksum'] == 'sha256-' + d.digest_file(file('declaration')) and checksum['size'] == file('declaration').stat().st_size, 'JSR declaration checksum differs')
        require(any(i['algorithm'] == 'sha256' and i['value'] == d.digest_file(file('metadata')) for i in component['integrities']), 'JSR metadata differs from selected lock')
    elif method in ('exact-maven-pom', 'exact-maven-source-grants', 'publisher-package-source-grant'):
        jar = file('archive'); pom = ET.parse(file('metadata')).getroot()
        group, name = component['name'].split(':')
        coordinates = (pom.findtext('{*}groupId') or pom.findtext('{*}parent/{*}groupId'), pom.findtext('{*}artifactId'), pom.findtext('{*}version') or pom.findtext('{*}parent/{*}version'))
        require(coordinates == (group, name, component['version']), 'Maven release coordinates differ')
        selected = [evidence[k] for k in component['evidence']
                    if evidence[k]['kind'] == 'file' and evidence[k]['path'].endswith('.jar')
                    and set(evidence[k]['roles']) & {'resolved-native-cache-artifact', 'selected-gradle-classpath-bytes'}]
        require(selected and all(d.digest_file(jar) == item['sha256'] for item in selected), 'Published JAR differs from selected artifact')
        require(license_id == 'Apache-2.0', 'Unsupported Maven license')
        if method == 'exact-maven-pom':
            require(any('Apache' in (node.findtext('{*}name') or '') and '2.0' in (node.findtext('{*}name') or '') for node in pom.findall('{*}licenses/{*}license')), 'Exact POM package-wide declaration absent')
        elif method == 'exact-maven-source-grants':
            with zipfile.ZipFile(file('sourcesArchive')) as z:
                sources = {Path(name).name: z.read(name) for name in z.namelist() if name.endswith('.java')}
            require(len(sources) == 23 and all(apache_grant(raw) for raw in sources.values()), 'Exact source release has unlicensed Java files')
            coverage = class_coverage(jar, sources)
            require(len(coverage) == row['classCount'], 'Exact source coverage count differs')
        else:
            # A publisher package grant is license evidence. This does not assert
            # an exact release commit or a reproducible binary build.
            require(component['name'] == 'org.tensorflow:tensorflow-lite-metadata', 'Unsupported source publisher')
            require(row['exactReleaseCommitClaimed'] is False, 'Unsupported exact release provenance claim')
            for field in ('packageBuild', 'schemaBuild'):
                text = file(field).read_text()
                require(re.search(r'licenses\s*=\s*\["notice"\].*Apache 2\.0', text), 'Publisher package-wide Apache grant absent')
            sources = {}
            for path in row['javaSources']:
                require(path in paths and apache_grant(paths[path].read_bytes()), 'Publisher Java source grant absent')
                sources[paths[path].name.removeprefix('release-')] = True
            for path in row['schemaSources']:
                require(path in paths and apache_grant(paths[path].read_bytes()), 'Publisher schema source grant absent')
                sources.update({name + '.java': True for name in re.findall(r'^\s*(?:table|struct|enum|union)\s+(\w+)', paths[path].read_text(), re.M)})
            coverage = class_coverage(jar, sources)
            require(len(coverage) == row['classCount'], 'Publisher class/source coverage count differs')
            require('Apache License' in file('licenseText').read_text(), 'Publisher Apache license text absent')
    else:
        raise d.InventoryError('Unknown license evidence relationship')
    return paths


def apply_closure(inventory, manifest_path, outputs_path=None):
    result = copy.deepcopy(inventory); root = Path(result['repositoryRoot']).resolve()
    manifest = d.load_json(manifest_path)
    require(manifest['schemaVersion'] == 1 and len(manifest['licenses']) == 22, 'Publisher closure scope differs')
    observer = d.Inventory(root); observer.evidence = result['evidence']
    observer.file_evidence(manifest_path, 'publisher-license-relationship-manifest')
    components = {c['ref']: c for c in result['components']}
    recovered = set(); findings = {f['ref']: f for f in result['licenseRecovery']['findings']}
    for row in manifest['licenses']:
        require(row['ref'] not in recovered and row['ref'] in components, 'Repeated or absent publisher component')
        component = components[row['ref']]
        paths = verify_license(row, component, root, result['evidence'])
        keys = [observer.file_evidence(path, 'verified-publisher-license-provenance') for path in paths.values()]
        text_keys = [observer.file_evidence(paths[path], 'verified-package-license-text') for path in row.get('licenseTexts', [])]
        association = {key: row[key] for key in ('method', 'license', 'basis')}
        association.update(declarationEvidence=keys, licenseTextEvidence=text_keys, manifest=str(Path(manifest_path).resolve().relative_to(root)))
        for field, values in [('evidence', keys), ('licenseEvidence', text_keys), ('licenseDeclarations', [row['license']])]:
            component[field] = sorted(set(component[field] + values))
        component['licenseAssociations'] = [association]
        findings[row['ref']] = {'ref': row['ref'], 'ecosystem': row['ecosystem'], 'name': row['name'], 'version': row['version'], 'recovered': True, 'associations': [association], 'partialEvidence': findings.get(row['ref'], {}).get('partialEvidence', []), 'remainingReason': None}
        recovered.add(row['ref'])
    built = set()
    if outputs_path:
        observer.file_evidence(outputs_path, 'actual-plugin-output-build-receipt')
        receipt = d.load_json(outputs_path)
        require(receipt['passed'] is True and receipt['applicationReleaseBuilds'] == 0, 'Plugin build receipt failed')
        for club in receipt['results']:
            require(club['passed'] is True and club['exitCode'] == 0 and club['sourceBefore'] == club['sourceAfter'], 'Plugin build changed resolution inputs')
            for item in club['sourceAfter']:
                require(d.digest_file(root / item['path']) == item['sha256'] and (root / item['path']).stat().st_size == item['bytes'], 'Plugin build source inputs changed')
            for item in club['outputs']:
                path = Path(item['path']).resolve()
                require(path.is_relative_to(root) and path.as_posix().endswith('/classes.jar'), 'Plugin output path differs')
                subject = path.relative_to(root).as_posix()
                require(subject not in built and d.digest_file(path) == item['sha256'] and path.stat().st_size == item['bytes'], 'Plugin artifact differs')
                with zipfile.ZipFile(path) as z:
                    require(z.testzip() is None and sum(n.endswith('.class') for n in z.namelist()) == item['classCount'] > 0, 'Plugin JAR contents differ')
                observer.file_evidence(path, 'selected-gradle-classpath-bytes'); built.add(subject)
        require(len(built) == receipt['outputCount'] == 282, 'Plugin output coverage incomplete')
    missing_outputs = {g['subject'] for g in result['unresolved'] if g['kind'] == 'native-project-artifact-not-built'}
    if outputs_path:
        require(missing_outputs <= built, 'A missing plugin output was not built')
    result['unresolved'] = [g for g in result['unresolved'] if not (g['kind'] == 'license-evidence-unavailable' and g['subject'] in recovered) and not (g['kind'] == 'native-project-artifact-not-built' and g['subject'] in built)]
    recovery = result['licenseRecovery']
    recovery['recoveredComponents'] = sorted(set(recovery['recoveredComponents']) | recovered)
    recovery['findings'] = [findings[key] for key in sorted(findings)]
    recovery['remainingGapCount'] = sum(g['kind'] == 'license-evidence-unavailable' for g in result['unresolved'])
    recovery['publisherEvidenceManifest'] = {'path': str(Path(manifest_path).resolve().relative_to(root)), 'sha256': d.digest_file(manifest_path), 'components': len(recovered), 'retrievalUsedNetwork': True, 'applicationPerformedNetworkRequests': 0}
    result['dependencyGapClosure'] = {'publisherLicenseComponents': len(recovered), 'builtPluginOutputs': len(built), 'selectedVersionsChanged': 0, 'edgesChanged': 0, 'legalApprovalClaimed': False, 'applicationReleaseBuilds': 0}
    # Bind the affected tools as current inputs, retaining their previous hash.
    rebound = result.get('dependencyGapClosure', {}).get('previousImplementationEvidence', {})
    for relative, role in [('tools/scripts/local_dependency_inventory.py', 'inventory-generator'),
                           ('tools/scripts/dependency_gap_closure.py', 'publisher-closure-validator'),
                           ('tools/scripts/test_dependency_gap_closure.py', 'publisher-admission-regressions')]:
        if relative in result['evidence'] and result['evidence'][relative]['sha256'] != d.digest_file(root / relative):
            rebound[relative] = result['evidence'].pop(relative)
        observer.file_evidence(root / relative, role)
    result['dependencyGapClosure']['previousImplementationEvidence'] = rebound
    result['summary'].update(evidenceItems=len(result['evidence']), unresolvedFields=len(result['unresolved']), componentsWithLicenseText=sum(bool(c['licenseEvidence']) for c in result['components']), componentsWithLicenseDeclaration=sum(bool(c['licenseDeclarations']) for c in result['components']))
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--inventory', type=Path, required=True)
    parser.add_argument('--manifest', type=Path, default=Path(DEFAULT_MANIFEST))
    parser.add_argument('--plugin-outputs', type=Path)
    args = parser.parse_args()
    result = apply_closure(d.load_report(args.inventory), args.manifest, args.plugin_outputs)
    d.write_reports(result, args.inventory.with_suffix(''))
    print(d.canonical(result['summary']))

if __name__ == '__main__':
    main()
