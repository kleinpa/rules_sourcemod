#if defined _mylib_math_util_included
 #endinput
#endif
#define _mylib_math_util_included

stock int ClampInt(int value, int lo, int hi) {
    if (value < lo) {
        return lo;
    }
    if (value > hi) {
        return hi;
    }
    return value;
}
