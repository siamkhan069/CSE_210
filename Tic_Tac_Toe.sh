#!/usr/bin/env bash
# =============================================================================
#  Tic_Tac_Toe.sh - Tic Tac Toe game written entirely in Bash (Linux)
# =============================================================================
#  This single file IS the whole project. No .c / .cpp / .py files and no
#  compiler are needed - only Bash, which every Linux system already has.
#
#  Features:
#    - Two-player X / O game on a 3x3 board
#    - Win detection and "smart draw" detection (a draw is declared as soon
#      as neither player can win any more, even before the board is full)
#    - Input validation (letters, empty input, out-of-range numbers, and
#      already-taken cells are all handled)
#    - Menu using case/esac (the shell version of switch-case)
#    - while / for loops, if-else, break and continue
#    - Persistent scoreboard stored in a file (scores.txt)
#
#  How to run:
#    Terminal     : ./Tic_Tac_Toe.sh        (or: bash Tic_Tac_Toe.sh)
#    Double-click : do the one-time setup below, then double-click the file.
#
#  One-time setup for double-click:
#    1. chmod +x Tic_Tac_Toe.sh             (make the file executable)
#    2. In your file manager choose "Run" for executable text files:
#         Nautilus (GNOME)      : Preferences -> Behavior -> Executable Text
#                                 Files -> "Run executable text files"
#         Thunar / Nemo / PCManFM: right-click -> Properties -> Permissions ->
#                                 tick "Allow executing file as program"
#
#  Useful Unix commands to demonstrate in your OS course:
#    pwd                      show the current directory
#    ls -l                    list files with permissions and size
#    cat Tic_Tac_Toe.sh       view this source code
#    chmod +x Tic_Tac_Toe.sh  make the script executable
#    ./Tic_Tac_Toe.sh         run the game
#    cat scores.txt           view the saved scores (after a game)
#    rm scores.txt            reset the scoreboard
# =============================================================================

# -----------------------------------------------------------------------------
# Step 0: Find where this script lives and move into that folder.
#   readlink -f turns $0 into a full absolute path, dirname removes the file
#   name, and cd moves there so scores.txt is always saved next to the script.
# -----------------------------------------------------------------------------
SELF="$(readlink -f "$0")"
DIR="$(dirname "$SELF")"
cd "$DIR" || { echo "Cannot enter folder: $DIR"; exit 1; }

# -----------------------------------------------------------------------------
# Step 1: Make sure we are running inside a terminal.
#   "-t 0" is true when standard input is a terminal. On a double-click there
#   is no terminal, so we open one and run this same script inside it.
#   TTT_IN_TERM is a flag that prevents an endless relaunch loop.
# -----------------------------------------------------------------------------
if [ ! -t 0 ] && [ -z "$TTT_IN_TERM" ]; then
    export TTT_IN_TERM=1
    for term in gnome-terminal x-terminal-emulator konsole xfce4-terminal \
                mate-terminal lxterminal tilix xterm; do
        if command -v "$term" >/dev/null 2>&1; then
            case "$term" in
                gnome-terminal) exec gnome-terminal -- bash "$SELF" ;;
                *)              exec "$term" -e bash "$SELF" ;;
            esac
        fi
    done
    exit 1   # No terminal emulator found.
fi

# -----------------------------------------------------------------------------
# Global variables
# -----------------------------------------------------------------------------
SCORE_FILE="$DIR/scores.txt"   # File where the scoreboard is saved
board=()                       # The 9 cells of the board (index 0..8)
x_wins=0                       # Number of games won by X
o_wins=0                       # Number of games won by O
draws=0                        # Number of drawn games

# All 8 winning lines (3 rows, 3 columns, 2 diagonals) as cell indexes.
WIN_LINES=("0 1 2" "3 4 5" "6 7 8" "0 3 6" "1 4 7" "2 5 8" "0 4 8" "2 4 6")

# -----------------------------------------------------------------------------
# pause_and_exit: keep the window open after a double-click launch so the
# last messages can be read, then exit with the given status (default 0).
# -----------------------------------------------------------------------------
pause_and_exit() {
    if [ -n "$TTT_IN_TERM" ]; then
        echo
        printf "Press Enter to close this window..."
        read -r _
    fi
    exit "${1:-0}"
}

# -----------------------------------------------------------------------------
# load_scores: read "xWins oWins draws" from scores.txt (file handling: input).
# Only plain numbers are accepted, so a damaged file cannot break the game.
# -----------------------------------------------------------------------------
load_scores() {
    if [ -f "$SCORE_FILE" ]; then
        local x o d
        read -r x o d < "$SCORE_FILE"
        [[ $x =~ ^[0-9]+$ ]] && x_wins=$x
        [[ $o =~ ^[0-9]+$ ]] && o_wins=$o
        [[ $d =~ ^[0-9]+$ ]] && draws=$d
    fi
}

# -----------------------------------------------------------------------------
# save_scores: write "xWins oWins draws" to scores.txt (file handling: output).
# -----------------------------------------------------------------------------
save_scores() {
    echo "$x_wins $o_wins $draws" > "$SCORE_FILE" 2>/dev/null
}

# -----------------------------------------------------------------------------
# reset_board: fill the board with the numbers 1..9 (the cell labels).
# -----------------------------------------------------------------------------
reset_board() {
    local i
    for (( i = 0; i < 9; i++ )); do
        board[i]=$(( i + 1 ))
    done
}

# -----------------------------------------------------------------------------
# show_board: print the 3x3 board.
# -----------------------------------------------------------------------------
show_board() {
    echo
    echo "       TIC TAC TOE"
    echo
    local i
    for (( i = 0; i < 9; i++ )); do
        printf "  %s  " "${board[i]}"
        if (( i % 3 != 2 )); then
            printf "|"
        fi
        if (( i % 3 == 2 && i != 8 )); then
            printf "\n-----+-----+-----\n"
        fi
    done
    printf "\n\n"
}

# -----------------------------------------------------------------------------
# check_win MARK: returns 0 (true) if MARK ("X" or "O") fills any winning line.
# -----------------------------------------------------------------------------
check_win() {
    local mark=$1 line a b c
    for line in "${WIN_LINES[@]}"; do
        read -r a b c <<< "$line"
        if [[ ${board[a]} == "$mark" && ${board[b]} == "$mark" && ${board[c]} == "$mark" ]]; then
            return 0
        fi
    done
    return 1
}

# -----------------------------------------------------------------------------
# can_still_win PLAYER: returns 0 (true) if PLAYER could still complete some
# line, i.e. there is at least one line that contains no opponent mark.
# -----------------------------------------------------------------------------
can_still_win() {
    local player=$1 opponent line a b c
    if [[ $player == "X" ]]; then opponent="O"; else opponent="X"; fi
    for line in "${WIN_LINES[@]}"; do
        read -r a b c <<< "$line"
        if [[ ${board[a]} != "$opponent" && ${board[b]} != "$opponent" && ${board[c]} != "$opponent" ]]; then
            return 0
        fi
    done
    return 1
}

# -----------------------------------------------------------------------------
# is_draw: "smart draw" - true when nobody can win any more, even if the
# board still has empty cells.
# -----------------------------------------------------------------------------
is_draw() {
    ! can_still_win "X" && ! can_still_win "O"
}

# -----------------------------------------------------------------------------
# play_game: play one full game between player X and player O.
# -----------------------------------------------------------------------------
play_game() {
    reset_board
    local player="X"
    local input position

    while true; do
        show_board
        printf "Player %s, choose (1-9): " "$player"

        # Read one line. If input ends (Ctrl+D), save and leave the program.
        if ! read -r input; then
            echo
            save_scores
            exit 0
        fi

        # Input validation 1: must be a whole number.
        if [[ ! $input =~ ^[0-9]+$ ]]; then
            echo "Invalid input! Enter a number."
            continue
        fi

        # Input validation 2: must be between 1 and 9.
        # (More than 3 digits is always out of range; this also avoids
        #  arithmetic overflow and octal problems with numbers like 09.)
        if (( ${#input} > 3 )); then
            echo "Choose a position from 1 to 9."
            continue
        fi
        position=$(( 10#$input ))
        if (( position < 1 || position > 9 )); then
            echo "Choose a position from 1 to 9."
            continue
        fi

        # Input validation 3: the cell must not be taken already.
        if [[ ${board[position-1]} == "X" || ${board[position-1]} == "O" ]]; then
            echo "Position already taken. Try again."
            continue
        fi

        # Place the player's mark on the board.
        board[position-1]=$player

        # Did this move win the game?
        if check_win "$player"; then
            show_board
            echo "Player $player wins!"
            if [[ $player == "X" ]]; then
                x_wins=$(( x_wins + 1 ))
            else
                o_wins=$(( o_wins + 1 ))
            fi
            break
        fi

        # Is the game a draw (nobody can win any more)?
        if is_draw; then
            show_board
            echo "Match Draw! No player can win anymore."
            draws=$(( draws + 1 ))
            break
        fi

        # Switch to the other player.
        if [[ $player == "X" ]]; then player="O"; else player="X"; fi
    done

    save_scores
}

# -----------------------------------------------------------------------------
# show_scores: print the scoreboard.
# -----------------------------------------------------------------------------
show_scores() {
    echo
    echo "--- SCOREBOARD ---"
    echo "X Wins: $x_wins"
    echo "O Wins: $o_wins"
    echo "Draws : $draws"
}

# -----------------------------------------------------------------------------
# main: load scores, then show the menu until the user chooses Exit.
# -----------------------------------------------------------------------------
main() {
    load_scores
    local choice

    while true; do
        echo
        echo "===== TIC TAC TOE ====="
        echo "1. Start Game"
        echo "2. View Scoreboard"
        echo "3. Exit"
        printf "Enter choice: "

        # If input ends (Ctrl+D), save and leave.
        if ! read -r choice; then
            echo
            save_scores
            exit 0
        fi

        # Menu using case/esac (the shell's switch-case).
        case "$choice" in
            1)
                play_game
                ;;
            2)
                show_scores
                ;;
            3)
                save_scores
                echo "Thanks for playing!"
                pause_and_exit 0
                ;;
            *)
                echo "Invalid choice. Select 1, 2, or 3."
                ;;
        esac
    done
}

main
