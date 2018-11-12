#! /bin/bash

#TODO:
# - functions: use local, shorten varnames

##### Configuration
configuration_filepath="/etc/sendmail2mailgun/main.conf"
emergency_log_path="/var/log/sendmail2mailgun_emergency.conf"

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
        local val=$(grep "^\s*$2\s*\=" "$1" | awk -F = '{print $2}')
        if [ -z "$val" ]; then
                return 1
        fi
        echo $(sanitize_variable_quotes "$val")
}

### log
# Logging helper with support for prefix-aware multi-line output and independent stdout and file
# output handling
#
# Parametrization:
#  $1 message to log
#  $2 (optional) output restriction
#     - "file" avoids stdout write even if $stdout_logging is enabled
#     - "stdout" avoid file logging even if $log_filepath is set
# Globals used: $stdout_logging, $run_id, $log_filepath
function log()
{
	local line
	# IFS set to whitespace preservation
	while IFS='' read -r line; do
		# log caching if logging is not available
		if [ "$logging_available" -eq 0 ]; then
                	if [ ! -z "$logging_backlog" ]; then
                        	logging_backlog[${#logging_backlog[*]}]="$line"
                	else
                        	logging_backlog[0]="$line"
                	fi
			continue
        	fi
		if [ ! -z "$stdout_log_level" ] && [ $stdout_log_level -gt 0 ] && [ ! "$2" = "file" ]; then
			printf '%s\n' "${line}"
			#printf "$line\n" can lead to string interpretation. f.ex. if $line = '- a list item' it's going to complain printf: - : invalid option
		fi
		if [ ! -z "$log_filepath" ] && [ ! "$2" = "stdout" ]; then
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
	for idx in ${!logging_backlog[*]}; do
        	log "${logging_backlog[$idx]}"
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
	log "Looking for sendmail format headers"
	while read -r line; do
		header_match="$(echo "$line" | egrep '^\s*[[:alnum:]]*:')"
		# important: after matches, there's one pass with a header_match=""
		if [ ! -z "$header_match" ]; then
			handle_sendmail_format_header "$header_match"
		else
			break
		fi
		((nb_headers++))
	done <<< "${!1}"
	if [ $nb_headers -gt 0 ]; then
		log "$nb_headers header(s) found, extracting mail body"
		mail_body="$(echo "${!1}" | tail -n +$((nb_headers+1)))"
	else
		log "No headers found, all input is mail body"
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
			log " - found 'Subject' header with value $value"
			subject="$value"
		;;
		"To" )
			log " - found 'To' (aka recipient) header with value $value"
			recipients[${#recipients[*]}]="$value"
		;;
		"From" )
			log " - fund 'From' (aka sender) header with value $value"
			sender="$value"
		;;
		* )
			log " - warning: Unknown header type '$type' with value '$value'. Discarded"
			#'Date' is not handled
		;;
	esac
}

### try_filepath_deduction
# If there's only a single file (match) in the folder $1, returns it
#
# Parametrization
#  $1 folder to search
#  $2 (optional) pattern
function try_filepath_deduction()
{
	if [ ! -z "$2" ]; then
		local pattern="$2"
	else
		local pattern="*"
	fi
	local file_cnt=0
	if [ -d "$1" ]; then
		for filepath in "$1/"$pattern; do
			#echo "fp: $filepath"
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
log_level=0
stdout_log_level=0
logging_backlog=()
mail_uses_html_body=0
recipients=()
# Random ID for the run to be able to distinguish interleaving log entries if several processes run in parallel
run_id=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 13 ;)
log "New run | ID: $run_id - Timestamp: $(date +"%d-%m-%Y %T")"

# Parameter processing
log "Processing parameters..."
parameter_idx=0
flag_value_counter=0
for parameter in "$@"; do
	# required to handle flags that come with one or several values (pattern <flag> <value> [<value>]) - the counter is set by the flag handling and skips these values
	if [ $flag_value_counter -gt 0 ]; then
		((flag_value_counter--))
		continue
	fi
	case "$parameter" in
		"-help" )
			echo "Usage: <command> | sendmail_emulator.sh [<flags>] [<recipient>]"
			echo "  where - <command>: a program which writes the mail in sendmail format on stdout, like  printf or echo. See the example"
			echo "        - <flags> (optional): explained below"
			echo "        - <recipient> (optional): a email address or a comma separated list of several email addresses"
			echo "Flags:"
			echo " -v	enable stdout logging"
			echo " -html	HTML mail body (default: text)"
			echo ""
			echo "Examples:"
			echo " - A simple mail"
			echo "   printf \"From:<sender@example.com>\nTo:<recipient@example.com>\nSubject:A mail!\nThis is the mail body.\" | sendmail_emulator.sh"
			exit 0
		;;
		"-v" )
                        stdout_log_level=1
                ;;
                "-html" )
                        mail_uses_html_body=1
                        log " - Flag -html: sets the mail body format to HTML"
                ;;
		"--cfg" )
			configuration_filepath="$@[((parameter_idx+1))]"
			flag_value_counter=1
		;;
		"--mg-api-acc-cfg" )
			mailgun_api_account_configuration_filepath="$@[((parameter_idx+1))]"
			flag_value_counter=1
		;;
		"--uc-cfg" )
                        usecase_configuration_filepath="$@[((parameter_idx+1))]"
			flag_value_counter=1
                ;;
		"--log-filepath" )
			runtime_log_filepath="$@[((parameter_idx+1))]"
			flag_value_conter=1
		;;
		"--log-level" )
			runtime_log_level="$@[((parameter_idx+1))]"
                        flag_value_conter=1
		;;
		* )
			if [ $parameter_idx -eq $(($#-1)) ]; then
				recipients[0]="$parameter"
				log "Recipient '$recipient' set via CLI parameter"
			else
				log "Error: Unknown CLI parameter '$parameter'."
			fi
		;;
	esac
	((parameter_idx++))
done

# Load "main" configuration if applicable
if [ ! -z "$configuration_filepath" ]; then
	if [ -f "$configuration_filepath" ]; then
		# log_filepath, only loaded if it was not defined as parameter
		if [ -z "$log_filepath" ]; then
        		log_filepath="$(load_cfg_file_variable "$configuration_filepath" "log_filepath")"
		fi
		# Mailgun account
		domain="$(load_cfg_file_variable "$configuration_filepath" "domain")"
        	api_key="$(load_cfg_file_variable "$configuration_filepath" "api_key")"
		# "Subconfig" folders
		mailgun_api_account_configurations_folder="$(load_cfg_file_variable "$configuration_filepath" "mailgun_api_account_configurations_folder")"
		usecase_configurations_folder="$(load_cfg_file_variable "$configuration_filepath" "usecase_configurations_folder")"
		# Mailing defaults - can be overwritten by a usecase configuration and runtime parameters
		default_sender="$(load_cfg_file_variable "$configuration_filepath" "default_sender")"
        	default_recipient="$(load_cfg_file_variable "$configuration_filepath" "default_recipient")"
        	default_subject="$(load_cfg_file_variable "$configuration_filepath" "default_subject")"
		log "Loaded configuration file '$configuration_filepath'"
	else
		log "Unable to load configuration file '$configuration_filepath'"
	fi
fi

# Usecase configuration: if applicable, compute composed filepath
if [ -z "$usecase_configuration_filepath" ] && [ ! -z "$usecase_configurations_folder" ]; then
	if [ ! -z "$usecase" ]; then
		usecase_configuration_filepath="$usecase_configurations_folder/$usecase.conf"
	else
		usecase_configuration_filepath="$(try_filepath_deduction "$usecase_configurations_folder" *.conf)"
		#try_filepath_deduction "$usecase_configurations_folder" *.conf
	fi
fi

# Load usecase configuration
if [ ! -z "$usecase_configuration_filepath" ]; then
	if [ -f "$usecase_configuration_filepath" ]; then
		usecase_name="$(load_cfg_file_variable "$usecase_configuration_filepath" "name")"
		mailgun_api_account_name="$(load_cfg_file_variable "$usecase_configuration_filepath" "mailgun_api_account_name")"
		log_filepath="$(load_cfg_file_variable "$usecase_configuration_filepath" "log_filepath")"
		default_sender="$(load_cfg_file_variable "$usecase_configuration_filepath" "default_sender")"
		default_recipient="$(load_cfg_file_variable "$usecase_configuration_filepath" "default_recipient")"
		default_subject="$(load_cfg_file_variable "$usecase_configuration_filepath" "default_subject")"
		log "Usecase configuration $usecase_configuration_filepath used. Usecase is called '$usecase_name'"
	else
		log "Unable to load usecase configuration '$usecase_configuration_filepath'"
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
#echo "API filepath: $mailgun_api_account_configuration_filepath"
#echo "API folder: $mailgun_api_account_configurations_folder"
if [ -z "$mailgun_api_account_configuration_filepath" ] && [ ! -z "$mailgun_api_account_configurations_folder" ]; then
        if [ ! -z "$mailgun_api_account_name" ]; then
                mailgun_api_account_configuration_filepath="$mailgun_api_account_configurations_folder/$mailgun_api_account_name.conf"
        else
		mailgun_api_account_configuration_filepath="$(try_filepath_deduction "$mailgun_api_account_configurations_folder" "*.conf")"
		#try_filepath_deduction "$mailgun_api_account_configurations_folder" *.conf
	fi
fi

# Mailgun API account configuration load
if [ ! -z "$mailgun_api_account_configuration_filepath" ]; then
	if [ -f "$mailgun_api_account_configuration_filepath" ]; then
		domain="$(load_cfg_file_variable "$mailgun_api_account_configuration_filepath" "domain")"
		api_key="$(load_cfg_file_variable "$mailgun_api_account_configuration_filepath" "api_key")"
		log "Mailgun API account configuration file '$mailgun_api_account_configuration_filepath' used. Domain: $domain"
	else
		log "Unable to load Mailgun API account configuration file '$mailgun_api_account_configuration_filepath'"
	fi
fi

# Pipe check
if [ ! -p /dev/stdin ]; then
        log "No piped input, aborting. Run the script with the flag --help to get usage details"
        exit 1
fi
piped_input="$(cat)"

# Minimal requirements
if [ -z "$domain" ] || [ -z "$api_key" ]; then
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
recipient_string="${recipient_string%?}"

# launch API request
log "Sender ('from'): $sender | Recipient(s) ('to'): $recipient_string"
curl_return=$(curl -s --user "api:$api_key" \
     https://api.mailgun.net/v3/$domain/messages \
     -F from="$sender" \
     -F to="$recipient_string" \
     -F "subject= $subject" \
     -F "$request_mail_body_parameter_name= $mail_body" \
     -w "\n%{http_code}")
     # the variables are in a "parameter= $name" here and the blank after the '=' is important because if a value starts with a '<' that's
     # interpreted as a bash file operation and breaks everything

# process response
server_msg="$(echo "$curl_return" | sed '$d')"
http_code="${curl_return##*$'\n'}"
if [ $http_code -eq 200 ]; then
	log "Mailgun API request successful, server response: $server_msg"
else
	log "Mailgun API request failed with HTTP status code $http_code, server response: $server_msg"
fi
log "Run $run_id finished" file
