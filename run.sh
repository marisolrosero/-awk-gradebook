#!/usr/bin/env bash

file="${1:-Lab03-data.csv}"

awk -f student_grades.awk "$file" | {
  head -n 1
  tail -n +2 | sort
}