#!/bin/bash

### SOURCE ###
# https://github.com/TeraSky-OSS/TerraforMig

### LICENSE ###
# MIT License

# Copyright (c) 2020 TeraSky and Yeshayahu Wasserman

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

### CONFIGURATION ###
set -e # Exit when any command fails

### GLOBAL VARIABLES ###
TERRAFORMIG_VERSION="0.1.0"
OUTPUT_TYPE_WIDTH=7

# Output Text Formatting 
BOLD=$(tput bold)
NORMAL=$(tput sgr0)
UNDERLINE=$(tput smul)

### DEFAULT VARIABLES ###
CLEANUP_BACKUPS=0
DEBUG=0
PURGE=0
OTHER_ARGUMENTS=()
TF_SRC_DIR=$(pwd)
NUM_OF_ARGS=$#
HELP=0
DRY_RUN=0
APPLY=0
VERSION=0
START_DIR=$(pwd)
COMMANDS_COUNT=0
AUTO_APPROVE=0

### FUNCTIONS ###

print_readme(){
cat << EOF

Usage: terraformig [options] <subcommand> <dest>
  [options]     See below for available options.
  <subcommand>  See below for available commands.
  <dest>        Path to destination terraform directory.

Main commands:
  apply         Moves resouces/modules between states.
  plan          Runs migration tool in DRY_RUN mode without modifying states.
  purge         ${BOLD}CAUTION:${NORMAL} Only use if you know what you're doing!
                Deletes backup files created by this tool in both SRC and DEST Terraform directories.
                ${BOLD}NOTE:${NORMAL} This does not remove "terraform.tfstate.backup" files which are generated by the terraform command.
  (TBD) rollback      Recovers previous states in both SRC and DEST Terraform directories.
  help          Show this help output.
  version       Show the current Terraformig version.

Global options (use these before the subcommand, if any):
  -chdir=DIR    Switch to a different working directory before executing the
                given subcommand. (Defaults to current working directory).
  -cleanup      ${BOLD}CAUTION:${NORMAL} Only use if you know what you're doing!
                Cleans up any backup files at the successful conclusion of this script.
                ${BOLD}NOTE:${NORMAL} This does not remove "terraform.tfstate.backup" files which are generated by the terraform command.
  -auto-approve Skip interactive approval of plan before applying.
  -debug        Enables DEBUG mode which prints otherwise hidden output and enables xtrace.
  -help         An alias for the "help" subcommand.
  -version      An alias for the "version" subcommand.

See here for more information: https://github.com/TeraSky-OSS/TerraforMig

EOF
}

format_input(){
  echo "$(echo "$*" | sed -e 's/^[[:space:]][[:space:]]*/\t/')" # Replaces lines with multiple leading spaces with a tab
}

info_print(){
  tabulated_input="$(format_input "$*")"
  printf "\n%-*s %s\n" $OUTPUT_TYPE_WIDTH "[INFO]" "$tabulated_input"
}

debug_print(){
  if [[ $DEBUG -eq 1 ]]; then
    tabulated_input="$(format_input "$*")"
    printf "\n%-*s %s\n" $OUTPUT_TYPE_WIDTH "[DEBUG]" "$tabulated_input"
  fi
}

warn_print(){
  tabulated_input="$(format_input "$*")"
  printf "\n%-*s %s\n" $OUTPUT_TYPE_WIDTH "[WARN]" "$tabulated_input"
}

error_print(){
  tabulated_input="$(format_input "$*")"
  printf "\n%-*s %s. \
  \n\tExiting...\n\n" \
  $OUTPUT_TYPE_WIDTH "[ERROR]" "$tabulated_input" >&2
  exit 1
}

backup_exists_error(){
  error_print "There already exists a backup made by this script.
    Please remove or rename it and then try again.
    You may wish to run the \"purge\" command."
}

error_handler(){
  error_print "Something went wrong.
    You may wish to add the \"-debug\" flag to your command."
}

cleanup_backups(){
  info_print "Cleaning up all backup files."
  cd $START_DIR
  cd $TF_SRC_DIR
  info_print "Source terraform directory: \"$TF_SRC_DIR\"
  Removing $(ls -l | grep "terraformig.tfstate*" | wc -l) file(s) from the source terraform directory..."
  rm -rf terraformig.tfstate*
  cd $START_DIR
  cd $TF_DEST_DIR
  info_print "Destination terraform directory: \"$TF_DEST_DIR\"
  Removing $(ls -l | grep "terraformig.tfstate*" | wc -l) file(s) from the destination terraform directory..."
  rm -rf terraformig.tfstate*
}

user_confirmation(){
  if [[ $AUTO_APPROVE -eq 0 ]]; then
    if [[ ${BASH_VERSINFO[0]} < 4 ]]; then
      read -e -p "Are you ready to continue? [y/N] " answer
    else
      read -e -p "Are you ready to continue? " -i "yes" answer
    fi
    if [[ $answer != "yes" && $answer != "y" && $answer != "Y" ]]; then
      info_print "Canceled\n"
      exit 0
    fi
  fi
}

### MAIN ###
trap "error_handler" ERR

# Loop through arguments and process them
for arg in "$@"
do
    case $arg in
        -cleanup)
        CLEANUP_BACKUPS=1
        shift
        ;;
        -version|-v|version)
        VERSION=1
        COMMANDS_COUNT+=1
        shift
        ;;
        -debug|-d)
        DEBUG=1
        shift
        ;;
        purge)
        PURGE=1
        COMMANDS_COUNT+=1
        shift
        ;;
        -help|-h|help)
        HELP=1
        COMMANDS_COUNT+=1
        shift
        ;;
        plan)
        DRY_RUN=1
        CLEANUP_BACKUPS=1
        COMMANDS_COUNT+=1
        shift
        ;;
        apply)
        APPLY=1
        COMMANDS_COUNT+=1
        shift
        ;;
        -chdir=*)
        TF_SRC_DIR="$(echo "$1" | sed -e 's/^-chdir=//')" # Removes the option flag prefix `-chdir=`
        shift
        ;;
        -auto-approve)
        AUTO_APPROVE=1
        shift
        ;;
        *)
        OTHER_ARGUMENTS+=("$1")
        shift
        ;;
    esac
done

TF_DEST_DIR=${OTHER_ARGUMENTS[0]}

# -help
if [[ $HELP -eq 1 ]] ; then
  print_readme
  exit 0
fi

# Check if no commands were called and print warning
if [[ COMMANDS_COUNT -eq 0 ]]; then
  if [[ $OTHER_ARGUMENTS -eq 0 ]]; then
    error_print "No commands supplied.
    See \`terraformig -help\`."
  else
    error_print "Unknown command(s): \`${OTHER_ARGUMENTS[@]}\`.
    See \`terraformig -help\`."
  fi
fi

# -version
if [[ $VERSION -eq 1 ]]; then
  info_print "TerraforMig v$TERRAFORMIG_VERSION"
  exit 0
fi

if [[ $DRY_RUN -eq 1 ]]; then
  info_print "DRY_RUN mode enabled. Nothing will be moved. Only temporary backups and plans will be created."
fi

if [[ $DEBUG -eq 1 ]]; then
  debug_print "Enabling xtrace (command tracing)"
  set -x
fi

if [[ ! -d $TF_SRC_DIR ]]; then
  info_print "Current directory (\$pwd): \"$(pwd)\""
  error_print "Could not locate source terraform directory at: \"$TF_SRC_DIR\""
fi
# Check if string is empty using -z
while [[ -z "$TF_DEST_DIR" ]]; do
  info_print "Current directory (\$pwd): \"$(pwd)\"
  Source terraform directory: \"$TF_SRC_DIR\"
  "
  read -p "Please enter the destination terraform directory (include path): " TF_DEST_DIR
done
if [[ ! -d $TF_DEST_DIR ]]; then
  info_print "Current directory (\$pwd): \"$(pwd)\""
  error_print "Could not locate destination terraform directory at: \"$TF_DEST_DIR\""
else
  info_print "Source terraform directory: \"$TF_SRC_DIR\"
  Destination terraform directory: \"$TF_DEST_DIR\""
fi

if [[ $PURGE -eq 1 ]]; then
  warn_print "Purging previous backups performed by this tool..."
  user_confirmation
  cleanup_backups
  info_print "Purge complete. Exiting..."
  exit 0
fi

cd $START_DIR
cd $TF_SRC_DIR
info_print "Ensuring source terraform directory is initialized."
TF_SRC_INIT=$(terraform init -reconfigure -input=false)
debug_print "$TF_SRC_INIT"

TF_BACKEND_STR="Successfully configured the backend"
TF_SRC_BACKEND_EXIST=0
if [[ "$TF_SRC_INIT" == *"$TF_BACKEND_STR"* ]]; then
  debug_print "Source terraform backend exists."
  TF_SRC_BACKEND_EXIST=1
fi

info_print "Creating source statefile backup titled \"terraformig.tfstate.backup\" before modifying."
if [[ -f terraformig.tfstate.backup ]]; then
  backup_exists_error
fi
terraform refresh
echo "$(terraform state pull)" > terraform.tfstate
cp terraform.tfstate terraformig.tfstate.backup

cd $START_DIR
cd $TF_DEST_DIR
info_print "Ensuring destination terraform is initialized."
TF_DEST_INIT=$(terraform init -reconfigure -input=false)
debug_print "$TF_DEST_INIT"

TF_DEST_BACKEND_EXIST=0
if [[ "$TF_DEST_INIT" == *"$TF_BACKEND_STR"* ]]; then
  debug_print "Destination terraform backend exists."
  TF_DEST_BACKEND_EXIST=1
fi

info_print "Creating destination statefile backup titled \"terraformig.tfstate.backup\" before modifying."
if [[ -f terraformig.tfstate.backup ]]; then
  backup_exists_error
fi
terraform refresh
echo "$(terraform state pull)" > terraform.tfstate
cp terraform.tfstate terraformig.tfstate.backup

cd $START_DIR
cd $TF_SRC_DIR
info_print "Creating temporary terraform plan file."
terraform plan -out=terraformig.tfplan > /dev/null

CMD() {
  terraform show -json terraformig.tfplan | jq -r '.resource_changes[] | select(.change.actions[] | contains ("delete")) | .address'
}
count=0
previous=
current=
for n in $(CMD)
do
  current=$n
  if [[ $current == "module."* ]]; then
    current=$(echo $current | cut -d'.' -f1,2)
    if [[ $current == $previous ]]; then
      continue
    fi
  fi
  if [[ $DRY_RUN -eq 1 ]]; then
    info_print "DRY_RUN mode enabled. Would move $current resource/module."
  else
    info_print "Moving $current resource/module..."
    terraform state mv -state-out=$TF_DEST_DIR/terraform.tfstate $current $current
  fi
  previous=$current
  count=$((count + 1))
done
rm -f terraformig.tfplan

if [[ $count -eq 0 ]]; then
  info_print "0 resources to move."
  info_print "Did you remove the resource definitions from the source config files?"
else
  cd $START_DIR
  cd $TF_DEST_DIR
  rm -f ./.terraform/terraform.tfstate
  info_print "Initializing destination terraform with updated statefile."
  TF_DEST_UPDATE_INIT=$(terraform init -force-copy -input=false)
  debug_print "$TF_DEST_UPDATE_INIT"
fi

if [[ $TF_DEST_BACKEND_EXIST -eq 1 ]]; then
  cd $START_DIR
  cd $TF_DEST_DIR
  rm -f terraform.tfstate
fi

if [[ $TF_SRC_BACKEND_EXIST -eq 1 ]]; then
  cd $START_DIR
  cd $TF_SRC_DIR
  rm -f terraform.tfstate
fi

if [[ $CLEANUP_BACKUPS -eq 1 ]]; then
  cleanup_backups
fi

info_print "Finished!"
exit 0
