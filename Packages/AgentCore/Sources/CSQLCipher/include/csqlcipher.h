// Vstupní hlavička modulu: zajistí, že jsou viditelná SQLCipher API (sqlite3_key, sqlite3_rekey).
#ifndef CSQLCIPHER_H
#define CSQLCIPHER_H
#ifndef SQLITE_HAS_CODEC
#define SQLITE_HAS_CODEC 1
#endif
#include "sqlite3.h"
#endif
