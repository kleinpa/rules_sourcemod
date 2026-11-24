#pragma semicolon 1
#pragma newdecls required

#include <spshell>
#include <mylib/math_util>

#if !defined ENABLE_BONUS
 #error "expected ENABLE_BONUS define"
#endif

enum struct Vec2 {
    float x;
    float y;

    float Dot(Vec2 other) {
        return this.x * other.x + this.y * other.y;
    }
}

static int Fibonacci(int n) {
    if (n <= 1) {
        return n;
    }
    return Fibonacci(n - 1) + Fibonacci(n - 2);
}

static void ReverseInPlace(char[] buf, int len) {
    for (int i = 0, j = len - 1; i < j; i++, j--) {
        char tmp = buf[i];
        buf[i] = buf[j];
        buf[j] = tmp;
    }
}

public int main() {
    assert_eq(Fibonacci(10), 55);
    assert_eq(ClampInt(99, 0, 20) + EXTRA_OFFSET, 25);

    Vec2 a;
    a.x = 3.0;
    a.y = 4.0;
    assert_true(a.Dot(a) == 25.0, "3^2 + 4^2 == 25");
    assert_false(a.Dot(a) < 0.0, "dot product is non-negative");

    char word[] = "nodraw";
    ReverseInPlace(word, 6);
    assert_streq(word, "wardon");

    int[] squares = new int[5];
    for (int i = 0; i < 5; i++) {
        squares[i] = i * i;
    }
    assert_eq(squares[4], 16);

    return 0;
}
