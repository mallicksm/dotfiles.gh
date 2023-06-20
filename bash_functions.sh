#!/usr/bin/env bash
#===============================================================================
# Bash Script
# Created: May-18-2023
# Author: soummya
#
# Note:
#
# Description: basic functions for shell
#
#===============================================================================
source ~/dotfiles/utils/bash_snippets.sh 2>/dev/null
#
#-------------------------------------------------------------------------------
# Functions
#===============================================================================
#{{{ modpath
function modpath () {
   loc=$1
   cmd=${2:-"d"}
   var=${3:-PATH}
   eval PATHv=\$$var    # set PATHv to the var reference (double indirection)
   NEW_PATH=${PATHv/#"$loc:"}         #    Begining
   NEW_PATH=${NEW_PATH/#"$loc"}       #    Solo
   NEW_PATH=${NEW_PATH/%":$loc"}      #    Ending
   NEW_PATH=${NEW_PATH//":$loc:"/:}   #    Multiple middles

   if [ $cmd = "d" ]; then
      export ${var}=$NEW_PATH
   elif [ $cmd = "b" ]; then
      if [ -z $NEW_PATH ]; then
         export ${var}=$loc   # old PATH empty
      else
         export ${var}=$loc:$NEW_PATH
      fi
   elif [ $cmd = "a" ]; then
      if [ -z $NEW_PATH ]; then
         export ${var}=$loc   # old PATH empty
      else
         export ${var}=$NEW_PATH:$loc
      fi
   else
      echo "usage: modpath [location] [d elete|b efore|a fter] [VARIABLE]"
   fi
}
#}}}

#-------------------------------------------------------------------------------
#{{{ Pushd/Popd
function Pushd () {
   command pushd "$@" > /dev/null
}
# Popd (pair)
function Popd () {
   command popd "$@" > /dev/null
}
#}}}

#-------------------------------------------------------------------------------
#{{{ var
function var () {
   VAR=${1:-PATH}
   DOLLARVAR=${!VAR}
   echo -e ${DOLLARVAR//:/\\n}
}
#}}}

#-------------------------------------------------------------------------------
#{{{ xpushd/xpopd
function xpushd () {
   dir=${1:-.}
   cd $dir
   echo "pushing: $proj/.x_push_pop_stack"
   mkdir -p $proj
   echo "$PWD" > "$proj/.x_push_pop_stack"
}
# xpopd (pair)
function xpopd () {
   echo "popping: $proj/.x_push_pop_stack"
   if [[ -f $proj/.x_push_pop_stack ]]; then
      cd $(command cat "$proj/.x_push_pop_stack")
   else
      echo "Note: xpushd first"
   fi
}
#}}}

#-------------------------------------------------------------------------------
#{{{ cd/cd_up/cd_func
# cd up to n dirs
# using:  cd.. 10   cd.. dir
function cd () {
   # replace "builtin cd" with cd_func() to enable "cd with history"
   if [ -n "$1" ]; then
      # builtin cd "$@"&& ls
      cd_func "$@" && [ "$1" != "--" ]
   else
      # builtin cd ~&& ls
      cd_func ~
   fi
}

function cd_up () {
  case $1 in
    *[!0-9]*)                                          # if not a number ..
      cd $( pwd | sed -r "s|(.*/$1[^/]*/).*|\1|" )     # search dir_name in current path, if found - cd to it
      ;;                                               # if not found - not cd
    *)
      cd $(printf "%0.0s../" $(seq 1 $1));             # cd ../../../../  (N dirs)
    ;;
  esac
}
alias 'cd..'='cd_up'                                   # because can not name function 'cd..'

function cd_func () {
   local x2 the_new_dir adir index
   local -i cnt

   if [[ $1 ==  "--" ]]; then
      dirs -v
      return 0
   fi

   the_new_dir=$1
   [[ -z $1 ]] && the_new_dir=$HOME

   if [[ ${the_new_dir:0:1} == '-' ]]; then
      # Extract dir N from dirs
      index=${the_new_dir:1}
      [[ -z $index ]] && index=1
      adir=$(dirs +$index)
      [[ -z $adir ]] && return 1
      the_new_dir=$adir
   fi

   #
   # '~' has to be substituted by ${HOME}
   [[ ${the_new_dir:0:1} == '~' ]] && the_new_dir="${HOME}${the_new_dir:1}"

   #
   # Now change to the new dir and add to the top of the stack
   Pushd "${the_new_dir}"
   [[ $? -ne 0 ]] && return 1
   the_new_dir=$(pwd)

   #
   # Trim down everything beyond 11th entry
   popd -n +11 2>/dev/null 1>/dev/null

   #
   # Remove any other occurence of this dir, skipping the top of the stack
   for ((cnt=1; cnt <= 10; cnt++)); do
      x2=$(dirs +${cnt} 2>/dev/null)
      [[ $? -ne 0 ]] && return 0
      [[ ${x2:0:1} == '~' ]] && x2="${HOME}${x2:1}"
      if [[ "${x2}" == "${the_new_dir}" ]]; then
         popd -n +$cnt 2>/dev/null 1>/dev/null
         cnt=cnt-1
      fi
   done

   return 0
}
#}}}

#-------------------------------------------------------------------------------
#{{{ vgrep
function vgrep () {
   declare -A opt
   local args
   while (( $# )); do
      case $1 in
         -i|--ignorecase)
            opt[IGNORECASE]=1
            shift 1
         ;;
         -v|--verilog)
            opt[VERILOG]=1
            shift 1
         ;;
         -t|--tcl)
            opt[TCL]=1
            shift 1
         ;;
         -c)
            opt[C_LANG]=1
            shift 1
         ;;
         -h|--header)
            opt[HEADER]=1
            shift 1
         ;;
         -m|--makefile)
            opt[MAKEFILE]=1
            shift 1
         ;;
         --help)
            opt[HELP]=1
            shift 1
         ;;
         -*)
            echo "Attention: Unknown Argument $1" >&2
            return 1
         ;;
         *)
            args+=("$1")
            shift
         ;;
      esac
   done
   if [[ ${opt[HELP]} -eq 1 ]]; then
      echo "Usage: vgrep PATTERN [OPTION]"
      echo "Search for PATTERN recursively in current directory"
      echo "PATTERN is, by default, a basic regular expression."
      echo "Example: vgrep 'hello world' -v"
      echo "Example: vgrep '[hello|world]' -v"
      echo ""
      echo "File selection:"
      echo "-v|--verilog          RTL Files in Verilog and VHDL, .sv .svh and .v "
      echo "-t|--tcl              tcl style files like .tcl .qel"
      echo "-c                    C programming files like .c .S"
      echo "-h|--header           Header files in c and rtl, .h, .svh"
      echo "-m |--makefile        Makefiles like Makefile and .mk"
      return 0
   fi
   ex="--exclude=*svn* --exclude-dir=archive --exclude=tags"
   if [[ $args == "" ]]; then
      echo "Attention: PATTERN not provided" >&2
      echo ""
      vgrep --help
      return 1
   fi
   local v
   ic=""
   if [[ ${opt[IGNORECASE]} -eq 1 ]]; then
      ic="-i"
   fi
   if [[ ${opt[VERILOG]} -eq 1 ]]; then
      v="--include=*.v --include=*.sv --include=*.vhd --include=*.svh"
   fi
   local t
   if [[ ${opt[TCL]} -eq 1 ]]; then
      t="--include=*.tcl --include=*.qel --include=*.fs"
   fi
   local c
   if [[ ${opt[C_LANG]} -eq 1 ]]; then
      c="--include=*.c --include=*.S --include=*.cpp"
   fi
   local h
   if [[ ${opt[HEADER]} -eq 1 ]]; then
      h="--include=*.h --include=*.svh"
   fi
   local m
   if [[ ${opt[MAKEFILE]} -eq 1 ]]; then
      m="--include=*.mk --include=Makefile --include=makefile"
   fi
   str="grep --color=auto $ic "${args[@]}" . -R $v $h $c $t $m $ex"
   echo "Executing: $str"
   command $str
}
#}}}

#-------------------------------------------------------------------------------
#{{{ fzf
# Configuration
# -------------
export FZF_DEFAULT_COMMAND="fd --type f --follow --exclude '.git'"
export FZF_DEFAULT_OPTS='--height 100% --layout=reverse --border=double --margin=1 --padding=1 --multi --info=inline'

export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_CTRL_T_OPTS="
   --height 100% 
   --preview 'bat -n --theme=Nord --color=always {}'
   --bind 'ctrl-/:change-preview-window(down|hidden|)'
   --color header:italic
   --header 'Press CTRL-/ to toggle preview'"

export FZF_CTRL_R_OPTS="
   --preview 'echo {}' --preview-window up:3:hidden:wrap
   --bind 'ctrl-/:toggle-preview'
   --color header:italic
   --header 'Press CTRL-/ to toggle preview'"

export FZF_ALT_C_COMMAND="fd --type d . --color=never --hidden --exclude '.git'"
export FZF_ALT_C_OPTS="
   --preview 'tree -C {}'
   --bind 'ctrl-/:toggle-preview'
   --color header:italic
   --header 'Press CTRL-/ to toggle preview'"

export FZF_TMUX=1
# for more info see fzf/shell/completion.zsh
_fzf_compgen_path() {
    fd . "$1"
}
_fzf_compgen_dir() {
    fd --type d . "$1"
}

# (EXPERIMENTAL) Advanced customization of fzf options via _fzf_comprun function
# - The first argument to the function is the name of the command.
# - You should make sure to pass the rest of the arguments to fzf.
_fzf_comprun() {
  local command=$1
  shift

  case "$command" in
    cd)           fzf "$@" --preview 'tree -C {} | head -200' ;;
    export|unset) fzf "$@" --preview "eval 'echo \$'{}" ;;
    ssh)          fzf "$@" --preview 'dig {}' ;;
    *)            fzf "$@" ;;
  esac
}
# }}}

#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
#{{{ cat ll la and lt aliases
unalias cat 2> /dev/null # blow away any previous aliases if any
function cat() {
   if command -v bat >/dev/null ; then
      command bat --theme=Nord "$@"
   else
      command cat "$@"
   fi
}
unalias ll 2> /dev/null
function ll() {
   if command -v exa >/dev/null ; then
      command exa --long --header -s modified "$@"
   else
      command ls -Fslr --color=auto "$@"
   fi
}
unalias la 2> /dev/null
function la() {
   if command -v exa >/dev/null ; then
      command exa --long --header -s modified -a "$@"
   else
      command ls -Fslra --color=auto "$@"
   fi
}
unalias lt 2> /dev/null
function lt() {
   if command -v exa >/dev/null ; then
      command exa --tree "$@"
   else
      command tree
   fi
}
unalias du 2> /dev/null
function du() {
   if command -v ncdu >/dev/null ; then
      command ncdu "$@"
   else
      command du -k "$@"
   fi
}
unalias df 2> /dev/null
function df() {
   if command -v pydf >/dev/null ; then
      command pydf "$@"
   else
      command df -k "$@"
   fi
}
#}}}

#-------------------------------------------------------------------------------
#{{{ clip from gvim
# My workaround for not having xsel or xclip
#   Ex: clipboard=$( get_clip )
function get_clip() {
   mkdir -p /tmp/$USER
   file=/tmp/$USER/clipboard_contents.txt
   /bin/rm -f $file
   # Help from:  http://stackoverflow.com/a/23237529/120681
   command gvim $file -T dumb --noplugin -n -es -c 'set nomore' +'normal "*P' +'wq'
   cat $file
}
#}}}

#-------------------------------------------------------------------------------
function rgrep() {
rg --color=always --line-number --no-heading --smart-case "${*:-}" |
   fzf --ansi \
       --delimiter : \
       --preview 'bat --theme=Nord --color=always {1} --highlight-line {2}' \
       --preview-window 'up,60%,border-bottom,+{2}+3/3,~3' \
       --bind 'enter:become(vim {1} +{2})'
}

function tm() {
  [[ -n "$TMUX" ]] && change="switch-client" || change="attach-session"
  if [ $1 ]; then
    tmux $change -t "$1" 2>/dev/null || (tmux new-session -d -s $1 && tmux $change -t "$1"); return
  fi
  session=$(tmux list-sessions -F "#{session_name}" 2>/dev/null | fzf --exit-0) &&  tmux $change -t "$session" || echo "No sessions found."
}

function ifont() {
   # Install font
   echo "Note: Installing FiraCode font"
   mkdir -p ~/.fonts && pushd ~/.fonts >> /dev/null
   wget --no-verbose https://github.com/ryanoasis/nerd-fonts/releases/download/v2.2.2/FiraCode.zip -O /tmp/FiraCode.zip 2>/dev/null
   unzip -q /tmp/FiraCode.zip
   popd >> /dev/null
   # Now set font@gnome-terminal
   GNOME_TERMINAL_PROFILE=$(gsettings get org.gnome.Terminal.ProfilesList default | awk -F \' '{print $2}')
   gsettings set org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$GNOME_TERMINAL_PROFILE/ font 'FiraCode Nerd Font Mono 12'
}

function xvim() {
   dbus-launch gnome-terminal --title="gvim: $@" --hide-menubar --geometry=130x50 -- vim "$@" >/dev/null
}

function num {
   input="$@"
   if [[ ($input =~ ^(-h|help)$) || ($input == "") ]]; then
      echo "Usage:"
      echo "   ${FUNCNAME[0]} [1234|0xdeadbeef|2#1101|'0xab<<2'] - quote <<|>>"
      echo "   ${FUNCNAME[0]} [-h|help]                          - this message"
      return
   fi
   input=$(($input))
   printne "WHITE"   "dec: $input\n"
   printne "GREEN"   "hex: 0x"; print_sequence "$(printf "%X\n" $input)" 8
   printne "MAGENTA" "bin: 2#"; print_sequence "$(echo "obase=2; $input" | bc)" 4
}
function dis() {
   input="$@"
   echo "quit to exit"
   if [[ $input =~ ^(-h|help)$ ]]; then
      echo "Usage:"
      echo "   ${FUNCNAME[0]} -v7  - armv7 compiler"
      echo "   ${FUNCNAME[0]} -h|help"
      echo "quit to exit"
      return
   fi
   if [[ $input =~ ^(-v7)$ ]]; then
      ARCH="ARM-v7"
      CC=(suite_exec -q -t 'Arm Compiler 6' armclang --target=arm-arm-none-eabi -marm -mcpu=cortex-r5)
      LK=(suite_exec -q -t 'Arm Compiler 6' armlink --diag_suppress=L6305W)
      OBJDUMP=(aarch64-unknown-nto-qnx7.1.0-objdump)
   else
      ARCH="ARM-v8"
      CC=(suite_exec -q -t 'Arm Compiler 6' armclang --target=aarch64-arm-none-eabi)
      LK=(suite_exec -q -t 'Arm Compiler 6' armlink --diag_suppress=L6305W)
      OBJDUMP=(aarch64-unknown-nto-qnx7.1.0-objdump)
   fi
   while true; do
      read -p "$ARCH >> " input
      if [[ $input == "quit" ]]; then
         break
      fi
      echo "$input" > temp.s
      "${CC[@]}" -c -o temp.o temp.s
      if [ $? -eq 0 ]; then
          "${LK[@]}" -o temp temp.o
         if [ $? -eq 0 ]; then
            "${OBJDUMP[@]}" -d temp | grep '8[0-9]*:' | sed 's/.*:\s*//'
         fi
      fi
   done
   rm temp.s temp.o temp 2>/dev/null
}
function duration() {
   local seconds=$1

   local formatted_time=$(date -u -d @${seconds} +"%Hh %Mm %Ss")
   echo "${formatted_time}"
}
function ascii() {
   arg=$(echo "$1" | tr '[:upper:]' '[:lower:]')

   echo "ASCII Table:"
   echo "------------"
   printf "%-10s %-10s %-15s\n" "Decimal" "Hex" "Character"
   echo "--------------------------------"

   for ((i=0; i<=127; i++))
   do
      hex=$(printf "%02x" "$i")
      if (( i < 33 || i == 127 )); then
         case $i in
            0) char="Null";;
            1) char="Start of Heading";;
            2) char="Start of Text";;
            3) char="End of Text";;
            4) char="End of Transmission";;
            5) char="Enquiry";;
            6) char="Acknowledge";;
            7) char="Bell";;
            8) char="BS: Backspace";;
            9) char="TAB: Horizontal Tab";;
            10) char="LF: Line Feed";;
            11) char="Vertical Tab";;
            12) char="FF: Form Feed";;
            13) char="CR: Carriage Return";;
            14) char="Shift Out";;
            15) char="Shift In";;
            16) char="Data Link Escape";;
            17) char="Device Control 1";;
            18) char="Device Control 2";;
            19) char="Device Control 3";;
            20) char="Device Control 4";;
            21) char="Negative Acknowledge";;
            22) char="Synchronous Idle";;
            23) char="End of Transmission Block";;
            24) char="Cancel";;
            25) char="End of Medium";;
            26) char="Substitute";;
            27) char="Escape";;
            28) char="File Separator";;
            29) char="Group Separator";;
            30) char="Record Separator";;
            31) char="Unit Separator";;
            32) char="SPC: Space";;
            127) char="DEL: Delete";;
         esac
      else
         char=$(printf "\\x$(printf %x $i)")
      fi

      if [[ -z "$arg" ]] || [[ "$arg" == "$i" ]] || [[ "$arg" == "0x$hex" ]] || [[ $(echo "$char" | tr '[:upper:]' '[:lower:]') == *$(echo "$arg" | tr '[:upper:]' '[:lower:]')* ]]; then
         printf "%-10s %-10s %-15s\n" "$i" "0x$hex" "$char"
      fi
   done
}
