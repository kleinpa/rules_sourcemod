/**
 * Standalone SourcePawn VM (`spshell`) `<float>` bindings.
 *
 * `spcomp` implicitly injects `#tryinclude <float>` before line 1 of every `.sp`
 * file. SourceMod's `plugins/include/float.inc` binds operators to `smn_float.cpp`
 * (`__FLOAT_MUL__`), whereas `spshell` installs the standalone VM's `builtins.cpp`
 * (`__float_mul`). Placed ahead of `stdlib_includes` on `sourcemod_test` targets.
 */

#if defined _float_included
 #endinput
#endif
#define _float_included

#if !defined __sourcepawn2__
native float __float_ctor(int value);
native float __float_mul(float a, float b);
native float __float_div(float a, float b);
native float __float_mod(float a, float b);
native float __float_add(float a, float b);
native float __float_sub(float a, float b);
native bool __float_gt(float a, float b);
native bool __float_ge(float a, float b);
native bool __float_lt(float a, float b);
native bool __float_le(float a, float b);
native bool __float_eq(float a, float b);
native bool __float_ne(float a, float b);
native bool __float_not(float a);

stock float float(int value) { return __float_ctor(value); }

stock float operator*(float a, float b) { return __float_mul(a, b); }
stock float operator/(float a, float b) { return __float_div(a, b); }
stock float operator+(float a, float b) { return __float_add(a, b); }
stock float operator-(float a, float b) { return __float_sub(a, b); }
stock float operator%(float a, float b) { return __float_mod(a, b); }
stock bool operator!(float a) { return __float_not(a); }
stock bool operator>(float a, float b) { return __float_gt(a, b); }
stock bool operator>=(float a, float b) { return __float_ge(a, b); }
stock bool operator<(float a, float b) { return __float_lt(a, b); }
stock bool operator<=(float a, float b) { return __float_le(a, b); }
stock bool operator!=(float a, float b) { return __float_ne(a, b); }
stock bool operator==(float a, float b) { return __float_eq(a, b); }

stock float operator++(float a) { return a + 1.0; }
stock float operator--(float a) { return a - 1.0; }
stock float operator-(float a) { return a ^ view_as<float>(cellmin); }

stock float operator*(float a, int b) { return __float_mul(a, float(b)); }
stock float operator/(float a, int b) { return __float_div(a, float(b)); }
stock float operator/(int a, float b) { return __float_div(float(a), b); }
stock float operator+(float a, int b) { return __float_add(a, float(b)); }
stock float operator-(float a, int b) { return __float_sub(a, float(b)); }
stock float operator-(int a, float b) { return __float_sub(float(a), b); }
stock float operator%(float a, int b) { return __float_mod(a, float(b)); }
stock float operator%(int a, float b) { return __float_mod(float(a), b); }
stock bool operator==(float a, int b) { return __float_eq(a, float(b)); }
stock bool operator!=(float a, int b) { return __float_ne(a, float(b)); }
stock bool operator>(float a, int b) { return __float_gt(a, float(b)); }
stock bool operator>(int a, float b) { return __float_gt(float(a), b); }
stock bool operator>=(float a, int b) { return __float_ge(a, float(b)); }
stock bool operator>=(int a, float b) { return __float_ge(float(a), b); }
stock bool operator<(float a, int b) { return __float_lt(a, float(b)); }
stock bool operator<(int a, float b) { return __float_lt(float(a), b); }
stock bool operator<=(float a, int b) { return __float_le(a, float(b)); }
stock bool operator<=(int a, float b) { return __float_le(float(a), b); }
#endif

#define FLOAT_PI 3.1415926535897932384626433832795
stock float DegToRad(float angle) { return (angle * FLOAT_PI) / 180; }
stock float RadToDeg(float angle) { return (angle * 180) / FLOAT_PI; }
