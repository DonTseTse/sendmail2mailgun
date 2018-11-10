#! /bin/bash

function log()
{
	while read -r line; do
		if [ $verbose -eq 1 ]; then
			printf "%s\n" "${line}"
		fi
		printf "[$mail_id] $line\n" >> "$log_filepath"
	done <<< "$1"
}

function processLoggingBacklog()
{
	for index in ${!log_cache[*]}; do
        	log "${log_cache[$index]}"
	done
}


function trim()
{
	local input
	if [ ! -z "$1" ]; then
		input="$1"
	else
		input="$(cat)"
	fi
	echo "$input" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

function process_sendmail_format()
{
	local nb_headers=0
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
	log "$nb_headers headers found, extracting mail body"
	if [ $nb_headers -gt 0 ]; then
		mail_body="$(echo "${!1}" | tail -n +$((nb_headers+1)))"
	else
		mail_body="${!1}"
	fi
}

function handle_sendmail_format_header()
{
	type="$(echo "$1" | awk -F ':' '{print $1}' | trim)"
	value="$(echo "$1" | awk -F: '{st=index($0,":"); print substr($0,st+1)}')"

	case "$type" in
		"Subject" )
			log "Found 'Subject' header with value $value"
			subject="$value"
		;;
		"To" )
			log "Found 'To' (aka recipient) header with value $value"
			recipients[${#recipients[*]}]="$value"
		;;
		"From" )
			log "Found 'From' (aka sender) header with value $value"
			sender="$value"
		;;
		* )
			log "Warning: Unknown header type '$type' with value '$value'. Discarded"
			#Date header are not handled
		;;
	esac
}

##### Preparation
# Default parameters
verbose=0
mail_uses_html_body=0
log_cache=()
recipients=()

# Random ID for the mail to be able to distinguish interleaving log entries if several processes run in parallel
mail_id=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 13 ;)
# no logging here, it's not available yet => the log line is after the parameter processing below
log_cache[0]="----- New mail $mail_id ----- "
log_cache[1]="application: $application_name - timestamp: "$(date +"%d-%m-%Y %T")

# Parameter processing
parameter_idx=0
flag_value_counter=0
for parameter in "$@"; do
	if [ $flag_value_counter -gt 0 ]; then
		((flag_value_counter--))
		continue
	fi
	case "$parameter" in
		"-v" )
			verbose=1
			log_cache[${#log_cache[*]}]="CLI verbose mode enabled"
		;;
		"-html" )
			mail_uses_html_body=1
			log_cache[${#log_cache[*]}]="HTML mail body requested"
		;;
		"-help" )
			echo "Usage: <command> | sendmail_emulator.sh [<flags>][<recipient>]"
			echo "  where - <command>: a program which writes the mail in sendmail format on stdout, like  printf or echo. See the example"
			echo "        - <flags> (optional): explained below"
			echo "        - <recipient> (optional): a email address or a comma separated list of several email addresses"
			echo "Flags:"
			echo " -v	CLI verbose mode"
			echo " -html	HTML mail body (default: text)"
			echo ""
			echo "Examples:"
			echo " - A simple mail"
			echo "   printf \"From:<sender@example.com>\nTo:<recipient@example.com>\nSubject:A mail!\nThis is the mail body.\" | sendmail_emulator.sh"
			exit 0
		;;
		* )
			if [ $parameter_idx -eq $(($#-1)) ]; then
				recipients[0]="$parameter"
				log_cache[${#log_cache[*]}]="Recipient '$recipient' set via CLI parameter"
			else
				processLoggingBacklog
				log "Error: Unknown CLI parameter '$parameter'. Aborting..."
				exit 1
			fi
		;;
	esac
	((parameter_idx++))
done

# Logging is now set up since the conditions "mail ID set" + "verbose's value known" are fulfilled => the cached backlog can be completed
processLoggingBacklog

# Pipe check
if [ ! -p /dev/stdin ]; then
        log "No piped input, aborting. Run the script with the flag --help to get usage details"
        exit 1
fi
piped_input="$(cat)"

##### Process
process_sendmail_format "piped_input"
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
log "----- Mail $mail_id finished -----"
