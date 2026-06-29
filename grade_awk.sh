#!/usr/bin/env bash
# =============================================================================
# grade_awk.sh  --  Autograder for "Reports with AWK on a Gradebook File"
# Total: 4.00 points.  Clones each student's Codeberg repo, runs the commands
# from their answers.md against YOUR reference Lab03-data.csv, scores the rubric
# and PRINTS THE DEDUCTIONS (why each point was lost).
#
# Usage:
#   ./grade_awk.sh [options] <student> [<student> ...]
#   ./grade_awk.sh --csv grades.csv -f students.txt
#
# A <student> can be a repo URL, user/repo, a bare username (-> awk-gradebook),
# or a local directory. Options: --ref FILE  --csv FILE  --reponame NAME  -f FILE
#
# SECURITY: runs commands taken from each answers.md. Use a throwaway VM/container
#           for untrusted repos. 20s timeout per command.
# =============================================================================
set -u

REPONAME="awk-gradebook"; DATA_NAME="Lab03-data.csv"
REF=""; CSV=""; STUDENTS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --ref)      REF="$2"; shift 2;;
    --csv)      CSV="$2"; shift 2;;
    --reponame) REPONAME="$2"; shift 2;;
    -f|--file)  while IFS= read -r ln; do ln="${ln%%#*}"; ln="$(echo "$ln" | xargs)"; [ -n "$ln" ] && STUDENTS+=("$ln"); done < "$2"; shift 2;;
    -h|--help)  sed -n '2,24p' "$0"; exit 0;;
    *)          STUDENTS+=("$1"); shift;;
  esac
done
: "${REF:=$(cd "$(dirname "$0")" && pwd)/$DATA_NAME}"
[ "${#STUDENTS[@]}" -gt 0 ] || { echo "no students given (see --help)"; exit 1; }
[ -f "$REF" ] || { echo "ERROR: reference $DATA_NAME not found at: $REF"; exit 1; }

TMPDIRS=(); cleanup(){ for d in "${TMPDIRS[@]:-}"; do [ -n "$d" ] && rm -rf "$d"; done; }
trap cleanup EXIT

# ---- expected answers (computed once from YOUR reference data) -------------
A1=$(awk -F',' 'NR>1{c++} END{print c}' "$REF")
A2=$(awk -F',' 'NR>1 && !seen[$1]++{n++} END{print n}' "$REF")
A3=$(awk -F',' '$3=="FINAL"{printf "%-10s %3d\n",$1,$4}' "$REF")
A4=$(awk -F',' 'NR>1 && $4 < 0.6*$5 {c++} END{print c}' "$REF")
A5=$(awk -F',' '
  NR>1{ s[$3]+=$4; n[$3]++
    if(!($3 in lo)||$4<lo[$3]) lo[$3]=$4
    if(!($3 in hi)||$4>hi[$3]) hi[$3]=$4 }
  END{ printf "%-8s %5s %5s %9s\n","Name","Low","High","Average"
    for(a in s) printf "%-8s %5d %5d %9.2f\n",a,lo[a],hi[a],s[a]/n[a] }' "$REF")
A6=$(awk -F',' '
  NR>1{ earned[$1]+=$4; poss[$1]+=$5 }
  END{ printf "%-10s %7s %s\n","Name","Percent","Letter"
    for(st in earned){ p=100*earned[st]/poss[st]
      if(p>=90)g="A";else if(p>=80)g="B";else if(p>=70)g="C";else if(p>=60)g="D";else g="E"
      printf "%-10s %7.2f %s\n",st,p,g } }' "$REF")
A7="$A6"
EXP=( "" "$A1" "$A2" "$A3" "$A4" "$A5" "$A6" "$A7" )
SORTED=" 3 5 6 7 "; SCALAR=" 1 2 4 "
HINT=( "" \
 "skip the header (NR>1) and count rows" \
 "use an array as a set so each student counts once" \
 "filter \$3==\"FINAL\" and printf aligned columns" \
 "a row fails when score < 60% of its own max (\$4 < 0.6*\$5)" \
 "per-assignment low/high/average using arrays" \
 "weighted % = sum(\$4)/sum(\$5)*100 with a letter grade" \
 "run.sh must run your Task 6 .awk, sorted, header on top" )

# ---- helpers ---------------------------------------------------------------
norm(){ sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//' | grep -vE '^[[:space:]]*$'; }
nsort(){ norm | LC_ALL=C sort; }
add(){ awk -v a="$1" -v b="$2" 'BEGIN{printf "%.2f", a+b}'; }
sub2(){ awk -v a="$1" -v b="$2" 'BEGIN{d=a-b; if(d<0)d=0; printf "%.2f", d}'; }

extract_cmd(){
  [ -f "$ANS" ] || return 0
  awk -v t="$1" '
    function ishdr(s){ return (s ~ /^#{2,}[[:space:]]+[Tt]ask[[:space:]]+[0-9]+/) }
    { if (ishdr($0)) {
        if ($0 ~ "^#{2,}[[:space:]]+[Tt]ask[[:space:]]+"t"([^0-9]|$)") {intask=1;incmd=0}
        else {intask=0;incmd=0}; next }
      if (!intask) next
      if ($0 ~ /^[[:space:]]*```/) next
      if ($0 ~ /^[[:space:]]*Command:/){incmd=1; l=$0
           sub(/^[[:space:]]*Command:[[:space:]]*/,"",l); if(l!="")print l; next}
      if ($0 ~ /^[[:space:]]*Result:/ || $0 ~ /^[[:space:]]*Explanation:/){incmd=0; next}
      if (incmd){ sub(/^    /,""); print }
    }' "$ANS"
}
get_block(){
  [ -f "$ANS" ] || return 0
  awk -v t="$1" '
    function ishdr(s){ return (s ~ /^#{2,}[[:space:]]+[Tt]ask[[:space:]]+[0-9]+/) }
    { if (ishdr($0)){ p = ($0 ~ "^#{2,}[[:space:]]+[Tt]ask[[:space:]]+"t"([^0-9]|$)") ? 1 : 0; next }
      if (p) print }' "$ANS"
}
run_cmd(){ printf '%s\n' "$1" > "$WORK/.studentcmd.sh"; ( cd "$WORK" && timeout 20 bash .studentcmd.sh ) 2>/dev/null; }

resolve(){
  local a="$1" url t
  if [ -d "$a" ] && { [ -e "$a/.git" ] || [ -f "$a/answers.md" ]; }; then REPO="$a"; SRC="$a"; return 0; fi
  case "$a" in
    http://*|https://*|git@*|file://*) url="$a";;
    */*)                      url="https://codeberg.org/$a";;
    *)                        url="https://codeberg.org/$a/$REPONAME";;
  esac
  t="$(mktemp -d)"; TMPDIRS+=("$t"); SRC="$url"
  if git clone --quiet "$url" "$t/repo" 2>/dev/null; then REPO="$t/repo"; return 0
  else REPO=""; return 1; fi
}
sid_of(){ local a="${1%/}"; if [ -d "$a" ]; then basename "$a"; return; fi
  case "$a" in file://*) basename "$a";; http*|git@*) echo "$a" | awk -F/ '{print $(NF-1)}';; */*) echo "${a%%/*}";; *) basename "$a";; esac; }

# =============================== grade one ==================================
grade_one(){
  local STU="$1" sid; sid="$(sid_of "$STU")"
  if ! resolve "$STU"; then
    printf '============================================================\n'
    printf 'STUDENT: %s   SOURCE: %s   TOTAL: 0.00/4.00\n' "$sid" "$SRC"
    printf 'DEDUCTIONS:\n  - could not clone the repository (-4.00). Check the URL/visibility.\n'
    printf '============================================================\n\n'
    [ -n "$CSV" ] && echo "$sid,0.00,0,0,0,0,0,0,0,0,0,0" >> "$CSV"
    return
  fi
  ANS="$REPO/answers.md"
  WORK="$(mktemp -d)"; TMPDIRS+=("$WORK")
  cp -r "$REPO"/. "$WORK"/ 2>/dev/null || true
  cp -f "$REF" "$WORK/$DATA_NAME"
  chmod +x "$WORK"/*.sh 2>/dev/null || true

  local TOTAL=0.00; local -a ROWS=(); local -a DED=(); local -a TPTS=()

  # 1) task correctness (7 x 0.40)
  local t cmd exp got g e pts
  for t in 1 2 3 4 5 6 7; do
    cmd="$(extract_cmd "$t")"; exp="${EXP[$t]}"
    if [ -n "$cmd" ]; then
      got="$(run_cmd "$cmd")"
      if [[ "$SORTED" == *" $t "* ]]; then
        g="$(printf '%s\n' "$got" | nsort)"; e="$(printf '%s\n' "$exp" | nsort)"
      else
        g="$(printf '%s\n' "$got" | norm)"; e="$(printf '%s\n' "$exp" | norm)"
      fi
      if [ -n "$e" ] && [ "$g" = "$e" ]; then
        pts=0.40
      else
        pts=0.20
        if [[ "$SCALAR" == *" $t "* ]]; then
          DED+=("Task $t: -0.20 - your program returned '${g:-<empty>}' but the expected answer is '$e' (${HINT[$t]}).")
        else
          DED+=("Task $t: -0.20 - the produced table does not match the expected values (${HINT[$t]}).")
        fi
      fi
    else
      if [[ "$SCALAR" == *" $t "* ]] && get_block "$t" | grep -qF "$exp" 2>/dev/null; then
        pts=0.20; DED+=("Task $t: -0.20 - you reported the result but no runnable command was found to verify it.")
      else
        pts=0.00; DED+=("Task $t: -0.40 - no command/answer found (${HINT[$t]}).")
      fi
    fi
    ROWS+=("Task $t correctness|$pts|0.40")
    TPTS+=("$pts"); TOTAL=$(add "$TOTAL" "$pts")
  done

  # 2) documentation (0.60)
  local doc=0 missing="" b
  for t in 1 2 3 4 5 6 7; do
    cmd="$(extract_cmd "$t")"; b="$(get_block "$t")"
    if [ -n "$cmd" ] && grep -qiE 'Result:' <<<"$b" && grep -qiE 'Explanation:' <<<"$b"; then doc=$((doc+1))
    else missing="$missing $t"; fi
  done
  local docpts; docpts=$(awk -v d="$doc" 'BEGIN{printf "%.2f", 0.60*d/7}')
  ROWS+=("Documentation (answers.md)|$docpts|0.60")
  [ "$doc" -lt 7 ] && DED+=("Documentation: -$(sub2 0.60 "$docpts") - task(s)$missing lack command + result + explanation.")
  TOTAL=$(add "$TOTAL" "$docpts")

  # 3) repository & commits (0.40)   [README + .awk + run.sh expected; no literal task-N]
  local nc=0 hasR=0 hasA=0 hasK=0 hasS=0
  [ -f "$REPO/README.md" ] && hasR=1
  [ -f "$ANS" ] && hasA=1
  ls "$REPO"/*.awk >/dev/null 2>&1 && hasK=1
  [ -f "$REPO/run.sh" ] && hasS=1
  if git -C "$REPO" rev-parse --git-dir >/dev/null 2>&1; then nc=$(git -C "$REPO" rev-list --count HEAD 2>/dev/null || echo 0); fi
  local reppts; reppts=$(awk -v n="$nc" -v r="$hasR" -v k="$hasK" -v s="$hasS" 'BEGIN{
      c = (n>=7?0.18:(n>=4?0.12:(n>=2?0.06:0)))
      p = c + 0.08*r + 0.07*k + 0.07*s; if(p>0.40)p=0.40; printf "%.2f",p }')
  ROWS+=("Repository & commits|$reppts|0.40")
  if [ "$(awk -v p="$reppts" 'BEGIN{print (p<0.40)?1:0}')" = 1 ]; then
    local rr="Repository: -$(sub2 0.40 "$reppts") -"
    [ "$hasR" = 0 ] && rr="$rr no README.md;"
    [ "$hasK" = 0 ] && rr="$rr no .awk script committed;"
    [ "$hasS" = 0 ] && rr="$rr no run.sh committed;"
    [ "$nc" -lt 7 ] && rr="$rr only $nc commit(s) (one per task ~7 expected, incremental);"
    DED+=("$rr")
  fi
  TOTAL=$(add "$TOTAL" "$reppts")

  # 4) awk technique (0.20)
  local allcmd catawk tech=0.00 tnote="" hdr_ok=0 n_awk=0 f first
  allcmd="$(for t in 1 2 3 4 5 6 7; do extract_cmd "$t"; done)"
  catawk="$(cat "$REPO"/*.awk 2>/dev/null)"
  for f in "$REPO"/*.awk; do
    [ -f "$f" ] || continue; n_awk=$((n_awk+1))
    first="$(grep -vE '^[[:space:]]*$' "$f" | head -1)"
    [[ "$first" =~ ^[[:space:]]*# ]] && hdr_ok=$((hdr_ok+1))
  done
  if [ "$n_awk" -gt 0 ] && [ "$hdr_ok" -eq "$n_awk" ]; then tech=$(add "$tech" 0.10)
  else tnote="$tnote .awk scripts must start with a comment header ($hdr_ok/$n_awk ok);"; fi
  if grep -qE "(-F|FS[[:space:]]*=)" <<<"$allcmd$catawk" && grep -qE 'printf' <<<"$allcmd$catawk"; then
    tech=$(add "$tech" 0.10)
  else tnote="$tnote use FS (-F or FS=) and printf;"; fi
  ROWS+=("awk technique|$tech|0.20")
  [ -n "$tnote" ] && DED+=("awk technique: -$(sub2 0.20 "$tech") -$tnote")
  TOTAL=$(add "$TOTAL" "$tech")

  # ---- print report block --------------------------------------------------
  printf '============================================================\n'
  printf 'STUDENT: %s   SOURCE: %s   TOTAL: %s/4.00\n' "$sid" "$SRC" "$TOTAL"
  printf -- '------------------------------------------------------------\n'
  printf 'CRITERION|POINTS|MAX\n'
  printf '%s\n' "${ROWS[@]}"
  printf -- '------------------------------------------------------------\n'
  printf 'DEDUCTIONS (why points were lost):\n'
  if [ "${#DED[@]}" -eq 0 ]; then printf '  None - full marks (4.00/4.00).\n'
  else printf '  - %s\n' "${DED[@]}"; fi
  printf '============================================================\n\n'

  [ -n "$CSV" ] && echo "$sid,$TOTAL,${TPTS[0]},${TPTS[1]},${TPTS[2]},${TPTS[3]},${TPTS[4]},${TPTS[5]},${TPTS[6]},$docpts,$reppts,$tech" >> "$CSV"
}

# =============================== main =======================================
if [ -n "$CSV" ]; then echo "student,total,t1,t2,t3,t4,t5,t6,t7,documentation,repository,technique" > "$CSV"; fi
for s in "${STUDENTS[@]}"; do grade_one "$s"; done
[ -n "$CSV" ] && echo "consolidated CSV written to: $CSV"
