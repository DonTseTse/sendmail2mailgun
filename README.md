# Introduction
`sendmail2mailgun` is a bash script handling sendmail input to send mails over [Mailgun](https://www.mailgun.com/)'s 
HTTP API. It can be a useful alternative ...
- if the usual mailing infrastructure is not available or desirable, f.ex. in containerized environments
- to avoid the hassle of mail client configuration and mail log monitoring
`sendmail2mailgun` just needs a keyfile with the API key for the Mailgun account and it's ready to go. 

Mailgun's API gives the advantage to have a definitive return status: a successful request is guaranteed to lead to a mail 
delivery attempt - hence, if it's used with known recipients where mail bounces are not a problem (f.ex. system 
notifications to a set of admin email adresses), it can be used without further monitoring. 

The sendmail format encodes the mail variables as `<key>:<value>` headers, with everything else beeing the mail body: 
```
From: <Identity>sender@example.com
To: receiver@example.com
Subject: This is a mail
This is the mail body.
```  
`sendmail2mailgun` expects it as piped input:
```
printf "From: ...\nTo: ...\nSubject:...\nMail body" | sendmail2mailgun
```
To log into the Mailgun API, `sendmail2mailgun` needs the domain and key. For security reasons the key can't be a runtime parameter 
(visibility in the logs), it has to be provided through a file. 

The formal usage description is:
```
... | sendmail2mailgun [flags] [recipient_string]
```
where the optional `recipient_string` is a email address or a comma separated list of several email addresses. Flags
are explained in the [dedicated section](#flags).  

# Configuration
`sendmail2mailgun`'s configuration options are:
- Mailgun API account settings: domain + key
- Log filepath and logging levels
- Mailing defaults: sender, recipient(s), subject
- cURL timeouts: globally, for connection setup

`sendmail2mailgun` is able to work in two different modes:
- the "configuration file less" (called runtime) mode: the only file used is the keyfile for the Mailgun API account. 
  The flags `--domain <domain> --keyfile <filepath>` are compulsory. The keyfile should contain the Mailgun API key
  without any decoration. 
- the normal file-based mode, with a global configuration file and possible further ramifications

The default mode can be selected at installation time and it can be overwritten at runtime with:
- `--cfg <filepath>` to switch to normal mode and read `filepath` as global configuration file
- `--cfg ""` to switch to runtime mode

## File-based configuration
To be able to adapt the file-based configuration easily to different contexts and/or several Mailgun API accounts, the global 
configuration may be extended with **usecase configurations**. These replicate and overwrite the global configuration and add a 
usecase name which can be useful in log analytics. Likewise, in case several Mailgun API accounts are (re)used accross the different 
configuration files, these may stored in dedicated files and addressed by name.

Every configuration file type is explained in detail below, templates may be found [here](./configuration_templates)

### Global configuration
The path of the global configuration file is determined by, in order of precendence:
- the `--cfg <filepath>` runtime flag
- the default path set on installation if a file-based configuration was chosen

A global configuration may define:
- `mailgun_domain` and `mailgun_api_key`
- `log_filepath` and `log_level`
- `default_sender`, `default_recipient`, `default_subject`
- `usecase_configurations_folder`
- `mailgun_api_account_configurations_folder`
- `curl_connection_timeout` and `curl_timeout`

`usecase_configurations_folder` and `mailgun_api_account_configurations_folder` are used to locate the respective configuration 
files, explained in the sections below. 

### Usecase configurations
The filepath of a usecase configuration file is determined by, in order of precedence:
- the `--uc-cfg <filepath>` runtime flag
- the `--uc <name>` runtime flag - in this case, the filepath is `usecase_configurations_folder/<name>.conf` where 
  `usecase_configurations_folder` is defined in the global configuration file
- if `usecase_configurations_folder` is defined and there's only a single `.conf` file in it, this one is used

A usecase configuration file may define:
- `name`: useful for log analytics if a single global log is used
- `mailgun_domain` and `mailgun_api_key`
- `log_filepath` and `log_level`
- `default_sender`, `default_recipient`, `default_subject`
- `mailgun_api_account_name` in case [Mailgun API account configurations](#mailgun-api-account-configurations) are used
- `curl_connection_timeout` and `curl_timeout`
 
### Mailgun API account configurations
The filepath of a Mailgun API account configuration file is determined by, in order precedence
- the `--mg-cfg <filepath>` runtime flag
- if a usecase configuration specifies a `mailgun_api_account_name` and the global configuration defines a 
  `mailgun_api_account_configurations_folder`, the path is `<mailgun_api_account_name>.conf` in that folder
- if `mailgun_api_account_configurations_folder` is defined in the global configuration file and there's only a single `.conf` file
  in this folder, this one is used  

A Mailgun API account configuration should define:
- `domain`
- `key`

## Flags
The part of `sendmail2mailgun --help` about flags:
```
--cfg <filepath>            Global configuration filepath
--domain <domain>           Mailgun API account domain
--help                      Print this message and quit
--html                      HTML mail body (default: text)
--keyfile <filepath>        Mailgun API account key filepath
--log-file <filepath>       Log filepath
--log-level <level>         Level for file logging
--mg-cfg <filepath>         Mailgun API account configuration filepath
--test                      Enable test mode
--uc-cfg <filepath>         Usecase configuration filepath
--uc <name>                 Name of the usecase configuration
-v                          Enable stdout logging, level 1
--vv                        Enable stdout logging, level 2
```

# Logging
`sendmail2mailgun` provides fully configurable logging capabilities. It's able to handle stdout and file logging each with their own 
logging level.

By default, stdout logging is disabled (`stdout_log_level` set to 0) and file logging is disabled as long as no `log_filepath` is set. 
`log_level` defaults to 1. Have a look at the [internals](#internals), section "Logging", to see the different ways this can be 
configured. 

# Internals
An overview of the internal parameter set and how the configurations apply - by order of precedence: 

Mail
- `sender` / `recipient` / `subject`:
	+ extracted from the sendmail input (the details, especially regarding multiple recipients, are given 
	[here](#sendmail-format-processing-details--multiple-recipients)
	+ `default_<x>`, where `x` is `sender` / `recipient` / `subject`, from a usecase configuration
	+ `default_<x>` from the global configuration
- `mail_body`: extracted from the sendmail input
- `mail_uses_html_body`: defaults to 0/false for a text body. Enable with the flag `--html`

Mailgun API account
- `domain`
	+ `--domain <domain>`
	+ `domain` in a Mailgun account configuration
	+ `mailgun_api_account_domain` in the usecase configuration
	+ `mailgun_api_account_domain` in the global configuration
- `api_key`
	+ content of the file referenced by `--keyfile <filepath>`
	+ `key` in a Mailgun account configuration
	+ `mailgun_api_account_key` in the usecase configuration
	+ `mailgun_api_account_key` in the global configuration

Logging 
- `log_filepath`: 
	+ `--log-file <filepath>` flag
	+ `log_filepath` in the usecase configuration
	+ `log_filepath` in the global configuration
- `log_level`: defaults to 1 (normal logging)
	+ `--log-level <level>` flag
	+ `log_level` in the usecase configuration
	+ `log_level` in the global configuration
- `stdout_log_level`: defaults to 0/disabled. The flag `-v` sets it to 1, `-vv` to 2

Configuration filepaths
- `configuration_filepath`: explained in the [dedicated section](#global-configuration)
- `usecase_configuration_filepath`: explained in the [dedicated section](#usecase-configurations)
- `mailgun_api_account_configuration_filepath`: explained in the [dedicated section](#mailgun-api-account-configurations)

cURL settings
- `curl_connection_timeout`
	+ `curl_connection_timeout` in the usecase configuration
	+ `curl_connection_timeout` in the global configuration
- `curl_timeout`
	+ `curl_timeout` in the usecase configuration
	+ `curl_timeout` in the global configuration

## Sendmail format processing details | Multiple recipients
`sendmail2mailgun` looks at the beginning of the piped input, line by line, as long as it finds header matches. As soon
as there's no match, that line and any subsequent ones are considered to be the mail's body. If there's 
more than one *From* and/or *Subject* headers, the last one (higher line number) will prevail. Multiple *To* headers 
are cumulated to build a comma separated email address list. The *To* headers themselves can be such lists. Recipients
provided on the CLI (last parameter) and those provided as sendmail headers are aggregated; there's no duplicate check. 

# How To
- clone this repository
- decide which configuration mode you wish to use (see the [configuration section](#configuration) for details)
- create a first configuration, either:
	+ a file with the Mailgun API key written into it. The key can be found in the Mailgun web interface. This allows to run
	  sendmail2mailgun just with `--domain <domain> --keyfile <filepath>` flags, no further configuration (files) needed
	+ a global configuration (template provided in [configuration_templates/global.conf](configuration_templates/global.conf)
- protect this file (and any other with API keys)  with appropriate permissions

Keyfile
- run `installer.sh`, it will just check dependancies and give a few advices

Global configuration
- run `installer.sh path/to/config.file` and follow the instructions on screen

# TODO
- implement tests
- improve installer

# License

Written in 2018 by [DonTseTse](https://github.com/DonTseTse/).

Licensed under the LGPL, Version 3.0
