# Name: Ashley Espinoza
# Course: Introduction to Unix
# File: student_grades.awk
# Purpose: Calculate weighted percentage and letter grade for each student.

BEGIN {
  FS = ","
  printf "%-10s %7s %s\n", "Name", "Percent", "Letter"
}

NR > 1 {
  earned[$1] += $4
  possible[$1] += $5
}

END {
  for (student in earned) {
    percent = 100 * earned[student] / possible[student]

    if (percent >= 90) {
      letter = "A"
    } else if (percent >= 80) {
      letter = "B"
    } else if (percent >= 70) {
      letter = "C"
    } else if (percent >= 60) {
      letter = "D"
    } else {
      letter = "E"
    }

    printf "%-10s %7.2f %s\n", student, percent, letter
  }
}