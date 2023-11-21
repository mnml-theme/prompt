prompt_opts=(cr sp subst percent)
: ${PROMPT_EOL_MARK:=}
setopt no_prompt_{bang,cr,sp,percent,subst} prompt_$^prompt_opts

# Default Spacing
: ${ZSH_PROMPT_NEWLINE:=true}
: ${ZLE_RPROMPT_INDENT:=0}

# Default Colours
case $ZSH_THEME in
  Dracula)
    : ${ZSH_PROMPT_COLOR_MODIFIED:=215}
    : ${ZSH_PROMPT_COLOR_COMMENT:=61}
    : ${ZSH_PROMPT_SYMBOL_COLOR:=5}
esac

: ${ZSH_PROMPT_COLOR_ERROR:=red}
: ${ZSH_PROMPT_COLOR_COMMENT:=8}
: ${ZSH_PROMPT_COLOR_JOBS:=$ZSH_PROMPT_COLOR_COMMENT}

: ${ZSH_PROMPT_COLOR_PWD:=$ZSH_PROMPT_COLOR_COMMENT}
: ${ZSH_PROMPT_SYMBOL_COLOR:=default}

: ${ZSH_PROMPT_COLOR_ADDED:=green}
: ${ZSH_PROMPT_COLOR_UNTRACKED:=$ZSH_PROMPT_COLOR_ADDED}
: ${ZSH_PROMPT_COLOR_MODIFIED:=yellow}
: ${ZSH_PROMPT_COLOR_RENAMED:=blue}
: ${ZSH_PROMPT_COLOR_DELETED:=$ZSH_PROMPT_COLOR_ERROR}
: ${ZSH_PROMPT_COLOR_STASHED:=$ZSH_PROMPT_COLOR_JOBS}
: ${ZSH_PROMPT_COLOR_REVISION:=$ZSH_PROMPT_COLOR_STASHED}
: ${ZSH_PROMPT_COLOR_BRANCH:=$ZSH_PROMPT_COLOR_REVISION}

# Default Symbols
: ${ZSH_PROMPT_SYMBOL:=>}
: ${ZSH_PROMPT_SYMBOL_JOBS:=☰ }

: ${ZSH_PROMPT_SYMBOL_REVISION:= }
: ${ZSH_PROMPT_SYMBOL_BRANCH:= }
: ${ZSH_PROMPT_SYMBOL_UNTRACKED:=\*}
: ${ZSH_PROMPT_SYMBOL_ADDED:=+}
: ${ZSH_PROMPT_SYMBOL_RENAMED:=\~}
: ${ZSH_PROMPT_SYMBOL_MODIFIED:=$ZSH_PROMPT_SYMBOL_ADDED}
: ${ZSH_PROMPT_SYMBOL_DELETED:=-}
: ${ZSH_PROMPT_SYMBOL_STASHED:=$ZSH_PROMPT_SYMBOL_JOBS}
: ${ZSH_PROMPT_SYMBOL_BEHIND:=↓}
: ${ZSH_PROMPT_SYMBOL_AHEAD:=↑}

# Detail
: ${ZSH_PROMPT_PWD:=}
: ${ZSH_PROMPT_COUNT_JOBS:=}

: ${ZSH_PROMPT_REVISION:=}
: ${ZSH_PROMPT_REMOTE:=}
: ${ZSH_PROMPT_COUNT_FETCH:=true}
: ${ZSH_PROMPT_COUNT_STASHED:=}
: ${ZSH_PROMPT_COUNT_CHANGED:=}

: ${ZSH_PROMPT_FORMAT:=$ZSH_PROMPT_SYMBOL_FORMAT_PREFIX${ZSH_PROMPT_REVISION:+%F{$ZSH_PROMPT_COLOR_REVISION}$ZSH_PROMPT_SYMBOL_REVISION%f%7.7i }%b%u%c%m$ZSH_PROMPT_SYMBOL_FORMAT_SUFFIX}

# https://devfonts.gafi.dev
# copy(Array.from(document.querySelectorAll('.font-name')).map((node) => `'${node.textContent}'`).sort().join('\n'))
local font{,s}
fonts=(
  'Cascadia Code'
  'Consolas Ligaturized'
  'Dank Mono'
  'Fantasque Sans Mono'
  'Fira Code'
  'Hasklig'
  'Inconsolata'
  'Iosevka Slab'
  'Iosevka'
  'JetBrains Mono'
  'Julia Mono'
  'Lilex'
  'Monoid'
  'Operator Mono'
  'SF Mono'
  'Victor Mono'
  'Lig(atur)?[^h]'
)

fontFamily() { perl -ne "/fontFamily.*['\"](.+?)[,'\"]/ && print \$1" < $1 }

case $TERM_PROGRAM in
  Apple_Terminal) osascript -l JavaScript -e 'Application("Terminal").windows[0].fontName()';;

  Hyper) fontFamily ~/.hyper.js;;

  vscode) : local ${VSCODE_APPDATA:=~/Library/Application Support}
    fontFamily $VSCODE_APPDATA/{Code,VSCodium}/User/settings.json(om[1]N)

esac | read font
unfunction fontFamily

# https://graphemica.com/200D
if ! [[ $font =~ 'NerdFont.*M|NL' ]]
then
  if [[ ${font:l:gs/ /} =~ ${(j | )fonts:l:gs/ /} && $ZSH_PROMPT_COUNT_CHANGED != true ]]
  then local ZWJ='‍'
    ZLE_RPROMPT_INDENT=0
  elif [[ $ZSH_PROMPT_SYMBOL_BRANCH =~  ]]
  then     ZSH_PROMPT_SYMBOL_BRANCH=/
  fi
fi

autoload promptinit colors add-zsh-hook vcs_info
promptinit
colors

add-zsh-hook precmd vcs_info
zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:*' use-simple true
if (($#ZSH_PROMPT_REVISION)) zstyle ':vcs_info:*' get-revision true
zstyle ':vcs_info:*' check-for-changed true

zstyle ':vcs_info:git:*' formats $ZSH_PROMPT_FORMAT

zstyle ':vcs_info:git+set-message:*' hooks branch untracked status stashed fetch

+vi-branch() {
  if (($#ZSH_PROMPT_REMOTE))
  then git remote | read
  elif [[ $ZSH_PROMPT_SYMBOL_BRANCH == / ]]
  then unset ZSH_PROMPT_SYMBOL_BRANCH
  fi
  hook_com[branch]="%F{$ZSH_PROMPT_COLOR_BRANCH}$ZSH_PROMPT_SYMBOL_BRANCH%f${REPLY:+$REPLY/}$hook_com[branch]"
}

+vi-untracked() {
  git ls-files --exclude-standard --others | wc -l | read
  if (($#REPLY)) hook_com[unstaged]+="%F{$ZSH_PROMPT_COLOR_UNTRACKED}$ZSH_PROMPT_SYMBOL_UNTRACKED%f"
}

+vi-status() {
  local {added,modified,deleted,renamed}{,_staged} unmerged

  git diff --name-only --diff-filter UB | wc -l | read unmerged
  git diff --name-only --staged | read -d '' -A staged

  git ls-files --deleted --exclude-standard --others -z | xargs -0 \
  git add --intent-to-add --ignore-errors --no-warn-embedded-repo

  git status --porcelain --ignore-submodules --untracked-files=all | while read
  do local files=(${=REPLY//(->|[ARDM]  )/})
    case $REPLY in
      A*) if ([[ $staged =~ $files[1] ]]) then
            ((added_staged++)) else ((added++))
          fi;;
      R*) if ([[ $staged =~ $files[2] ]]) then
            staged+=$files[1]
            ((renamed_staged++)) else ((renamed++))
          fi;;
      D*) if ([[ $staged =~ $files[1] ]]) then
            ((deleted_staged++)) else ((deleted++))
          fi;;
      M*) if ([[ $staged =~ $files[1] ]]) then
            ((modified_staged++)) else ((modified++))
          fi
    esac
  done

  git reset --quiet
  if (($#staged > 1)) git add $staged

  if (($unmerged))        hook_com[unstaged]+="%F{$ZSH_PROMPT_COLOR_ERROR}${ZSH_PROMPT_COUNT_CHANGED:+$unmerged}$ZSH_PROMPT_SYMBOL_UNTRACKED%f"
  if (($added))           hook_com[unstaged]+="%F{$ZSH_PROMPT_COLOR_ADDED}${ZSH_PROMPT_COUNT_CHANGED:+$added}$ZSH_PROMPT_SYMBOL_ADDED%f$ZWJ"
  if (($renamed))         hook_com[unstaged]+="%F{$ZSH_PROMPT_COLOR_RENAMED}${ZSH_PROMPT_COUNT_CHANGED:+$renamed}$ZSH_PROMPT_SYMBOL_RENAMED%f$ZWJ"
  if (($modified))        hook_com[unstaged]+="%F{$ZSH_PROMPT_COLOR_MODIFIED}${ZSH_PROMPT_COUNT_CHANGED:+$modified}$ZSH_PROMPT_SYMBOL_MODIFIED%f$ZWJ"
  if (($deleted))         hook_com[unstaged]+="%F{$ZSH_PROMPT_COLOR_DELETED}${ZSH_PROMPT_COUNT_CHANGED:+$deleted}$ZSH_PROMPT_SYMBOL_DELETED%f$ZWJ"

  if (($added_staged))    hook_com[staged]+="%U%F{$ZSH_PROMPT_COLOR_ADDED}${ZSH_PROMPT_COUNT_CHANGED:+$added_staged}$ZSH_PROMPT_SYMBOL_ADDED%f%u$ZWJ"
  if (($renamed_staged))  hook_com[staged]+="%U%F{$ZSH_PROMPT_COLOR_RENAMED}${ZSH_PROMPT_COUNT_CHANGED:+$renamed_staged}$ZSH_PROMPT_SYMBOL_RENAMED%f%u$ZWJ"
  if (($modified_staged)) hook_com[staged]+="%U%F{$ZSH_PROMPT_COLOR_MODIFIED}${ZSH_PROMPT_COUNT_CHANGED:+$modified_staged}$ZSH_PROMPT_SYMBOL_MODIFIED%f%u$ZWJ"
  if (($deleted_staged))  hook_com[staged]+="%U%F{$ZSH_PROMPT_COLOR_DELETED}${ZSH_PROMPT_COUNT_CHANGED:+$deleted_staged}$ZSH_PROMPT_SYMBOL_DELETED%f%u$ZWJ"
}

+vi-stashed() {
  git stash list | wc -l | read
  if (($REPLY)) hook_com[staged]+="%F{$ZSH_PROMPT_COLOR_STASHED}${ZSH_PROMPT_COUNT_STASHED:+$REPLY}$ZSH_PROMPT_SYMBOL_STASHED%f"
}

+vi-fetch() {
  local ahead behind
  git rev-list --left-right --count HEAD...@{u} 2> /dev/null | read ahead behind

  if ((${behind:-$ahead})) hook_com[staged]+=$ZSH_PROMPT_SYMBOL_FETCH
  if (($behind)) hook_com[staged]+="${ZSH_PROMPT_COUNT_FETCH:+$behind}$ZSH_PROMPT_SYMBOL_BEHIND"
  if (($ahead)) hook_com[staged]+="${ZSH_PROMPT_COUNT_FETCH:+$ahead}$ZSH_PROMPT_SYMBOL_AHEAD"
}

PS1=${ZSH_PROMPT_PWD:+%F{$ZSH_PROMPT_COLOR_PWD}%~%f$'\n'}
PS1+="%F{$ZSH_PROMPT_COLOR_JOBS}%(1j.${ZSH_PROMPT_COUNT_JOBS:+%j}$ZSH_PROMPT_SYMBOL_JOBS.)%f"
if (($#ZSH_PROMPT_SYMBOL_ERROR)) then
  PS1+="%F{$ZSH_PROMPT_COLOR_ERROR}%B%(?..$ZSH_PROMPT_SYMBOL_ERROR)%b%f"
  PS1+=`printf "%%F{$ZSH_PROMPT_SYMBOL_COLOR}$ZSH_PROMPT_SYMBOL%%f%.0s" {1..$SHLVL}`
else
  PS1+=`printf "%%F{%%(?.$ZSH_PROMPT_SYMBOL_COLOR.$ZSH_PROMPT_COLOR_ERROR)}$ZSH_PROMPT_SYMBOL%%f%.0s" {1..$SHLVL}`
fi
PS1+=' '

add-zsh-hook precmd $funcstack[1]
if (($#funcstack == 1)) then
  if (($#ZSH_PROMPT_NEWLINE)) $funcstack[1]() echo
  vcs_info
  RPS1='$vcs_info_msg_0_'
fi
