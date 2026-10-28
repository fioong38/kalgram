#!/usr/bin/env python3
# Generates fake provisioning profiles for the kalgram bundle id.
#
# The stock fake profiles in build-system/fake-codesigning are made for
# ph.telegra.Telegraph. We decode each of them, swap the bundle id and
# re-wrap the plist in a CMS envelope signed by a throwaway key. Nothing
# verifies the signature at build time, and the final .ipa is re-signed by
# the user (ESign), so the key is never used for anything real.

import argparse
import os
import shutil
import subprocess
import tempfile

OFFICIAL_BUNDLE_ID = 'ph.telegra.Telegraph'


def run(args, **kwargs):
    return subprocess.run(args, check=True, **kwargs)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--source', required=True, help='Directory with stock fake codesigning (certs/, profiles/)')
    parser.add_argument('--destination', required=True, help='Output directory (certs/, profiles/)')
    parser.add_argument('--bundleId', required=True)
    args = parser.parse_args()

    profiles_out = os.path.join(args.destination, 'profiles')
    os.makedirs(profiles_out, exist_ok=True)
    shutil.copytree(os.path.join(args.source, 'certs'), os.path.join(args.destination, 'certs'), dirs_exist_ok=True)

    with tempfile.TemporaryDirectory() as tmp:
        key_path = os.path.join(tmp, 'key.pem')
        cert_path = os.path.join(tmp, 'cert.pem')
        run(['openssl', 'req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-days', '3650',
             '-subj', '/CN=kalgram fake profiles', '-keyout', key_path, '-out', cert_path],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

        source_profiles = os.path.join(args.source, 'profiles')
        for name in sorted(os.listdir(source_profiles)):
            if not name.endswith('.mobileprovision'):
                continue
            plist = run(['openssl', 'smime', '-inform', 'der', '-verify', '-noverify',
                         '-in', os.path.join(source_profiles, name)],
                        capture_output=True).stdout
            plist = plist.replace(OFFICIAL_BUNDLE_ID.encode(), args.bundleId.encode())

            plist_path = os.path.join(tmp, name + '.plist')
            with open(plist_path, 'wb') as f:
                f.write(plist)
            run(['openssl', 'smime', '-sign', '-binary', '-nodetach', '-outform', 'der',
                 '-signer', cert_path, '-inkey', key_path,
                 '-in', plist_path, '-out', os.path.join(profiles_out, name)])
            print('Generated {}'.format(name))


if __name__ == '__main__':
    main()
