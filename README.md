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
To log into the Mailgun API, `sendmail2mailgun` needs the domain and key. For security reasons the key can't be a runtime parameter 
(visibility in the logs), it has to be provided through a file. 

# Configuration
`sendmail2mailgun`'s configuration options are:
- Mailgun API account settings: domain + key
- Log filepath and logging levels
- Mailing defaults: sender, recipient(s), subject

`sendmail2mailgun` is able to work in two different modes:
- the "configuration file less" - called runtime - mode: the only file used is the keyfile for the Mailgun API. The flags 
  `--domain <domain> --keyfile <filepath>` are compulsory
- the normal file-based mode, with a global configuration file and possible further ramifications

The default mode can be selected at installation time and it can be overwritten at runtime with:
- `--cfg <filepath>` to switch to normal mode and read `filepath` as global configuration file
- `--cfg ""` to switch to runtime mode

## File-based configuration
In normal mode, `sendmail2mailgun` loads the global configuration file (`--cfg` flag overwrites default location). To be able to adapt 
the file-based configuration easily to different contexts and/or several Mailgun API accounts, the global configuration may be extended 
with **usecase configurations**. These replicate and overwrite the global configuration and add a usecase name which can be useful in 
log analytics. Likewise, in case several Mailgun API accounts are (re)used accross the different configuration files, these may stored 
in dedicated files and addressed by name.

Every configuration file type is explained in detail below, templates may be found [here](blob/master/configuration_templates)

### Global configuration
The path of the global configuration file is determined by, in order of precendence:
- the `--cfg <filepath>` runtime flag
- the default path set on installation if a file-based configuration was chosen

A global configuration may define:
- `mailgun_domain` and `mailgun_api_key`
- `log_filepath` and `logging_level`
- `default_sender`, `default_recipient`, `default_subject`
- `usecase_configurations_folder`
- `mailgun_api_account_configurations_folder`

`usecase_configurations_folder` and `mailgun_api_account_configurations_folder` are used to locate the respective configuration 
files, explained in the sections below. 

### Usecase configurations
The filepath of a usecase configuration file is determined by, in order of precedence:
- the `--uc-cfg <filepath>` runtime flag
- the `-uc <name>` runtime flag - in this case, the filepath is `usecase_configurations_folder/<name>.conf` where 
  `usecase_configurations_folder` is defined in the global configuration file
- if `usecase_configurations_folder` is defined and there's only a single `.conf` file in it, this one is used

A usecase configuration file may define:
- `name`: useful for log analytics if a single global log is used
- `log_filepath` and `logging_level`
- `default_sender`, `default_recipient`, `default_subject`
- `mailgun_api_account_name`
 
### Mailgun API account configurations
The filepath of a Mailgun API account configuration file is determined by, in order precedence
- the `--mg-cfg <filepath>` runtime flag
- if a usecase configuration specifies a `mailgun_api_account_name` and the global configuration defines a 
  `mailgun_api_account_configurations_folder`, the path is `<mailgun_api_account_configurations_folder>/<mailgun_api_account_name>`
- if `mailgun_api_account_configurations_folder` is defined in the global configuration file and there's only a single `.conf` file
  in this folder, this one is used  

A Mailgun API account configuration should define:
- `domain`
- `key`

## Flags
Part of the output of `sendmail2mailgun --help`:
```

```

# Logging
`sendmail2mailgun` provides fully configurable logging capabilities. It's able to handle stdout and file logging (to `log_filepath`), 
each with their own logging level.

By default, stdout logging is disabled, use the flag `-v` to enable it, `-vv` to raise verbosity. File logging is disabled as long
as no `log_filepath` is set. By default, the file `logging_level` defaults to 1 and may be overwritten in the global or usecase
configuration and through the runtime flag `--log-level <level>` 

# Internals
An overview of the internal parameter set and how the configurations apply - by order or precedence: 

Mail
- `sender` / `recipient` / `subject`:
	+ extracted from the sendmail input
	+ `default_<x>`, where `x` is `sender` / `recipient` / `subject`, from a usecase configuration
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
- `configuration_filepath`: explained in the [section](#file-based-configuration)
- `usecase_configuration_filepath`: explained in the [section](#usecase-configurations)
- `mailgun_api_account_configuration_filepath`: explained in their [section](#mailgun-api-account-configurations)

## Sendmail format processing details | Multiple recipients
TODO

# Installer
TODO 
By default, installs global configurtion to `/etc/sendmail2mailgun/main.conf`
