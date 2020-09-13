#!/bin/sh
gcc -g -std=c99 -O3 -march=native tools/vaporize.c -o tools/vaporize -lm
