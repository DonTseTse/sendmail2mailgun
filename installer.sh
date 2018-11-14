#! /bin/bash

# bash built-ins used: read
# not checked: echo
dependencies="pwd grep printf sed egrep awk head tr cat curl"

default_main_configuration_filepath="/etc/sendmail2mailgun/main.conf"
executable_logging_name="sendmail2mailgun"
sendmail2mailgun_path="./emulator.sh"

# TODO
# 1 - todos throughout the file
# 2 - add check that sendmail2mailgun_path exists
# future - add dry run mode
# - Use local in functions 

##### Functions
### sanitize_variable_quotes
# In configuration files, if a definition is <var>="...", the loaded value is '"..."' (the double quotes are part of the value).
# This function removes them. Check for single and double quotes.
#
# Parametrization:
#  $1 string to process
# Retuns: processed string
function sanitize_variable_quotes()
{
        if [ ! -z "$(echo "$1" | grep "^\s*[\"']" | grep "[\"']\s*$")" ]; then
                echo "$1" | sed "s/[^\"']*[\"']//" | sed "s/\(.*\)[\"'].*/\1/"
        else
                echo "$1"
        fi
}

### load_cfg_file_variable
#
# Parametrization:
#  $1 path of the configuration file
#  $2 name of the variable to load
# Returns: value of the variable in the file, if it exits and is defined
function load_cfg_file_variable()
{
        local val="$(grep "^\s*$2\s*\=" "$1" | awk -F = '{print $2}')"
        if [ -z "$val" ]; then
                return 1
        fi
        echo "$(sanitize_variable_quotes "$val")"
}

### check_dependencies
#
# Parametrization:
#  $1 dependancies to check
# Returns: exit aka return code (0/success or 1/failure)
function check_dependencies()
{
	local error=0
	for dependency in $@; do
		printf " - $dependency: "
		if [ $(which $dependency) ]; then
        		echo "OK"
		else
        		echo "Check failed, please install."
			error=1
		fi
	done
	return $error
}

### confirm
#
# Parametrization:
#  $1 question
# Retuns: exit aka return code (0/success or 1/failure)
function confirm()
{
	printf "$1 | Type 'y' to confirm, anything else to reject: "
	read -n 1 answer
	echo ""
	# shorthand for if [ "$answer" = "y" ] then; return 0; else return 1; fi 
	[ "$answer" = "y" ]
	return $?
}

##### Process
echo "**** $executable_logging_name installer ****"

# parameter check
has_config=1
if [ -z "$1" ] || [ ! -f "$1" ]; then
	echo "No path to a sendmail2mailgun configuration file (aka global configuration) provided as parameter. This sets the installer into configuration-file-less mode."
	echo "If this was not your intention, reject the confirmation below and re-run with the pattern"
	echo "       ${0}  path/to/configuration/file "
	echo "If you're new or simply want help creating a configuration, check out the template at ./configuration_templates/global.conf"
	confirm "Confirm configuration-file-less installation? "
	if [ $? -ne 0 ]; then
		echo "Aborting..."
		exit 1
	fi
	has_config=0
fi

echo "Dependency check:"
check_dependencies "$dependencies"
if [ $? -eq 1 ]; then
	echo "Dependency check failed, please install missing elements."
	exit 1
fi

if [ $has_config -eq 1 ]; then
	# make cfg filepath absolute if given as relative
	if [ $(echo "$1" | grep "^\s*/") ]; then
		main_cfg_filepath="$1"
	else
		main_cfg_filepath="$(pwd)/$1"
		echo "Main configuration absolute filepath: $main_cfg_filepath"
	fi

	# get configuration values from files, properly formatted without enclosing single or double quotes
	mailgun_api_account_configurations_folder=$(load_cfg_file_variable "$main_cfg_filepath" "mailgun_api_account_configurations_folder")
	usecase_configurations_folder=$(load_cfg_file_variable "$main_cfg_filepath" "usecase_configurations_folder")
	log_filepath=$(load_cfg_file_variable "$main_cfg_filepath" "log_filepath")
fi

echo "Installation:"
if [ $has_config -eq 1 ]; then
	printf " - Mailgun API account configurations folder: "
	if [ ! -z "$mailgun_api_account_configurations_folder" ]; then
		echo  "set to $mailgun_api_account_configurations_folder"
		if [ ! -d "$mailgun_api_account_configurations_folder" ]; then
			mkdir -p "$mailgun_api_account_configurations_folder"
			echo "   Info: folder created"
		else
			echo "   Info: folder exists, nothing to do"
		fi
	else
        	printf "'mailgun_api_account_configurations_folder' in $main_cfg_filepath not set or empty.\n   Warning: $executable_logging_name will have to be called with the --api-acc-cfg-fp flag specifying the filepath of a Mailgun API account configuration, otherwise it will fail\n"
	fi

	printf " - Usecase configurations folder: "
	if [ ! -z "$usecase_configurations_folder" ]; then
        	echo  "set to $usecase_configurations_folder"
        	if [ ! -d "$usecase_configurations_folder" ]; then
                	mkdir -p "$usecase_configurations_folder"
                	echo "   Info: folder created"
        	else
                	echo "   Info: folder exists, nothing to do"
        	fi
	else
        	printf "'usecase_configurations_folder' in $main_cfg_filepath not set or empty.\n   Warning: $executable_logging_name will have to be called with the --uc-cfg-fp flag specifying the filepath of a usecase configuration, otherwise it will fail\n"
	fi

	printf " - Log filepath: "
	if [ ! -z "$log_filepath" ]; then
  		echo "set to $log_filepath"
	else
        	printf "configuration variable not set or empty. Logging will be disabled (can be overwritten on usecase basis and by the --log-filepath parameter)\n"
	fi
fi

echo " - Executable <=> main configuration link:"
final_configuration_filepath="$main_cfg_filepath"
if [ $has_config -eq 1 ]; then
	script_load_instruction_filepath="$default_main_configuration_filepath"
else
	script_load_instruction_filepath=""
fi

if [ ! -z "$script_load_instruction_filepath" ] && [ ! "$final_configuration_filepath" = "$script_load_instruction_filepath" ]; then
	echo "   Currently, the configuration is not where $executable_logging_name expects it."
	echo "   Expected: $default_main_configuration_filepath, Current: $main_cfg_filepath"
	echo "   Options:"
	echo "     (1) move configuration from current to expected location"
	echo "     (2) keep the current location (adapts $executable_logging_name's \"configuration load\" instruction)"
	echo "     (3) choose yet another path (combination of (1) and (2))"
	printf "   Answer: "
	while true; do
		read -n 1 -s answer
		# protection against wrong answers - if f.ex. a char is entered, the other ifs complain because of type mismatch
		if ! [[ "$answer" =~ ^[1-3]$ ]]; then
			continue
		fi
		if [ "$answer" -eq 1 ]; then
			echo 1
			final_configuration_filepath="$script_load_instruction_filepath"
			break
		fi
		if [ "$answer" -eq 2 ]; then
			echo 2
			script_load_instruction_filepath="$final_configuration_filepath"
			break
		fi
		if [ "$answer" -eq 3 ]; then
			printf "3 | Path: "
			read path
			final_configuration_filepath="$path"
			script_load_instruction_filepath="$path"
			break
		fi
	done
fi

if [ ! -z "$final_configuration_filepath" ] && [ ! "$final_configuration_filepath" = "$main_cfg_filepath" ]; then
	cfg_file_folder="$(dirname "$final_configuration_filepath")"
	if [ ! -d "$cfg_file_folder" ]; then
		printf "   [Operation] Creating configuration file folder $cfg_file_folder: "
		mkdir_ret=$(mkdir -p "$cfg_file_folder" 2>&1)
		if [ $? -ne 0 ]; then
			echo "Error"
			echo "   mkdir error message: \"$mkdir_ret\""
			echo "   Please fix and re-run. Aborting..."
			exit 1
		fi
		echo "OK"
	fi
	printf "   [Operation] Moving configuration file $main_cfg_filepath to $final_configuration_filepath: "
	mv "$main_cfg_filepath" "$final_configuration_filepath"
	if [ $? -ne 0 ]; then
		echo "Error"
        fi
	echo "OK"
fi

if [ ! "$script_load_instruction_filepath" = "$default_main_configuration_filepath" ]; then
	if [ -z "$script_load_instruction_filepath" ]; then
		printf "   [Operation] Disabling $executable_logging_name \"configuration load\" instruction: "
	else
		printf "   [Operation] Adapting $executable_logging_name \"configuration load\" instruction to $script_load_instruction_filepath: "
	fi
	sed "s/^\s*configuration_filepath=\"\"/configuration_filepath=\"$script_load_instruction_filepath\"/" -i "$sendmail2mailgun_path"
	# TODO sed change
	# TODO check if successful
	echo "OK"
fi

# TODO make executable
# TODO protect configuration files
echo "Installer finished"
