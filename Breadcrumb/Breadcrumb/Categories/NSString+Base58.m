//
//  NSString+Base58.m
//  Breadcrumb
//
//  Adapted by Andrew Hurst on 2/13/15.
//
//  Created by Aaron Voisine on 5/13/13.
//  Copyright (c) 2013 Aaron Voisine <voisine@gmail.com>
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to
//  deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#import "NSString+Base58.h"
#import "NSMutableData+Bitcoin.h"
#import "NSData+Hash.h"
#import "ccMemory.h"

#define BITCOIN_PUBKEY_ADDRESS 0
#define BITCOIN_SCRIPT_ADDRESS 5
#define BITCOIN_PUBKEY_ADDRESS_TEST 111
#define BITCOIN_SCRIPT_ADDRESS_TEST 196
#define BITCOIN_PRIVKEY 128
#define BITCOIN_PRIVKEY_TEST 239

#define BIP38_NOEC_PREFIX 0x0142
#define BIP38_EC_PREFIX 0x0143
#define BIP38_NOEC_FLAG (0x80 | 0x40)
#define BIP38_COMPRESSED_FLAG 0x20
#define BIP38_LOTSEQUENCE_FLAG 0x04
#define BIP38_INVALID_FLAG (0x10 | 0x08 | 0x02 | 0x01)

// From Breadwallets implmentation of base58
// https://github.com/voisine/breadwallet/blob/ce1d76ef20d39be0ae31c4d5f22f912de4ac0b89/BreadWallet/NSString%2BBitcoin.m
static const UniChar base58chars[] = {
  '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'J', 'K', 'L', 'M', 'N', 'P',
  'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'm', 'n',
  'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z'
};
static const int8_t base58map[] = {
  -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
  -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
  -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
  -1, 0, 1, 2, 3, 4, 5, 6, 7, 8, -1, -1, -1, -1, -1, -1,
  -1, 9, 10, 11, 12, 13, 14, 15, 16, -1, 17, 18, 19, 20, 21, -1,
  22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, -1, -1, -1, -1, -1,
  -1, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, -1, 44, 45, 46,
  47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, -1, -1, -1, -1, -1
};

@implementation NSString (BCBase58)
#pragma mark Encoding

+ (NSString *)base58WithData:(NSData *)data {
  // From https://github.com/voisine/breadwallet/blob/ce1d76ef20d39be0ae31c4d5f22f912de4ac0b89/BreadWallet/NSString%2BBitcoin.m
  size_t i, z = 0;
  
  while (z < data.length && ((const uint8_t *)data.bytes)[z] == 0) z++; // count leading zeroes
  
  uint8_t buf[(data.length - z)*138/100 + 1]; // log(256)/log(58), rounded up
  
  CC_XZEROMEM(buf, sizeof(buf));
  
  for (i = z; i < data.length; i++) {
    uint32_t carry = ((const uint8_t *)data.bytes)[i];
    
    for (ssize_t j = (ssize_t)sizeof(buf) - 1; j >= 0; j--) {
      carry += (uint32_t)buf[j] << 8;
      buf[j] = carry % 58;
      carry /= 58;
    }
  }
  i = 0;
  
  while (i < sizeof(buf) && buf[i] == 0) i++; // skip leading zeroes
  
  CFMutableStringRef str = CFStringCreateMutable(SecureAllocator(), (CFIndex)(z + sizeof(buf) - i));
  
  while (z-- > 0) CFStringAppendCharacters(str, base58chars, 1);
  
  while (i < sizeof(buf)) CFStringAppendCharacters(str, &base58chars[buf[i++]], 1);
  
  CC_XZEROMEM(buf, sizeof(buf));
  
  return CFBridgingRelease(str);
}

+ (NSString *)base58checkWithData:(NSData *)data {
  NSMutableData *_data = [NSMutableData secureDataWithData:data];

  [_data appendBytes:_data.SHA256_2.bytes length:4];

  return [self base58WithData:_data];
}

- (NSString *)hexToBase58check {
  return [NSString base58checkWithData:self.hexToData];
}

+ (NSString *)hexWithData:(NSData *)data {
  const uint8_t *bytes = data.bytes;
  NSMutableString *hex = CFBridgingRelease(
      CFStringCreateMutable(SecureAllocator(), (CFIndex)(data.length * 2)));

  for (NSUInteger i = 0; i < data.length; i++)
    [hex appendFormat:@"%02x", bytes[i]];

  return [hex isKindOfClass:[NSString class]] ? hex : NULL;
}

- (NSString *)hexToBase58 {
  return [[self class] base58WithData:self.hexToData];
}

#pragma mark Decoding

- (NSData *)base58ToData {
  // From https://github.com/voisine/breadwallet/blob/ce1d76ef20d39be0ae31c4d5f22f912de4ac0b89/BreadWallet/NSString%2BBitcoin.m
  size_t i, z = 0;
  
  
  // Check all chars are allowed
  BOOL pass;
  for (NSUInteger w = 0; w < self.length; ++w) {
    pass = false;
    for (NSUInteger q = 0; q < 59; ++q)
      if ( [self characterAtIndex:w] == base58chars[q] )
        pass = true;
    if ( !pass )
      return NULL;
  }
  
  
  // Decode
  while (z < self.length && [self characterAtIndex:z] == *base58chars) z++; // count leading zeroes
  
  uint8_t buf[(self.length - z)*733/1000 + 1]; // log(58)/log(256), rounded up
  
  CC_XZEROMEM(buf, sizeof(buf));
  
  for (i = z; i < self.length; i++) {
    
    UniChar c = [self characterAtIndex:i];
    
    if (c >= sizeof(base58map)/sizeof(*base58map) || base58map[c] == -1) break; // invalid base58 digit
    
    uint32_t carry = (uint32_t)base58map[c];
    
    for (ssize_t j = (ssize_t)sizeof(buf) - 1; j >= 0; j--) {
      carry += (uint32_t)buf[j]*58;
      buf[j] = carry & 0xff;
      carry >>= 8;
    }
  }
  i = 0;
  
  while (i < sizeof(buf) && buf[i] == 0) i++; // skip leading zeroes
  
  NSMutableData *d = [NSMutableData secureDataWithCapacity:z + sizeof(buf) - i];
  
  d.length = z;
  
  [d appendBytes:&buf[i] length:sizeof(buf) - i];
  
  CC_XZEROMEM(buf, sizeof(buf));
  
  return d;
}

- (NSData *)base58checkToData {
  NSData *data, *d;
  d = self.base58ToData;
  if (d.length < 4) return NULL;
  data =
      CFBridgingRelease(CFDataCreate(SecureAllocator(), d.bytes, (CFIndex)(d.length - 4)));

  // verify checksum
  if (*(uint32_t *)((const uint8_t *)d.bytes + d.length - 4) !=
      *(uint32_t *)data.SHA256_2.bytes)
    return NULL;
  return data;
}

- (NSString *)base58checkToHex {
  return [NSString hexWithData:self.base58checkToData];
  ;
}

- (NSString *)base58ToHex {
  return [NSString hexWithData:self.base58ToData];
  ;
}

- (NSData *)hexToData {
  if (self.length % 2) return nil;

  NSMutableData *d = [NSMutableData secureDataWithCapacity:self.length / 2];
  uint8_t b = 0;

  for (NSUInteger i = 0; i < self.length; i++) {
    unichar c = [self characterAtIndex:i];

    switch (c) {
      case '0':
      case '1':
      case '2':
      case '3':
      case '4':
      case '5':
      case '6':
      case '7':
      case '8':
      case '9':
        b += c - '0';
        break;
      case 'A':
      case 'B':
      case 'C':
      case 'D':
      case 'E':
      case 'F':
        b += c + 10 - 'A';
        break;
      case 'a':
      case 'b':
      case 'c':
      case 'd':
      case 'e':
      case 'f':
        b += c + 10 - 'a';
        break;
      default:
        return d;
    }

    if (i % 2) {
      [d appendBytes:&b length:1];
      b = 0;
    } else
      b *= 16;
  }

  return [d isKindOfClass:[NSData class]] ? d : NULL;
}

- (NSData *)addressToHash160 {
  NSData *d = self.base58checkToData;

  return (d.length == 160 / 8 + 1)
             ? [d subdataWithRange:NSMakeRange(1, d.length - 1)]
             : nil;
}

#pragma mark Validity Checks
//
//- (BOOL)isValidBitcoinAddress {
//  return NULL;
//}
//
//- (BOOL)isValidBitcoinPrivateKey {
//  return NULL;
//}
//
//- (BOOL)isValidBitcoinBIP38Key {
//  return NULL;
//}

#pragma mark Old

// NOTE: It's important here to be permissive with scriptSig (spends) and strict
// with scriptPubKey (receives). If we
// miss a receive transaction, only that transaction's funds are missed, however
// if we accept a receive transaction that
// we are unable to correctly sign later, then the entire wallet balance after
// that point would become stuck with the
// current coin selection code
//+ (NSString *)addressWithScriptPubKey:(NSData *)script {
//  if (script == (id)[NSNull null]) return nil;
//
//  NSArray *elem = [script scriptElements];
//  NSUInteger l = elem.count;
//  NSMutableData *d = [NSMutableData data];
//  uint8_t v = BITCOIN_PUBKEY_ADDRESS;
//
//#if BITCOIN_TESTNET
//  v = BITCOIN_PUBKEY_ADDRESS_TEST;
//#endif
//
//  if (l == 5 && [elem[0] intValue] == OP_DUP &&
//      [elem[1] intValue] == OP_HASH160 && [elem[2] intValue] == 20 &&
//      [elem[3] intValue] == OP_EQUALVERIFY &&
//      [elem[4] intValue] == OP_CHECKSIG) {
//    // pay-to-pubkey-hash scriptPubKey
//    [d appendBytes:&v length:1];
//    [d appendData:elem[2]];
//  } else if (l == 3 && [elem[0] intValue] == OP_HASH160 &&
//             [elem[1] intValue] == 20 && [elem[2] intValue] == OP_EQUAL) {
//    // pay-to-script-hash scriptPubKey
//    v = BITCOIN_SCRIPT_ADDRESS;
//#if BITCOIN_TESTNET
//    v = BITCOIN_SCRIPT_ADDRESS_TEST;
//#endif
//    [d appendBytes:&v length:1];
//    [d appendData:elem[1]];
//  } else if (l == 2 && ([elem[0] intValue] == 65 || [elem[0] intValue] == 33)
//  &&
//             [elem[1] intValue] == OP_CHECKSIG) {
//    // pay-to-pubkey scriptPubKey
//    [d appendBytes:&v length:1];
//    [d appendData:[elem[0] hash160]];
//  } else
//    return nil;  // unknown script type
//
//  return [self base58checkWithData:d];
//}

//+ (NSString *)addressWithScriptSig:(NSData *)script {
//  if (script == (id)[NSNull null]) return nil;
//
//  NSArray *elem = [script scriptElements];
//  NSUInteger l = elem.count;
//  NSMutableData *d = [NSMutableData data];
//  uint8_t v = BITCOIN_PUBKEY_ADDRESS;
//
//#if BITCOIN_TESTNET
//  v = BITCOIN_PUBKEY_ADDRESS_TEST;
//#endif
//
//  if (l >= 2 && [elem[l - 2] intValue] <= OP_PUSHDATA4 &&
//      [elem[l - 2] intValue] > 0 &&
//      ([elem[l - 1] intValue] == 65 ||
//       [elem[l - 1] intValue] == 33)) {  // pay-to-pubkey-hash scriptSig
//        [d appendBytes:&v length:1];
//        [d appendData:[elem[l - 1] hash160]];
//      } else if (l >= 2 && [elem[l - 2] intValue] <= OP_PUSHDATA4 &&
//                 [elem[l - 2] intValue] > 0 &&
//                 [elem[l - 1] intValue] <= OP_PUSHDATA4 &&
//                 [elem[l - 1] intValue] > 0) {  // pay-to-script-hash
//                 scriptSig
//        v = BITCOIN_SCRIPT_ADDRESS;
//#if BITCOIN_TESTNET
//        v = BITCOIN_SCRIPT_ADDRESS_TEST;
//#endif
//        [d appendBytes:&v length:1];
//        [d appendData:[elem[l - 1] hash160]];
//      } else if (l >= 1 && [elem[l - 1] intValue] <= OP_PUSHDATA4 &&
//                 [elem[l - 1] intValue] > 0) {  // pay-to-pubkey scriptSig
//        // TODO: implement Peter Wullie's pubKey recovery from signature
//        return nil;
//      } else
//        return nil;  // unknown script type
//
//  return [self base58checkWithData:d];
//}

- (BOOL)isValidBitcoinAddress {
  // TODO: Replace and move this to the address object, also there should be
  // better reporting than just a bool...
  NSData *d = self.base58checkToData;
  if (d.length != 21) return NO;

  uint8_t version = *(const uint8_t *)d.bytes;

#if BITCOIN_TESTNET
  return (version == BITCOIN_PUBKEY_ADDRESS_TEST ||
          version == BITCOIN_SCRIPT_ADDRESS_TEST)
             ? YES
             : NO;
#else
  return (version == BITCOIN_PUBKEY_ADDRESS ||
          version == BITCOIN_SCRIPT_ADDRESS)
             ? YES
             : NO;
#endif
}

- (BOOL)isValidBitcoinPrivateKey {
  NSData *d = self.base58checkToData;

  if (d.length == 33 || d.length == 34) {  // wallet import format:
// https://en.bitcoin.it/wiki/Wallet_import_format
#if BITCOIN_TESNET
    return (*(const uint8_t *)d.bytes == BITCOIN_PRIVKEY_TEST) ? YES : NO;
#else
    return (*(const uint8_t *)d.bytes == BITCOIN_PRIVKEY) ? YES : NO;
#endif
  } else if ((self.length == 30 || self.length == 22) &&
             [self characterAtIndex:0] == 'S') {  // mini private key format
    NSMutableData *md = [NSMutableData secureDataWithCapacity:self.length + 1];

    md.length = self.length;
    [self getBytes:md.mutableBytes
             maxLength:md.length
            usedLength:NULL
              encoding:NSUTF8StringEncoding
               options:0
                 range:NSMakeRange(0, self.length)
        remainingRange:NULL];
    [md appendBytes:"?" length:1];
    return (*(const uint8_t *)md.SHA256.bytes == 0) ? YES : NO;
  } else
    return (self.hexToData.length == 32) ? YES : NO;  // hex encoded key
}

// BIP38 encrypted keys:
// https://github.com/bitcoin/bips/blob/master/bip-0038.mediawiki
- (BOOL)isValidBitcoinBIP38Key {
  NSData *d = self.base58checkToData;

  if (d.length != 39) return NO;  // invalid length

  uint16_t prefix = CFSwapInt16BigToHost(*(const uint16_t *)d.bytes);
  uint8_t flag = ((const uint8_t *)d.bytes)[2];

  if (prefix == BIP38_NOEC_PREFIX) {  // non EC multiplied key
    return ((flag & BIP38_NOEC_FLAG) == BIP38_NOEC_FLAG &&
            (flag & BIP38_LOTSEQUENCE_FLAG) == 0 &&
            (flag & BIP38_INVALID_FLAG) == 0)
               ? YES
               : NO;
  } else if (prefix == BIP38_EC_PREFIX) {  // EC multiplied key
    return ((flag & BIP38_NOEC_FLAG) == 0 && (flag & BIP38_INVALID_FLAG) == 0)
               ? YES
               : NO;
  } else
    return NO;  // invalid prefix
}

@end

@implementation NSData (BCBase58)

- (NSString *)base58Encoding {
  return [NSString base58WithData:self];
}

+ (NSData *)fromBase58:(NSString *)base58Encoding {
  return [base58Encoding base58ToData];
}

- (NSString *)base58CheckEncoding {
  return [NSString base58checkWithData:self];
}

+ (NSData *)fromBase58Check:(NSString *)base58CheckEncoding {
  return [base58CheckEncoding base58checkToData];
}

- (NSString *)toHex {
  return [NSString hexWithData:self];
}

+ (NSData *)fromHex:(NSString *)hex {
  return [hex hexToData];
}

@end
