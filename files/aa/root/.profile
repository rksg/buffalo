# aliases
alias ll="ls -al"
alias lr="ls -R"

# exports
export CLICOLOR=1
export LSCOLORS=ExFxCxDxBxegedabagacad
export PAGER=most
export PATH="$PATH:$HOME/bin"

# prompt PS1
MYPSDIR_AWK=$(cat << 'EOF'
BEGIN { FS = OFS = "/" }
{ 
   if (length($0) > 16 && NF > 4)
      print $1,$2,".." NF-4 "..",$(NF-1),$NF
   else
      print $0
}
EOF
)
export MYPSDIR='$(echo -n "${PWD/#$HOME/~}" | awk "$MYPSDIR_AWK")'
export PS1='\[\033[1;30m\]$(date +"%d/%m/%y %H:%M") \[\033[1;34m\]\u \[\033[0;34m\]\h \[\033[1;32m\]$(eval "echo ${MYPSDIR}") \[\033[1;30m\]$ \[\033[0m\]'
# unused history: \[\033[1;30m\][\!] 
# unused date: \[\033[1;30m\]$(date +"%d/%m/%y %H:%M") 
# unused user: \[\033[1;34m\]\u


# set x/ssh window title as well
#export PROMPT_COMMAND='echo -ne "\033]0;${HOSTNAME%%.*} $(eval "echo ${MYPSDIR}")\007"'
echo -ne "\033]0;$(whoami)@$(hostname)\007"

