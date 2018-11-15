#! /bin/bash

# bash built-ins used: read
# not checked: echo
dependencies="pwd grep printf sed egrep awk head tr cat curl"

executable_logging_name="sendmail2mailgun"
sendmail2mailgun_path="./emulator.sh"

# TODO
# 2 - add check that sendmail2mailgun_path exists
# future - add dry run mode

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
	local dependency
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
	echo "No path to a $executable_logging_name configuration file (aka global configuration) provided as parameter."
	echo "This sets the installer to configure $executable_logging_name in configuration-file-less mode."
	echo "If this was not your intention, reject the confirmation below and re-run with the pattern"
	echo "       ${0}  path/to/configuration.file "
	echo "A template may be found at ./configuration_templates/global.conf."
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
		#echo "Global configuration absolute filepath: $main_cfg_filepath"
	fi
	echo "Global configuration $main_cfg_filepath used"
	# get configuration values, properly formatted without enclosing single or double quotes
	mailgun_api_account_configurations_folder=$(load_cfg_file_variable "$main_cfg_filepath" "mailgun_api_account_configurations_folder")
	usecase_configurations_folder=$(load_cfg_file_variable "$main_cfg_filepath" "usecase_configurations_folder")
	log_filepath=$(load_cfg_file_variable "$main_cfg_filepath" "log_filepath")
fi

if [ $has_config -eq 1 ]; then
echo "Installation:"
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

	echo " - Executable <=> main configuration link:"
	echo "   If you want this global configuration to be loaded by default, this installer can adapt $sendmail2mailgun_path to do so"
	echo "   Do you want this and if yes, shall it stay at the current location $main_cfg_filepath or be moved?"
	echo "   Options:"
	echo "     ( ) set as default global configuration at ..."
	echo "          (1) the current location"
	echo "          (2) another location (file will be moved)"
	echo "     (3) don't set as default global configuration"
	echo "   Please be aware that option (3) sets $executable_logging_name in \"configuration-file less\" mode which requires the flag --cfg <filepath>"
	echo "   to indicate a global configuration"
	printf "   Answer: "
	while true; do
		read -n 1 -s answer
		# protection against wrong answers - if f.ex. a char is entered, the other ifs complain because of type mismatch
		if ! [[ "$answer" =~ ^[1-3]$ ]]; then
			continue
		fi
		if [ "$answer" -eq 1 ]; then
			echo 1
			script_load_instruction_filepath="$main_cfg_filepath"
			break
		fi
		if [ "$answer" -eq 2 ]; then
			printf "2 | Path: "
			read path
			final_configuration_filepath="$path"
			script_load_instruction_filepath="$path"
			break
		fi
		if [ "$answer" -eq 3 ]; then
			echo 3
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
	if [ -f "$final_configuration_filepath" ]; then
		echo "Error"
		echo "  $final_configuration_filepath exists, won't overwrite. Aborting..."
		exit 1
	fi
	mv "$main_cfg_filepath" "$final_configuration_filepath"
	if [ $? -ne 0 ]; then
		echo "Error"
		exit 1
        fi
	echo "OK"
fi

if [ ! -z "$script_load_instruction_filepath" ]; then
	printf "   [Operation] Adapting $executable_logging_name \"configuration load\" instruction to $script_load_instruction_filepath: "
	sed  "s#^configuration_filepath=\"\"#configuration_filepath=\"$script_load_instruction_filepath\"#" -i "$sendmail2mailgun_path"
	echo "OK"
fi

# TODO make executable
# TODO protect configuration files
echo "Installer finished"
echo "IMPORTANT: protect the configuration/keyfile holding the Mailgun API keys with appropriate permissions - their access should be restricted to the user running $executable_logging_name"
echo "You may also want to make $sendmail2mailgun_path executable and link/copy into somewhere into \$PATH($PATH) to be able to execute it globally"
if [ $has_config -eq 0 ]; then
	echo ""
	echo "${executable_logging_name}'s flags are documented at https://github.com/DonTseTse/sendmail2mailgun/#flags"
	echo "In configuration-file-less mode, --domain <domain> and --keyfile <keyfile>, are compulsory, make sure to check out https://github.com/DonTseTse/sendmail2mailgun/#configuration"
fi
