# TerraforMig <!-- omit in toc -->

>*The missing Terraform state migration tool*

- [Installation](#installation)
- [1. Goal](#1-goal)
- [2. Motivation](#2-motivation)
- [3. Prerequisites](#3-prerequisites)
- [4. Directions](#4-directions)
- [5. CLI](#5-cli)
  - [5.1. Usage](#51-usage)
  - [5.2. Commands](#52-commands)
  - [5.3. Options](#53-options)

## Installation

1. Download the shell script
2. Give executable permissions to the script
3. (Optional) Rename the script to `terraformig` without the `.sh` suffix
4. Move the script to a location in your $PATH
   - It's recommended to place this script at the same location as your terraform binary since it is reliant on it

## 1. Goal

This project provides a migration tool to move any number of resources from one statefile to another (including remote backends).

## 2. Motivation
  
- There are a few open feature requests related to this usage:
  - [23580](https://github.com/hashicorp/terraform/issues/23580)
  - [21796](https://github.com/hashicorp/terraform/issues/21796)
- While some improvements / bug fixes have been applied for the state management, there does not seem to be any effort on providing a simplified and more robust state migration (through Terraform 0.14.0 __*__)
  >__*__ Last checked on 2020-11-11

## 3. Prerequisites
  
- Terraform version 12.13+ (Untested on earlier versions, but may work).
- jq version >= jq-1.5-1-a5b5cbe (Untested on earlier versions, but may work).

## 4. Directions

- Move the Terraform code (that defines the resources you wish to move) to the Target directory.
  - Option 1: Separate the terraform resources to a separate .tf file and then move the whole file to the Target directory.
  - Option 2: Cut and paste each resource/module block from the current (Source) directory and paste them in a .tf (usually main.tf) file at the Target directory.

## 5. CLI

### 5.1. Usage

`terraformig [options] <command> [src path] <dest path>`

| **Argument** | **Description** | **Requirement** |
|---|---|---|
| \[options] | Command-line flags. List of available flags below. | Optional |
| \<command> | Command to run. List of available commands below. | Required |
| [src path] | Path to source terraform directory | Optional (Defaults to current working directory) |
| \<dest path> | Path to destination terraform directory | Required |

### 5.2. Commands

| **Command** | **Description** |
|---|---|
| apply | Moves resouces/modules between states |
| plan | Runs migration tool in DRY_RUN mode without modifying states |
| purge | Deletes backup files created by this tool in both SRC and DEST Terraform directories |
| rollback | Recovers previous states in both SRC and DEST Terraform directories |

### 5.3. Options

| **Flag** | **Description** | **Notes** |
|---|---|---|
|-version | Prints this tool's version | |
|-help | Prints this script's README | |
|-debug | Enables DEBUG mode and prints otherwise hidden output | |
|-cleanup | Cleans up any backup files at the successful conclusion of this script | **CAUTION**: Only use if you know what you're doing! |
