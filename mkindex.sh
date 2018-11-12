#!/bin/bash

path=manuscript

find manuscript -iname "*.md" -printf "%P\n" | sort > ${path}/Book.txt