#include "llama-grammar.h"
#include "unicode.h"
#include <cstdio>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>

static bool match(const std::string & input, llama_grammar * g) {
    auto & stacks = llama_grammar_get_stacks(g);
    size_t off = 0;
    while (off < input.size()) {
        uint32_t cpt = unicode_cpt_from_utf8(input, off);
        try { llama_grammar_accept_token(*g, 0, unicode_cpt_to_utf8(cpt)); } catch (...) { return false; }
        if (stacks.empty()) return false;
    }
    for (auto & s : stacks) if (s.empty()) return true;
    return false;
}

int main(int argc, char ** argv) {
    std::ifstream f(argv[1]); std::stringstream ss; ss << f.rdbuf();
    std::string gs = ss.str();
    llama_grammar * g = llama_grammar_init_impl(nullptr, gs.c_str(), "root", false, nullptr, 0, nullptr, 0);
    if (!g) { printf("GRAMMAR PARSE FAILED: %s\n", argv[1]); return 1; }
    auto orig = llama_grammar_get_stacks(g);
    int fails = 0;
    for (int i = 2; i < argc; i++) {
        std::string s = argv[i];
        bool expect = s[0] == '+';
        s = s.substr(1);
        llama_grammar_get_stacks(g) = orig;
        bool m = match(s, g);
        printf("%s %s %s\n", m == expect ? "OK  " : "FAIL", expect ? "accept" : "reject", s.c_str());
        if (m != expect) fails++;
    }
    return fails;
}
