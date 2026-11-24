/**
 * Standalone SourcePawn VM (`spshell`) natives and assertion helpers for `sourcemod_test`.
 *
 * Tests run in SourcePawn's standalone VM (`public int main()` or `public void main()`),
 * without `srcds` or SourceMod engine natives. Any failed assertion or unhandled VM
 * error prints a line-numbered stack trace and exits non-zero.
 */

#if defined _spshell_included
 #endinput
#endif
#define _spshell_included

#include <float>
#include <handles>

native void print(const char[] str);
native void printf(const char[] fmt, any ...);
native void printnum(int n);
native void writenum(int n);
native void printnums(any ...);
native void printfloat(float n);
native void writefloat(float n);
native void dump_stack_trace();
native void report_error();
native void assert_eq(any actual, any expected);

stock void assert_true(bool cond, const char[] message = "expected true")
{
    if (!cond)
    {
        printf("ASSERT FAILED: %s\n", message);
        assert_eq(cond, true);
    }
}

stock void assert_false(bool cond, const char[] message = "expected false")
{
    if (cond)
    {
        printf("ASSERT FAILED: %s\n", message);
        assert_eq(cond, false);
    }
}

stock void assert_streq(const char[] actual, const char[] expected)
{
    int i = 0;
    while (actual[i] != '\0' && expected[i] != '\0')
    {
        if (actual[i] != expected[i])
        {
            printf("ASSERT FAILED: expected \"%s\", got \"%s\"\n", expected, actual);
            assert_eq(actual[i], expected[i]);
            return;
        }
        i++;
    }
    if (actual[i] != expected[i])
    {
        printf("ASSERT FAILED: expected \"%s\", got \"%s\"\n", expected, actual);
        assert_eq(actual[i], expected[i]);
    }
}
