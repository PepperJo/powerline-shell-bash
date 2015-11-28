#!/bin/bash

#Defaultcolors
USERNAME_FG=250
USERNAME_BG=240
USERNAME_ROOT_BG=124

HOSTNAME_FG=0
HOSTNAME_BG=203

HOME_SPECIAL_DISPLAY=True
HOME_BG=31 #blueish
HOME_FG=15 #white
PATH_BG=237 #darkgrey
PATH_FG=250 #lightgrey
CWD_FG=254 #nearly-whitegrey
SEPARATOR_FG=244

READONLY_BG=124
READONLY_FG=254

SSH_BG=166 #mediumorange
SSH_FG=254

REPO_CLEAN_BG=148 #alightgreencolor
REPO_CLEAN_FG=0 #black
REPO_DIRTY_BG=161 #pink/red
REPO_DIRTY_FG=15 #white

JOBS_FG=39
JOBS_BG=238

CMD_PASSED_BG=236
CMD_PASSED_FG=15
CMD_FAILED_BG=161
CMD_FAILED_FG=15

SVN_CHANGES_BG=148
SVN_CHANGES_FG=22 #darkgreen

GIT_AHEAD_BG=240
GIT_AHEAD_FG=250
GIT_BEHIND_BG=240
GIT_BEHIND_FG=250
GIT_STAGED_BG=22
GIT_STAGED_FG=15
GIT_NOTSTAGED_BG=130
GIT_NOTSTAGED_FG=15
GIT_UNTRACKED_BG=52
GIT_UNTRACKED_FG=15
GIT_CONFLICTED_BG=9
GIT_CONFLICTED_FG=15

VIRTUAL_ENV_BG=35 #amid-tonegreen
VIRTUAL_ENV_FG=00

FG_COLOR_PREFIX=38
BG_COLOR_PREFIX=48

# special powerline font characters
SEPERATOR="\uE0B0"
PATH_SEPARATOR="\uE0B1"
READ_ONLY="\uE0A2"
BRANCH_SYM="\uE0A0"

set -x

function color_template {
    echo -en "\[\e$1\]"
}

function color {
    # $1=prefix $2=color
    color_template "[$1;5;$2m"
}

FG_SEGMENTS=()
BG_SEGMENTS=()
CONTENT_SEGMENTS=()

function append_segment {
    FG_SEGMENTS+=($1)
    BG_SEGMENTS+=($2)
    CONTENT_SEGMENTS+=("$3")
}

# virtual environment
[ -n "$VIRTUAL_ENV" ] && _ENV="$VIRTUAL_ENV" || _ENV="$CONDA_ENV_PATH"
if [ -n "$_ENV" ]; then
    append_segment $VIRTUAL_ENV_BG $VIRTUAL_ENV_FG $(basename $_ENV)
fi

# username
USER_COLOR=
USERBG_COLOR=
if [ "$USER" == "root" ]; then
    USERBG_COLOR=$USERNAME_ROOT_BG
else
    USERBG_COLOR=$USERNAME_BG
fi
append_segment $USERNAME_FG $USERBG_COLOR "\u"

# hostname
append_segment $HOSTNAME_FG $HOSTNAME_BG $HOSTNAME

# ssh
[ -n "$SSH_CLIENT" ] && append_segment $SSH_FG $SSH_BG $SSH_CLIENT

# path
PATH_NAME=""
IS_HOME=$(expr match $PWD $HOME)
if [[ "$IS_HOME" == "${#HOME}" ]]; then
    PATH_NAME="${PWD:${#HOME}+1}"
    append_segment $HOME_FG $HOME_BG "~"
else
    PATH_NAME=${PWD:1}
fi

OLD_IFS=$IFS
IFS="/"
PATH_ARRAY=($PATH_NAME)
IFS=$OLD_IFS
PATH_FMT=""
for i in ${!PATH_ARRAY[@]}; do
    PATH_FMT+="${PATH_ARRAY[$i]}"
    [ $i != $((${#PATH_ARRAY[@]} - 1)) ] && PATH_FMT+=" $PATH_SEPARATOR "
done
[ -n "$PATH_FMT" ] && append_segment $PATH_FG $PATH_BG "$PATH_FMT"

# read-only
[ -w $PWD ] || append_segment $READONLY_FG $READONLY_BG $READ_ONLY

# git
GIT_DETACHED="\u2693"
GIT_AHEAD="\u2B06"
GIT_BEHING="\u2B07"
GIT_STAGED="\u2714"
GIT_NOTSTAGED="\u270E"
GIT_UNTRACKED="\u2753"
GIT_CONFLICTED="\u273C"

PARENT_DIR=$PWD
IS_GIT=false
while [ -n $PARENT_DIR ] ; do
    [ -e "$PARENT_DIR/.git" ] && IS_GIT=true; break
    PARENT_DIR=$(dirname $PARENT_DIR)
done

function git_segment {
    # $1=number $2=fg $3=bg $4=char
    if [ -n "$1" ]; then
        local str
        (( $1 == 1 )) && str="$4" || str="$1$4"
        append_segment $2 $3 $str
    fi
}

if [ "$IS_GIT" = true ]; then
    GIT_OUTPUT=$(git status --porcelain -b 2>/dev/null)
    if [ -n "$GIT_OUTPUT" ]; then
        mapfile -t GIT_OUTPUT <<<"$GIT_OUTPUT"
        IS_DIRTY=false
        GIT_REGEX='^## ([^.]*)(\.{3}(\S+))?( \[((ahead) ([[:digit:]]+)(, )?)?((behind) ([[:digit:]]+))?\])?)?$'
        GIT_REGEX2='^## Initial commit on (\S*)$'
        if [[ "${GIT_OUTPUT[0]}" =~ $GIT_REGEX ]] || [[ "${GIT_OUTPUT[0]}" =~  $GIT_REGEX2 ]]; then
            # branch (local)
            BRANCH=${BASH_REMATCH[1]}

            # ahead / behind
            if ((${#BASH_REMATCH[@]} > 5)); then
                for ((i=6;i<=${#BASH_REMATCH[@]};i++)); do
                    if [[ "${BASH_REMATCH[$i]}" == "ahead" ]]; then
                        git_segment "${BASH_REMATCH[$i+1]}" $GIT_AHEAD_FG $GIT_AHEAD_BG $GIT_AHEAD
                    elif [[ "${BASH_REMATCH[$i]}" == "behind" ]]; then
                        git_segment "${BASH_REMATCH[$i+1]}" $GIT_BEHIND_FG $GIT_BEHIND_BG $GIT_BEHIND
                    fi
                done
            fi

            # stats
            for code in "${GIT_OUTPUT[@]:1}"; do
                IS_DIRTY=true
                if [[ "$code" =~ ^\?\? ]]; then
                    GIT_UNTRACKED_NO=$(($GIT_UNTRACKED_NO + 1))
                elif [[ "$code" =~ ^(DD|AU|UD|UA|DU|AA|UU) ]]; then
                    GIT_CONFLICTED_NO=$(($GIT_CONFLICTED_NO + 1))
                elif [[ "$code" =~ ^\ . ]]; then
                    GIT_NOTSTAGED_NO=$(($GIT_NOTSTAGED_NO + 1))
                elif [[ "$code" =~ ^.\  ]]; then
                    GIT_STAGED_NO=$(($GIT_STAGED_NO + 1))
                fi
            done
            git_segment "$GIT_STAGED_NO" $GIT_STAGED_FG $GIT_STAGED_BG $GIT_STAGED
            git_segment "$GIT_NOTSTAGED_NO" $GIT_NOTSTAGED_FG $GIT_NOTSTAGED_BG $GIT_NOTSTAGED
            git_segment "$GIT_UNTRACKED_NO" $GIT_UNTRACKED_FG $GIT_UNTRACKED_BG $GIT_UNTRACKED
            git_segment "$GIT_CONFLICTED_NO" $GIT_CONFLICTED_FG $GIT_CONFLICTED_BG $GIT_CONFLICTED
        else
            GIT_OUTPUT=$(git describe --tags --always 2> /dev/null)
            [ $? == 0 ] && BRANCH="$GIT_OUTPUT"
        fi
        BRANCH="$BRANCH_SYM$BRANCH"
        if [ "$IS_DIRTY" == true ]; then
            append_segment $REPO_DIRTY_FG $REPO_DIRTY_BG "$BRANCH"
        else
            append_segment $REPO_CLEAN_FG $REPO_CLEAN_BG "$BRANCH"
        fi
    fi
fi

# svn


# jobs
[[ "$2" != "0" ]] && append_segment $JOBS_FG $JOBS_BG "&$2"

# exit code
(( $1 != 0 )) && append_segment $CMD_FAILED_FG $CMD_FAILED_BG "\u2BA1 $1"

function separator {
    color $FG_COLOR_PREFIX $1
    color $BG_COLOR_PREFIX $2
    echo -en $SEPERATOR
}

for i in ${!FG_SEGMENTS[@]}; do
    FG_COLOR=${FG_SEGMENTS[$i]}
    BG_COLOR=${BG_SEGMENTS[$i]}
    CONTENT=${CONTENT_SEGMENTS[$i]}
    color $FG_COLOR_PREFIX $FG_COLOR
    color $BG_COLOR_PREFIX $BG_COLOR
    echo -en " $CONTENT "
    NEXT_BG_COLOR=${BG_SEGMENTS[$i+1]}
    separator $BG_COLOR $NEXT_BG_COLOR
done
# reset
color_template "[0m "

