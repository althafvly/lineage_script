#!/usr/bin/env python3

import os
import subprocess
import struct
import argparse
import getpass

class AvbError(Exception):
    pass

def egcd(a, b):
    """Extended GCD algorithm."""
    if a == 0:
        return b, 0, 1
    gcd, x1, y1 = egcd(b % a, a)
    return gcd, y1 - (b // a) * x1, x1

def modinv(a, m):
    """Modular inverse using extended GCD."""
    gcd, x, _ = egcd(a, m)
    if gcd != 1:
        return None  # Modular inverse does not exist
    return x % m

def round_to_pow2(number):
    """Round up to the next power of 2."""
    return 2 ** ((number - 1).bit_length())

def encode_long(num_bits, value):
    """Encode an integer into a big-endian byte array."""
    ret = bytearray()
    for bit_pos in range(num_bits, 0, -8):
        octet = (value >> (bit_pos - 8)) & 0xff
        ret.extend(struct.pack('!B', octet))
    return ret

class RSAPublicKey:
    MODULUS_PREFIX = b'modulus='

    def __init__(self, key_path, password=None):
        self.key_path = key_path
        self.key_password = password

        self.modulus = self._extract_modulus()
        self.num_bits = round_to_pow2(self.modulus.bit_length())
        self.exponent = 65537

    def _extract_modulus(self):
        """Extract the RSA modulus using openssl."""
        base_args = ['openssl', 'rsa', '-in', self.key_path, '-modulus', '-noout']
        if self.key_password:
            base_args += ['-passin', f'pass:{self.key_password}']

        for args in [base_args, base_args + ['-pubin']]:
            with subprocess.Popen(args, stdout=subprocess.PIPE, stderr=subprocess.PIPE) as proc:
                stdout, stderr = proc.communicate()
                if proc.returncode == 0:
                    if stdout.lower().startswith(self.MODULUS_PREFIX):
                        modulus_hex = stdout[len(self.MODULUS_PREFIX):].strip()
                        return int(modulus_hex, 16)
        raise AvbError(f"Failed to extract modulus:\n{stderr.decode()}")

    def encode(self):
        """Encode the public key for AVB (Android Verified Boot)."""
        if self.exponent != 65537:
            raise AvbError("Only exponent 65537 supported")

        n0inv = (2 ** 32 - modinv(self.modulus % 2 ** 32, 2 ** 32)) % 2 ** 32
        r = 2 ** self.num_bits
        rrmodn = (r * r) % self.modulus

        out = bytearray()
        out += struct.pack('!II', self.num_bits, n0inv)
        out += encode_long(self.num_bits, self.modulus)
        out += encode_long(self.num_bits, rrmodn)
        return bytes(out)

def extract_public_key(in_key, out_file, password=None):
    """Extract and write the encoded public key to file."""
    pubkey = RSAPublicKey(in_key, password)
    with open(out_file, 'wb') as f:
        f.write(pubkey.encode())

def main():
    parser = argparse.ArgumentParser(description="Extract AVB public key.")
    parser.add_argument('--key', required=True, help='Path to private key PEM')
    parser.add_argument('--output', required=True, help='Output file')
    parser.add_argument('--password', help='Optional key password (unsafe on command line)')
    parser.add_argument('--no-password', action='store_true',
                        help='Skip password prompt and assume no password')

    args = parser.parse_args()

    if args.no_password:
        password = None
    else:
        password = args.password
        if password is None:
            try:
                password = getpass.getpass("Enter key password (if any): ")
            except KeyboardInterrupt:
                print("\nCancelled.")
                return

    try:
        extract_public_key(args.key, args.output, password if password else None)
        print(f"Public key written to {args.output}")
    except AvbError as e:
        print(f"Error: {e}")
    except Exception as e:
        print(f"Unexpected error: {e}")

if __name__ == '__main__':
    main()
