#! /bin/bash

# TODO
# - user / permission aspects, check for file read/write

##### Configuration
# configuration_filepath: default filepath of the global configuration, set by the installer
configuration_filepath=""

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

### handle_configuration_value_load
#
# Parametrization
#  $1 path of the configuration file
#  $2 variable name in file
#  $3 (optional) variable name in script - if omitted, $2 is used
#  $4 (optional) secret mode, how many characters of the secret are shown
function handle_configuration_value_load()
{
	local script_varname="${3:-$2}"
	#echo "script varname: $script_varname - 2: $2 - 3: $3"
        local val="$(load_cfg_file_variable "$1" "$2")"
        if [ ! -z "$val" ]; then
		# This bit weird cmd is required to force the creation of a global variable, not a local one (like "declare") 
		# See https://stackoverflow.com/questions/9871458/declaring-global-variable-inside-a-function
		IFS="" read $script_varname <<< "$val"
		if [ ! -z "$4" ]; then
			val="[Secret - begins with $(echo "$val" | cut -c1-5)]"
		fi
		log " - $script_varname set to '$val' (applying '$1', field '$2')" 2
        fi
}

### load_configuration_profile
#
# Parametrization
# $1 path of the configuration file
function load_configuration_profile()
{
	# Mailgun account
	handle_configuration_value_load "$1" "mailgun_domain" "domain"
	handle_configuration_value_load "$1" "mailgun_api_key" "api_key" 5
	# Mailing defaults
	handle_configuration_value_load "$1" "default_sender"
	handle_configuration_value_load "$1" "default_recipient"
	handle_configuration_value_load "$1" "default_subject"
	# Logging
	handle_configuration_value_load "$1" "log_filepath"
	handle_configuration_value_load "$1" "log_level"
	# cURL
	handle_configuration_value_load "$1" "curl_connection_timeout"
	handle_configuration_value_load "$1" "curl_timeout"
}


### log
# Logging helper with support for prefix-aware multi-line output and independent stdout and file
# output handling
#
# Parametrization:
#  $1 message to log
#  $2 (optional) log level - if omitted, defaults to 1
#  $3 (optional) output restriction - if omitted, both output channels are used
#     - "file" avoids stdout write even if $stdout_logging is enabled
#     - "stdout" avoid file logging even if $log_filepath is set
# Globals used: $stdout_logging, $run_id, $log_filepath
function log()
{
	local msg_log_level="${2:-1}"
	local line
	# IFS set to whitespace preservation
	while IFS='' read -r line; do
		# log caching if logging is not available
		if [ "$logging_available" -eq 0 ]; then
                	if [ ! -z "$logging_backlog" ]; then
                        	logging_backlog[${#logging_backlog[*]}]="$line|$2|$3"
                	else
                        	logging_backlog[0]="$line|$2|$3"
                	fi
			continue
        	fi
		if [ ! -z "$stdout_log_level" ] && [ "$stdout_log_level" -ge $msg_log_level ] && [ ! "$3" = "file" ]; then
			printf '%s\n' "${line}"
			#printf "$line\n" can lead to string interpretation. f.ex. if $line = '- a list item' it's going to complain printf: - : invalid option
		fi
		if [ ! -z "$log_filepath" ] && [[ "$log_level" =~ ^[0-9]+$ ]] && [ "$log_level" -ge $msg_log_level ] && [ ! "$3" = "stdout" ]; then
			printf "[$run_id] $line\n" >> "$log_filepath"
		fi
	done <<< "$1"
}

### launchLogging
# Processes the logging backlog and clears it
#
# Globals used: $logging_backlog
function launchLogging()
{
	logging_available=1
	local idx
	local backlog_entry
	local entry_output_resitriction
	local entry_log_level
	for idx in ${!logging_backlog[*]}; do
		backlog_entry="${logging_backlog[$idx]}"
		entry_output_restriction=$(echo "$backlog_entry" | sed 's/.*|//')
		backlog_entry=$(echo "$backlog_entry" | sed 's/\(.*\)|.*/\1/')
		entry_log_level=$(echo "$backlog_entry" | sed 's/.*|//')
		backlog_entry=$(echo "$backlog_entry" | sed 's/\(.*\)|.*/\1/')
		log "$backlog_entry" $entry_log_level $entry_output_restriction
	done
	logging_backlog=()
}

### trim
# Cut leading and trailing whitespace on either the provided parameter or the piped stdin
#
# Parametrization:
#  $1 (optional) string to trim. If it's empty trim tries to get input from a eventual stdin pipe
# Returns: trimmed input
# Usage:
#  - Input as parameter: trimmed_string=$(trim "$string_to_trim")
#  - Piped input: trimmed_string=$(echo "$string_to_trim" | trim)
function trim()
{
	local input
	if [ ! -z "$1" ]; then
		input="$1"
	else
		if [ -p /dev/stdin ]; then
			input="$(cat)"
		fi
	fi
	echo "$input" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

### process_sendmail_formatted_input
#
# Parametrization:
#  $1 sendmail formatted input
# Globals used: mail_body, those affected by handle_sendmail_format_header()
function process_sendmail_formatted_input()
{
	local nb_headers=0
	log "Looking for sendmail format headers" 2
	while read -r line; do
		local header_match="$(echo "$line" | egrep '^\s*[[:alnum:]]*:')"
		# important: after matches, there's one pass with a header_match=""
		if [ ! -z "$header_match" ]; then
			handle_sendmail_format_header "$header_match"
		else
			break
		fi
		((nb_headers++))
	done <<< "${!1}"
	if [ $nb_headers -gt 0 ]; then
		log "$nb_headers header(s) found, extracting mail body" 2
		mail_body="$(echo "${!1}" | tail -n +$((nb_headers+1)))"
	else
		log "No headers found, all input is mail body" 2
		mail_body="${!1}"
	fi
}

### handle_sendmail_format_header
#
# Parametrization:
#  $1 header line
# Globals used: $subject, $recipients array, $sender
function handle_sendmail_format_header()
{
	local type="$(echo "$1" | awk -F ':' '{print $1}' | trim)"
	local value="$(echo "$1" | awk -F: '{st=index($0,":"); print substr($0,st+1)}')"

	case "$type" in
		"Subject" )
			log " - found 'Subject' header with value $value" 2
			subject="$value"
		;;
		"To" )
			log " - found 'To' (aka recipient) header with value $value" 2
			recipients[${#recipients[*]}]="$value"
		;;
		"From" )
			log " - fund 'From' (aka sender) header with value $value" 2
			sender="$value"
		;;
		* )
			log " - Warning: Unknown header type '$type' with value '$value'. Discarded"
			#'Date' is not handled
		;;
	esac
}

### try_filepath_deduction
# If there's only a single file (match) in the folder $1, returns it
#
# Parametrization
#  $1 folder to search
#  $2 (optional) pattern - if omitted, defaults to * (= everything)
# Returns: filepath of the single match, if any
function try_filepath_deduction()
{
	local pattern="${2:-*}"
	local file_cnt=0
	if [ -d "$1" ]; then
		for filepath in "$1/"$pattern; do
			if [ -f "$filepath" ]; then
				single_file_path="$filepath"
				((file_cnt++))
			fi
			if [ $file_cnt -eq 2 ]; then
				return
			fi
		done
		echo "$single_file_path"
	fi
}

################################  Preparation  ################################
### Init internals
logging_available=0
log_level=1
stdout_log_level=0
logging_backlog=()
mail_uses_html_body=0
recipients=()
test_mode=0
executable_name="$(basename "$0")"
curl_connection_timeout=5
curl_timeout=15
# Random ID for the run to be able to distinguish interleaving log entries if several processes run in parallel
run_id=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 13 ;)
timestamp="$(date +"%d-%m-%Y %T")"
log "New run | ID in logs: $run_id - Timestamp: $timestamp" 1 stdout
log "New run, started $timestamp" 1 file

# Parameter processing
log "Processing parameters..." 2
parameter_idx=0
flag_value_counter=0
param_array=("$@")
for parameter in "$@"; do
	# required to handle flags that come with one or several values (pattern <flag> <value> [<value>]) - the counter is set by the flag handling and skips these values
	if [ $flag_value_counter -gt 0 ]; then
		((flag_value_counter--))
		((parameter_idx++))
		continue
	fi
	case "$parameter" in
		"--help" )
			echo "Usage: <command> | $executable_name [<flags>] [<recipient>]"
			echo "  where - <command>: a program which writes the mail in sendmail format on stdout, like  printf or echo. See the example"
			echo "        - <flags> (optional): explained below"
			echo "        - <recipient> (optional): a email address or a comma separated list of several email addresses"
			echo "Flags:"
			echo " --cfg <filepath>            Global configuration filepath"
			echo " --domain <domain>           Mailgun API account domain"
			echo " --help                      Print this message and quit"
			echo " --html                      HTML mail body (default: text)"
			echo " --keyfile <filepath>        Mailgun API account key filepath"
			echo " --log-file <filepath>       Log filepath"
			echo " --log-level <level>         Level for file logging"
			echo " --mg-cfg <filepath>         Mailgun API account configuration filepath"
			echo " --test                      Enable test mode"
			echo " --uc-cfg <filepath>         Usecase configuration filepath"
			echo " --uc <name>                 Name of the usecase configuration"
			echo " -v                          Enable stdout logging, level 1"
			echo " --vv                        Enable stdout logging, level 2"
			echo ""
			echo "Examples:"
			echo " - A simple mail"
			echo "   printf \"From:<sender@example.com>\nTo:<recipient@example.com>\nSubject:A mail!\nThis is the mail body.\" | $executable_name"
			echo ""
			exit 0
		;;
                "--html" )
			mail_uses_html_body=1
			log " - Flag --html: sets the mail body format to HTML" 2
		;;
		"--domain" )
			runtime_domain="${param_array[((parameter_idx+1))]}"
			log " - Flag --domain: Mailgun API account domain set to $runtime_domain" 2
			flag_value_counter=1
		;;
		"--keyfile" )
                        key_filepath="${param_array[((parameter_idx+1))]}"
                        log " - Flag --keyfile: Mailgun API account keyfile set to $key_filepath" 2
			flag_value_counter=1
		;;
		"--cfg" )
			configuration_filepath="${param_array[((parameter_idx+1))]}"
			log " - Flag --cfg: global configuration filepath set to $configuration_filepath" 2
			flag_value_counter=1
		;;
		"--mg-cfg" )
			mailgun_api_account_configuration_filepath="${param_array[((parameter_idx+1))]}"
			log " - Flag --mg-cfg: Mailgun API account configuration filepath set to $mailgun_api_account_configuration_filepath" 2
			flag_value_counter=1
		;;
		"--test" )
			test_mode=1
			log " - Flag --test: test mode enabled" 2
                ;;
		"--uc-cfg" )
			usecase_configuration_filepath="${param_array[((parameter_idx+1))]}"
			log " - Flag --uc-cfg: usecase configuration filepath set to $usecase_configuration_filepath" 2
			flag_value_counter=1
		;;
		"--uc" )
			usecase_name="${param_array[((parameter_idx+1))]}"
			log " - Flag --uc: usecase '$usecase_name' selected" 2
			flag_value_counter=1
		;;
		"-v" )
			stdout_log_level=1
		;;
		"--vv" )
			stdout_log_level=2
		;;
		"--log-file" )
			runtime_log_filepath="${param_array[((parameter_idx+1))]}"
			log " - Flag --log-file: logs go to $runtime_log_filepath" 2 stdout
			flag_value_counter=1
		;;
		"--log-level" )
			runtime_log_level="${param_array[((parameter_idx+1))]}"
			log " - Flag --log-level: log level set to $runtime_log_level" 2 stdout
			flag_value_counter=1
		;;
		* )
			if [ $parameter_idx -eq $(($#-1)) ]; then
				recipients[0]="$parameter"
				log "Recipient '$parameter' set via CLI parameter" 2
			else
				log "Error: Unknown CLI parameter '$parameter'"
			fi
		;;
	esac
	((parameter_idx++))
done

if [ $test_mode -eq 1 ]; then
	stdout_log_level=0
	log_level=0
	runtime_log_level=0
fi

# Load "main" configuration if applicable
log "Applying configurations..." 2
if [ ! -z "$configuration_filepath" ]; then
	if [ -f "$configuration_filepath" ]; then
		load_configuration_profile "$configuration_filepath"
		# "Subconfig" folders
		handle_configuration_value_load "$configuration_filepath" "mailgun_api_account_configurations_folder"
		handle_configuration_value_load "$configuration_filepath" "usecase_configurations_folder"
	else
		log "Error: configuration file '$configuration_filepath' not found"
	fi
fi

# Usecase configuration: if applicable, compute composed filepath
if [ -z "$usecase_configuration_filepath" ] && [ ! -z "$usecase_configurations_folder" ]; then
	if [ ! -z "$usecase_name" ]; then
		usecase_configuration_filepath="$usecase_configurations_folder/$usecase_name.conf"
	else
		usecase_configuration_filepath="$(try_filepath_deduction "$usecase_configurations_folder" *.conf)"
	fi
fi

# Load usecase configuration
if [ ! -z "$usecase_configuration_filepath" ]; then
	if [ -f "$usecase_configuration_filepath" ]; then
		load_configuration_profile "$usecase_configuration_filepath"
		handle_configuration_value_load "$usecase_configuration_filepath" "name" "usecase_name"
		handle_configuration_value_load "$usecase_configuration_filepath" "mailgun_api_account_name"
	else
		log "Error: usecase configuration '$usecase_configuration_filepath' not found"
	fi
fi

# Apply precedence of runtime over configuration file values
if [ ! -z "$runtime_log_filepath" ]; then
	log_filepath="$runtime_log_filepath"
fi
if [ ! -z "$runtime_log_level" ]; then
        log_level="$runtime_log_level"
fi

# At this point, the logging settings log_filepath, log_level and stdout_log_level are known => the cached backlog can be completed
launchLogging

# Mailgun API account configuration: if applicable, compute composed filepath
if [ -z "$mailgun_api_account_configuration_filepath" ] && [ ! -z "$mailgun_api_account_configurations_folder" ]; then
        if [ ! -z "$mailgun_api_account_name" ]; then
                mailgun_api_account_configuration_filepath="$mailgun_api_account_configurations_folder/$mailgun_api_account_name.conf"
        else
		mailgun_api_account_configuration_filepath="$(try_filepath_deduction "$mailgun_api_account_configurations_folder" *.conf)"
	fi
fi

# Mailgun API account configuration load
if [ ! -z "$mailgun_api_account_configuration_filepath" ]; then
	if [ -f "$mailgun_api_account_configuration_filepath" ]; then
		handle_configuration_value_load "$mailgun_api_account_configuration_filepath" "domain"
		handle_configuration_value_load "$mailgun_api_account_configuration_filepath" "api_key" "api_key" 5
	else
		log "Error: Mailgun API account configuration file '$mailgun_api_account_configuration_filepath' not found"
	fi
fi

if [ ! -z "$runtime_domain" ]; then
	domain="$runtime_domain"
fi
if [ ! -z "$keyfile" ]; then
	if [ -f "$keyfile" ]; then
		api_key=$(<"$keyfile")
	else
		log "Error: Mailgun API keyfile '$keyfile' not found"
	fi
fi

# Pipe check
if [ ! -p /dev/stdin ]; then
	stdout_log_level=1
        log "No piped input, aborting. Run the script with the flag --help to get usage details"
        exit 1
fi
piped_input="$(cat)"

# Minimal requirements
if [ -z "$domain" ] || [ -z "$api_key" ]; then
	stdout_log_level=1
	log "Mailgun API domain and/or key missing. Domain value: '$domain'. Unable to send without that, aborting..."
	exit 1
fi

################################  Process  ################################
process_sendmail_formatted_input "piped_input"
# process_sendmail_format() sets up $mail_body and, if the corresponding header are defined, $subject, $sender and the array $recipients
subject="${subject:-$default_subject}"
sender="${sender:-$default_sender}"
recipient[0]="${recipient[0]:-$default_recipient}"

# prepare Mailgun cURL request
request_mail_body_parameter_name="text"
if [ $mail_uses_html_body -eq 1 ]; then
	request_mail_body_parameter_name="html"
fi

recipient_string=""
for recipient in ${recipients[*]}; do
	recipient_string="$recipient,$recipient_string"
done
# remove last ','
recipient_string="${recipient_string%?}"

if [ -z "$sender" ] || [ -z "$recipient_string" ]; then
        stdout_log_level=1
        log "Sender and/or recipient(s) missing. Sender: '$sender', recipient(s): '$recipient_string'. Unable to send without that, aborting..."
        exit 1
fi

if [ $test_mode -eq 1 ]; then
	shortened_key="$(echo "$api_key" | cut -c1-5)"
	printf "curl -s -v --user \"api:[key, starts with $shortened_key...]\" --connect-timeout 10 \n https://api.mailgun.net/v3/$domain/messages\n -F from=\"$sender\"\n -F to=\"$recipient_string\"\n -F \"subject= $subject\"\n -F \"$request_mail_body_parameter_name= $mail_body\""
	echo ""
	exit 0
fi

# launch API request
curl_log_filepath="/tmp/sendmail2mailgun_${run_id}_curl.log"
log "Launching request... Domain: $domain | Sender: $sender | Recipient(s): $recipient_string" 2
curl_return=$(2>"$curl_log_filepath" curl -s -v --user "api:$api_key" --connect-timeout $curl_connection_timeout --max-time $curl_timeout \
     https://api.mailgun.net/v3/$domain/messages \
     -F from="$sender" \
     -F to="$recipient_string" \
     -F "subject= $subject" \
     -F "$request_mail_body_parameter_name= $mail_body" \
     -w "\n%{http_code}")
     # the variables are in a "parameter= $name" here and the blank after the '=' is important because if a value starts with a '<' that's
     # interpreted as a bash file operation and breaks everything

curl_status=$?
api_key=""

# process response
if [ $curl_status -eq 0 ]; then
	server_msg="$(echo "$curl_return" | sed '$d')"
	http_code="${curl_return##*$'\n'}"
	if [ $http_code -eq 200 ]; then
		log "Mailgun API request successful, server response: $server_msg"
	else
		log "Mailgun API request failed with HTTP status code $http_code, server response: $server_msg"
	fi
else
	log "Mailgun API request failed with cURL error code $curl_status. See https://ec.haxx.se/usingcurl-returns.html for error code signification"
	log "cURL output:"
	log "$(<"$curl_log_filepath")"
fi
rm "$curl_log_filepath"
log "Run finished" 1 file
