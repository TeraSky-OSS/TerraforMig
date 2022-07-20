#!/bin/bash

### CONFIGURATION ###
set -e # Exit when any command fails

### GLOBAL VARIABLES ###
OUTPUT_TYPE_WIDTH=7
START_DIR=$(pwd)
TEST_DIR_1="$START_DIR/tests/bar"
TEST_DIR_2="$START_DIR/tests/foo"


### FUNCTIONS ###
format_input(){
  echo "$(echo "$*" | sed -e 's/^[[:space:]][[:space:]]*/\t/')" # Replaces lines with multiple leading spaces with a tab
}

info_print(){
  tabulated_input="$(format_input "$*")"
  printf "\n%-*s %s\n" $OUTPUT_TYPE_WIDTH "[INFO]" "$tabulated_input"
  sleep 2
}

error_print(){
  tabulated_input="$(format_input "$*")"
  printf "\n%-*s %s. \
  \n\tExiting...\n\n" \
  $OUTPUT_TYPE_WIDTH "[ERROR]" "$tabulated_input" >&2
  sleep 1
  exit 1
}

error_handler(){
  error_print "Something went wrong.
    Tests failed."
}

enable_examples(){
  CWD=$(pwd)
  DIR="${1:-$(pwd)}"  
  info_print "Enabling examples $DIR."
  cd $DIR
  DISABLED_EXAMPLES="$(ls | grep  "example.*\.tf\.disabled$")"
  ENABLING_EXAMPLES="$(echo $DISABLED_EXAMPLES | sed -e 's/\.disabled//' )"
  cp $DISABLED_EXAMPLES $ENABLING_EXAMPLES 
  cd $CWD
}

disable_examples(){
  CWD=$(pwd)
  DIR="${1:-$(pwd)}"
  info_print "Disabling examples $DIR."
  cd $DIR
  DISABLED_EXAMPLES="$(ls | grep  "example.*\.tf\.disabled$")"
  ENABLED_EXAMPLES="$(echo $DISABLED_EXAMPLES | sed -e 's/\.disabled//' )"
  rm -f $ENABLED_EXAMPLES 
  cd $CWD
}

### MAIN ###

trap "error_handler" ERR

# Test
$START_DIR/terraformig.sh -auto-approve -cleanup -chdir=$TEST_DIR_1 purge $TEST_DIR_2

# Initialize
cd $TEST_DIR_1
disable_examples $TEST_DIR_1
enable_examples $TEST_DIR_1
terraform init
terraform apply -auto-approve
terraform show
disable_examples $TEST_DIR_1

# Test
cd $TEST_DIR_1
disable_examples $TEST_DIR_2
enable_examples $TEST_DIR_2
$START_DIR/terraformig.sh -auto-approve -cleanup apply $TEST_DIR_2
terraform show
disable_examples $TEST_DIR_2

# Test
cd $START_DIR
cd $TEST_DIR_2
disable_examples $TEST_DIR_1
enable_examples $TEST_DIR_1
terraform show
$START_DIR/terraformig.sh -auto-approve -cleanup apply $TEST_DIR_1
terraform show
disable_examples $TEST_DIR_1

# Test
$START_DIR/terraformig.sh -auto-approve -cleanup -chdir=$TEST_DIR_1 purge $TEST_DIR_2

# Cleanup
cd $TEST_DIR_1
terraform destroy -auto-approve
cd $TEST_DIR_2
terraform destroy -auto-approve

info_print "Tests completed successfully!"
