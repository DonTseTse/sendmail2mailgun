# Introduction
`sendmail2mailgun` is a bash script handling sendmail input to send mails over [Mailgun](https://www.mailgun.com/)'s 
HTTP API. It can be a useful alternative if the usual mailing infrastructure is not available or desirable. 

The sendmail format encodes the mail variables as `<key>:<value>` headers, with everything else beeing the mail body: 
```
From: <The Sender>sender@example.com
To: receiver@example.com
Subject: This is a mail
This is the mail body.
```  
`sendmail2mailgun` expects it as piped input:
```
printf "From: ...\nTo: ...\nSubject:...\nMail body" | sendmail2mailgun
```
To log into the Mailgun API, `sendmail2mailgun` needs the domain and key to use. For security reasons the key can't be a runtime 
parameter (visibility in the logs), it has to be provided through a file. 

# Configuration
`sendmail2mailgun`'s configuration options are:
- Mailgun API account settings: domain + key
- Log filepath and logging levels
- Mailing defaults: sender, recipient(s), subject

`sendmail2mailgun` is able to work in two different modes for greatest flexibility:
- the "configuration file less" - called runtime - mode: the only file used is the keyfile for the Mailgun API. The flags 
  `--domain <domain> --keyfile <filepath>` are compulsory
- the normal file-based mode, with a global configuration file and possible further ramifications

The default mode can be selected at installation time and it can be overwritten at runtime using:
- `--cfg <filepath>` to switch to normal mode and read `filepath` as global configuration file
- `--cfg ""` to switch it to runtime mode

## File-based configuration
In normal mode, `sendmail2mailgun` loads the global configuration file (`--cfg` flag overwrites default location). To be able to adapt 
the file-based configuration easily to different contexts and/or several Mailgun API accounts, the global configuration may be extended 
with **usecase configurations**. These replicate and overwrite the global configuration and add a usecase name which can be useful in 
log analytics. Likewise, in case several Mailgun API accounts are (re)used accross the different configuration files, these may stored 
in dedicated files and addressed by name.

Every configuration file type is explained in detail below, templates may be found [here](../blob/master/configuration_templates)

### Global configuration
Variable definitions:
- `mailgun_domain` and `mailgun_api_key`
- `log_filepath` and `logging_level`
- `default_sender`, `default_recipient`, `default_subject`
- `usecase_configurations_folder`
- `mailgun_api_account_configurations_folder`

`usecase_configurations_folder` and `mailgun_api_account_configurations_folder` are used to indicate where the respective configuration 
files are stored. 

### Usecase configurations
A usecase configuration file may either be specified by `--uc-cfg <filepath>` or using the flag `-uc <name>` if 
`usecase_configurations_folder` is defined in the global configuration file (the path beeing `usecase_configurations_folder/<name>.conf`)

Variable definitions:
- `name`: useful for log analytics if a single global log is used
- `log_filepath` and `logging_level`
- `default_sender`, `default_recipient`, `default_subject`
- `mailgun_api_account_name`
 
### Mailgun API account configurations
A Mailgun API account configuration file may either be specified by `--mg-api-acc-cfg <filepath>` or in the usecase definition using 
`mailgun_api_account_name` if `mailgun_api_account_configurations_folder` is defined in the global configuration file.

Variable definitions are taken into account in this type of file:
- `domain`
- `key`

# Logging
`sendmail2mailgun` provides fully configurable logging capabilities. It's able to handle stdout and file logging (to `log_filepath`), 
each with their own logging level.

By default, the `stdout_logging_level` is set to 0 (disabled), the `logging_level` to 1. 

# Internals
An overview of the internal parameter set and how the configurations apply - by order or precedence: 

Mail
- `sender` / `recipient` / `subject`:
        + extracted from the sendmail input
        + `default_<x>`, where x is `sender` / `recipient` / `subject`, from a usecase configuration
        + `default_<x>` from the global configuration
- `mail_body`: extracted from the sendmail input
- `mail_uses_html_body`: defaults to 0/false for a text body. Enable with the flag `--html`

Mailgun API account
- `domain`
        + `--domain <domain>`
        + `domain` in a Mailgun account configuration
        + `mailgun_api_account_domain` in the global configuration
- `api_key`
        + `--keyfile <filepath>`
        + `key` in a Mailgun account configuration
        + `mailgun_api_account_key` in the global configuration

Logging 
- `log_filepath`: 
	+ `--log-filepath <filepath>` flag
	+ in the usecase configuration
	+ in the global configuration
- `log_level`: defaults to 1 (normal logging)
	+ `--log-level <level>` flag
	+ in the usecase configuration
	+ in the global configuration
- `stdout_log_level`: defaults to 0/disabled. The flag `-v` set it to 1, `-vv` to 2

Configuration
- `configuration_filepath`: 
	+ `--cfg <filepath>`
	+ default set on installation

## Sendmail format processing details | Multiple recipients
TODO

# Installer
TODO 
By default, installs global configurtion to `/etc/sendmail2mailgun/main.conf`
