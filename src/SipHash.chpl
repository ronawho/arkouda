module SipHash {

  require "siphash.h";
  param cROUNDS = 2;
  param dROUNDS = 4;

  private config param DEBUG = false;

  const defaultSipHashKey: [0..#16] uint(8) = for i in 0..#16 do i: uint(8);
  
  class ArgumentError: Error {}

  inline proc ROTL(x, b) {
    return (((x) << (b)) | ((x) >> (64 - (b))));
  }

  private inline proc U32TO8_LE(p: [?D] uint(8), v: uint(32)) {
    p[D.low] = v: uint(8);
    p[D.low+1] = (v >> 8): uint(8);
    p[D.low+2] = (v >> 16): uint(8);
    p[D.low+3] = (v >> 24): uint(8);
  }
  
  private inline proc U64TO8_LE(p: [?D] uint(8), v: uint(64)) {
    U32TO8_LE(p[D.low..#4], v: uint(32));
    U32TO8_LE(p[D.low+4..#4], (v >> 32): uint(32));
  }

  private inline proc U8TO64_LE(p: [] uint(8), D): uint(64) {
    return ((p[D.low]: uint(64)) |
            (p[D.low+1]: uint(64) << 8) |
            (p[D.low+2]: uint(64) << 16) |
            (p[D.low+3]: uint(64) << 24) |
            (p[D.low+4]: uint(64) << 32) |
            (p[D.low+5]: uint(64) << 40) |
            (p[D.low+6]: uint(64) << 48) |
            (p[D.low+7]: uint(64) << 56));
  }

  private inline proc byte_reverse(b: uint(64)): uint(64) {
    var c: uint(64);
    c |= (b & 0xff) << 56;
    c |= ((b >> 8) & 0xff) << 48;
    c |= ((b >> 16) & 0xff) << 40;
    c |= ((b >> 24) & 0xff) << 32;
    c |= ((b >> 32) & 0xff) << 24;
    c |= ((b >> 40) & 0xff) << 16;
    c |= ((b >> 48) & 0xff) << 8;
    c |= ((b >> 56) & 0xff);
    return c;
  }
  
  use SysCTypes;
  extern proc siphash(i:c_ptr(uint(8)), inlen:size_t, k:c_ptr(uint(8)), o:c_void_ptr, outlen: size_t): c_int;

  proc sipHash64(msg: [] uint(8), D, k: [?kD] uint(8)): uint(64) throws {
    var res = computeSipHash(msg, D, k, 8);
    return res[1];
  }

  proc sipHash128(msg: [] uint(8), D, k: [?kD] uint(8)): 2*uint(64) throws {
    var res: 2*uint(64);
    siphash(c_ptrTo(msg[D.low]), D.size:size_t, c_ptrTo(k[kD.low]), c_ptrTo(res[1]), 16:size_t);
    return res;
  }
  
  private proc computeSipHash(msg: [] uint(8), D,  k: [?kD] uint(8), param outlen: int) throws {
    if !((outlen == 8) || (outlen == 16)) {
      throw new owned ArgumentError();
    }
    if (kD.size != 16) {
      throw new owned ArgumentError();
    }
    var v0 = 0x736f6d6570736575: uint(64);
    var v1 = 0x646f72616e646f6d: uint(64);
    var v2 = 0x6c7967656e657261: uint(64);
    var v3 = 0x7465646279746573: uint(64);
    const k0 = U8TO64_LE(k, kD.low..#8);
    const k1 = U8TO64_LE(k, kD.low+8..#8);
    var m: uint(64);
    var i: int;
    const lastPos = D.low + D.size - (D.size % 8);
    // const uint8_t *end = in + inlen - (inlen % sizeof(uint64_t));
    const left: int = D.size & 7;
    // const int left = inlen & 7;
    var b: uint(64) = (D.size: uint(64)) << 56;
    v3 ^= k1;
    v2 ^= k0;
    v1 ^= k1;
    v0 ^= k0;
    
    if (outlen == 16) {
      v1 ^= 0xee;
    }
    
    inline proc SIPROUND() {
        v0 += v1;
        v1 = ROTL(v1, 13);
        v1 ^= v0;
        v0 = ROTL(v0, 32);
        v2 += v3;
        v3 = ROTL(v3, 16);
        v3 ^= v2;
        v0 += v3;
        v3 = ROTL(v3, 21);
        v3 ^= v0;
        v2 += v1;
        v1 = ROTL(v1, 17);
        v1 ^= v2;
        v2 = ROTL(v2, 32);
    }

    inline proc TRACE() throws {
      if DEBUG {
        writeln("%i v0 %016xu".format(msg.size, v0));
        writeln("%i v1 %016xu".format(msg.size, v1));
        writeln("%i v2 %016xu".format(msg.size, v2));
        writeln("%i v3 %016xu".format(msg.size, v3));
      }
    }

    for pos in D.low..lastPos-1 by 8 {
        m = U8TO64_LE(msg, pos..#8);
        v3 ^= m;
        TRACE();
        for i in 0..#cROUNDS {
          SIPROUND();
        }

        v0 ^= m;
    }

    if (left == 7) {
        b |= (msg[lastPos+6]: uint(64)) << 48;
}
    if (left >= 6) {
        b |= (msg[lastPos+5]: uint(64)) << 40;
    }
    if (left >= 5) {
        b |= (msg[lastPos+4]: uint(64)) << 32;
}
    if (left >= 4) {
        b |= (msg[lastPos+3]: uint(64)) << 24;
}
    if (left >= 3) {
        b |= (msg[lastPos+2]: uint(64)) << 16;
}
    if (left >= 2) {
        b |= (msg[lastPos+1]: uint(64)) << 8;
}
    if (left >= 1) {
        b |= (msg[lastPos]: uint(64));
        }

    v3 ^= b;

    TRACE();
    for i in 0..#cROUNDS {
      SIPROUND();
    }

    v0 ^= b;

    if (outlen == 16) {
      v2 ^= 0xee;
    } else {
      v2 ^= 0xff;
    }

    TRACE();
    for i in 0..#dROUNDS {
      SIPROUND();
    }

    b = v0 ^ v1 ^ v2 ^ v3;
    var res: 2*uint(64);
    res[1] = byte_reverse(b);

    if (outlen == 8) {
        return res;
    }

    v1 ^= 0xdd;

    TRACE();
    for i in 0..#dROUNDS {
      SIPROUND();
    }
    
    b = v0 ^ v1 ^ v2 ^ v3;
    res[2] = byte_reverse(b);

    return res;
  }
}
