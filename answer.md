# answers.md

## Task 1

Command:
awk -F',' 'NR>1{c++} END{print c}' Lab03-data.csv

Result:
322

Explanation:
This command skips the header and counts all remaining rows.

## Task 2

Command:
awk -F',' 'NR>1 && !seen[$1]++{n++} END{print n}' Lab03-data.csv

Result:
14

Explanation:
This command uses an array to count each student only once.

## Task 3

Command:
awk -F',' '$3=="FINAL"{printf "%-10s %3d\n",$1,$4}' Lab03-data.csv

Result:
The command prints each student with the FINAL score.

Explanation:
This command filters rows where the assignment field is FINAL and prints the student name and score.

## Task 4

Command:
awk -F',' 'NR>1 && $4 < 0.6*$5 {c++} END{print c}' Lab03-data.csv

Result:
50

Explanation:
This command counts rows where the score is less than 60 percent of the maximum score.

## Task 5

Command:
awk -f assignment_report.awk Lab03-data.csv

Result:
The command prints the low, high, and average score for each assignment.

Explanation:
This script uses arrays to calculate the low, high, and average score by assignment.

## Task 6

Command:
awk -f student_grades.awk Lab03-data.csv

Result:
The command prints each student's weighted percent and letter grade.

Explanation:
This script calculates weighted percent using total earned points divided by total possible points.

## Task 7

Command:
./run.sh Lab03-data.csv

Result:
The command prints the Task 6 report sorted by student name.

Explanation:
This Bash script runs the Task 6 AWK script and sorts the student rows while keeping the header on top.