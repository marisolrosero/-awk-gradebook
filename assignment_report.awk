# Name: Ashley Espinoza
# Course: Introduction to Unix
# File: assignment_report.awk
# Purpose: Create a report by assignment with low, high, and average score.

BEGIN {
  FS = ","
  printf "%-8s %5s %5s %9s\n", "Name", "Low", "High", "Average"
}

NR > 1 {
  assignment = $3
  score = $4 + 0

  total[assignment] += score
  count[assignment]++

  if (!(assignment in low) || score < low[assignment]) {
    low[assignment] = score
  }

  if (!(assignment in high) || score > high[assignment]) {
    high[assignment] = score
  }
}

END {
  for (assignment in total) {
    printf "%-8s %5d %5d %9.2f\n", assignment, low[assignment], high[assignment], total[assignment] / count[assignment]
  }
}